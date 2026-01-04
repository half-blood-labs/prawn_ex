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

    n_pages = length(pages)
    # All image ids referenced in the doc (1-based)
    image_ids_used = image_ids_from_pages(pages) |> Enum.uniq() |> Enum.sort()
    n_images = length(image_ids_used)
    # PDF object IDs: 1=Catalog, 2=Pages, then image objs, then content streams and pages
    first_content_id = 3 + n_images
    content_ids = Enum.to_list(first_content_id..(first_content_id - 1 + n_pages))
    page_ids = Enum.to_list((first_content_id + n_pages)..(first_content_id + 2 * n_pages - 1))

    image_id_to_pdf_id =
      image_ids_used
      |> Enum.with_index(3)
      |> Map.new(fn {img_id, pdf_id} -> {img_id, pdf_id} end)

    {body_io, _} =
      build_body(page_ids, content_ids, pages, media_box, images, image_id_to_pdf_id)

    body = IO.iodata_to_binary(body_io)

    all_ids =
      [1, 2] ++
        Map.values(image_id_to_pdf_id) ++
        Enum.flat_map(Enum.zip([content_ids, page_ids]), fn {c, p} -> [c, p] end)

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

  defp build_body(page_ids, content_ids, pages, media_box, images, image_id_to_pdf_id) do
    catalog_frag = "1 0 obj\n" <> Objects.catalog(2) <> "\nendobj\n"
    pages_frag = "2 0 obj\n" <> Objects.pages_tree(page_ids) <> "\nendobj\n"

    image_frags =
      Enum.map(Map.keys(image_id_to_pdf_id) |> Enum.sort(), fn id ->
        spec = Enum.at(images, id - 1)
        pdf_id = image_id_to_pdf_id[id]

        if spec && spec.filter == :dct do
          body = Objects.image_xobject(spec.width, spec.height, spec.data, filter: :dct)
          "#{pdf_id} 0 obj\n#{body}\nendobj\n"
        else
          ""
        end
      end)

    page_frags =
      Enum.flat_map(Enum.zip([content_ids, page_ids, pages]), fn {content_id, page_id, page} ->
        image_ids_on_page =
          page.content_ops
          |> Enum.filter(&match?({:image, _, _, _, _, _}, &1))
          |> Enum.map(fn {:image, id, _, _, _, _} -> id end)
          |> Enum.uniq()

        xobject_refs =
          Enum.map(image_ids_on_page, fn id -> {"Im#{id}", image_id_to_pdf_id[id]} end)

        resources =
          if xobject_refs == [],
            do: Objects.resources_font("Helvetica"),
            else: Objects.resources_font_and_xobject("Helvetica", xobject_refs)

        content_bin = ContentStream.build(page.content_ops)
        stream_body = Objects.stream_dict_and_data(content_bin)
        stream_frag = "#{content_id} 0 obj\n#{stream_body}\nendobj\n"
        page_body = Objects.page(2, content_id, media_box, resources)
        page_frag = "#{page_id} 0 obj\n#{page_body}\nendobj\n"
        [stream_frag, page_frag]
      end)

    body_iodata = [catalog_frag, pages_frag] ++ image_frags ++ page_frags
    {body_iodata, []}
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
