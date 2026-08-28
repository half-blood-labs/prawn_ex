defmodule PrawnEx.Chart do
  @moduledoc """
  Bar and line charts using drawing primitives (rectangles, lines, text).

  Used by `PrawnEx.bar_chart/3`, `PrawnEx.line_chart/3`, and
  `PrawnEx.multi_line_chart/3`. Data is scaled to fit the chart box;
  optional axis and labels.

  Colors: every `:bar_color` / `:stroke_color` (and a series `:color`)
  accepts either a gray level (`0..1`) or an `{r, g, b}` tuple (`0..1`
  each), so charts can carry a brand color instead of grayscale.
  """

  alias PrawnEx.Document

  # ---------- Bar chart ----------

  @doc """
  Draws a vertical bar chart. Data: list of `{label, value}` or `[label, value]`.
  Bars grow upward from the baseline; labels go below.

  Options (beyond `:at`, `:width`, `:height`, `:axis`, `:labels`,
  `:label_font_size`, `:padding`):

    * `:bar_color` — gray level or `{r, g, b}` tuple
    * `:value_labels` — draw each bar's value above it (default `false`)
    * `:value_formatter` — 1-arity fun turning the value into the label
      text (default `&to_string/1`)
    * `:value_font_size` — default `8`
  """
  @spec bar_chart(Document.t(), [{String.t(), number()} | [term()]], keyword()) :: Document.t()
  def bar_chart(doc, data, opts) do
    at = Keyword.fetch!(opts, :at)
    {at_x, at_y} = at
    width = Keyword.get(opts, :width, 400)
    height = Keyword.get(opts, :height, 200)
    bar_color = Keyword.get(opts, :bar_color, 0.4)
    show_axis = Keyword.get(opts, :axis, true)
    show_labels = Keyword.get(opts, :labels, true)
    label_font_size = Keyword.get(opts, :label_font_size, 9)
    padding = Keyword.get(opts, :padding, 12)

    items = normalize_bar_data(data)
    values = Enum.map(items, fn {_l, v} -> v end)
    max_val = max_value(values)
    n = length(items)

    # Chart area: at is top-left (PDF: top = higher y). Baseline at bottom.
    chart_bottom = at_y - height
    chart_left = at_x + padding
    chart_inner_w = width - 2 * padding
    chart_inner_h = height - 2 * padding
    bar_gap = max(4, chart_inner_w / max(n, 1) * 0.2)
    bar_w = max(8, (chart_inner_w - (n + 1) * bar_gap) / max(n, 1))

    doc =
      if show_axis do
        doc
        |> Document.append_op({:set_stroking_gray, 0.7})
        |> Document.append_op(
          {:line, {chart_left, chart_bottom}, {chart_left + chart_inner_w, chart_bottom}}
        )
        |> Document.append_op(:stroke)
        |> Document.append_op({:line, {chart_left, chart_bottom}, {chart_left, at_y - padding}})
        |> Document.append_op(:stroke)
        |> Document.append_op({:set_stroking_gray, 0})
      else
        doc
      end

    value_labels = Keyword.get(opts, :value_labels, false)
    value_formatter = Keyword.get(opts, :value_formatter, &to_string/1)
    value_font_size = Keyword.get(opts, :value_font_size, 8)

    doc =
      Enum.with_index(items)
      |> Enum.reduce(doc, fn {{label, value}, i}, acc ->
        bar_left = chart_left + bar_gap + i * (bar_w + bar_gap)
        bar_h = if max_val > 0, do: value / max_val * chart_inner_h, else: 0
        bar_bottom = chart_bottom

        acc
        |> set_fill_color(bar_color)
        |> Document.append_op({:rectangle, bar_left, bar_bottom, bar_w, bar_h})
        |> Document.append_op(:fill)
        |> Document.append_op({:set_non_stroking_gray, 0})
        |> then(fn d ->
          if show_labels do
            label_y = chart_bottom - 14
            label_x = bar_left + bar_w / 2 - 8

            d
            |> Document.append_op({:set_font, "Helvetica", label_font_size})
            |> Document.append_op({:text_at, {label_x, label_y}, to_string(label)})
          else
            d
          end
        end)
        |> then(fn d ->
          if value_labels do
            text = value_formatter.(value)
            # No text metrics in a pure writer: approximate Helvetica at
            # ~0.53em average advance to center the label over the bar.
            text_w = String.length(text) * value_font_size * 0.53
            value_x = bar_left + bar_w / 2 - text_w / 2
            value_y = bar_bottom + bar_h + 5

            d
            |> Document.append_op({:set_font, "Helvetica", value_font_size})
            |> Document.append_op({:text_at, {value_x, value_y}, text})
          else
            d
          end
        end)
      end)

    doc
  end

  # Gray level or {r, g, b} — both journeys end in a fill-color op.
  defp set_fill_color(doc, {r, g, b}),
    do: Document.append_op(doc, {:set_non_stroking_rgb, r, g, b})

  defp set_fill_color(doc, gray) when is_number(gray),
    do: Document.append_op(doc, {:set_non_stroking_gray, gray})

  defp set_stroke_color(doc, {r, g, b}),
    do: Document.append_op(doc, {:set_stroking_rgb, r, g, b})

  defp set_stroke_color(doc, gray) when is_number(gray),
    do: Document.append_op(doc, {:set_stroking_gray, gray})

  defp normalize_bar_data(data) do
    Enum.map(data, fn
      {l, v} -> {to_string(l), number(v)}
      [l, v] -> {to_string(l), number(v)}
    end)
  end

  defp number(n) when is_number(n), do: n

  defp number(s) when is_binary(s) do
    s = String.trim(s)

    case Float.parse(s) do
      {f, _} -> f
      :error -> String.to_integer(s)
    end
  end

  defp number(x), do: x

  defp max_value([]), do: 1
  defp max_value(vals), do: Enum.max(vals) |> max(1)

  # ---------- Line chart ----------

  @doc """
  Draws a line chart. Data: list of y-values (x = index) or list of `{x, y}` points.
  Points are scaled to fit the chart box.
  """
  @spec line_chart(Document.t(), [number()] | [{number(), number()}], keyword()) :: Document.t()
  def line_chart(doc, data, opts) do
    at = Keyword.fetch!(opts, :at)
    {at_x, at_y} = at
    width = Keyword.get(opts, :width, 400)
    height = Keyword.get(opts, :height, 200)
    stroke_color = Keyword.get(opts, :stroke_color, 0)
    show_axis = Keyword.get(opts, :axis, true)
    padding = Keyword.get(opts, :padding, 12)

    points = normalize_line_data(data)

    if length(points) < 2 do
      doc
    else
      {xs, ys} = Enum.unzip(points)
      min_x = Enum.min(xs)
      max_x = Enum.max(xs)
      min_y = Enum.min(ys)
      max_y = max(Enum.max(ys), min_y + 1)
      range_x = max_x - min_x
      range_x = if range_x == 0, do: 1, else: range_x
      range_y = max_y - min_y
      range_y = if range_y == 0, do: 1, else: range_y

      chart_left = at_x + padding
      chart_bottom = at_y - height + padding
      inner_w = width - 2 * padding
      inner_h = height - 2 * padding

      scale_x = fn x -> chart_left + (x - min_x) / range_x * inner_w end
      scale_y = fn y -> chart_bottom + (y - min_y) / range_y * inner_h end

      scaled = Enum.map(points, fn {x, y} -> {scale_x.(x), scale_y.(y)} end)

      doc =
        if show_axis do
          doc
          |> Document.append_op({:set_stroking_gray, 0.7})
          |> Document.append_op(
            {:line, {chart_left, chart_bottom}, {chart_left + inner_w, chart_bottom}}
          )
          |> Document.append_op(:stroke)
          |> Document.append_op({:line, {chart_left, chart_bottom}, {chart_left, at_y - padding}})
          |> Document.append_op(:stroke)
          |> Document.append_op({:set_stroking_gray, 0})
        else
          doc
        end

      doc =
        doc
        |> set_stroke_color(stroke_color)
        |> Document.append_op({:move_to, hd(scaled)})
        |> then(fn d ->
          Enum.reduce(tl(scaled), d, fn pt, acc -> Document.append_op(acc, {:line_to, pt}) end)
        end)
        |> Document.append_op(:stroke)
        |> Document.append_op({:set_stroking_gray, 0})

      doc
    end
  end

  # ---------- Multi-series line chart ----------

  @doc """
  Draws several lines in ONE chart box on a SHARED scale — the thing a
  single `line_chart/3` per series cannot do, since each would
  normalize to its own min/max and the comparison would lie.

  Series: list of maps (or keywords) with `:data` (y-values or `{x, y}`
  points), optional `:color` (gray or `{r, g, b}`, defaults cycle a
  small gray ramp), and optional `:label` for the legend.

  Options: `:at`, `:width`, `:height`, `:padding`, `:axis`,
  `:from_zero` (scale the y-axis from zero instead of the data minimum,
  default `false`), `:legend` (draw color-swatch labels above the box
  when any series has a `:label`, default `true`),
  `:legend_font_size` (default `8`).
  """
  @spec multi_line_chart(Document.t(), [map() | keyword()], keyword()) :: Document.t()
  def multi_line_chart(doc, series, opts) do
    at = Keyword.fetch!(opts, :at)
    {at_x, at_y} = at
    width = Keyword.get(opts, :width, 400)
    height = Keyword.get(opts, :height, 200)
    show_axis = Keyword.get(opts, :axis, true)
    padding = Keyword.get(opts, :padding, 12)
    from_zero = Keyword.get(opts, :from_zero, false)
    show_legend = Keyword.get(opts, :legend, true)
    legend_font_size = Keyword.get(opts, :legend_font_size, 8)

    series = Enum.map(series, &normalize_series/1)
    all_points = Enum.flat_map(series, & &1.points)

    if length(all_points) < 2 do
      doc
    else
      {xs, ys} = Enum.unzip(all_points)
      min_x = Enum.min(xs)
      max_x = Enum.max(xs)
      min_y = if from_zero, do: 0.0, else: Enum.min(ys)
      max_y = max(Enum.max(ys), min_y + 1)
      range_x = max(max_x - min_x, 1)
      range_y = max(max_y - min_y, 1)

      chart_left = at_x + padding
      chart_bottom = at_y - height + padding
      inner_w = width - 2 * padding
      inner_h = height - 2 * padding

      scale_x = fn x -> chart_left + (x - min_x) / range_x * inner_w end
      scale_y = fn y -> chart_bottom + (y - min_y) / range_y * inner_h end

      doc =
        if show_axis do
          doc
          |> Document.append_op({:set_stroking_gray, 0.7})
          |> Document.append_op(
            {:line, {chart_left, chart_bottom}, {chart_left + inner_w, chart_bottom}}
          )
          |> Document.append_op(:stroke)
          |> Document.append_op({:line, {chart_left, chart_bottom}, {chart_left, at_y - padding}})
          |> Document.append_op(:stroke)
          |> Document.append_op({:set_stroking_gray, 0})
        else
          doc
        end

      doc =
        series
        |> Enum.with_index()
        |> Enum.reduce(doc, fn {%{points: points, color: color}, i}, acc ->
          case Enum.map(points, fn {x, y} -> {scale_x.(x), scale_y.(y)} end) do
            scaled when length(scaled) >= 2 ->
              acc
              |> set_stroke_color(color || default_series_color(i))
              |> Document.append_op({:move_to, hd(scaled)})
              |> then(fn d ->
                Enum.reduce(tl(scaled), d, fn pt, a -> Document.append_op(a, {:line_to, pt}) end)
              end)
              |> Document.append_op(:stroke)
              |> Document.append_op({:set_stroking_gray, 0})

            _ ->
              acc
          end
        end)

      labeled = Enum.filter(series, & &1.label)

      if show_legend and labeled != [] do
        draw_legend(doc, labeled, chart_left, at_y - 2, legend_font_size)
      else
        doc
      end
    end
  end

  defp normalize_series(series) do
    series = Map.new(series)

    %{
      points: normalize_line_data(Map.fetch!(series, :data)),
      color: Map.get(series, :color),
      label: Map.get(series, :label)
    }
  end

  # A small ramp so unstyled series stay distinguishable in grayscale.
  defp default_series_color(i), do: rem(i, 4) * 0.2

  defp draw_legend(doc, labeled, x, y, font_size) do
    {doc, _x} =
      labeled
      |> Enum.with_index()
      |> Enum.reduce({doc, x}, fn {%{label: label, color: color}, i}, {doc, cx} ->
        doc =
          doc
          |> set_fill_color(color || default_series_color(i))
          |> Document.append_op({:rectangle, cx, y - font_size + 2, font_size - 1, font_size - 1})
          |> Document.append_op(:fill)
          |> Document.append_op({:set_non_stroking_gray, 0.25})
          |> Document.append_op({:set_font, "Helvetica", font_size})
          |> Document.append_op({:text_at, {cx + font_size + 3, y - font_size + 2}, label})
          |> Document.append_op({:set_non_stroking_gray, 0})

        {doc, cx + font_size + 3 + String.length(label) * font_size * 0.53 + 14}
      end)

    doc
  end

  defp normalize_line_data(ys) when is_list(ys) and length(ys) > 0 do
    case hd(ys) do
      {_x, _y} -> Enum.map(ys, fn {x, y} -> {x * 1.0, y * 1.0} end)
      _ -> Enum.with_index(ys, fn y, i -> {i * 1.0, number(y) * 1.0} end)
    end
  end

  defp normalize_line_data(_), do: []
end
