defmodule PrawnEx.Units do
  @moduledoc """
  Unit conversion and standard page sizes for PDF.

  PDF uses points (pt) as the base unit: 1 pt = 1/72 inch.

  ## Examples

      iex> PrawnEx.Units.pt(72)
      72
      iex> PrawnEx.Units.inch(1)
      72
      iex> PrawnEx.Units.mm(25.4)
      72.0
      iex> PrawnEx.Units.page_size(:a4)
      {595, 842}
      iex> PrawnEx.Units.page_size(:letter)
      {612, 792}
  """

  @points_per_inch 72

  @doc """
  Identity for points (PDF base unit). Use for clarity.
  """
  @spec pt(number()) :: number()
  def pt(n), do: n

  @doc """
  Convert inches to points. 1 inch = 72 pt.
  """
  @spec inch(number()) :: number()
  def inch(n), do: n * @points_per_inch

  @doc """
  Convert millimetres to points.
  """
  @spec mm(number()) :: float()
  def mm(n), do: n * @points_per_inch / 25.4

  @doc """
  Convert centimetres to points.
  """
  @spec cm(number()) :: float()
  def cm(n), do: n * @points_per_inch / 2.54

  @doc """
  Return page dimensions in points `{width, height}` for a named size.

  Supports `:a4`, `:letter`, `:legal`, `:a3`, `:a5`. Optional second element
  `:landscape` flips width and height.

  ## Examples

      iex> PrawnEx.Units.page_size(:a4)
      {595, 842}
      iex> PrawnEx.Units.page_size({:a4, :landscape})
      {842, 595}
  """
  @spec page_size(:a3 | :a4 | :a5 | :letter | :legal | {atom(), :landscape}) :: {number(), number()}
  def page_size(:a4), do: {595, 842}
  def page_size(:a3), do: {841, 1190}
  def page_size(:a5), do: {420, 595}
  def page_size(:letter), do: {612, 792}
  def page_size(:legal), do: {612, 1008}

  def page_size({size, :landscape}) do
    {w, h} = page_size(size)
    {h, w}
  end
end
