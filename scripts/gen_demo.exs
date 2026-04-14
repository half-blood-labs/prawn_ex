# Run with: mix run scripts/gen_demo.exs
# Writes a beautiful demo PDF (4 pages: hero, table, charts, images) to project's output/ folder.
#
# Images on page 4: "demo.jpg" and "demo.png" resolve via config :prawn_ex, image_dir (default "assets").
# This repo ships assets/demo.png; add assets/demo.jpg for a custom JPEG, or set image_dir in config.

# Minimal 1x1 pixel JPEG fallback when no demo.jpg is found
minimal_jpeg =
  "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
  |> Base.decode64!(padding: false)

output_dir = Path.join(File.cwd!(), "output")
File.mkdir_p!(output_dir)
path = Path.join(output_dir, "prawn_ex_demo.pdf")

# A4: 595 x 842 pt (origin bottom-left)
page_w = 595
page_h = 842
margin = 50
header_h = 72
footer_y = 48

:ok =
  PrawnEx.build(
    path,
    [
      footer: fn doc, page_num ->
        doc
        |> PrawnEx.set_stroking_gray(0.85)
        |> PrawnEx.line({margin, footer_y + 18}, {page_w - margin, footer_y + 18})
        |> PrawnEx.stroke()
        |> PrawnEx.set_stroking_gray(0)
        |> PrawnEx.set_font("Helvetica", 9)
        |> PrawnEx.set_non_stroking_gray(0.4)
        |> PrawnEx.text_at({margin, footer_y - 2}, "PrawnEx demo")
        |> PrawnEx.text_at({page_w - margin - 40, footer_y - 2}, "Page #{page_num}")
        |> PrawnEx.set_non_stroking_gray(0)
      end
    ],
    fn doc ->
      doc
      # —— Page 1: Hero ——
      |> then(fn d ->
        d
        |> PrawnEx.set_non_stroking_gray(0.18)
        |> PrawnEx.rectangle(0, page_h - header_h, page_w, header_h)
        |> PrawnEx.fill()
        |> PrawnEx.set_non_stroking_gray(1)
        |> PrawnEx.set_font("Helvetica", 22)
        |> PrawnEx.text_at({margin, page_h - 48}, "PrawnEx")
        |> PrawnEx.set_font("Helvetica", 11)
        |> PrawnEx.text_at({page_w - margin - 120, page_h - 50}, "Pure Elixir PDF")
        |> PrawnEx.set_non_stroking_gray(0)
        |> PrawnEx.set_font("Helvetica", 28)
        |> PrawnEx.text_at({margin, page_h - 140}, "Beautiful documents.")
        |> PrawnEx.set_font("Helvetica", 14)
        |> PrawnEx.text_at(
          {margin, page_h - 175},
          "Zero dependencies. No Chrome. No HTML. Just Elixir."
        )
        |> PrawnEx.set_stroking_gray(0.85)
        |> PrawnEx.line({margin, page_h - 210}, {page_w - margin, page_h - 210})
        |> PrawnEx.stroke()
        |> PrawnEx.set_stroking_gray(0)
        |> PrawnEx.set_font("Helvetica", 12)
        |> PrawnEx.text_at({margin, page_h - 245}, "Why PrawnEx?")
        |> PrawnEx.set_stroking_gray(0.75)
        |> PrawnEx.rectangle(margin, page_h - 380, (page_w - 2 * margin - 24) / 3, 110)
        |> PrawnEx.stroke()
        |> PrawnEx.rectangle(
          margin + (page_w - 2 * margin - 24) / 3 + 12,
          page_h - 380,
          (page_w - 2 * margin - 24) / 3,
          110
        )
        |> PrawnEx.stroke()
        |> PrawnEx.rectangle(
          margin + 2 * ((page_w - 2 * margin - 24) / 3 + 12),
          page_h - 380,
          (page_w - 2 * margin - 24) / 3,
          110
        )
        |> PrawnEx.stroke()
        |> PrawnEx.set_font("Helvetica", 11)
        |> PrawnEx.text_at({margin + 14, page_h - 318}, "Fast & lightweight")
        |> PrawnEx.set_font("Helvetica", 9)
        |> PrawnEx.text_at({margin + 14, page_h - 338}, "No external renderer.")
        |> PrawnEx.set_font("Helvetica", 11)
        |> PrawnEx.text_at(
          {margin + (page_w - 2 * margin - 24) / 3 + 26, page_h - 318},
          "Declarative API"
        )
        |> PrawnEx.set_font("Helvetica", 9)
        |> PrawnEx.text_at(
          {margin + (page_w - 2 * margin - 24) / 3 + 26, page_h - 338},
          "Pipe-friendly, immutable."
        )
        |> PrawnEx.set_font("Helvetica", 11)
        |> PrawnEx.text_at(
          {margin + 2 * ((page_w - 2 * margin - 24) / 3 + 12) + 14, page_h - 318},
          "PDF 1.4 compliant"
        )
        |> PrawnEx.set_font("Helvetica", 9)
        |> PrawnEx.text_at(
          {margin + 2 * ((page_w - 2 * margin - 24) / 3 + 12) + 14, page_h - 338},
          "Standard, portable."
        )
        |> PrawnEx.set_stroking_gray(0.9)
        |> PrawnEx.rectangle(margin, page_h - 480, page_w - 2 * margin, 52)
        |> PrawnEx.stroke()
        |> PrawnEx.set_non_stroking_gray(0.35)
        |> PrawnEx.set_font("Helvetica", 10)
        |> PrawnEx.text_at(
          {margin + 16, page_h - 455},
          "The library you can drop in to replace HTML-to-PDF or heavy stacks."
        )
        |> PrawnEx.set_non_stroking_gray(0)
      end)
      # —— Page 2: Table demo ——
      |> PrawnEx.add_page()
      |> PrawnEx.set_font("Helvetica", 18)
      |> PrawnEx.text_at({margin, page_h - 60}, "Table API")
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.set_non_stroking_gray(0.5)
      |> PrawnEx.text_at(
        {margin, page_h - 85},
        "Phase 2: table(rows, opts) with optional header row"
      )
      |> PrawnEx.set_non_stroking_gray(0)
      |> PrawnEx.table(
        [
          ["Feature", "Status", "Notes"],
          ["Tables", "Done", "Header row, borders, column_widths"],
          ["Headers / footers", "Done", "Per-page callback, page number"],
          ["Charts", "Done", "Bar & line charts (Phase 3)"],
          ["Images", "Done", "JPEG (DCT) & PNG (Flate) XObjects"]
        ],
        at: {margin, page_h - 130},
        column_widths: [120, 80, 280],
        row_height: 26,
        header: true,
        cell_padding: 8
      )
      |> PrawnEx.set_font("Helvetica", 11)
      |> PrawnEx.text_at({margin, page_h - 320}, "Text wrapping (text_box):")
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.set_non_stroking_gray(0.2)
      |> PrawnEx.text_box(
        "PrawnEx can wrap long text to fit a width. Use text_box(doc, string, at: {x, y}, width: pt) for paragraphs. Lines break on spaces; long words break by character.",
        at: {margin, page_h - 345},
        width: page_w - 2 * margin,
        font_size: 10,
        line_height: 14
      )
      |> PrawnEx.set_non_stroking_gray(0)
      # —— Page 3: Charts ——
      |> PrawnEx.add_page()
      |> PrawnEx.set_font("Helvetica", 18)
      |> PrawnEx.text_at({margin, page_h - 60}, "Charts (Phase 3)")
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.set_non_stroking_gray(0.5)
      |> PrawnEx.text_at(
        {margin, page_h - 85},
        "Bar and line charts from drawing primitives — no external deps"
      )
      |> PrawnEx.set_non_stroking_gray(0)
      |> PrawnEx.set_font("Helvetica", 11)
      |> PrawnEx.text_at({margin, page_h - 115}, "Bar chart")
      |> PrawnEx.bar_chart(
        [{"Q1", 42}, {"Q2", 68}, {"Q3", 55}, {"Q4", 90}],
        at: {margin, page_h - 320},
        width: page_w - 2 * margin,
        height: 180,
        bar_color: 0.45,
        labels: true,
        axis: true
      )
      |> PrawnEx.set_font("Helvetica", 11)
      |> PrawnEx.text_at({margin, page_h - 360}, "Line chart")
      |> PrawnEx.line_chart(
        [12, 28, 22, 45, 38, 52, 48],
        at: {margin, page_h - 550},
        width: page_w - 2 * margin,
        height: 160,
        stroke_color: 0.2,
        axis: true
      )
      # —— Page 4: Image demo ——
      |> PrawnEx.add_page()
      |> PrawnEx.set_font("Helvetica", 18)
      |> PrawnEx.text_at({margin, page_h - 60}, "Images (Phase 3)")
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.set_non_stroking_gray(0.5)
      |> PrawnEx.text_at(
        {margin, page_h - 85},
        "JPEG (/DCTDecode) and PNG (/FlateDecode) — file path or raw binary"
      )
      |> PrawnEx.set_non_stroking_gray(0)
      |> PrawnEx.set_font("Helvetica", 11)
      |> PrawnEx.text_at({margin, page_h - 118}, "JPEG")
      |> PrawnEx.text_at({margin + 268, page_h - 118}, "PNG")
      |> then(fn doc ->
        doc =
          case PrawnEx.image(doc, "demo.jpg", at: {margin, page_h - 380}, width: 220, height: 140) do
            {:error, _} ->
              case PrawnEx.image(doc, minimal_jpeg,
                     at: {margin, page_h - 380},
                     width: 220,
                     height: 140
                   ) do
                {:error, _} -> doc
                d -> d
              end

            d ->
              d
          end

        png_fallback = Path.join(File.cwd!(), "test/fixtures/tiny_rgb.png")

        case PrawnEx.image(doc, "demo.png",
               at: {margin + 268, page_h - 380},
               width: 220,
               height: 140
             ) do
          {:error, _} ->
            case PrawnEx.image(doc, png_fallback,
                   at: {margin + 268, page_h - 380},
                   width: 220,
                   height: 140
                 ) do
              {:error, _} -> doc
              d -> d
            end

          d ->
            d
        end
      end)
      |> PrawnEx.set_font("Helvetica", 9)
      |> PrawnEx.set_non_stroking_gray(0.5)
      |> PrawnEx.text_at(
        {margin, page_h - 460},
        "config :prawn_ex, image_dir: \"assets\" — demo.png is included; add demo.jpg for your own JPEG"
      )
      |> PrawnEx.set_non_stroking_gray(0)
    end
  )

IO.puts("Demo PDF written to: #{path}")
IO.puts("Open it with your PDF viewer.")
