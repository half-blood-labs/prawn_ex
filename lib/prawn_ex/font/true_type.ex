defmodule PrawnEx.Font.TrueType do
  @moduledoc """
  Minimal TrueType (sfnt) parser — just enough metadata to embed a font
  in a PDF as a simple /TrueType font with WinAnsi encoding.

  Reads the table directory and pulls what the PDF FontDescriptor and
  /Widths array need: units per em, bounding box, ascent/descent,
  cap height, italic angle, weight, and per-character advance widths
  for the WinAnsi range (32..255).

  CFF-flavoured OpenType (`OTTO`) is rejected: those need /FontFile3,
  which is out of scope for now.
  """

  import Bitwise

  # WinAnsi byte -> Unicode codepoint for the CP1252 0x80..0x9F block.
  @cp1252_specials %{
    0x80 => 0x20AC,
    0x82 => 0x201A,
    0x83 => 0x0192,
    0x84 => 0x201E,
    0x85 => 0x2026,
    0x86 => 0x2020,
    0x87 => 0x2021,
    0x88 => 0x02C6,
    0x89 => 0x2030,
    0x8A => 0x0160,
    0x8B => 0x2039,
    0x8C => 0x0152,
    0x8E => 0x017D,
    0x91 => 0x2018,
    0x92 => 0x2019,
    0x93 => 0x201C,
    0x94 => 0x201D,
    0x95 => 0x2022,
    0x96 => 0x2013,
    0x97 => 0x2014,
    0x98 => 0x02DC,
    0x99 => 0x2122,
    0x9A => 0x0161,
    0x9B => 0x203A,
    0x9C => 0x0153,
    0x9E => 0x017E,
    0x9F => 0x0178
  }

  @doc """
  Parses a TTF binary. Returns `{:ok, metrics}` or `{:error, reason}`.

  Metrics (all font-design values already scaled to a 1000-unit em,
  as PDF expects):

  - `:ascent`, `:descent`, `:cap_height`, `:italic_angle`, `:bbox`
  - `:stem_v` — estimated from the OS/2 weight class
  - `:widths` — advance widths for WinAnsi codes 32..255, in order
  """
  @spec parse(binary()) :: {:ok, map()} | {:error, atom()}
  def parse(<<"OTTO", _::binary>>), do: {:error, :cff_not_supported}

  def parse(<<version::32, num_tables::16, _::48, rest::binary>> = font)
      when version in [0x00010000, 0x74727565] do
    tables =
      for <<tag::binary-4, _checksum::32, offset::32,
            length::32 <- binary_part(rest, 0, num_tables * 16)>>,
          into: %{} do
        {tag, binary_part(font, offset, length)}
      end

    with {:ok, head} <- fetch(tables, "head"),
         {:ok, hhea} <- fetch(tables, "hhea"),
         {:ok, maxp} <- fetch(tables, "maxp"),
         {:ok, hmtx} <- fetch(tables, "hmtx"),
         {:ok, cmap} <- fetch(tables, "cmap") do
      units_per_em = u16(head, 18)
      scale = fn v -> round(v * 1000 / units_per_em) end

      bbox =
        {scale.(s16(head, 36)), scale.(s16(head, 38)), scale.(s16(head, 40)),
         scale.(s16(head, 42))}

      num_h_metrics = u16(hhea, 34)
      num_glyphs = u16(maxp, 4)
      advances = parse_hmtx(hmtx, num_h_metrics, num_glyphs)
      char_to_glyph = parse_cmap(cmap)

      {ascent, descent, cap_height, weight} = os2_metrics(tables["OS/2"], hhea, scale)
      italic_angle = post_italic_angle(tables["post"])

      widths =
        for code <- 32..255 do
          gid = Map.get(char_to_glyph, winansi_to_unicode(code), 0)
          scale.(elem(advances, min(gid, tuple_size(advances) - 1)))
        end

      {:ok,
       %{
         ascent: ascent,
         descent: descent,
         cap_height: cap_height,
         italic_angle: italic_angle,
         bbox: bbox,
         stem_v: if(weight >= 600, do: 120, else: 80),
         widths: widths
       }}
    end
  end

  def parse(_), do: {:error, :not_a_truetype_font}

  defp fetch(tables, tag) do
    case tables do
      %{^tag => data} -> {:ok, data}
      _ -> {:error, :"missing_#{String.replace(tag, "/", "_")}_table"}
    end
  end

  defp u16(bin, offset), do: :binary.decode_unsigned(binary_part(bin, offset, 2))

  defp s16(bin, offset) do
    <<v::signed-16>> = binary_part(bin, offset, 2)
    v
  end

  defp parse_hmtx(hmtx, num_h_metrics, num_glyphs) do
    listed =
      for <<advance::16, _lsb::signed-16 <- binary_part(hmtx, 0, num_h_metrics * 4)>>, do: advance

    # Glyphs past numberOfHMetrics all reuse the last listed advance.
    last = List.last(listed) || 0
    List.to_tuple(listed ++ List.duplicate(last, max(num_glyphs - num_h_metrics, 0)))
  end

  defp os2_metrics(nil, hhea, scale) do
    ascent = scale.(s16(hhea, 4))
    {ascent, scale.(s16(hhea, 6)), round(ascent * 0.7), 400}
  end

  defp os2_metrics(os2, _hhea, scale) do
    version = u16(os2, 0)
    ascent = scale.(s16(os2, 68))
    descent = scale.(s16(os2, 70))
    cap_height = if version >= 2, do: scale.(s16(os2, 88)), else: round(ascent * 0.7)
    {ascent, descent, cap_height, u16(os2, 4)}
  end

  defp post_italic_angle(nil), do: 0

  defp post_italic_angle(post) do
    <<angle::signed-32>> = binary_part(post, 4, 4)
    round(angle / 65_536)
  end

  ## ── cmap: unicode -> glyph id ─────────────────────────────────────────

  defp parse_cmap(<<_version::16, num_tables::16, rest::binary>> = cmap) do
    records =
      for <<platform::16, encoding::16, offset::32 <- binary_part(rest, 0, num_tables * 8)>> do
        {platform, encoding, offset}
      end

    offset =
      Enum.find_value(records, fn
        {3, 1, off} -> off
        _ -> nil
      end) ||
        Enum.find_value(records, fn
          {0, _, off} -> off
          {3, 0, off} -> off
          _ -> nil
        end)

    case offset && binary_part(cmap, offset, byte_size(cmap) - offset) do
      <<4::16, _::binary>> = subtable -> parse_cmap_format4(subtable)
      _ -> %{}
    end
  end

  defp parse_cmap_format4(<<4::16, _length::16, _lang::16, seg_x2::16, _::48, rest::binary>>) do
    seg = div(seg_x2, 2)
    end_codes = u16_tuple(rest, 0, seg)
    start_codes = u16_tuple(rest, seg * 2 + 2, seg)
    deltas = u16_tuple(rest, seg * 4 + 2, seg)
    range_offsets = u16_tuple(rest, seg * 6 + 2, seg)
    glyph_array_base = seg * 6 + 2

    for i <- 0..(seg - 1),
        start = elem(start_codes, i),
        start != 0xFFFF,
        code <- start..min(elem(end_codes, i), 0xFFFE),
        gid = glyph_id(code, i, start_codes, deltas, range_offsets, glyph_array_base, rest),
        gid != 0,
        into: %{} do
      {code, gid}
    end
  end

  defp glyph_id(code, i, start_codes, deltas, range_offsets, base, rest) do
    case elem(range_offsets, i) do
      0 ->
        code + elem(deltas, i) &&& 0xFFFF

      range_offset ->
        # idRangeOffset is relative to its own position in the table.
        pos = base + i * 2 + range_offset + (code - elem(start_codes, i)) * 2

        if pos + 2 <= byte_size(rest) do
          case :binary.decode_unsigned(binary_part(rest, pos, 2)) do
            0 -> 0
            gid -> gid + elem(deltas, i) &&& 0xFFFF
          end
        else
          0
        end
    end
  end

  defp u16_tuple(bin, offset, count) do
    for(<<v::16 <- binary_part(bin, offset, count * 2)>>, do: v) |> List.to_tuple()
  end

  defp winansi_to_unicode(code) when code in 0x80..0x9F, do: Map.get(@cp1252_specials, code, code)
  defp winansi_to_unicode(code), do: code
end
