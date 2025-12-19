defmodule PrawnEx.PDF.EncoderTest do
  use ExUnit.Case, async: true

  describe "escape_string/1" do
    test "escapes backslash and parens" do
      assert PrawnEx.PDF.Encoder.escape_string("a(b)c") == "a\\(b\\)c"
      assert PrawnEx.PDF.Encoder.escape_string("\\") == "\\\\"
    end
  end

  describe "literal_string/1" do
    test "wraps in parentheses" do
      assert PrawnEx.PDF.Encoder.literal_string("Hi") == "(Hi)"
      assert PrawnEx.PDF.Encoder.literal_string("(x)") == "(\\(x\\))"
    end
  end

  describe "name/1" do
    test "adds leading slash" do
      assert String.starts_with?(PrawnEx.PDF.Encoder.name("Helvetica"), "/")
    end
  end

  describe "number/1" do
    test "formats integer" do
      assert PrawnEx.PDF.Encoder.number(72) == "72"
    end

    test "formats float" do
      assert PrawnEx.PDF.Encoder.number(72.5) == "72.5000"
    end
  end
end
