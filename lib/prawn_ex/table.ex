defmodule PrawnEx.Table do
  @moduledoc """
  Table layout: draws a grid of cells with optional header row.

  Used by `PrawnEx.table/3`. Rows are list of lists (or list of maps with consistent keys).
  Options control position, column widths, row height, padding, and header styling.
  """

  alias PrawnEx.Document
  alias PrawnEx.Units

  @doc """
  Draws a table on the document at the given position.

  ## Options

  - `:at` - `{x, y}` top-left of table (required). PDF coordinates: y is from bottom.
  - `:column_widths` - list of widths in pt, or `:auto` to split page width equally
  - `:row_height` - height of each row in pt (default 24)
  - `:cell_padding` - padding inside each cell (default 6)
  - `:header` - if true, first row is styled as header (default true when rows present)
  - `:border` - draw cell borders (default true)
  - `:font_size` - body font size (default 10)
  - `:header_font_size` - header row font size (default 11)
  - `:page_size` - for `:auto` column widths (default :a4)

  ## Examples

      rows = [["Product", "Qty", "Price"], ["Widget", "2", "$10"], ["Gadget", "1", "$25"]]
      doc
      |> PrawnEx.table(rows, at: {50, 650}, column_widths: [200, 80, 80], header: true)
  """
  @spec layout(Document.t(), [list()], keyword()) :: Document.t()
  def layout(doc, rows, opts) do
    at = Keyword.fetch!(opts, :at)
    {at_x, at_y} = at
    row_height = Keyword.get(opts, :row_height, 24)
    cell_padding = Keyword.get(opts, :cell_padding, 6)
    header? = Keyword.get(opts, :header, true)
    border? = Keyword.get(opts, :border, true)
    font_size = Keyword.get(opts, :font_size, 10)
    header_font_size = Keyword.get(opts, :header_font_size, 11)
    page_size = Keyword.get(opts, :page_size, :a4)

    rows = normalize_rows(rows)
    n_cols = rows |> List.first() |> length()
    column_widths = resolve_column_widths(opts, n_cols, page_size)

    draw_rows(doc, rows, at_x, at_y, column_widths, row_height, cell_padding, %{
      header?: header?,
      border?: border?,
      font_size: font_size,
      header_font_size: header_font_size
    })
  end

  defp normalize_rows(rows) when is_list(rows) do
    Enum.map(rows, fn
      row when is_list(row) -> Enum.map(row, &to_string/1)
      row when is_map(row) -> row |> Map.values() |> Enum.map(&to_string/1)
    end)
  end

  defp resolve_column_widths(opts, n_cols, page_size) do
    case Keyword.get(opts, :column_widths, :auto) do
      :auto ->
        {page_w, _} = Units.page_size(page_size)
        margin = 50 * 2
        width = (page_w - margin) / n_cols
        List.duplicate(width, n_cols)

      widths when is_list(widths) ->
        widths
    end
  end

  defp draw_rows(doc, rows, at_x, at_y, col_widths, row_height, padding, opts) do
    header? = opts.header?
    border? = opts.border?
    font_size = opts.font_size
    header_font_size = opts.header_font_size

    Enum.with_index(rows)
    |> Enum.reduce(doc, fn {row, i}, acc ->
      is_header = header? and i == 0
      y_top = at_y - i * row_height
      y_bottom = y_top - row_height

      draw_row_cells(acc, row, at_x, y_bottom, col_widths, row_height, padding, %{
        is_header: is_header,
        border?: border?,
        font_size: if(is_header, do: header_font_size, else: font_size)
      })
    end)
  end

  defp draw_row_cells(doc, row, x_start, y_bottom, col_widths, row_height, padding, opts) do
    is_header = opts.is_header
    border? = opts.border?
    font_size = opts.font_size

    doc =
      if is_header do
        # Header background
        total_w = Enum.sum(col_widths)

        doc
        |> Document.append_op({:set_non_stroking_gray, 0.9})
        |> Document.append_op({:rectangle, x_start, y_bottom, total_w, row_height})
        |> Document.append_op(:fill)
        |> Document.append_op({:set_non_stroking_gray, 0})
      else
        doc
      end

    doc =
      Enum.with_index(Enum.zip(row, col_widths))
      |> Enum.reduce(doc, fn {{cell_text, col_w}, j}, d ->
        cell_x = x_start + (Enum.take(col_widths, j) |> Enum.sum())
        text_x = cell_x + padding
        text_y = y_bottom + padding

        d =
          if border? do
            d
            |> Document.append_op({:set_stroking_gray, 0.75})
            |> Document.append_op({:rectangle, cell_x, y_bottom, col_w, row_height})
            |> Document.append_op(:stroke)
            |> Document.append_op({:set_stroking_gray, 0})
          else
            d
          end

        d
        |> Document.append_op({:set_font, "Helvetica", font_size})
        |> Document.append_op({:text_at, {text_x, text_y}, cell_text})
      end)

    doc
  end
end
