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
  def write(%Document{pages: []}), do: write(Document.add_page(%Document{pages: [], opts: []}))

  def write(%Document{opts: opts, pages: pages} = _doc) do
    page_size = Keyword.get(opts, :page_size, :a4)
    media_box = Units.page_size(page_size)

    # Object IDs: 1=Catalog, 2=Pages, 3..2+len = Page objs, then content streams
    n_pages = length(pages)
    page_ids = Enum.to_list(3..(2 + n_pages))
    content_ids = Enum.to_list((3 + n_pages)..(2 + 2 * n_pages))

    # Build body chunks and collect offsets for xref
    {body_io, offsets} = build_body(page_ids, content_ids, pages, media_box)

    body = IO.iodata_to_binary(body_io)
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

  defp build_body(page_ids, content_ids, pages, media_box) do
    base = byte_size(@pdf_header)
    catalog_frag = "1 0 obj\n" <> Objects.catalog(2) <> "\nendobj\n"
    pages_frag = "2 0 obj\n" <> Objects.pages_tree(page_ids) <> "\nendobj\n"

    frags =
      [catalog_frag, pages_frag] ++
        Enum.flat_map(Enum.zip([content_ids, page_ids, pages]), fn {content_id, page_id, page} ->
          content_bin = ContentStream.build(page.content_ops)
          stream_body = Objects.stream_dict_and_data(content_bin)
          stream_frag = "#{content_id} 0 obj\n#{stream_body}\nendobj\n"
          resources = Objects.resources_font("Helvetica")
          page_body = Objects.page(2, content_id, media_box, resources)
          page_frag = "#{page_id} 0 obj\n#{page_body}\nendobj\n"
          [stream_frag, page_frag]
        end)

    body_iodata = frags
    body_bin = IO.iodata_to_binary(body_iodata)
    all_ids = [1, 2] ++ Enum.flat_map(Enum.zip([content_ids, page_ids]), fn {c, p} -> [c, p] end)
    offsets = compute_offsets(body_bin, base, all_ids)
    {body_iodata, offsets}
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
