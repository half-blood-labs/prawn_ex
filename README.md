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

### Tables

Draw tables with an optional header row (Phase 2):

```elixir
rows = [["Product", "Qty", "Price"], ["Widget", "2", "$10"], ["Gadget", "1", "$25"]]
doc
|> PrawnEx.table(rows, at: {50, 650}, column_widths: [200, 80, 80], header: true)
```

Options: `:at`, `:column_widths` (list or `:auto`), `:row_height`, `:cell_padding`, `:header`, `:border`, `:font_size`, `:header_font_size`.

### Headers and footers

Use `build(path, opts, fun)` with `:header` and/or `:footer` callbacks (receiving `doc` and page number). Ideal for "Page N" and repeating titles:

```elixir
PrawnEx.build("out.pdf", [
  footer: fn doc, page_num ->
    doc
    |> PrawnEx.set_font("Helvetica", 9)
    |> PrawnEx.text_at({50, 30}, "Page \#{page_num}")
  end
], fn doc ->
  # your content; footer is injected on every page
  doc |> PrawnEx.add_page() |> ...
end)
```

### Charts

Bar and line charts (Phase 3), built from drawing primitives:

```elixir
# Bar chart: list of {label, value}
PrawnEx.bar_chart(doc, [{"Jan", 40}, {"Feb", 55}, {"Mar", 70}],
  at: {50, 500}, width: 400, height: 200, bar_color: 0.4)

# Line chart: list of y-values (x = index) or [{x, y}, ...]
PrawnEx.line_chart(doc, [10, 25, 15, 40, 35], at: {50, 400}, width: 400, height: 150)
```

Options: `:at`, `:width`, `:height`, `:bar_color` / `:stroke_color`, `:axis`, `:labels`, `:padding`.

### Colors

Use gray for strokes and fill/text: `PrawnEx.set_stroking_gray(doc, 0.8)`, `PrawnEx.set_non_stroking_gray(doc, 0.2)` (0 = black, 1 = white).

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

