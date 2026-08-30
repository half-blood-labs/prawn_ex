defmodule PrawnEx.TextTest do
  use ExUnit.Case, async: true

  describe "estimated_width/2" do
    test "returns zero for empty string" do
      assert PrawnEx.Text.estimated_width("", 12) == 0
    end

    test "sums the Helvetica advance widths" do
      # H is 0.7222 em, i is 0.2222 em
      assert_in_delta PrawnEx.Text.estimated_width("Hi", 12), (0.7222 + 0.2222) * 12, 1.0e-9
    end

    test "scales linearly with font size" do
      at_12 = PrawnEx.Text.estimated_width("Hi", 12)

      assert_in_delta PrawnEx.Text.estimated_width("Hi", 24), at_12 * 2, 1.0e-9
    end

    test "narrow and wide glyphs measure differently" do
      # The flat half-em guess this replaced called these the same width.
      assert PrawnEx.Text.estimated_width("lllll", 12) <
               PrawnEx.Text.estimated_width("WWWWW", 12) / 3
    end

    test "counts the space between words" do
      assert_in_delta PrawnEx.Text.estimated_width("a b", 10),
                      PrawnEx.Text.estimated_width("ab", 10) +
                        PrawnEx.Text.estimated_width(" ", 10),
                      1.0e-9
    end

    test "unknown codepoints fall back to 0.55 em" do
      # U+4E2D is outside the WinAnsi table Helvetica can show.
      assert_in_delta PrawnEx.Text.estimated_width("中", 20), 0.55 * 20, 1.0e-9
    end

    test "measures accented Latin-1 characters" do
      assert PrawnEx.Text.estimated_width("ü", 12) == PrawnEx.Text.estimated_width("u", 12)
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

    test "wrapping follows real glyph widths, not character count" do
      # Same character count, very different widths.
      assert PrawnEx.Text.wrap_to_lines("iiiiiiiiii", 60, 12) == ["iiiiiiiiii"]
      assert length(PrawnEx.Text.wrap_to_lines("WWWWWWWWWW", 60, 12)) > 1
    end

    test "single word longer than width breaks by character" do
      # "AAAAAAAAAA" (10 chars) at 12pt = 60pt; width 20 forces break
      lines = PrawnEx.Text.wrap_to_lines("AAAAAAAAAA", 20, 12)
      assert length(lines) >= 2
      assert Enum.join(lines) == "AAAAAAAAAA"
    end
  end
end
