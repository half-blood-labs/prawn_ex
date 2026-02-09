defmodule PrawnEx.PDF.Objects do
  @moduledoc """
  Builds PDF indirect object definitions (catalog, pages, page, stream).
  """
  alias PrawnEx.PDF.Encoder

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
  Single page: /Type /Page, /Parent, /MediaBox, /Contents, /Resources. Optional /Annots.
  """
  def page(parent_id, contents_id, media_box, resources, annot_refs \\ []) do
    {w, h} = media_box

    annots_part =
      if annot_refs == [] do
        ""
      else
        refs = Enum.map(annot_refs, fn id -> "#{id} 0 R" end) |> Enum.join(" ")
        " /Annots [ #{refs} ]"
      end

    "<< /Type /Page /Parent #{parent_id} 0 R /MediaBox [ 0 0 #{w} #{h} ] /Contents #{contents_id} 0 R /Resources #{resources}#{annots_part} >>"
  end

  @doc """
  Link annotation: /Type /Annot /Subtype /Link /Rect [ llx lly urx ury ] /A << /S /URI /URI (url) >>
  """
  def link_annotation(x, y, width, height, url) do
    # PDF coords: bottom-left origin; Rect is [ llx lly urx ury ]
    uri = Encoder.literal_string(url)

    "<< /Type /Annot /Subtype /Link /Rect [ #{x} #{y} #{x + width} #{y + height} ] /A << /S /URI /URI #{uri} >> >>"
  end

  @doc """
  Resources dict with built-in font(s). font_names: list of e.g. ["Helvetica", "Times-Bold"].
  Emits /F1, /F2, ... for each. Empty list defaults to ["Helvetica"].
  """
  def resources_fonts(font_names) do
    names = if font_names == [], do: ["Helvetica"], else: font_names

    font_part =
      names
      |> Enum.with_index(1)
      |> Enum.map(fn {name, i} ->
        base = "/" <> name
        "/F#{i} << /Type /Font /Subtype /Type1 /BaseFont #{base} >>"
      end)
      |> Enum.join(" ")

    "<< /Font << #{font_part} >> >>"
  end

  @doc """
  Resources dict with fonts and XObject refs. xobject_refs: [{"Im1", 7}] -> /Im1 7 0 R
  """
  def resources_fonts_and_xobject(font_names, xobject_refs) do
    names = if font_names == [], do: ["Helvetica"], else: font_names

    font_part =
      names
      |> Enum.with_index(1)
      |> Enum.map(fn {name, i} ->
        base = "/" <> name
        "/F#{i} << /Type /Font /Subtype /Type1 /BaseFont #{base} >>"
      end)
      |> Enum.join(" ")

    xobj_part =
      Enum.map(xobject_refs, fn {name, id} -> "/#{name} #{id} 0 R" end)
      |> Enum.join(" ")

    "<< /Font << #{font_part} >> /XObject << #{xobj_part} >> >>"
  end

  @doc """
  Image XObject: stream dict + data. filter: :dct for JPEG.
  """
  def image_xobject(width, height, data, filter: :dct) do
    len = byte_size(data)

    "<< /Type /XObject /Subtype /Image /Width #{width} /Height #{height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{len} >>\nstream\n#{data}\nendstream"
  end

  @doc """
  Stream object body: dictionary + stream data. Caller adds "n 0 obj\n" and "endobj".
  """
  def stream_dict_and_data(data) when is_binary(data) do
    len = byte_size(data)
    "<< /Length #{len} >>\nstream\n#{data}\nendstream"
  end
end
