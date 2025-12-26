# PrawnEx

Prawn-style declarative PDF generation for Elixir. Pure Elixir, no Chrome or HTML: build a document spec and emit PDF 1.4.

## Usage

```elixir
PrawnEx.build("output.pdf", fn doc ->
  doc
  |> PrawnEx.set_font("Helvetica", 12)
  |> PrawnEx.text_at({100, 700}, "Hello, PDF!")
  |> PrawnEx.rectangle(100, 600, 200, 50)
  |> PrawnEx.stroke()
end)
```

Or build a document and get binary:

```elixir
binary =
  PrawnEx.Document.new()
  |> PrawnEx.add_page()
  |> PrawnEx.set_font("Helvetica", 12)
  |> PrawnEx.text_at({72, 72}, "Hello")
  |> PrawnEx.to_binary()
```

Coordinates use PDF points (72 pt = 1 inch); origin is bottom-left.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `prawn_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:prawn_ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/prawn_ex>.

