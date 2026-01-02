defmodule PrawnEx.PDF.Objects do
  @moduledoc """
  Builds PDF indirect object definitions (catalog, pages, page, stream).
  """

  @doc """
  Returns the PDF fragment for an indirect object: "n 0 obj ... endobj"
  """
  def indirect(id, body) when is_binary(body) do
    "#{id} 0 obj\n#{body}\nendobj\n"
  end

  @doc """
  Catalog: root of the document. References the Pages tree.
  """
  def catalog(pages_id) do
    body = "<< /Type /Catalog /Pages #{pages_id} 0 R >>"
    body
  end

  @doc """
  Pages tree: /Type /Pages, /Count n, /Kids [id1 0 R, id2 0 R, ...]
  """
  def pages_tree(kid_ids) do
    refs = Enum.map(kid_ids, fn id -> "#{id} 0 R" end) |> Enum.join(" ")
    "<< /Type /Pages /Count #{length(kid_ids)} /Kids [ #{refs} ] >>"
  end

  @doc """
  Single page: /Type /Page, /Parent, /MediaBox, /Contents, /Resources.
  """
  def page(parent_id, contents_id, media_box, resources) do
    {w, h} = media_box

    "<< /Type /Page /Parent #{parent_id} 0 R /MediaBox [ 0 0 #{w} #{h} ] /Contents #{contents_id} 0 R /Resources #{resources} >>"
  end

  @doc """
  Resources dict with built-in font. font_name e.g. "Helvetica".
  """
  def resources_font(font_name) do
    base = "/" <> font_name
    "<< /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont #{base} >> >> >>"
  end

  @doc """
  Stream object body: dictionary + stream data. Caller adds "n 0 obj\n" and "endobj".
  """
  def stream_dict_and_data(data) when is_binary(data) do
    len = byte_size(data)
    "<< /Length #{len} >>\nstream\n#{data}\nendstream"
  end
end
