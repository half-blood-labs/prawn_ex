defmodule PrawnEx.FontEmbeddingTest do
  use ExUnit.Case, async: true

  alias PrawnEx.Font.TrueType

  # A tiny hand-assembled sfnt: 4 glyphs, cmap maps A->1 and B->2,
  # 1000 units per em so design units pass through unscaled.
  defp synthetic_ttf do
    head =
      <<0x00010000::32, 0::32, 0::32, 0x5F0F3CF5::32, 0::16, 1000::16, 0::64, 0::64,
        -100::signed-16, -200::signed-16, 900::signed-16, 800::signed-16, 0::16, 0::16, 0::16,
        0::16, 0::16>>

    hhea = <<0x00010000::32, 750::signed-16, -250::signed-16, 0::16, 0::unit(8)-size(24), 3::16>>
    maxp = <<0x00010000::32, 4::16>>
    hmtx = <<500::16, 0::16, 600::16, 10::16, 700::16, 20::16>>

    cmap_subtable =
      <<4::16, 32::16, 0::16, 4::16, 4::16, 1::16, 0::16, 66::16, 0xFFFF::16, 0::16, 65::16,
        0xFFFF::16, 0xFFC0::16, 1::16, 0::16, 0::16>>

    cmap = <<0::16, 1::16, 3::16, 1::16, 12::32>> <> cmap_subtable

    os2 =
      <<2::16, 0::16, 700::16>> <>
        :binary.copy(<<0>>, 62) <>
        <<760::signed-16, -240::signed-16>> <> :binary.copy(<<0>>, 16) <> <<710::signed-16>>

    post = <<0x00030000::32, 0::signed-32, 0::64>>

    tables = [
      {"head", head},
      {"hhea", hhea},
      {"maxp", maxp},
      {"hmtx", hmtx},
      {"cmap", cmap},
      {"OS/2", os2},
      {"post", post}
    ]

    header = <<0x00010000::32, length(tables)::16, 0::16, 0::16, 0::16>>
    directory_size = 12 + length(tables) * 16

    {records, _} =
      Enum.map_reduce(tables, directory_size, fn {tag, data}, offset ->
        {<<tag::binary, 0::32, offset::32, byte_size(data)::32>>, offset + byte_size(data)}
      end)

    header <> IO.iodata_to_binary(records) <> IO.iodata_to_binary(Enum.map(tables, &elem(&1, 1)))
  end

  describe "TrueType.parse/1" do
    test "extracts PDF-ready metrics from the sfnt tables" do
      assert {:ok, metrics} = TrueType.parse(synthetic_ttf())

      assert metrics.ascent == 760
      assert metrics.descent == -240
      assert metrics.cap_height == 710
      assert metrics.italic_angle == 0
      assert metrics.bbox == {-100, -200, 900, 800}
      # weight class 700 -> bold-ish stem
      assert metrics.stem_v == 120

      # 'A' maps to glyph 1 (advance 600), 'B' to glyph 2 (700),
      # anything unmapped falls back to glyph 0 (500).
      assert Enum.at(metrics.widths, ?A - 32) == 600
      assert Enum.at(metrics.widths, ?B - 32) == 700
      assert Enum.at(metrics.widths, ?C - 32) == 500
      assert length(metrics.widths) == 224
    end

    test "rejects CFF-flavoured OpenType" do
      assert {:error, :cff_not_supported} = TrueType.parse("OTTO" <> <<0::64>>)
    end

    test "rejects binaries that are not fonts" do
      assert {:error, :not_a_truetype_font} = TrueType.parse("not a font at all")
    end
  end

  describe "embedding in a document" do
    test "an embedded font gets a FontFile2, descriptor, and TrueType dict" do
      pdf =
        PrawnEx.Document.new()
        |> PrawnEx.add_page()
        |> PrawnEx.register_font("TestSans", synthetic_ttf())
        |> PrawnEx.set_font("TestSans", 12)
        |> PrawnEx.text_at({50, 700}, "AB")
        |> PrawnEx.to_binary()

      assert pdf =~ "/Subtype /TrueType"
      assert pdf =~ "/BaseFont /TestSans"
      assert pdf =~ "/FontFile2"
      assert pdf =~ "/Filter /FlateDecode"
      assert pdf =~ "/Encoding /WinAnsiEncoding"
      assert pdf =~ "/FontDescriptor"
      # widths land in the font dict: A=600 then B=700 next to each other
      assert pdf =~ "600 700"
    end

    test "base-14 fonts on the same page keep working alongside" do
      pdf =
        PrawnEx.Document.new()
        |> PrawnEx.add_page()
        |> PrawnEx.register_font("TestSans", synthetic_ttf())
        |> PrawnEx.set_font("TestSans", 12)
        |> PrawnEx.text_at({50, 700}, "embedded")
        |> PrawnEx.set_font("Helvetica", 9)
        |> PrawnEx.text_at({50, 680}, "built in")
        |> PrawnEx.to_binary()

      assert pdf =~ "/BaseFont /TestSans"
      assert pdf =~ "/BaseFont /Helvetica"
    end

    test "register_font raises on garbage" do
      assert_raise ArgumentError, ~r/could not parse/, fn ->
        PrawnEx.register_font(PrawnEx.Document.new(), "Bad", "definitely not a font")
      end
    end
  end

  describe "opacity and rounded rectangles" do
    test "set_opacity emits an ExtGState and a gs operator" do
      pdf =
        PrawnEx.Document.new()
        |> PrawnEx.add_page()
        |> PrawnEx.set_opacity(0.3)
        |> PrawnEx.rectangle(10, 10, 100, 50)
        |> PrawnEx.fill()
        |> PrawnEx.set_opacity(1.0)
        |> PrawnEx.to_binary()

      assert pdf =~ "/Type /ExtGState /ca 0.3"
      assert pdf =~ "/ExtGState << /GS1"
      assert pdf =~ "/GS1 gs"
    end

    test "rounded_rectangle builds a Bézier path and fill_stroke paints it" do
      pdf =
        PrawnEx.Document.new()
        |> PrawnEx.add_page()
        |> PrawnEx.rounded_rectangle(50, 50, 200, 100, 12)
        |> PrawnEx.fill_stroke()
        |> PrawnEx.to_binary()

      assert pdf =~ " c\n"
      assert pdf =~ "h\nB"
    end
  end
end
