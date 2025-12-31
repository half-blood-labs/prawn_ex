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

  Options (when passing a keyword list as second argument):
  - `:header` - `fn(doc, page_number) -> doc` — add ops at top of each page (e.g. title, line)
  - `:footer` - `fn(doc, page_number) -> doc` — add ops at bottom of each page (e.g. "Page N")

  Returns `:ok` or `{:error, reason}`.
  """
  @spec build(String.t(), (Document.t() -> Document.t())) :: :ok | {:error, term()}
  @spec build(String.t(), keyword(), (Document.t() -> Document.t())) :: :ok | {:error, term()}
  def build(path, opts, fun) when is_list(opts) and is_function(fun, 1) do
    doc = Document.new() |> fun.() |> inject_headers_footers(opts)
    write_to_file(doc, path)
  end

  def build(path, fun) when is_function(fun, 1) do
    build(path, [], fun)
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

  @doc """
  Sets the non-stroking (fill and text) color to gray. `g` in 0..1 (0=black, 1=white).
  """
  @spec set_non_stroking_gray(Document.t(), number()) :: Document.t()
  def set_non_stroking_gray(doc, g), do: Document.append_op(doc, {:set_non_stroking_gray, g})

  @doc """
  Sets the stroking (lines, borders) color to gray. `g` in 0..1.
  """
  @spec set_stroking_gray(Document.t(), number()) :: Document.t()
  def set_stroking_gray(doc, g), do: Document.append_op(doc, {:set_stroking_gray, g})

  @doc """
  Draws a table at the given position. `rows` is a list of rows (list of cell values).
  First row can be styled as header with `header: true` (default).

  ## Options

  - `:at` - `{x, y}` top-left of table (default `{50, 750}`)
  - `:column_widths` - list of pt widths or `:auto`
  - `:row_height`, `:cell_padding`, `:header`, `:border`, `:font_size`, `:header_font_size`

  ## Example

      PrawnEx.table(doc, [["Name", "Score"], ["Alice", "95"], ["Bob", "87"]],
        at: {50, 650}, column_widths: [200, 80])
  """
  @spec table(Document.t(), [list()], keyword()) :: Document.t()
  def table(doc, rows, opts \\ []) do
    doc = ensure_current_page(doc)
    opts = Keyword.put_new(opts, :at, {50, 750})
    opts = Keyword.put(opts, :page_size, doc.opts[:page_size] || :a4)
    PrawnEx.Table.layout(doc, rows, opts)
  end

  defp ensure_current_page(%Document{pages: []} = doc), do: Document.add_page(doc)
  defp ensure_current_page(doc), do: doc

  defp inject_headers_footers(doc, opts) do
    header_cb = Keyword.get(opts, :header)
    footer_cb = Keyword.get(opts, :footer)
    if header_cb == nil and footer_cb == nil, do: doc, else: do_inject(doc, header_cb, footer_cb)
  end

  defp do_inject(doc, header_cb, footer_cb) do
    Enum.with_index(doc.pages)
    |> Enum.reduce(doc, fn {_page, i}, acc ->
      page_num = i + 1
      header_ops = if header_cb, do: ops_from_callback(header_cb, acc, page_num), else: []
      footer_ops = if footer_cb, do: ops_from_callback(footer_cb, acc, page_num), else: []
      Document.inject_page_ops(acc, i, header_ops, footer_ops)
    end)
  end

  defp ops_from_callback(cb, doc, page_num) do
    # Run callback with a doc that has one empty page; it adds header/footer ops
    blank = Document.new(doc.opts) |> Document.add_page()
    result = cb.(blank, page_num)
    case Document.current_page(result) do
      nil -> []
      page -> page.content_ops
    end
  end
end
