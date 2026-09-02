defmodule PrawnEx.PDF.ContentStreamTest do
  use ExUnit.Case, async: true

  test "builds stream for set_font and text_at" do
    ops = [
      {:set_font, "Helvetica", 12},
      {:text_at, {100, 500}, "Hello"}
    ]

    stream = PrawnEx.PDF.ContentStream.build(ops)
    assert stream =~ "/F1 12 Tf"
    assert stream =~ "BT"
    assert stream =~ "100 500 Tm"
    assert stream =~ "(Hello)"
    assert stream =~ "ET"
  end

  test "builds stream for rectangle and stroke" do
    ops = [
      {:rectangle, 50, 50, 200, 100},
      :stroke
    ]

    stream = PrawnEx.PDF.ContentStream.build(ops)
    assert stream =~ "50 50 200 100 re"
    assert stream =~ "S"
  end

  test "builds stream for line" do
    ops = [{:line, {0, 0}, {100, 100}}]
    stream = PrawnEx.PDF.ContentStream.build(ops)
    assert stream =~ "0 0 m"
    assert stream =~ "100 100 l S"
  end

  describe "graphics state ops" do
    test "save and restore state" do
      ops = [:save_state, {:rectangle, 0, 0, 10, 10}, :fill, :restore_state]

      assert PrawnEx.PDF.ContentStream.build(ops) == "q\n0 0 10 10 re\nf\nQ"
    end

    test "concat_matrix" do
      ops = [{:concat_matrix, 1, 0, 0, 1, 20, 30}]

      assert PrawnEx.PDF.ContentStream.build(ops) == "1 0 0 1 20 30 cm"
    end

    test "concat_matrix formats floats to four decimals" do
      ops = [{:concat_matrix, 0.5, 0.0, 0.0, 0.5, 1.25, -2.5}]

      assert PrawnEx.PDF.ContentStream.build(ops) ==
               "0.5000 0.0000 0.0000 0.5000 1.2500 -2.5000 cm"
    end

    test "set_dash" do
      ops = [{:set_dash, [3, 3], 0}]

      assert PrawnEx.PDF.ContentStream.build(ops) == "[3 3] 0 d"
    end

    test "set_dash with a phase and an odd-length pattern" do
      ops = [{:set_dash, [2, 1, 4], 1}]

      assert PrawnEx.PDF.ContentStream.build(ops) == "[2 1 4] 1 d"
    end

    test "empty set_dash array resets to a solid line" do
      ops = [{:set_dash, [], 0}]

      assert PrawnEx.PDF.ContentStream.build(ops) == "[] 0 d"
    end

    test "set_line_cap" do
      for style <- 0..2 do
        assert PrawnEx.PDF.ContentStream.build([{:set_line_cap, style}]) == "#{style} J"
      end
    end

    test "set_line_join" do
      for style <- 0..2 do
        assert PrawnEx.PDF.ContentStream.build([{:set_line_join, style}]) == "#{style} j"
      end
    end

    test "ops emit in order" do
      ops = [
        :save_state,
        {:set_line_cap, 1},
        {:set_line_join, 2},
        {:set_dash, [3, 3], 0},
        {:concat_matrix, 1, 0, 0, 1, 5, 5},
        :restore_state
      ]

      assert PrawnEx.PDF.ContentStream.build(ops) ==
               "q\n1 J\n2 j\n[3 3] 0 d\n1 0 0 1 5 5 cm\nQ"
    end
  end
end
