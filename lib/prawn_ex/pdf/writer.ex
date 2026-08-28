defmodule PrawnEx.PDF.Writer do
  @moduledoc """
  Serializes a PrawnEx.Document to PDF 1.4 binary.

  Allocates object IDs, builds catalog → pages → page(s) → content stream(s),
  then emits body + xref + trailer.
  """

  alias PrawnEx.Document
  alias PrawnEx.PDF.{ContentStream, Objects}
  alias PrawnEx.Units

  @pdf_header "%PDF-1.4\n"
  @pdf_eof "\n%%EOF\n"

  @doc """
  Converts a Document to PDF binary.
  """
  @spec write(Document.t()) :: binary()
  def write(%Document{pages: []}),
    do: write(Document.add_page(%Document{pages: [], opts: [], images: []}))

  def write(%Document{opts: opts, pages: pages, images: images} = doc) do
    images = images || []
    fonts = doc.fonts || %{}
    page_size = Keyword.get(opts, :page_size, :a4)
    media_box = Units.page_size(page_size)

    image_ids_used = image_ids_from_pages(pages) |> Enum.uniq() |> Enum.sort()
    n_images = length(image_ids_used)

    image_id_to_pdf_id =
      image_ids_used
      |> Enum.with_index(3)
      |> Map.new(fn {img_id, pdf_id} -> {img_id, pdf_id} end)

    # Embedded fonts actually used anywhere get three objects each:
    # font program, descriptor, font dict.
    embedded_names =
      pages
      |> Enum.flat_map(&fonts_used_on_page(&1.content_ops || []))
      |> Enum.uniq()
      |> Enum.filter(&Map.has_key?(fonts, &1))
      |> Enum.sort()

    font_base = 3 + n_images

    embedded =
      embedded_names
      |> Enum.with_index()
      |> Enum.map(fn {name, i} ->
        base = font_base + i * 3
        {name, %{file_id: base, descriptor_id: base + 1, dict_id: base + 2}}
      end)
      |> Map.new()

    # One ExtGState object per distinct opacity used.
    alphas =
      pages
      |> Enum.flat_map(fn page ->
        for {:set_opacity, a} <- page.content_ops || [], do: a
      end)
      |> Enum.uniq()
      |> Enum.sort()

    gs_base = font_base + map_size(embedded) * 3

    gs_alloc =
      alphas
      |> Enum.with_index()
      |> Map.new(fn {a, i} -> {a, %{name: "GS#{i + 1}", id: gs_base + i}} end)

    {body_io, all_ids} =
      build_body(
        pages,
        media_box,
        images,
        image_id_to_pdf_id,
        gs_base + map_size(gs_alloc),
        fonts,
        embedded,
        gs_alloc
      )

    body = IO.iodata_to_binary(body_io)

    font_ids = Enum.flat_map(Map.values(embedded), &[&1.file_id, &1.descriptor_id, &1.dict_id])
    gs_ids = Enum.map(Map.values(gs_alloc), & &1.id)
    all_ids = [1, 2] ++ Map.values(image_id_to_pdf_id) ++ font_ids ++ gs_ids ++ all_ids

    offsets = compute_offsets(body, byte_size(@pdf_header), all_ids)
    xref = build_xref(offsets)
    startxref = byte_size(@pdf_header) + byte_size(body)
    size = length(offsets) + 1
    trailer = build_trailer(1, size, startxref)

    @pdf_header <> body <> xref <> trailer <> @pdf_eof
  end

  defp compute_offsets(body, base, ids) do
    # Each "n 0 obj" starts an object. Find position of each.
    Enum.map(ids, fn id ->
      pattern = "#{id} 0 obj"
      pos = :binary.match(body, pattern)

      case pos do
        {start, _} -> {id, base + start}
        :nomatch -> {id, base}
      end
    end)
  end

  defp image_ids_from_pages(pages) do
    Enum.flat_map(pages, fn page ->
      page.content_ops
      |> Enum.filter(&match?({:image, _, _, _, _, _}, &1))
      |> Enum.map(fn {:image, id, _, _, _, _} -> id end)
    end)
  end

  defp build_body(
         pages,
         media_box,
         images,
         image_id_to_pdf_id,
         next_id,
         fonts,
         embedded,
         gs_alloc
       ) do
    catalog_frag = "1 0 obj\n" <> Objects.catalog(2) <> "\nendobj\n"
    page_ids = collect_page_ids(pages, next_id)
    pages_frag = "2 0 obj\n" <> Objects.pages_tree(page_ids) <> "\nendobj\n"

    font_frags =
      embedded
      |> Enum.sort_by(fn {_, alloc} -> alloc.file_id end)
      |> Enum.flat_map(fn {name, alloc} ->
        %{data: data, metrics: metrics} = fonts[name]
        base_name = String.replace(name, ~r/[^A-Za-z0-9-]/, "")

        [
          "#{alloc.file_id} 0 obj\n" <> Objects.font_file2(data) <> "\nendobj\n",
          "#{alloc.descriptor_id} 0 obj\n" <>
            Objects.font_descriptor(base_name, metrics, alloc.file_id) <> "\nendobj\n",
          "#{alloc.dict_id} 0 obj\n" <>
            Objects.truetype_font(base_name, metrics.widths, alloc.descriptor_id) <> "\nendobj\n"
        ]
      end)

    gs_frags =
      gs_alloc
      |> Enum.sort_by(fn {_, %{id: id}} -> id end)
      |> Enum.map(fn {alpha, %{id: id}} ->
        "#{id} 0 obj\n" <> Objects.ext_gstate(alpha) <> "\nendobj\n"
      end)

    image_frags =
      Enum.map(Map.keys(image_id_to_pdf_id) |> Enum.sort(), fn id ->
        spec = Enum.at(images, id - 1)
        pdf_id = image_id_to_pdf_id[id]

        body =
          cond do
            spec == nil ->
              ""

            spec.filter == :dct ->
              Objects.image_xobject(spec.width, spec.height, spec.data, filter: :dct)

            spec.filter == :flate ->
              Objects.image_xobject(spec.width, spec.height, spec.data, filter: :flate)

            true ->
              ""
          end

        if body != "" do
          "#{pdf_id} 0 obj\n#{body}\nendobj\n"
        else
          ""
        end
      end)

    {page_frags, all_ids, _} =
      Enum.reduce(pages, {[], [], next_id}, fn page, {acc_frags, acc_ids, next_id} ->
        content_id = next_id
        next_id = next_id + 1

        annot_list = page.annotations || []

        {annot_frag_list, next_id} =
          Enum.map_reduce(annot_list, next_id, fn annot, id ->
            frag = annotation_frag(annot, id)
            {{id, frag}, id + 1}
          end)

        annot_ids = Enum.map(annot_frag_list, fn {id, _} -> id end)
        page_id = next_id
        next_id = next_id + 1

        font_names = fonts_used_on_page(page.content_ops || [])

        font_map =
          font_names
          |> Enum.with_index(1)
          |> Map.new(fn {name, i} -> {name, "F#{i}"} end)

        font_entries =
          font_names
          |> Enum.with_index(1)
          |> Enum.map(fn {name, i} ->
            case embedded do
              %{^name => alloc} -> {"F#{i}", {:ref, alloc.dict_id}}
              _ -> {"F#{i}", {:base14, name}}
            end
          end)

        page_alphas =
          for {:set_opacity, a} <- page.content_ops || [], uniq: true, do: a

        gs_refs = Enum.map(page_alphas, fn a -> {gs_alloc[a].name, gs_alloc[a].id} end)
        gs_map = Map.new(page_alphas, fn a -> {a, gs_alloc[a].name} end)

        image_ids_on_page =
          (page.content_ops || [])
          |> Enum.filter(&match?({:image, _, _, _, _, _}, &1))
          |> Enum.map(fn {:image, id, _, _, _, _} -> id end)
          |> Enum.uniq()

        xobject_refs =
          Enum.map(image_ids_on_page, fn id -> {"Im#{id}", image_id_to_pdf_id[id]} end)

        resources = Objects.resources(font_entries, xobject_refs, gs_refs)

        content_bin = ContentStream.build(page.content_ops || [], font_map, gs_map)
        stream_body = Objects.stream_dict_and_data(content_bin)
        stream_frag = "#{content_id} 0 obj\n#{stream_body}\nendobj\n"

        annot_obj_frags = Enum.map(annot_frag_list, fn {_, f} -> f end)
        page_body = Objects.page(2, content_id, media_box, resources, annot_ids)
        page_frag = "#{page_id} 0 obj\n#{page_body}\nendobj\n"

        ids = [content_id] ++ annot_ids ++ [page_id]
        {acc_frags ++ [stream_frag] ++ annot_obj_frags ++ [page_frag], acc_ids ++ ids, next_id}
      end)

    body_iodata =
      [catalog_frag, pages_frag] ++ image_frags ++ font_frags ++ gs_frags ++ page_frags

    {body_iodata, all_ids}
  end

  defp fonts_used_on_page(ops) do
    ops
    |> Enum.filter(&match?({:set_font, _, _}, &1))
    |> Enum.map(fn {:set_font, name, _} -> name end)
    |> Enum.uniq()
  end

  defp collect_page_ids(pages, start_id) do
    {ids, _} =
      Enum.reduce(pages, {[], start_id}, fn page, {acc, next_id} ->
        content_id = next_id
        n_annot = length(page.annotations || [])
        page_id = content_id + 1 + n_annot
        {acc ++ [page_id], page_id + 1}
      end)

    ids
  end

  defp annotation_frag(%{type: :link, rect: {x, y, w, h}, url: url}, id) do
    body = Objects.link_annotation(x, y, w, h, url)
    "#{id} 0 obj\n#{body}\nendobj\n"
  end

  defp build_xref(offsets) do
    # xref: object 0 is free; then objects 1..n in order by id
    sorted = Enum.sort_by(offsets, fn {id, _} -> id end)
    n = length(offsets) + 1
    header = "xref\n0 #{n}\n0000000000 65535 f \n"

    lines =
      Enum.map(sorted, fn {_id, pos} ->
        offset_str = String.pad_leading(Integer.to_string(pos), 10, "0")
        offset_str <> " 00000 n \n"
      end)

    header <> IO.iodata_to_binary(lines)
  end

  defp build_trailer(root_id, size, startxref) do
    "trailer\n<< /Size #{size} /Root #{root_id} 0 R >>\nstartxref\n#{startxref}\n"
  end
end
