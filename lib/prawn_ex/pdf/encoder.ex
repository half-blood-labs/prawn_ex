defmodule PrawnEx.PDF.Encoder do
  @moduledoc """
  Encodes values for PDF output: string escaping, name encoding.
  """

  # CP1252's 0x80..0x9F block, where Unicode punctuation actually lives.
  @winansi_specials %{
    0x20AC => 0x80,
    0x201A => 0x82,
    0x0192 => 0x83,
    0x201E => 0x84,
    0x2026 => 0x85,
    0x2020 => 0x86,
    0x2021 => 0x87,
    0x02C6 => 0x88,
    0x2030 => 0x89,
    0x0160 => 0x8A,
    0x2039 => 0x8B,
    0x0152 => 0x8C,
    0x017D => 0x8E,
    0x2018 => 0x91,
    0x2019 => 0x92,
    0x201C => 0x93,
    0x201D => 0x94,
    0x2022 => 0x95,
    0x2013 => 0x96,
    0x2014 => 0x97,
    0x02DC => 0x98,
    0x2122 => 0x99,
    0x0161 => 0x9A,
    0x203A => 0x9B,
    0x0153 => 0x9C,
    0x017E => 0x9E,
    0x0178 => 0x9F
  }

  @doc """
  Escapes a string for use inside a PDF literal string (parentheses),
  transliterating UTF-8 to WinAnsi (CP1252) on the way: the base-14
  fonts are single-byte, so bullets, dashes, and curly quotes would
  otherwise come out as mojibake. Unmappable codepoints become `?`.
  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(s) when is_binary(s) do
    s
    |> winansi()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  @doc """
  Transliterates a UTF-8 string into WinAnsi (CP1252) bytes: ASCII and
  Latin-1 pass through, the CP1252 punctuation block (bullet, en/em
  dash, curly quotes, ellipsis, euro...) maps to its byte, anything
  else becomes `?`.
  """
  @spec winansi(String.t()) :: binary()
  def winansi(s) when is_binary(s) do
    for <<cp::utf8 <- s>>, into: "" do
      cond do
        cp <= 0x7F -> <<cp>>
        cp >= 0xA0 and cp <= 0xFF -> <<cp>>
        true -> <<Map.get(@winansi_specials, cp, ??)>>
      end
    end
  end

  @doc """
  Encodes a PDF literal string: (escaped_content)
  """
  @spec literal_string(String.t()) :: String.t()
  def literal_string(s) when is_binary(s) do
    "(" <> escape_string(s) <> ")"
  end

  @doc """
  Encodes a PDF name (e.g. font resource). Leading / and special chars.
  """
  @spec name(String.t()) :: String.t()
  def name(s) when is_binary(s) do
    # PDF names: /Name; #xx for non-printable; space and / () [] {} <> need escaping
    encoded =
      s
      |> String.replace(" ", "#20")
      |> String.replace("#", "#23")
      |> String.replace("/", "#2F")
      |> String.replace("(", "#28")
      |> String.replace(")", "#29")
      |> String.replace("[", "#5B")
      |> String.replace("]", "#5D")
      |> String.replace("<", "#3C")
      |> String.replace(">", "#3E")
      |> String.replace("{", "#7B")
      |> String.replace("}", "#7D")

    "/" <> encoded
  end

  @doc """
  Format a number for PDF (integer or float).
  """
  @spec number(number()) :: String.t()
  def number(n) when is_integer(n), do: Integer.to_string(n)
  def number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 4)
end
