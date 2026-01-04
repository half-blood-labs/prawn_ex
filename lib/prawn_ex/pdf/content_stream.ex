defmodule PrawnEx.PDF.ContentStream do
  @moduledoc """
  Builds PDF content stream bytes from a list of content operations.

  Uses PDF graphics operators: BT/ET (text), Tm/Tf/Tj (position, font, show),
  m/l/re (path), S/f (stroke/fill), q/Q (save/restore state).
  """

  alias PrawnEx.PDF.Encoder

  @doc """
  Converts a list of content ops to a single content stream binary.

  Font name is mapped to a PDF resource name (e.g. Helvetica -> F1).
  """
  @spec build([PrawnEx.Page.content_op()], %{String.t() => String.t()}) :: binary()
  def build(ops, font_map \\ %{}) do
    font_map = font_map || %{}
    acc = {"", font_map}
    {stream, _} = Enum.reduce(ops, acc, &emit_op/2)
    String.trim(stream)
  end

  defp emit_op({:set_font, font_name, size}, {acc, font_map}) do
    name = Map.get(font_map, font_name, "F1")
    # We only emit when we actually draw text; store in state if needed. For now emit Tf.
    line = "/#{name} #{Encoder.number(size)} Tf\n"
    {acc <> line, font_map}
  end

  defp emit_op({:text, s}, {acc, font_map}) do
    # Assumes cursor position set; use Tj to show string
    line = "BT\n" <> Encoder.literal_string(s) <> " Tj\nET\n"
    {acc <> line, font_map}
  end

  defp emit_op({:text_at, {x, y}, s}, {acc, font_map}) do
    # Tm: a b c d e f = text matrix; 1 0 0 1 x y = translate to (x,y)
    line =
      "BT\n1 0 0 1 " <>
        Encoder.number(x) <>
        " " <>
        Encoder.number(y) <>
        " Tm\n" <>
        Encoder.literal_string(s) <> " Tj\nET\n"

    {acc <> line, font_map}
  end

  defp emit_op({:line, {x1, y1}, {x2, y2}}, {acc, font_map}) do
    line =
      Encoder.number(x1) <>
        " " <>
        Encoder.number(y1) <>
        " m\n" <>
        Encoder.number(x2) <> " " <> Encoder.number(y2) <> " l S\n"

    {acc <> line, font_map}
  end

  defp emit_op({:move_to, {x, y}}, {acc, font_map}) do
    {acc <> Encoder.number(x) <> " " <> Encoder.number(y) <> " m\n", font_map}
  end

  defp emit_op({:line_to, {x, y}}, {acc, font_map}) do
    {acc <> Encoder.number(x) <> " " <> Encoder.number(y) <> " l\n", font_map}
  end

  defp emit_op({:rectangle, x, y, w, h}, {acc, font_map}) do
    # re = rectangle (x y width height); path not drawn until S or f
    line =
      Encoder.number(x) <>
        " " <>
        Encoder.number(y) <>
        " " <>
        Encoder.number(w) <> " " <> Encoder.number(h) <> " re\n"

    {acc <> line, font_map}
  end

  defp emit_op(:stroke, {acc, font_map}) do
    {acc <> "S\n", font_map}
  end

  defp emit_op(:fill, {acc, font_map}) do
    {acc <> "f\n", font_map}
  end

  defp emit_op({:set_non_stroking_gray, g}, {acc, font_map}) do
    {acc <> Encoder.number(g) <> " g\n", font_map}
  end

  defp emit_op({:set_stroking_gray, g}, {acc, font_map}) do
    {acc <> Encoder.number(g) <> " G\n", font_map}
  end

  defp emit_op({:image, id, x, y, w, h}, {acc, font_map}) do
    # q ... Q = save/restore; w 0 0 h x y cm = concat matrix (place image); /ImN Do = draw XObject
    line =
      "q\n" <>
        Encoder.number(w) <>
        " 0 0 " <>
        Encoder.number(h) <>
        " " <>
        Encoder.number(x) <>
        " " <>
        Encoder.number(y) <>
        " cm\n" <>
        "/Im" <> Integer.to_string(id) <> " Do\nQ\n"

    {acc <> line, font_map}
  end
end
