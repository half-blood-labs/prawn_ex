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
end
