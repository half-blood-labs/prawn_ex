defmodule PrawnEx.PageTest do
  use ExUnit.Case, async: true

  alias PrawnEx.Page

  describe "add_op/2 and content_ops/1" do
    test "new page has no ops" do
      assert Page.content_ops(Page.new()) == []
    end

    test "ops come back in the order they were added" do
      page =
        Page.new()
        |> Page.add_op({:set_font, "Helvetica", 12})
        |> Page.add_op({:text, "one"})
        |> Page.add_op({:text, "two"})

      assert Page.content_ops(page) == [
               {:set_font, "Helvetica", 12},
               {:text, "one"},
               {:text, "two"}
             ]
    end

    test "order survives many appends" do
      ops = for i <- 1..2_000, do: {:text, Integer.to_string(i)}
      page = Enum.reduce(ops, Page.new(), &Page.add_op(&2, &1))

      assert Page.content_ops(page) == ops
    end
  end

  describe "put_content_ops/2" do
    test "replaces the ops, keeping draw order" do
      page =
        Page.new()
        |> Page.add_op({:text, "old"})
        |> Page.put_content_ops([{:text, "a"}, {:text, "b"}])

      assert Page.content_ops(page) == [{:text, "a"}, {:text, "b"}]
    end

    test "round-trips through content_ops/1" do
      page = Page.new() |> Page.add_op(:stroke) |> Page.add_op(:fill)
      ops = Page.content_ops(page)

      assert page |> Page.put_content_ops(ops) |> Page.content_ops() == ops
    end
  end
end
