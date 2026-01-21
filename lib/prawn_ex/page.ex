defmodule PrawnEx.Page do
  @moduledoc """
  Represents a single PDF page with a list of content operations.

  Content ops are stored in order and emitted by the PDF writer.
  Supported ops:
  - `{:set_font, font_name, size}`
  - `{:text, string}`
  - `{:text_at, {x, y}, string}`
  - `{:line, {x1, y1}, {x2, y2}}`
  - `{:move_to, {x, y}}`, `{:line_to, {x, y}}` (path building; then `stroke/1`)
  - `{:rectangle, x, y, width, height}`
  - `:stroke`, `:fill`
  - `{:set_non_stroking_gray, g}` (fill and text)
  - `{:set_stroking_gray, g}` (lines and strokes)
  - `{:set_non_stroking_rgb, r, g, b}` (fill and text, 0..1)
  - `{:set_stroking_rgb, r, g, b}` (lines and strokes, 0..1)
  - `{:image, image_id, x, y, width, height}` (draw image XObject)
  """

  defstruct [:content_ops, :annotations]

  @type content_op ::
          {:set_font, String.t(), number()}
          | {:text, String.t()}
          | {:text_at, {number(), number()}, String.t()}
          | {:line, {number(), number()}, {number(), number()}}
          | {:move_to, {number(), number()}}
          | {:line_to, {number(), number()}}
          | {:rectangle, number(), number(), number(), number()}
          | :stroke
          | :fill
          | {:set_non_stroking_gray, number()}
          | {:set_stroking_gray, number()}
          | {:set_non_stroking_rgb, number(), number(), number()}
          | {:set_stroking_rgb, number(), number(), number()}
          | {:image, pos_integer(), number(), number(), number(), number()}

  @type t :: %__MODULE__{content_ops: [content_op()], annotations: [map()]}

  @doc """
  Creates a new empty page.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{content_ops: [], annotations: []}
  end

  @doc """
  Appends a content operation to the page. Returns a new Page (immutable).
  """
  @spec add_op(t(), content_op()) :: t()
  def add_op(%__MODULE__{content_ops: ops} = page, op) do
    %{page | content_ops: ops ++ [op]}
  end

  @doc """
  Appends an annotation (e.g. link) to the page. Returns the updated page.
  """
  @spec add_annotation(t(), map()) :: t()
  def add_annotation(%__MODULE__{annotations: annots} = page, annot) do
    %{page | annotations: annots ++ [annot]}
  end
end
