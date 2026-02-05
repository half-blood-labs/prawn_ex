# PrawnEx

[![CI](https://github.com/prawn-ex/prawn_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/prawn-ex/prawn_ex/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/prawn_ex.svg)](https://hex.pm/packages/prawn_ex)
[![Hex.pm](https://img.shields.io/hexpm/dt/prawn_ex.svg)](https://hex.pm/packages/prawn_ex)
[![Hex.pm](https://img.shields.io/hexpm/l/prawn_ex.svg)](https://hex.pm/packages/prawn_ex)

**Version** 0.1.0 · **Elixir** ~> 1.16

Prawn-style declarative PDF generation for Elixir. Pure Elixir, no Chrome or HTML: build a document spec and emit PDF 1.4.

## Features

- **Document & pages** — Multi-page PDFs, configurable page size (A4, Letter, etc.).
- **Text** — Set font and size (Helvetica, Times-Roman, Times-Bold, Courier, etc.), draw text at position or append to cursor.
- **Graphics** — Lines, rectangles, move-to/line-to paths; stroke and fill.
- **Colors** — Gray (stroking and non-stroking) and RGB (e.g. for fill and stroke).
- **Tables** — Grid with optional header row, configurable column widths, row height, padding, borders; **cell alignment** per column (`:left`, `:center`, `:right`).
- **Charts** — Bar charts and line charts from data (no external deps).
- **Images** — Embed **JPEG** and **PNG** (file path or binary); optional width/height; asset directory via config.
- **Links** — External link annotations (clickable URLs).
- **Headers & footers** — Per-page callbacks with page number for titles and “Page N”.

## Getting started

Add the dependency and build your first PDF:

```elixir
# mix.exs
def deps do
  [{:prawn_ex, "~> 0.1.0"}]
end
```

```elixir
PrawnEx.build("output.pdf", fn doc ->
  doc
  |> PrawnEx.add_page()
  |> PrawnEx.set_font("Helvetica", 12)
  |> PrawnEx.text_at({72, 700}, "Hello, PDF!")
end)
```

See [Demo](#demo) for a full tour, or try the [invoice](#examples) or [report with chart](#examples) examples.

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

Options: `:at`, `:column_widths` (list or `:auto`), `:row_height`, `:cell_padding`, `:header`, `:border`, `:align` (`:left` / `:center` / `:right` or list per column), `:font_size`, `:header_font_size`.

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

### Images

Embed **JPEG** or **PNG** images (file path or binary). Optionally set `:width` and `:height` in pt; default is intrinsic size.

**Image / asset path:** Set `config :prawn_ex, image_dir: "priv/images"` (or any directory) in your application config. Relative paths passed to `PrawnEx.image/3` are then resolved from that directory. Absolute paths and raw JPEG binaries are used as-is.

```elixir
# In your config/config.exs:
config :prawn_ex, image_dir: "priv/images"

# In your code — "photo.jpg" is loaded from priv/images/photo.jpg:
doc
|> PrawnEx.image("photo.jpg", at: {50, 400})
|> PrawnEx.image("logo.jpg", at: {400, 700}, width: 80, height: 40)
```

### Colors

Gray: `PrawnEx.set_stroking_gray(doc, 0.8)`, `PrawnEx.set_non_stroking_gray(doc, 0.2)` (0 = black, 1 = white).  
RGB: `PrawnEx.set_non_stroking_rgb(doc, r, g, b)`, `PrawnEx.set_stroking_rgb(doc, r, g, b)` (0–1).

## Demo

Generate the demo PDF:

```bash
mix run scripts/gen_demo.exs
```

Output: `output/prawn_ex_demo.pdf` (4 pages: hero, table, charts, images). The image on page 4 uses `demo.jpg` resolved from the configured `image_dir` (default `"assets"`). Add `assets/demo.jpg` to show your own image, or set `config :prawn_ex, image_dir: "path/to/your/jpegs"` in `config/config.exs`.

### Examples

- **Invoice** — `mix run scripts/invoice.exs` → `output/invoice.pdf` (header, line-item table with alignment, totals, footer).
- **Report with chart** — `mix run scripts/report_with_chart.exs` → `output/report_with_chart.pdf` (table + bar chart).

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

