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
             PrawnEx.build(path, [
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
             ], fn doc ->
               doc
               |> PrawnEx.add_page()
               |> PrawnEx.text_at({50, 400}, "Page 1 body")
               |> PrawnEx.add_page()
               |> PrawnEx.text_at({50, 400}, "Page 2 body")
             end)

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
end
