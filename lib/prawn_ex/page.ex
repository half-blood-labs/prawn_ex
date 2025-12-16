defmodule PrawnEx.Page do
  @moduledoc """
  Represents a single PDF page with a list of content operations.

  Content ops are stored in order and emitted by the PDF writer.
  Supported ops (for Phase 1):
  - `{:set_font, font_name, size}`
  - `{:text, string}`
  - `{:text_at, {x, y}, string}`
  - `{:line, {x1, y1}, {x2, y2}}`
  - `{:rectangle, x, y, width, height}`
  - `:stroke`
  - `:fill`
  """

  defstruct [:content_ops]

  @type content_op ::
          {:set_font, String.t(), number()}
          | {:text, String.t()}
          | {:text_at, {number(), number()}, String.t()}
          | {:line, {number(), number()}, {number(), number()}}
          | {:rectangle, number(), number(), number(), number()}
          | :stroke
          | :fill

  @type t :: %__MODULE__{content_ops: [content_op()]}

  @doc """
  Creates a new empty page.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{content_ops: []}
  end

  @doc """
  Appends a content operation to the page. Returns a new Page (immutable).
  """
  @spec add_op(t(), content_op()) :: t()
  def add_op(%__MODULE__{content_ops: ops} = page, op) do
    %{page | content_ops: ops ++ [op]}
  end
end
