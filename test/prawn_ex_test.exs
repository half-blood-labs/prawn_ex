defmodule PrawnExTest do
  use ExUnit.Case

  test "generates valid PDF binary via Writer" do
    doc =
      PrawnEx.Document.new()
      |> PrawnEx.Document.add_page()
      |> PrawnEx.Document.append_op({:set_font, "Helvetica", 12})
      |> PrawnEx.Document.append_op({:text_at, {100, 700}, "Hello, PDF!"})
      |> PrawnEx.Document.append_op({:rectangle, 100, 600, 200, 50})
      |> PrawnEx.Document.append_op(:stroke)

    binary = PrawnEx.PDF.Writer.write(doc)
    assert binary =~ "%PDF-1.4"
    assert binary =~ "%%EOF"
  end

  test "main API: build and to_binary" do
    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.set_font("Helvetica", 12)
      |> PrawnEx.text_at({100, 700}, "From API")
      |> PrawnEx.rectangle(50, 50, 100, 100)
      |> PrawnEx.stroke()
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "From API"
  end

  test "build/2 writes file" do
    path =
      Path.join(System.tmp_dir!(), "prawn_ex_test_#{:erlang.unique_integer([:positive])}.pdf")

    assert :ok =
             PrawnEx.build(path, fn doc ->
               doc
               |> PrawnEx.set_font("Helvetica", 10)
               |> PrawnEx.text_at({72, 72}, "Saved to file")
             end)

    assert File.exists?(path)
    assert path |> File.read!() |> String.starts_with?("%PDF-1.4")
    File.rm!(path)
  end

  test "build/3 with header and footer injects ops on each page" do
    path =
      Path.join(System.tmp_dir!(), "prawn_ex_test_#{:erlang.unique_integer([:positive])}.pdf")

    assert :ok =
             PrawnEx.build(
               path,
               [
                 header: fn doc, n ->
                   doc
                   |> PrawnEx.set_font("Helvetica", 9)
                   |> PrawnEx.text_at({50, 820}, "Header Page #{n}")
                 end,
                 footer: fn doc, n ->
                   doc
                   |> PrawnEx.set_font("Helvetica", 9)
                   |> PrawnEx.text_at({50, 30}, "Page #{n}")
                 end
               ],
               fn doc ->
                 doc
                 |> PrawnEx.add_page()
                 |> PrawnEx.text_at({50, 400}, "Page 1 body")
                 |> PrawnEx.add_page()
                 |> PrawnEx.text_at({50, 400}, "Page 2 body")
               end
             )

    bin = File.read!(path)
    assert bin =~ "Header Page 1"
    assert bin =~ "Header Page 2"
    assert bin =~ "Page 1"
    assert bin =~ "Page 2"
    File.rm!(path)
  end

  test "table/3 draws table with header row" do
    rows = [["A", "B"], ["1", "2"], ["3", "4"]]

    binary =
      PrawnEx.Document.new(page_size: :a4)
      |> PrawnEx.add_page()
      |> PrawnEx.table(rows, at: {100, 700}, column_widths: [80, 80], header: true)
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "A"
    assert binary =~ "B"
    assert binary =~ "1"
    assert binary =~ "2"
  end

  test "bar_chart/3 draws bars and labels" do
    data = [{"Jan", 40}, {"Feb", 55}, {"Mar", 70}]

    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.bar_chart(data, at: {80, 500}, width: 300, height: 150)
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "Jan"
    assert binary =~ "Feb"
    assert binary =~ "Mar"
  end

  test "line_chart/3 draws polyline" do
    data = [10, 25, 15, 40, 35]

    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.line_chart(data, at: {80, 500}, width: 300, height: 150)
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    # Content stream should have m (move) and l (line to) for the path
    assert binary =~ " m\n"
    assert binary =~ " l\n"
  end

  test "image/3 with nonexistent path returns error" do
    assert {:error, _} = PrawnEx.image(PrawnEx.Document.new(), "/nonexistent.jpg", at: {0, 0})
  end

  test "image XObject is emitted when doc has image" do
    spec = %{data: <<0xFF, 0xD8, 0xFF>>, width: 2, height: 2, filter: :dct}

    doc =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> then(fn d ->
        {d, id} = PrawnEx.Document.add_image(d, spec)
        PrawnEx.Document.append_op(d, {:image, id, 50, 50, 20, 20})
      end)

    binary = PrawnEx.to_binary(doc)
    assert binary =~ "%PDF-1.4"
    assert binary =~ "/Subtype /Image"
    assert binary =~ "/DCTDecode"
  end

  test "PNG image loads and emits FlateDecode XObject" do
    # Minimal 1x1 RGB PNG (filter 0, one row)
    sig = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
    ihdr = <<1::32-big, 1::32-big, 8, 2, 0, 0, 0>>
    crc_ihdr = :erlang.crc32(<<"IHDR", ihdr::binary>>)
    ihdr_chunk = <<13::32-big, "IHDR", ihdr::binary, crc_ihdr::32-big>>
    raw_row = <<0, 255, 0, 0>>
    idat_data = :zlib.compress(raw_row)
    crc_idat = :erlang.crc32(<<"IDAT", idat_data::binary>>)
    idat_chunk = <<byte_size(idat_data)::32-big, "IDAT", idat_data::binary, crc_idat::32-big>>
    iend_chunk = <<0::32-big, "IEND", :erlang.crc32("IEND")::32-big>>
    png = sig <> ihdr_chunk <> idat_chunk <> iend_chunk

    assert {:ok, spec} = PrawnEx.Image.PNG.load(png)
    assert spec.width == 1
    assert spec.height == 1
    assert spec.filter == :flate

    result =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.image(png, at: {10, 10})

    refute match?({:error, _}, result)
    binary = PrawnEx.to_binary(result)
    assert binary =~ "/FlateDecode"
    assert binary =~ "/Subtype /Image"
  end

  test "link/5 adds external link annotation" do
    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.link(100, 100, 200, 30, "https://hex.pm/packages/prawn_ex")
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "/Subtype /Link"
    assert binary =~ "/URI"
    assert binary =~ "hex.pm"
  end

  test "multiple built-in fonts (Helvetica, Times-Bold, Courier) are emitted in resources" do
    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.text_at({50, 600}, "Normal")
      |> PrawnEx.set_font("Times-Bold", 14)
      |> PrawnEx.text_at({100, 500}, "Bold")
      |> PrawnEx.set_font("Courier", 9)
      |> PrawnEx.text_at({100, 400}, "Mono")
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "/Helvetica"
    assert binary =~ "/Times-Bold"
    assert binary =~ "/Courier"
    assert binary =~ "/F1 10 Tf"
    assert binary =~ "/F2 14 Tf"
    assert binary =~ "/F3 9 Tf"
  end

  test "set_non_stroking_rgb and set_stroking_rgb emit rg and RG" do
    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.set_non_stroking_rgb(0.2, 0.4, 0.8)
      |> PrawnEx.set_stroking_rgb(0.1, 0.5, 0.9)
      |> PrawnEx.rectangle(50, 50, 100, 100)
      |> PrawnEx.fill()
      |> PrawnEx.stroke()
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ " rg\n"
    assert binary =~ " RG\n"
  end
end
