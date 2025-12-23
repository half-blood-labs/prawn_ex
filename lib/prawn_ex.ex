defmodule PrawnEx do
  @moduledoc """
  Prawn-style declarative PDF generation for Elixir.

  Pure Elixir, no Chrome or HTML. Build a document spec and emit PDF 1.4 binary.

  ## Example

      PrawnEx.build("out.pdf", fn doc ->
        doc
        |> PrawnEx.set_font("Helvetica", 12)
        |> PrawnEx.text("Hello, PDF!")
        |> PrawnEx.rectangle(100, 400, 200, 50)
        |> PrawnEx.stroke()
      end)

  See module docs for `PrawnEx.Document` and `PrawnEx.Units`.
  """

  alias PrawnEx.Document
  alias PrawnEx.PDF.Writer

  @doc """
  Builds a PDF by running the function on a new document, then writes to the given path.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec build(String.t(), (Document.t() -> Document.t())) :: :ok | {:error, term()}
  def build(path, fun) do
    doc = Document.new() |> fun.()
    write_to_file(doc, path)
  end

  @doc """
  Writes the document to a file at `path`.
  """
  @spec write_to_file(Document.t(), String.t()) :: :ok | {:error, term()}
  def write_to_file(doc, path) do
    binary = to_binary(doc)
    File.write(path, binary)
  end

  @doc """
  Converts the document to PDF binary.
  """
  @spec to_binary(Document.t()) :: binary()
  def to_binary(doc), do: Writer.write(doc)

  @doc """
  Adds a new page. The new page becomes current.
  """
  @spec add_page(Document.t()) :: Document.t()
  def add_page(doc), do: Document.add_page(doc)

  @doc """
  Sets the current font (e.g. "Helvetica") and size in points.
  """
  @spec set_font(Document.t(), String.t(), number()) :: Document.t()
  def set_font(doc, font_name, size), do: Document.append_op(doc, {:set_font, font_name, size})

  @doc """
  Appends text at the current position (single line).
  """
  @spec text(Document.t(), String.t()) :: Document.t()
  def text(doc, s), do: Document.append_op(doc, {:text, s})

  @doc """
  Draws text at the given position `{x, y}` (PDF coordinates: origin bottom-left).
  """
  @spec text_at(Document.t(), {number(), number()}, String.t()) :: Document.t()
  def text_at(doc, pos, s), do: Document.append_op(doc, {:text_at, pos, s})

  @doc """
  Draws a line from `{x1, y1}` to `{x2, y2}`. Call `stroke/1` to draw it.
  """
  @spec line(Document.t(), {number(), number()}, {number(), number()}) :: Document.t()
  def line(doc, from, to), do: Document.append_op(doc, {:line, from, to})

  @doc """
  Adds a rectangle at `(x, y)` with `width` and `height`. Call `stroke/1` or `fill/1` to draw it.
  """
  @spec rectangle(Document.t(), number(), number(), number(), number()) :: Document.t()
  def rectangle(doc, x, y, width, height),
    do: Document.append_op(doc, {:rectangle, x, y, width, height})

  @doc """
  Strokes the current path (e.g. after `rectangle/5` or `line/3`).
  """
  @spec stroke(Document.t()) :: Document.t()
  def stroke(doc), do: Document.append_op(doc, :stroke)

  @doc """
  Fills the current path.
  """
  @spec fill(Document.t()) :: Document.t()
  def fill(doc), do: Document.append_op(doc, :fill)
end
