defmodule PrawnEx.Chart do
  @moduledoc """
  Bar and line charts using drawing primitives (rectangles, lines, text).

  Used by `PrawnEx.bar_chart/3` and `PrawnEx.line_chart/3`. Data is scaled to fit
  the chart box; optional axis and labels.
  """

  alias PrawnEx.Document

  # ---------- Bar chart ----------

  @doc """
  Draws a vertical bar chart. Data: list of `{label, value}` or `[label, value]`.
  Bars grow upward from the baseline; labels go below.
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

    doc =
      Enum.with_index(items)
      |> Enum.reduce(doc, fn {{label, value}, i}, acc ->
        bar_left = chart_left + bar_gap + i * (bar_w + bar_gap)
        bar_h = if max_val > 0, do: value / max_val * chart_inner_h, else: 0
        bar_bottom = chart_bottom

        acc
        |> Document.append_op({:set_non_stroking_gray, bar_color})
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
      end)

    doc
  end

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
        |> Document.append_op({:set_stroking_gray, stroke_color})
        |> Document.append_op({:move_to, hd(scaled)})
        |> then(fn d ->
          Enum.reduce(tl(scaled), d, fn pt, acc -> Document.append_op(acc, {:line_to, pt}) end)
        end)
        |> Document.append_op(:stroke)
        |> Document.append_op({:set_stroking_gray, 0})

      doc
    end
  end

  defp normalize_line_data(ys) when is_list(ys) and length(ys) > 0 do
    case hd(ys) do
      {_x, _y} -> Enum.map(ys, fn {x, y} -> {x * 1.0, y * 1.0} end)
      _ -> Enum.with_index(ys, fn y, i -> {i * 1.0, number(y) * 1.0} end)
    end
  end

  defp normalize_line_data(_), do: []
end
