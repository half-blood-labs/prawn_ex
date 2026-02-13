defmodule PrawnEx.Text do
  @moduledoc """
  Text utilities: width estimation and line wrapping for PDF layout.

  Uses a Helvetica-like character-width approximation (~0.5 pt per character per unit font size).
  """

  @doc """
  Estimated width of a string in points (Helvetica-like).
  """
  @spec estimated_width(String.t(), number()) :: number()
  def estimated_width(text, font_size) when is_binary(text) do
    String.length(text) * font_size * 0.5
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
