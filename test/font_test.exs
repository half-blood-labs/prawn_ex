defmodule PrawnEx.FontTest do
  use ExUnit.Case, async: true

  alias PrawnEx.Font

  describe "text_width/3" do
    test "empty string returns 0" do
      assert Font.text_width("Helvetica", "", 12) == 0.0
    end

    test "single space — Helvetica at 12pt" do
      # AFM space = 278 units; 278 * 12 / 1000 = 3.336
      assert_in_delta Font.text_width("Helvetica", " ", 12), 3.336, 0.001
    end

    test "uppercase A — Helvetica at 10pt" do
      # AFM A = 667 units; 667 * 10 / 1000 = 6.67
      assert_in_delta Font.text_width("Helvetica", "A", 10), 6.67, 0.001
    end

    test "digit width — Helvetica digits are 556 units" do
      # "0" at 12pt: 556 * 12 / 1000 = 6.672
      assert_in_delta Font.text_width("Helvetica", "0", 12), 6.672, 0.001
    end

    test "multi-char string is sum of per-char widths" do
      # "Hi" — H=778, i=222; total=1000; at 12pt = 12.0
      assert_in_delta Font.text_width("Helvetica", "Hi", 12), 12.0, 0.001
    end

    test "Courier returns fixed width for every character" do
      # All Courier glyphs = 600 units
      w1 = Font.text_width("Courier", "i", 12)
      w2 = Font.text_width("Courier", "W", 12)
      assert_in_delta w1, w2, 0.001
      # 600 * 12 / 1000 = 7.2
      assert_in_delta w1, 7.2, 0.001
    end

    test "Helvetica-Bold differs from Helvetica for same text" do
      w_reg = Font.text_width("Helvetica", "Bold", 12)
      w_bold = Font.text_width("Helvetica-Bold", "Bold", 12)
      # Bold metrics are wider; they should differ
      assert w_reg != w_bold
    end

    test "Times-Roman space is 250 units" do
      # 250 * 10 / 1000 = 2.5
      assert_in_delta Font.text_width("Times-Roman", " ", 10), 2.5, 0.001
    end

    test "Times-Bold differs from Times-Roman" do
      w_roman = Font.text_width("Times-Roman", "Hello", 12)
      w_bold = Font.text_width("Times-Bold", "Hello", 12)
      assert w_roman != w_bold
    end

    test "unknown font falls back to Helvetica metrics" do
      w_unknown = Font.text_width("NonExistentFont", "Test", 12)
      w_helv = Font.text_width("Helvetica", "Test", 12)
      assert_in_delta w_unknown, w_helv, 0.001
    end

    test "width scales linearly with font size" do
      w12 = Font.text_width("Helvetica", "Hello", 12)
      w24 = Font.text_width("Helvetica", "Hello", 24)
      assert_in_delta w24, w12 * 2, 0.001
    end

    test "unknown character falls back to default width (500 for Helvetica)" do
      # Unicode char outside AFM table; default 500 units at 10pt = 5.0
      assert_in_delta Font.text_width("Helvetica", "é", 10), 5.0, 0.001
    end
  end
end
