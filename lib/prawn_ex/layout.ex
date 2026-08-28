defmodule PrawnEx.Layout do
  @moduledoc """
  Margin box + vertical flow helpers on top of `PrawnEx`.

  Tracks a PDF **baseline cursor** (`cursor_y`) so you avoid repeating `page_h - N`
  arithmetic for common stacks (title, paragraphs, table, spacer). Coordinates
  match the rest of PrawnEx: origin bottom-left, `y` increases upward.

  ## Phases

  - **Flow** — `attach/2`, `heading/3`, `paragraph/3`, `spacer/2`, `table/3`, `escape/2`, `to_doc/1`.
  - **B — stacks** — `vstack/3` (vertical list of flow blocks), `hstack/3` (fixed-width columns).
  - **C — region + pagination** — optional `region:` on `attach/2`; when content would extend
    below `floor_y`, a **new page** is started (`on_overflow: :new_page`, default). No automatic
    splitting of a single oversized paragraph across pages.
  - **D — markup** — see `PrawnEx.Layout.Markup` (`parse/1`, `apply/2`).

  Typical use:

      doc
      |> PrawnEx.add_page()
      |> PrawnEx.Layout.attach(page_size: :a4, margins: %{top: 60, left: 50, right: 50, bottom: 50})
      |> PrawnEx.Layout.heading("INVOICE", font_size: 24)
      |> PrawnEx.Layout.paragraph("Acme Inc.\\n123 Main St", font_size: 10, line_height: 14)
      |> PrawnEx.Layout.to_doc()

  Escape hatch for one-off coordinates: `escape/2`.
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
    :page_size,
    :region_floor_y,
    :on_overflow
  ]

  @type margins :: %{left: number(), right: number(), top: number(), bottom: number()}
  @type flow_block ::
          {:heading, String.t(), keyword()}
          | {:paragraph, String.t(), keyword()}
          | {:spacer, number()}
          | {:table, [list()], keyword()}
          | {:run, (t() -> t())}

  @type t :: %__MODULE__{
          doc: Document.t(),
          page_w: number(),
          page_h: number(),
          margins: margins(),
          cursor_y: number(),
          content_left: number(),
          content_width: number(),
          page_size: atom() | tuple(),
          region_floor_y: number() | nil,
          on_overflow: :new_page | :clip
        }

  @doc """
  Attaches flow state to `doc`. Requires at least one page.

  Options:

  - `:page_size` — passed to `PrawnEx.Units.page_size/1` (default from `doc.opts[:page_size]` or `:a4`)
  - `:margins` — a number (all sides) or `%{left:, right:, top:, bottom:}` (missing keys default to 50)
  - `:region` — `%{floor_y: y}` or bare `y` (PDF y); content must not extend **below** this y (see Phase C).
    When unset, no automatic page breaks are inserted.
  - `:on_overflow` — `:new_page` (default when region set) or `:clip` (draw anyway; no new page)

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

    {floor_y, on_overflow} = parse_region_opts(Keyword.get(opts, :region), opts)

    %__MODULE__{
      doc: doc,
      page_w: w,
      page_h: h,
      margins: margins,
      cursor_y: cursor_y,
      content_left: left,
      content_width: content_width,
      page_size: page_size,
      region_floor_y: floor_y,
      on_overflow: on_overflow
    }
  end

  defp parse_region_opts(nil, opts) do
    _ = Keyword.get(opts, :on_overflow, :new_page)
    {nil, :clip}
  end

  defp parse_region_opts(y, opts) when is_number(y) do
    {y, Keyword.get(opts, :on_overflow, :new_page)}
  end

  defp parse_region_opts(%{floor_y: y}, opts) when is_number(y) do
    {y, Keyword.get(opts, :on_overflow, :new_page)}
  end

  defp parse_region_opts(%{"floor_y" => y}, opts) when is_number(y) do
    {y, Keyword.get(opts, :on_overflow, :new_page)}
  end

  defp parse_region_opts(_, opts) do
    {nil, Keyword.get(opts, :on_overflow, :clip)}
  end

  @doc """
  Single-line heading. Options: `:font`, `:font_size` (default from `:level`), `:level` (1 or 2),
  `:lead` (default 1.0), `:gap_after` (default 6).
  """
  @spec heading(t(), String.t(), keyword()) :: t()
  def heading(%__MODULE__{} = l, text, opts \\ []) when is_binary(text) do
    font = Keyword.get(opts, :font, "Helvetica")
    level = Keyword.get(opts, :level, 1)

    size =
      Keyword.get(opts, :font_size, if(level == 2, do: 14, else: 20))

    lead = Keyword.get(opts, :lead, 1.0)
    gap_after = Keyword.get(opts, :gap_after, if(level == 2, do: 10, else: 8))

    lowest = l.cursor_y - size * 1.15
    l = maybe_break_for_extent(l, lowest)

    doc =
      l.doc
      |> PrawnEx.set_font(font, size)
      |> PrawnEx.text_at({l.content_left, l.cursor_y}, text)

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
    gap_after = Keyword.get(opts, :gap_after, 10)

    lines = Text.wrap_to_lines(text, width, font_size)

    if lines == [] do
      l
    else
      n = length(lines)
      lowest = l.cursor_y - (n - 1) * line_height
      l = maybe_break_for_extent(l, lowest)
      lowest2 = l.cursor_y - (n - 1) * line_height

      if l.region_floor_y && lowest2 < l.region_floor_y do
        raise ArgumentError,
              "PrawnEx.Layout: paragraph taller than the content region; split the text or widen the region"
      end

      doc =
        PrawnEx.text_box(l.doc, text,
          at: {l.content_left, l.cursor_y},
          width: width,
          font_name: font_name,
          font_size: font_size,
          line_height: line_height
        )

      last_baseline = l.cursor_y - (n - 1) * line_height
      %{l | doc: doc, cursor_y: last_baseline - gap_after}
    end
  end

  @doc """
  Moves the baseline cursor down the page by `pts` points (decreases PDF `y`).
  """
  @spec spacer(t(), number()) :: t()
  def spacer(%__MODULE__{} = l, pts) when is_number(pts) and pts >= 0 do
    cond do
      is_nil(l.region_floor_y) or l.on_overflow == :clip ->
        %{l | cursor_y: l.cursor_y - pts}

      true ->
        consume_spacer_vertical(l, pts, 0)
    end
  end

  defp consume_spacer_vertical(_, _, depth) when depth > 80 do
    raise ArgumentError,
          "PrawnEx.Layout: spacer exceeded page wrap limit (check region floor or spacer size)"
  end

  defp consume_spacer_vertical(l, 0, _depth), do: l

  defp consume_spacer_vertical(l, remaining, depth) do
    usable = l.cursor_y - l.region_floor_y

    cond do
      usable >= remaining ->
        %{l | cursor_y: l.cursor_y - remaining}

      usable <= 0 ->
        consume_spacer_vertical(new_page_reset(l), remaining, depth + 1)

      true ->
        l1 = %{l | cursor_y: l.cursor_y - usable}
        consume_spacer_vertical(new_page_reset(l1), remaining - usable, depth + 1)
    end
  end

  @doc """
  Draws a table whose **top** edge sits `clearance` pt **below** the current cursor.

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
    lowest = at_y - table_height
    l = maybe_break_for_extent(l, lowest)

    at_y = l.cursor_y - clearance

    opts =
      opts
      |> Keyword.put(:at, {l.content_left, at_y})
      |> Keyword.put_new(:page_size, l.page_size)

    doc = PrawnEx.table(l.doc, rows, opts)
    %{l | doc: doc, cursor_y: at_y - table_height - after_gap}
  end

  @doc """
  Vertical stack of **flow blocks** (Phase B). `blocks` are tuples:

  - `{:heading, text, opts}` — passed to `heading/3`
  - `{:paragraph, text, opts}` — passed to `paragraph/3`
  - `{:spacer, pts}` — passed to `spacer/2`
  - `{:table, rows, opts}` — passed to `table/3`
  - `{:run, fn layout -> layout end}` — custom

  Options: `:gap` — extra spacer inserted **between** blocks (not after the last).
  """
  @spec vstack(t(), [flow_block()], keyword()) :: t()
  def vstack(%__MODULE__{} = l, blocks, opts \\ []) when is_list(blocks) do
    gap = Keyword.get(opts, :gap, 0)
    n = length(blocks)

    blocks
    |> Enum.with_index()
    |> Enum.reduce(l, fn {block, i}, acc ->
      acc = apply_flow_block(acc, block)

      if gap > 0 and i < n - 1 do
        spacer(acc, gap)
      else
        acc
      end
    end)
  end

  @doc """
  Horizontal row of fixed-width columns (Phase B). Each column is `{width_pt, fn sub_layout -> sub_layout}`.
  The function receives a layout whose `content_left` / `content_width` / `cursor_y` are scoped to that
  column; merge the returned `doc` and advance the outer cursor by the **deepest** column drop plus
  `:row_gap_after` (default 8).

  Options: `:gap` between columns (default 8), `:row_gap_after` (default 10),
  `:min_row_depth` — minimum vertical budget in pt for the row (default 22). Short columns
  only move the cursor by `gap_after` pixels; without a floor, the next block can overlap the row.
  """
  @spec hstack(t(), [{number(), (t() -> t())}], keyword()) :: t()
  def hstack(%__MODULE__{} = l, columns, opts \\ []) when is_list(columns) do
    gap = Keyword.get(opts, :gap, 8)
    row_gap_after = Keyword.get(opts, :row_gap_after, 10)
    min_row_depth = Keyword.get(opts, :min_row_depth, 22)
    row_top_y = l.cursor_y

    {doc, max_drop} =
      Enum.with_index(columns)
      |> Enum.reduce({l.doc, 0}, fn {{width, render_fn}, i}, {doc, max_drop} ->
        x = l.content_left + hstack_prefix_width(columns, gap, i)

        col_l = %{
          l
          | doc: doc,
            content_left: x,
            content_width: width,
            cursor_y: row_top_y
        }

        out = render_fn.(col_l)
        drop = row_top_y - out.cursor_y
        {out.doc, max(max_drop, drop)}
      end)

    effective_drop = max(max_drop, min_row_depth)
    %{l | doc: doc, cursor_y: row_top_y - effective_drop - row_gap_after}
  end

  defp hstack_prefix_width(columns, gap, i) do
    columns
    |> Enum.take(i)
    |> Enum.reduce(0, fn {w, _}, acc -> acc + w + gap end)
  end

  defp apply_flow_block(l, {:heading, text, o}), do: heading(l, text, o)
  defp apply_flow_block(l, {:paragraph, text, o}), do: paragraph(l, text, o)
  defp apply_flow_block(l, {:spacer, n}), do: spacer(l, n)
  defp apply_flow_block(l, {:table, rows, o}), do: table(l, rows, o)
  defp apply_flow_block(l, {:run, f}) when is_function(f, 1), do: f.(l)

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

  defp maybe_break_for_extent(l, lowest_y) do
    cond do
      is_nil(l.region_floor_y) ->
        l

      lowest_y >= l.region_floor_y ->
        l

      l.on_overflow == :clip ->
        l

      true ->
        new_page_reset(l)
    end
  end

  defp new_page_reset(l) do
    doc = PrawnEx.add_page(l.doc)
    %{l | doc: doc, cursor_y: l.page_h - l.margins.top}
  end

  defp normalize_margins(n) when is_number(n) do
    %{left: n, right: n, top: n, bottom: n}
  end

  defp normalize_margins(%{} = m) do
    defaults = %{left: 50, right: 50, top: 50, bottom: 50}
    Map.merge(defaults, m)
  end
end
