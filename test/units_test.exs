defmodule PrawnEx.UnitsTest do
  use ExUnit.Case, async: true

  describe "pt/1" do
    test "returns value unchanged" do
      assert PrawnEx.Units.pt(72) == 72
    end
  end

  describe "inch/1" do
    test "1 inch = 72 pt" do
      assert PrawnEx.Units.inch(1) == 72
    end
  end

  describe "mm/1" do
    test "25.4 mm = 72 pt" do
      assert PrawnEx.Units.mm(25.4) == 72.0
    end
  end

  describe "cm/1" do
    test "2.54 cm = 72 pt" do
      assert PrawnEx.Units.cm(2.54) == 72.0
    end
  end

  describe "page_size/1" do
    test "a4 returns 595 x 842" do
      assert PrawnEx.Units.page_size(:a4) == {595, 842}
    end

    test "letter returns 612 x 792" do
      assert PrawnEx.Units.page_size(:letter) == {612, 792}
    end

    test "a4 landscape swaps dimensions" do
      assert PrawnEx.Units.page_size({:a4, :landscape}) == {842, 595}
    end
  end
end
