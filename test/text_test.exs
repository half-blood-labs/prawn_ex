defmodule PrawnEx.TextTest do
  use ExUnit.Case, async: true

  describe "estimated_width/2" do
    test "returns zero for empty string" do
      assert PrawnEx.Text.estimated_width("", 12) == 0
    end

    test "scales with font size and length" do
      # ~0.5 pt per char per unit font size
      assert PrawnEx.Text.estimated_width("Hi", 12) == 12.0
      assert PrawnEx.Text.estimated_width("Hi", 24) == 24.0
    end
  end

  describe "wrap_to_lines/3" do
    test "empty string returns empty list" do
      assert PrawnEx.Text.wrap_to_lines("", 100, 12) == []
    end

    test "short string fits on one line" do
      assert PrawnEx.Text.wrap_to_lines("Hello", 100, 12) == ["Hello"]
    end

    test "splits long text into multiple lines by words" do
      # "One two three" with width that fits ~2 words per line
      lines = PrawnEx.Text.wrap_to_lines("One two three four", 25, 12)
      assert length(lines) >= 2
      assert Enum.join(lines, " ") =~ "One"
      assert Enum.join(lines, " ") =~ "four"
    end

    test "preserves newlines as paragraph breaks" do
      lines = PrawnEx.Text.wrap_to_lines("A\nB", 200, 12)
      assert "A" in lines
      assert "B" in lines
    end

    test "single word longer than width breaks by character" do
      # "AAAAAAAAAA" (10 chars) at 12pt = 60pt; width 20 forces break
      lines = PrawnEx.Text.wrap_to_lines("AAAAAAAAAA", 20, 12)
      assert length(lines) >= 2
      assert Enum.join(lines) == "AAAAAAAAAA"
    end
  end
end
