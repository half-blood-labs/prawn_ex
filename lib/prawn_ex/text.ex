defmodule PrawnEx.Text do
  @moduledoc """
  Text utilities: width measurement and line wrapping for PDF layout.

  Widths come from the Helvetica AFM advance table below — the real per-glyph
  widths, in em, of the base-14 font PrawnEx draws with by default. A flat
  "half an em per character" guess is off by a third either way for text like
  "Illinois" or "WOMBAT", which shows up as ragged wraps in `text_box/3`,
  mis-centred table cells and axis labels that overrun their gutter.

  Codepoints outside the table (and any text set in an embedded TrueType font,
  whose own metrics live in `PrawnEx.Font.TrueType`) fall back to 0.55 em.
  """

  # Helvetica / Arial advance widths in em, keyed by codepoint.
  @helvetica %{
    32 => 0.2778,
    33 => 0.2778,
    34 => 0.355,
    35 => 0.5562,
    36 => 0.5562,
    37 => 0.8892,
    38 => 0.667,
    39 => 0.1909,
    40 => 0.333,
    41 => 0.333,
    42 => 0.3892,
    43 => 0.584,
    44 => 0.2778,
    45 => 0.333,
    46 => 0.2778,
    47 => 0.2778,
    48 => 0.5562,
    49 => 0.5562,
    50 => 0.5562,
    51 => 0.5562,
    52 => 0.5562,
    53 => 0.5562,
    54 => 0.5562,
    55 => 0.5562,
    56 => 0.5562,
    57 => 0.5562,
    58 => 0.2778,
    59 => 0.2778,
    60 => 0.584,
    61 => 0.584,
    62 => 0.584,
    63 => 0.5562,
    64 => 1.0151,
    65 => 0.667,
    66 => 0.667,
    67 => 0.7222,
    68 => 0.7222,
    69 => 0.667,
    70 => 0.6108,
    71 => 0.7778,
    72 => 0.7222,
    73 => 0.2778,
    74 => 0.5,
    75 => 0.667,
    76 => 0.5562,
    77 => 0.833,
    78 => 0.7222,
    79 => 0.7778,
    80 => 0.667,
    81 => 0.7778,
    82 => 0.7222,
    83 => 0.667,
    84 => 0.6108,
    85 => 0.7222,
    86 => 0.667,
    87 => 0.9438,
    88 => 0.667,
    89 => 0.667,
    90 => 0.6108,
    91 => 0.2778,
    92 => 0.2778,
    93 => 0.2778,
    94 => 0.4692,
    95 => 0.5562,
    96 => 0.333,
    97 => 0.5562,
    98 => 0.5562,
    99 => 0.5,
    100 => 0.5562,
    101 => 0.5562,
    102 => 0.2778,
    103 => 0.5562,
    104 => 0.5562,
    105 => 0.2222,
    106 => 0.2222,
    107 => 0.5,
    108 => 0.2222,
    109 => 0.833,
    110 => 0.5562,
    111 => 0.5562,
    112 => 0.5562,
    113 => 0.5562,
    114 => 0.333,
    115 => 0.5,
    116 => 0.2778,
    117 => 0.5562,
    118 => 0.5,
    119 => 0.7222,
    120 => 0.5,
    121 => 0.5,
    122 => 0.5,
    123 => 0.334,
    124 => 0.2598,
    125 => 0.334,
    126 => 0.584,
    176 => 0.3999,
    196 => 0.667,
    214 => 0.7778,
    220 => 0.7222,
    223 => 0.6108,
    228 => 0.5562,
    246 => 0.5562,
    252 => 0.5562,
    8211 => 0.5562,
    8212 => 1,
    8224 => 0.5562,
    8364 => 0.5562
  }

  @fallback_width 0.55

  @doc """
  Width of a string in points when set in Helvetica at `font_size`.

  Sums the per-codepoint advance widths; codepoints missing from the table
  count as #{@fallback_width} em.
  """
  @spec estimated_width(String.t(), number()) :: number()
  def estimated_width(text, font_size) when is_binary(text) do
    ems =
      for <<codepoint::utf8 <- text>>, reduce: 0.0 do
        acc -> acc + Map.get(@helvetica, codepoint, @fallback_width)
      end

    ems * font_size
  end

  @doc """
  Breaks a string into lines that fit within `max_width` (in points).
  Splits on spaces (words); if a word exceeds max_width, breaks by character.
  Preserves existing newlines as paragraph breaks.
  """
  @spec wrap_to_lines(String.t(), number(), number()) :: [String.t()]
  def wrap_to_lines(text, max_width, font_size) when max_width > 0 and font_size > 0 do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_paragraph(&1, max_width, font_size))
  end

  def wrap_to_lines(_, _max_width, _font_size), do: []

  defp wrap_paragraph("", _max_width, _font_size), do: []

  defp wrap_paragraph(paragraph, max_width, font_size) do
    words = String.split(paragraph, " ", trim: false)

    {lines, rest} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word
        candidate_width = estimated_width(candidate, font_size)

        if candidate_width <= max_width do
          {lines, candidate}
        else
          if current == "" do
            {char_lines, _} = wrap_word_by_char(word, max_width, font_size)
            {lines ++ char_lines, ""}
          else
            new_lines = lines ++ [current]

            if estimated_width(word, font_size) <= max_width do
              {new_lines, word}
            else
              {char_lines, _} = wrap_word_by_char(word, max_width, font_size)
              {new_lines ++ char_lines, ""}
            end
          end
        end
      end)

    if rest == "", do: lines, else: lines ++ [rest]
  end

  defp wrap_word_by_char(word, max_width, font_size) do
    chars = String.graphemes(word)

    {lines, buf} =
      Enum.reduce(chars, {[], ""}, fn c, {acc, buf} ->
        trial = buf <> c

        if estimated_width(trial, font_size) <= max_width do
          {acc, trial}
        else
          if buf == "" do
            {acc ++ [c], ""}
          else
            {acc ++ [buf], c}
          end
        end
      end)

    if buf == "" do
      {lines, ""}
    else
      {lines ++ [buf], ""}
    end
  end
end
