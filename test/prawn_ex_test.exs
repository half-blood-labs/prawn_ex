defmodule PrawnExTest do
  use ExUnit.Case
  doctest PrawnEx

  test "greets the world" do
    assert PrawnEx.hello() == :world
  end
end
