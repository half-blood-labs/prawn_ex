defmodule PrawnEx.Layout do
  @moduledoc """
  Margin box + vertical flow helpers on top of `PrawnEx`.

  Tracks a PDF **baseline cursor** (`cursor_y`) so you avoid repeating `page_h - N`
  arithmetic for common stacks (title, paragraphs, table, spacer). Coordinates
  match the rest of PrawnEx: origin bottom-left, `y` increases upward.

  Typical use:

      doc
      |> PrawnEx.add_page()
      |> PrawnEx.Layout.attach(page_size: :a4, margins: %{top: 60, left: 50, right: 50, bottom: 50})
      |> PrawnEx.Layout.heading("INVOICE", font_size: 24)
      |> PrawnEx.Layout.paragraph("Acme Inc.\\n123 Main St", font_size: 10, line_height: 14)
      |> PrawnEx.Layout.spacer(24)
      |> PrawnEx.Layout.table(rows, column_widths: [...], header: true, clearance: 24)
      |> PrawnEx.Layout.to_doc()

  Escape hatch for one-off coordinates: `escape/2`.

  Pagination and multi-column layout are **not** handled here; overflow is still manual.
  """

  alias PrawnEx.Document
  alias PrawnEx.Text
  alias PrawnEx.Units

  defstruct [
    :doc,
    :page_w,
    :page_h,
    :margins,
    :cursor_y,
    :content_left,
    :content_width,
    :page_size
  ]

  @type margins :: %{left: number(), right: number(), top: number(), bottom: number()}
  @type t :: %__MODULE__{
          doc: Document.t(),
          page_w: number(),
          page_h: number(),
          margins: margins(),
          cursor_y: number(),
          content_left: number(),
          content_width: number(),
          page_size: atom() | tuple()
        }

  @doc """
  Attaches flow state to `doc`. Requires at least one page.

  Options:

  - `:page_size` — passed to `PrawnEx.Units.page_size/1` (default from `doc.opts[:page_size]` or `:a4`)
  - `:margins` — a number (all sides) or `%{left:, right:, top:, bottom:}` (missing keys default to 50)

  Initial `cursor_y` is the first text baseline under the top margin: `page_h - margins.top`.
  """
  @spec attach(Document.t(), keyword()) :: t()
  def attach(%Document{} = doc, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, doc.opts[:page_size] || :a4)
    {w, h} = Units.page_size(page_size)
    margins = normalize_margins(Keyword.get(opts, :margins, 50))
    left = margins.left
    right = margins.right
    content_width = w - left - right
    cursor_y = h - margins.top

    %__MODULE__{
      doc: doc,
      page_w: w,
      page_h: h,
      margins: margins,
      cursor_y: cursor_y,
      content_left: left,
      content_width: content_width,
      page_size: page_size
    }
  end

  @doc """
  Single-line heading. Options: `:font`, `:font_size` (default 20), `:lead` (default 1.25),
  `:gap_after` (default 8).
  """
  @spec heading(t(), String.t(), keyword()) :: t()
  def heading(%__MODULE__{} = l, text, opts \\ []) when is_binary(text) do
    font = Keyword.get(opts, :font, "Helvetica")
    size = Keyword.get(opts, :font_size, 20)
    lead = Keyword.get(opts, :lead, 1.0)
    gap_after = Keyword.get(opts, :gap_after, 6)

    doc =
      l.doc
      |> PrawnEx.set_font(font, size)
      |> PrawnEx.text_at({l.content_left, l.cursor_y}, text)

    # Next block's first baseline sits `size * lead + gap_after` below this heading's baseline.
    %{l | doc: doc, cursor_y: l.cursor_y - (size * lead + gap_after)}
  end

  @doc """
  Wrapped paragraph using `PrawnEx.text_box/3`. Options: `:font_name`, `:font_size` (default 10),
  `:line_height` (default `font_size * 1.2`), `:width` (default content width), `:gap_after` (default 8).
  Preserves newlines like `text_box` / `Text.wrap_to_lines`.
  """
  @spec paragraph(t(), String.t(), keyword()) :: t()
  def paragraph(%__MODULE__{} = l, text, opts \\ []) when is_binary(text) do
    font_name = Keyword.get(opts, :font_name, "Helvetica")
    font_size = Keyword.get(opts, :font_size, 10)
    line_height = Keyword.get(opts, :line_height, font_size * 1.2)
    width = Keyword.get(opts, :width, l.content_width)
    gap_after = Keyword.get(opts, :gap_after, 8)

    lines = Text.wrap_to_lines(text, width, font_size)

    if lines == [] do
      l
    else
      doc =
        PrawnEx.text_box(l.doc, text,
          at: {l.content_left, l.cursor_y},
          width: width,
          font_name: font_name,
          font_size: font_size,
          line_height: line_height
        )

      n = length(lines)
      last_baseline = l.cursor_y - (n - 1) * line_height
      %{l | doc: doc, cursor_y: last_baseline - gap_after}
    end
  end

  @doc """
  Moves the baseline cursor down the page by `pts` points (decreases PDF `y`).
  """
  @spec spacer(t(), number()) :: t()
  def spacer(%__MODULE__{} = l, pts) when is_number(pts) do
    %{l | cursor_y: l.cursor_y - pts}
  end

  @doc """
  Draws a table whose **top** edge sits `clearance` pt **below** the current cursor (previous
  text baseline area). After the table, the cursor moves to the baseline region **below**
  the table (`after_gap` extra).

  Forwards options to `PrawnEx.table/3` except: `:clearance` (default 20), `:after_gap` (default 12),
  and `:at` / `:page_size` are supplied automatically unless you pass `:page_size` in opts.
  """
  @spec table(t(), [list()], keyword()) :: t()
  def table(%__MODULE__{} = l, rows, opts \\ []) when is_list(rows) do
    if rows == [] do
      l
    else
      do_table(l, rows, opts)
    end
  end

  defp do_table(l, rows, opts) do
    clearance = Keyword.get(opts, :clearance, 20)
    after_gap = Keyword.get(opts, :after_gap, 12)
    row_height = Keyword.get(opts, :row_height, 24)

    n_rows = length(rows)
    table_height = n_rows * row_height
    at_y = l.cursor_y - clearance

    opts =
      opts
      |> Keyword.put(:at, {l.content_left, at_y})
      |> Keyword.put_new(:page_size, l.page_size)

    doc = PrawnEx.table(l.doc, rows, opts)
    %{l | doc: doc, cursor_y: at_y - table_height - after_gap}
  end

  @doc """
  Low-level escape: `fun` receives `(doc, ctx)` where `ctx` is a map with `:cursor_y`,
  `:content_left`, `:content_width`, `:page_w`, `:page_h`, `:margins`. Return `{new_doc, new_cursor_y}`.
  """
  def escape(%__MODULE__{} = l, fun) when is_function(fun, 2) do
    ctx = %{
      cursor_y: l.cursor_y,
      content_left: l.content_left,
      content_width: l.content_width,
      page_w: l.page_w,
      page_h: l.page_h,
      margins: l.margins
    }

    {doc, cy} = fun.(l.doc, ctx)
    %{l | doc: doc, cursor_y: cy}
  end

  @doc "Returns the underlying document for `PrawnEx.build/2` callbacks or `to_binary/1`."
  @spec to_doc(t()) :: Document.t()
  def to_doc(%__MODULE__{doc: doc}), do: doc

  defp normalize_margins(n) when is_number(n) do
    %{left: n, right: n, top: n, bottom: n}
  end

  defp normalize_margins(%{} = m) do
    defaults = %{left: 50, right: 50, top: 50, bottom: 50}
    Map.merge(defaults, m)
  end
end
