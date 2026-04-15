defmodule PrawnEx.Text do
  @moduledoc """
  Text utilities: line wrapping for PDF layout.

  `wrap_to_lines/4` splits text into lines that fit a given width using precise
  AFM font metrics via `PrawnEx.Font.text_width/3`. The optional `font_name`
  argument (default `"Helvetica"`) selects the metrics table, so wrapping
  behaviour matches what the PDF renderer actually renders.

  `estimated_width/2` is kept for backwards compatibility but is deprecated —
  it uses a coarse `0.5 × font_size × char_count` approximation.
  """

  alias PrawnEx.Font

  @doc """
  Estimated width of a string in points (coarse Helvetica-like approximation).

  **Deprecated** — prefer `PrawnEx.Font.text_width/3` for precise AFM metrics.
  This function uses `0.5 × font_size × String.length(text)` and can be off
  by 30–50 % for mixed-case or narrow strings.
  """
  @spec estimated_width(String.t(), number()) :: number()
  def estimated_width(text, font_size) when is_binary(text) do
    String.length(text) * font_size * 0.5
  end

  @doc """
  Breaks `text` into lines that fit within `max_width` points.

  Splitting strategy:
  - Words (space-delimited) are accumulated until the line would exceed `max_width`.
  - A word that is itself wider than `max_width` is broken by grapheme.
  - Existing `\\n` characters in `text` act as hard paragraph breaks.

  Width is measured with `PrawnEx.Font.text_width/3` using `font_name`
  (default `"Helvetica"`). Pass the same font name you use for rendering so
  that wrap boundaries match the actual PDF output.

  Returns an empty list when `max_width` or `font_size` is ≤ 0.
  """
  @spec wrap_to_lines(String.t(), number(), number(), String.t()) :: [String.t()]
  def wrap_to_lines(text, max_width, font_size, font_name \\ "Helvetica")

  def wrap_to_lines(text, max_width, font_size, font_name)
      when max_width > 0 and font_size > 0 do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_paragraph(&1, max_width, font_size, font_name))
  end

  def wrap_to_lines(_, _max_width, _font_size, _font_name), do: []

  defp wrap_paragraph("", _max_width, _font_size, _font_name), do: []

  defp wrap_paragraph(paragraph, max_width, font_size, font_name) do
    words = String.split(paragraph, " ", trim: false)

    {lines, rest} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word
        candidate_width = Font.text_width(font_name, candidate, font_size)

        if candidate_width <= max_width do
          {lines, candidate}
        else
          if current == "" do
            {char_lines, _} = wrap_word_by_char(word, max_width, font_size, font_name)
            {lines ++ char_lines, ""}
          else
            new_lines = lines ++ [current]

            if Font.text_width(font_name, word, font_size) <= max_width do
              {new_lines, word}
            else
              {char_lines, _} = wrap_word_by_char(word, max_width, font_size, font_name)
              {new_lines ++ char_lines, ""}
            end
          end
        end
      end)

    if rest == "", do: lines, else: lines ++ [rest]
  end

  defp wrap_word_by_char(word, max_width, font_size, font_name) do
    chars = String.graphemes(word)

    {lines, buf} =
      Enum.reduce(chars, {[], ""}, fn c, {acc, buf} ->
        trial = buf <> c

        if Font.text_width(font_name, trial, font_size) <= max_width do
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
