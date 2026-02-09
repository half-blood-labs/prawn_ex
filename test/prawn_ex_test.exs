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

  test "table/3 with :align option (per-column center/right)" do
    rows = [["Item", "Qty", "Price"], ["Widget", "2", "$10"], ["Gadget", "1", "$25"]]

    binary =
      PrawnEx.Document.new()
      |> PrawnEx.add_page()
      |> PrawnEx.table(rows,
        at: {50, 650},
        column_widths: [200, 80, 80],
        align: [:left, :center, :right]
      )
      |> PrawnEx.to_binary()

    assert binary =~ "%PDF-1.4"
    assert binary =~ "Widget"
    assert binary =~ "$10"
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
