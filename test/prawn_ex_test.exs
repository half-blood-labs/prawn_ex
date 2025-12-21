defmodule PrawnExTest do
  use ExUnit.Case

  test "generates valid PDF binary" do
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
end
