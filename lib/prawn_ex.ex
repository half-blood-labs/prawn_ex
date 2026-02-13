defmodule PrawnEx do
  @moduledoc """
  Prawn-style declarative PDF generation for Elixir.

  Pure Elixir, no Chrome or HTML. Build a document spec and emit PDF 1.4 binary.

  ## Image / asset path

  When using this library as a dependency, set in your application config:

      config :prawn_ex, image_dir: "priv/images"

  Relative paths passed to `image/3` (e.g. `"photo.jpg"`) are then resolved from that directory.
  Absolute paths and raw JPEG binaries are used as-is.

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
  Draws text wrapped to fit within a width. First line baseline at `{x, y}`; subsequent lines below (smaller y).

  Options:
  - `:at` - `{x, y}` (required) — position of first line baseline
  - `:width` - max width in pt (required)
  - `:font_name` - default `"Helvetica"`
  - `:font_size` - default `12`
  - `:line_height` - default `1.2 * font_size`
  """
  @spec text_box(Document.t(), String.t(), keyword()) :: Document.t()
  def text_box(doc, text, opts) do
    at = Keyword.fetch!(opts, :at)
    width = Keyword.fetch!(opts, :width)
    font_name = Keyword.get(opts, :font_name, "Helvetica")
    font_size = Keyword.get(opts, :font_size, 12)
    line_height = Keyword.get(opts, :line_height, font_size * 1.2)

    {x, y} = at
    lines = PrawnEx.Text.wrap_to_lines(text, width, font_size)

    if lines == [] do
      doc
    else
      doc
      |> Document.append_op({:set_font, font_name, font_size})
      |> then(fn d ->
        Enum.with_index(lines)
        |> Enum.reduce(d, fn {line, i}, acc ->
          Document.append_op(acc, {:text_at, {x, y - i * line_height}, line})
        end)
      end)
    end
  end

  @doc """
  Draws a line from `{x1, y1}` to `{x2, y2}`. Call `stroke/1` to draw it.
  """
  @spec line(Document.t(), {number(), number()}, {number(), number()}) :: Document.t()
  def line(doc, from, to), do: Document.append_op(doc, {:line, from, to})

  @doc """
  Moves the path to `{x, y}` without drawing. Use with `line_to/2` and then `stroke/1` for polylines.
  """
  @spec move_to(Document.t(), {number(), number()}) :: Document.t()
  def move_to(doc, pos), do: Document.append_op(doc, {:move_to, pos})

  @doc """
  Draws a line from the current path point to `{x, y}`. Call `stroke/1` after the path is complete.
  """
  @spec line_to(Document.t(), {number(), number()}) :: Document.t()
  def line_to(doc, pos), do: Document.append_op(doc, {:line_to, pos})

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
  Sets the non-stroking (fill and text) color to RGB. `r`, `g`, `b` in 0..1.
  """
  @spec set_non_stroking_rgb(Document.t(), number(), number(), number()) :: Document.t()
  def set_non_stroking_rgb(doc, r, g, b),
    do: Document.append_op(doc, {:set_non_stroking_rgb, r, g, b})

  @doc """
  Sets the stroking (lines, borders) color to RGB. `r`, `g`, `b` in 0..1.
  """
  @spec set_stroking_rgb(Document.t(), number(), number(), number()) :: Document.t()
  def set_stroking_rgb(doc, r, g, b), do: Document.append_op(doc, {:set_stroking_rgb, r, g, b})

  @doc """
  Adds an external link annotation on the current page. Clicking the rectangle opens the URL.
  `x`, `y` are bottom-left in pt; `width` and `height` define the clickable area.
  """
  @spec link(Document.t(), number(), number(), number(), number(), String.t()) :: Document.t()
  def link(doc, x, y, width, height, url) do
    doc = ensure_current_page(doc)
    Document.append_annotation(doc, %{type: :link, rect: {x, y, width, height}, url: url})
  end

  @doc """
  Draws a bar chart. `data` is a list of `{label, value}` or `[label, value]`.
  Options: `:at`, `:width`, `:height`, `:bar_color` (gray 0–1), `:axis`, `:labels`, `:label_font_size`, `:padding`.
  """
  @spec bar_chart(Document.t(), [{String.t(), number()} | [term()]], keyword()) :: Document.t()
  def bar_chart(doc, data, opts \\ []) do
    doc = ensure_current_page(doc)
    opts = Keyword.put_new(opts, :at, {50, 600})
    PrawnEx.Chart.bar_chart(doc, data, opts)
  end

  @doc """
  Draws a line chart. `data` is a list of y-values (x = index) or `[{x, y}, ...]`.
  Options: `:at`, `:width`, `:height`, `:stroke_color`, `:axis`, `:padding`.
  """
  @spec line_chart(Document.t(), [number()] | [{number(), number()}], keyword()) :: Document.t()
  def line_chart(doc, data, opts \\ []) do
    doc = ensure_current_page(doc)
    opts = Keyword.put_new(opts, :at, {50, 600})
    PrawnEx.Chart.line_chart(doc, data, opts)
  end

  @doc """
  Embeds an image (JPEG) at the given position. `path_or_binary` is a file path or JPEG binary.

  If `path_or_binary` is a relative path, it is resolved against the configured image directory
  (see "Image / asset path" in the module docs). Set `config :prawn_ex, image_dir: "priv/images"`
  in your app to define where to look for image files.

  Options: `:at` (required) `{x, y}` bottom-left of image, `:width` and `:height` in pt (default: intrinsic size).
  """
  @spec image(Document.t(), String.t() | binary(), keyword()) :: Document.t() | {:error, term()}
  def image(doc, path_or_binary, opts) do
    at = Keyword.fetch!(opts, :at)
    {x, y} = at
    path_or_binary = resolve_image_path(path_or_binary)

    case load_image(path_or_binary) do
      {:ok, spec} ->
        w = Keyword.get(opts, :width, spec.width)
        h = Keyword.get(opts, :height, spec.height)
        doc = ensure_current_page(doc)
        {doc, id} = Document.add_image(doc, spec)
        Document.append_op(doc, {:image, id, x, y, w, h})

      err ->
        err
    end
  end

  defp load_image(path_or_binary), do: PrawnEx.Image.JPEG.load(path_or_binary)

  # Resolve relative paths against config :prawn_ex, :image_dir (asset path for users of the dep).
  defp resolve_image_path(path_or_binary) when is_binary(path_or_binary) do
    cond do
      byte_size(path_or_binary) >= 2 and binary_part(path_or_binary, 0, 2) == <<0xFF, 0xD8>> ->
        path_or_binary

      Path.type(path_or_binary) == :absolute ->
        path_or_binary

      true ->
        case Application.get_env(:prawn_ex, :image_dir) do
          nil -> path_or_binary
          dir -> Path.join(Path.expand(dir), path_or_binary)
        end
    end
  end

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
