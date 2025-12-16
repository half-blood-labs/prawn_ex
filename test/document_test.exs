defmodule PrawnEx.DocumentTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "empty opts gives empty pages" do
      doc = PrawnEx.Document.new()
      assert doc.pages == []
      assert doc.opts == []
    end

    test "accepts page_size option" do
      doc = PrawnEx.Document.new(page_size: :letter)
      assert doc.opts[:page_size] == :letter
    end
  end

  describe "add_page/1" do
    test "adds one page" do
      doc = PrawnEx.Document.new() |> PrawnEx.Document.add_page()
      assert length(doc.pages) == 1
      assert hd(doc.pages).content_ops == []
    end

    test "add_page twice adds two pages" do
      doc =
        PrawnEx.Document.new()
        |> PrawnEx.Document.add_page()
        |> PrawnEx.Document.add_page()

      assert length(doc.pages) == 2
    end
  end

  describe "append_op/2" do
    test "adds a page if none and appends op" do
      doc = PrawnEx.Document.new() |> PrawnEx.Document.append_op({:text, "Hi"})
      assert length(doc.pages) == 1
      assert hd(doc.pages).content_ops == [{:text, "Hi"}]
    end

    test "appends to current page" do
      doc =
        PrawnEx.Document.new()
        |> PrawnEx.Document.add_page()
        |> PrawnEx.Document.append_op({:set_font, "Helvetica", 12})
        |> PrawnEx.Document.append_op({:text, "Hello"})

      assert length(doc.pages) == 1
      assert hd(doc.pages).content_ops == [
               {:set_font, "Helvetica", 12},
               {:text, "Hello"}
             ]
    end
  end
end
