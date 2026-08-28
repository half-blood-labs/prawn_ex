defmodule PrawnEx.Shapes do
  @moduledoc """
  Path builders shared by the public API and the chart renderers.

  These append path ops only — the caller decides whether to `fill`,
  `stroke`, or `fill_stroke` the result.
  """

  alias PrawnEx.Document

  # Circle-to-Bézier constant: the control-point offset that makes four
  # curves approximate a quarter arc.
  @kappa 0.5523

  @doc """
  Appends a rounded-rectangle path. `radius` is clamped to half the
  shorter side, so an over-large radius degrades to a stadium instead
  of turning inside out. A radius of 0 emits a plain rectangle.
  """
  @spec rounded_rect(Document.t(), number(), number(), number(), number(), number()) ::
          Document.t()
  def rounded_rect(doc, x, y, w, h, radius) do
    r = min(radius, min(abs(w), abs(h)) / 2)

    if r <= 0 do
      Document.append_op(doc, {:rectangle, x, y, w, h})
    else
      k = @kappa * r

      doc
      |> op({:move_to, {x + r, y}})
      |> op({:line_to, {x + w - r, y}})
      |> op({:curve_to, {x + w - r + k, y}, {x + w, y + r - k}, {x + w, y + r}})
      |> op({:line_to, {x + w, y + h - r}})
      |> op({:curve_to, {x + w, y + h - r + k}, {x + w - r + k, y + h}, {x + w - r, y + h}})
      |> op({:line_to, {x + r, y + h}})
      |> op({:curve_to, {x + r - k, y + h}, {x, y + h - r + k}, {x, y + h - r}})
      |> op({:line_to, {x, y + r}})
      |> op({:curve_to, {x, y + r - k}, {x + r - k, y}, {x + r, y}})
      |> op(:close_path)
    end
  end

  defp op(doc, operation), do: Document.append_op(doc, operation)
end
