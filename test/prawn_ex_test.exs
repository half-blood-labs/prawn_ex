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
    path = Path.join(System.tmp_dir!(), "prawn_ex_test_#{:erlang.unique_integer([:positive])}.pdf")
    assert :ok = PrawnEx.build(path, fn doc ->
      doc
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.text_at({72, 72}, "Saved to file")
    end)
    assert File.exists?(path)
    assert path |> File.read!() |> String.starts_with?("%PDF-1.4")
    File.rm!(path)
  end
end
