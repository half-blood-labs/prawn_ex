defmodule PrawnEx.PDF.Encoder do
  @moduledoc """
  Encodes values for PDF output: string escaping, name encoding.
  """

  @doc """
  Escapes a string for use inside PDF literal string (parentheses).
  Backslash and parens must be escaped.
  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(s) when is_binary(s) do
    s
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
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
  def number(n) when is_float(n), do: :erlang.float_to_binary(n, [decimals: 4])
end
