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
        "/F#{i} << /Type /Font /Subtype /Type1 /BaseFont #{base} /Encoding /WinAnsiEncoding >>"
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
        "/F#{i} << /Type /Font /Subtype /Type1 /BaseFont #{base} /Encoding /WinAnsiEncoding >>"
      end)
      |> Enum.join(" ")

    xobj_part =
      Enum.map(xobject_refs, fn {name, id} -> "/#{name} #{id} 0 R" end)
      |> Enum.join(" ")

    "<< /Font << #{font_part} >> /XObject << #{xobj_part} >> >>"
  end

  @doc """
  Image XObject: stream dict + data.

  - `filter: :dct` — `data` is a full JPEG bitstream (`/DCTDecode`).
  - `filter: :flate` — `data` is raw top-to-bottom RGB pixels (`/FlateDecode`).
  """
  def image_xobject(width, height, data, filter: :dct) do
    len = byte_size(data)

    "<< /Type /XObject /Subtype /Image /Width #{width} /Height #{height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{len} >>\nstream\n#{data}\nendstream"
  end

  def image_xobject(width, height, data, filter: :flate) do
    compressed = :zlib.compress(data)
    len = byte_size(compressed)

    "<< /Type /XObject /Subtype /Image /Width #{width} /Height #{height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length #{len} >>\nstream\n#{compressed}\nendstream"
  end

  @doc """
  Embedded TrueType font program: /FontFile2 stream, flate-compressed.
  """
  def font_file2(ttf_data) do
    compressed = :zlib.compress(ttf_data)

    "<< /Filter /FlateDecode /Length #{byte_size(compressed)} /Length1 #{byte_size(ttf_data)} >>\nstream\n" <>
      compressed <> "\nendstream"
  end

  @doc """
  FontDescriptor for an embedded TrueType font. `metrics` comes from
  `PrawnEx.Font.TrueType.parse/1`.
  """
  def font_descriptor(base_name, metrics, font_file_id) do
    {x0, y0, x1, y1} = metrics.bbox

    "<< /Type /FontDescriptor /FontName /#{base_name} /Flags 32 " <>
      "/FontBBox [ #{x0} #{y0} #{x1} #{y1} ] /ItalicAngle #{metrics.italic_angle} " <>
      "/Ascent #{metrics.ascent} /Descent #{metrics.descent} /CapHeight #{metrics.cap_height} " <>
      "/StemV #{metrics.stem_v} /FontFile2 #{font_file_id} 0 R >>"
  end

  @doc """
  Simple /TrueType font dict with WinAnsi encoding and explicit widths.
  """
  def truetype_font(base_name, widths, descriptor_id) do
    "<< /Type /Font /Subtype /TrueType /BaseFont /#{base_name} /FirstChar 32 /LastChar 255 " <>
      "/Widths [ #{Enum.join(widths, " ")} ] /Encoding /WinAnsiEncoding " <>
      "/FontDescriptor #{descriptor_id} 0 R >>"
  end

  @doc """
  ExtGState dict carrying constant fill + stroke alpha.
  """
  def ext_gstate(alpha) do
    "<< /Type /ExtGState /ca #{Encoder.number(alpha)} /CA #{Encoder.number(alpha)} >>"
  end

  @doc """
  General resources dict.

  `font_entries` — `[{"F1", {:base14, "Helvetica"}} | {"F2", {:ref, id}}]`
  `xobject_refs` — `[{"Im1", id}]`; `gs_refs` — `[{"GS1", id}]`.
  """
  def resources(font_entries, xobject_refs \\ [], gs_refs \\ []) do
    entries = if font_entries == [], do: [{"F1", {:base14, "Helvetica"}}], else: font_entries

    font_part =
      Enum.map_join(entries, " ", fn
        {res, {:base14, name}} ->
          "/#{res} << /Type /Font /Subtype /Type1 /BaseFont /#{name} /Encoding /WinAnsiEncoding >>"

        {res, {:ref, id}} ->
          "/#{res} #{id} 0 R"
      end)

    xobj_part =
      case xobject_refs do
        [] ->
          ""

        refs ->
          " /XObject << " <>
            Enum.map_join(refs, " ", fn {n, id} -> "/#{n} #{id} 0 R" end) <> " >>"
      end

    gs_part =
      case gs_refs do
        [] ->
          ""

        refs ->
          " /ExtGState << " <>
            Enum.map_join(refs, " ", fn {n, id} -> "/#{n} #{id} 0 R" end) <> " >>"
      end

    "<< /Font << #{font_part} >>#{xobj_part}#{gs_part} >>"
  end

  @doc """
  Stream object body: dictionary + stream data. Caller adds "n 0 obj\n" and "endobj".
  """
  def stream_dict_and_data(data) when is_binary(data) do
    len = byte_size(data)
    "<< /Length #{len} >>\nstream\n#{data}\nendstream"
  end
end
