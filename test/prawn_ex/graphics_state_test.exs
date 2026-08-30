defmodule PrawnEx.GraphicsStateTest do
  use ExUnit.Case, async: true

  alias PrawnEx.Document
  alias PrawnEx.PDF.ContentStream

  defp doc, do: Document.new() |> Document.add_page()

  defp ops(doc), do: doc |> Document.current_page() |> PrawnEx.Page.content_ops()

  defp stream(doc), do: doc |> ops() |> ContentStream.build()

  # Applies a PDF matrix [a b c d e f] to a point, the way the viewer would.
  defp apply_matrix({:concat_matrix, a, b, c, d, e, f}, {x, y}) do
    {a * x + c * y + e, b * x + d * y + f}
  end

  describe "save_state/1 and restore_state/1" do
    test "emit q and Q around the ops they wrap" do
      stream =
        doc()
        |> PrawnEx.save_state()
        |> PrawnEx.set_line_width(2)
        |> PrawnEx.restore_state()
        |> stream()

      assert stream == "q\n2.0000 w\nQ"
    end
  end

  describe "concat_matrix/7" do
    test "appends the op and emits cm" do
      doc = PrawnEx.concat_matrix(doc(), 2, 0, 0, 2, 10, 20)

      assert ops(doc) == [{:concat_matrix, 2, 0, 0, 2, 10, 20}]
      assert stream(doc) == "2 0 0 2 10 20 cm"
    end
  end

  describe "translate/3" do
    test "emits a pure translation matrix" do
      assert doc() |> PrawnEx.translate(30, -15) |> stream() == "1 0 0 1 30 -15 cm"
    end

    test "moves a point by the offset" do
      [op] = doc() |> PrawnEx.translate(30, -15) |> ops()

      assert apply_matrix(op, {5, 5}) == {35, -10}
    end
  end

  describe "rotate/3" do
    test "90 degrees about the origin" do
      assert doc() |> PrawnEx.rotate(90) |> stream() ==
               "0.0000 1.0000 -1.0000 0.0000 0.0000 0.0000 cm"
    end

    test "0 degrees is the identity" do
      assert doc() |> PrawnEx.rotate(0) |> stream() ==
               "1.0000 0.0000 0.0000 1.0000 0.0000 0.0000 cm"
    end

    test "45 degrees" do
      assert doc() |> PrawnEx.rotate(45) |> stream() ==
               "0.7071 0.7071 -0.7071 0.7071 0.0000 0.0000 cm"
    end

    test "positive degrees turn counter-clockwise" do
      [op] = doc() |> PrawnEx.rotate(90) |> ops()
      {x, y} = apply_matrix(op, {1, 0})

      assert_in_delta x, 0.0, 1.0e-6
      assert_in_delta y, 1.0, 1.0e-6
    end

    test "negative degrees turn clockwise" do
      [op] = doc() |> PrawnEx.rotate(-90) |> ops()
      {x, y} = apply_matrix(op, {1, 0})

      assert_in_delta x, 0.0, 1.0e-6
      assert_in_delta y, -1.0, 1.0e-6
    end

    test ":about folds the pivot into a single matrix" do
      assert doc() |> PrawnEx.rotate(90, about: {100, 200}) |> stream() ==
               "0.0000 1.0000 -1.0000 0.0000 300.0000 100.0000 cm"
    end

    test ":about leaves the pivot point where it is" do
      pivot = {120, 90}

      for degrees <- [0, 37, 90, 180, -45, 270] do
        [op] = doc() |> PrawnEx.rotate(degrees, about: pivot) |> ops()
        {x, y} = apply_matrix(op, pivot)

        assert_in_delta x, 120.0, 1.0e-6, "x drifted at #{degrees} degrees"
        assert_in_delta y, 90.0, 1.0e-6, "y drifted at #{degrees} degrees"
      end
    end

    test ":about rotates the surrounding points around the pivot" do
      # A point 10pt to the right of the pivot, turned a quarter turn
      # counter-clockwise, ends up 10pt above it.
      [op] = doc() |> PrawnEx.rotate(90, about: {50, 50}) |> ops()
      {x, y} = apply_matrix(op, {60, 50})

      assert_in_delta x, 50.0, 1.0e-6
      assert_in_delta y, 60.0, 1.0e-6
    end

    test "matches an explicit translate / rotate / untranslate chain" do
      [folded] = doc() |> PrawnEx.rotate(37, about: {70, 40}) |> ops()

      chained =
        doc()
        |> PrawnEx.translate(70, 40)
        |> PrawnEx.rotate(37)
        |> PrawnEx.translate(-70, -40)
        |> ops()

      point = {17, 123}

      {fx, fy} = apply_matrix(folded, point)
      {cx, cy} = Enum.reduce(Enum.reverse(chained), point, &apply_matrix/2)

      assert_in_delta fx, cx, 1.0e-6
      assert_in_delta fy, cy, 1.0e-6
    end
  end

  describe "set_dash/3" do
    test "phase defaults to zero" do
      assert doc() |> PrawnEx.set_dash([3, 3]) |> stream() == "[3 3] 0 d"
    end

    test "takes an explicit phase" do
      assert doc() |> PrawnEx.set_dash([4, 2], 1) |> stream() == "[4 2] 1 d"
    end

    test "an empty array resets to solid" do
      assert doc() |> PrawnEx.set_dash([]) |> stream() == "[] 0 d"
    end
  end

  describe "set_line_cap/2 and set_line_join/2" do
    test "emit J and j" do
      stream = doc() |> PrawnEx.set_line_cap(1) |> PrawnEx.set_line_join(1) |> stream()

      assert stream == "1 J\n1 j"
    end

    test "reject styles outside 0..2" do
      assert_raise FunctionClauseError, fn -> PrawnEx.set_line_cap(doc(), 3) end
      assert_raise FunctionClauseError, fn -> PrawnEx.set_line_join(doc(), -1) end
    end
  end

  test "the new ops survive a full document write" do
    binary =
      doc()
      |> PrawnEx.save_state()
      |> PrawnEx.set_dash([3, 3])
      |> PrawnEx.set_line_cap(1)
      |> PrawnEx.set_line_join(1)
      |> PrawnEx.rotate(90, about: {100, 100})
      |> PrawnEx.line({0, 0}, {50, 0})
      |> PrawnEx.restore_state()
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "[3 3] 0 d"
    assert binary =~ "1 J"
    assert binary =~ "1 j"
    assert binary =~ "0.0000 1.0000 -1.0000 0.0000 200.0000 0.0000 cm"
  end
end
