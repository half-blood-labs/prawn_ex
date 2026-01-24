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

  def write(%Document{opts: opts, pages: pages, images: images}) do
    images = images || []
    page_size = Keyword.get(opts, :page_size, :a4)
    media_box = Units.page_size(page_size)

    image_ids_used = image_ids_from_pages(pages) |> Enum.uniq() |> Enum.sort()
    n_images = length(image_ids_used)

    image_id_to_pdf_id =
      image_ids_used
      |> Enum.with_index(3)
      |> Map.new(fn {img_id, pdf_id} -> {img_id, pdf_id} end)

    {body_io, all_ids} =
      build_body(pages, media_box, images, image_id_to_pdf_id, 3 + n_images)

    body = IO.iodata_to_binary(body_io)

    all_ids = [1, 2] ++ Map.values(image_id_to_pdf_id) ++ all_ids

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

  defp build_body(pages, media_box, images, image_id_to_pdf_id, next_id) do
    catalog_frag = "1 0 obj\n" <> Objects.catalog(2) <> "\nendobj\n"
    page_ids = collect_page_ids(pages, next_id)
    pages_frag = "2 0 obj\n" <> Objects.pages_tree(page_ids) <> "\nendobj\n"

    image_frags =
      Enum.map(Map.keys(image_id_to_pdf_id) |> Enum.sort(), fn id ->
        spec = Enum.at(images, id - 1)
        pdf_id = image_id_to_pdf_id[id]

        if spec && spec.filter in [:dct, :flate] do
          body = Objects.image_xobject(spec.width, spec.height, spec.data, filter: spec.filter)
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

        image_ids_on_page =
          (page.content_ops || [])
          |> Enum.filter(&match?({:image, _, _, _, _, _}, &1))
          |> Enum.map(fn {:image, id, _, _, _, _} -> id end)
          |> Enum.uniq()

        xobject_refs =
          Enum.map(image_ids_on_page, fn id -> {"Im#{id}", image_id_to_pdf_id[id]} end)

        resources =
          if xobject_refs == [],
            do: Objects.resources_font("Helvetica"),
            else: Objects.resources_font_and_xobject("Helvetica", xobject_refs)

        content_bin = ContentStream.build(page.content_ops || [])
        stream_body = Objects.stream_dict_and_data(content_bin)
        stream_frag = "#{content_id} 0 obj\n#{stream_body}\nendobj\n"

        annot_obj_frags = Enum.map(annot_frag_list, fn {_, f} -> f end)
        page_body = Objects.page(2, content_id, media_box, resources, annot_ids)
        page_frag = "#{page_id} 0 obj\n#{page_body}\nendobj\n"

        ids = [content_id] ++ annot_ids ++ [page_id]
        {acc_frags ++ [stream_frag] ++ annot_obj_frags ++ [page_frag], acc_ids ++ ids, next_id}
      end)

    body_iodata = [catalog_frag, pages_frag] ++ image_frags ++ page_frags
    {body_iodata, all_ids}
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
