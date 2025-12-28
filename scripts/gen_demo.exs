# Run with: mix run scripts/gen_demo.exs
# Writes a beautiful demo PDF to project's output/ folder.

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
  PrawnEx.build(path, fn doc ->
    doc
    # —— Header bar (dark gray) ——
    |> PrawnEx.set_non_stroking_gray(0.18)
    |> PrawnEx.rectangle(0, page_h - header_h, page_w, header_h)
    |> PrawnEx.fill()
    |> PrawnEx.set_non_stroking_gray(1)
    |> PrawnEx.set_font("Helvetica", 22)
    |> PrawnEx.text_at({margin, page_h - 48}, "PrawnEx")
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({page_w - margin - 120, page_h - 50}, "Pure Elixir PDF")
    # —— Hero ——
    |> PrawnEx.set_non_stroking_gray(0)
    |> PrawnEx.set_font("Helvetica", 28)
    |> PrawnEx.text_at({margin, page_h - 140}, "Beautiful documents.")
    |> PrawnEx.set_font("Helvetica", 14)
    |> PrawnEx.text_at({margin, page_h - 175}, "Zero dependencies. No Chrome. No HTML. Just Elixir.")
    # —— Divider ——
    |> PrawnEx.set_stroking_gray(0.85)
    |> PrawnEx.line({margin, page_h - 210}, {page_w - margin, page_h - 210})
    |> PrawnEx.stroke()
    # —— Section title ——
    |> PrawnEx.set_stroking_gray(0)
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({margin, page_h - 245}, "Why PrawnEx?")
    # —— Three feature cards (bordered boxes + text) ——
    |> PrawnEx.set_stroking_gray(0.75)
    |> PrawnEx.rectangle(margin, page_h - 380, (page_w - 2 * margin - 24) / 3, 110)
    |> PrawnEx.stroke()
    |> PrawnEx.rectangle(margin + (page_w - 2 * margin - 24) / 3 + 12, page_h - 380, (page_w - 2 * margin - 24) / 3, 110)
    |> PrawnEx.stroke()
    |> PrawnEx.rectangle(margin + 2 * ((page_w - 2 * margin - 24) / 3 + 12), page_h - 380, (page_w - 2 * margin - 24) / 3, 110)
    |> PrawnEx.stroke()
    |> PrawnEx.set_non_stroking_gray(0)
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({margin + 14, page_h - 318}, "Fast & lightweight")
    |> PrawnEx.set_font("Helvetica", 9)
    |> PrawnEx.text_at({margin + 14, page_h - 338}, "No external renderer.")
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({margin + (page_w - 2 * margin - 24) / 3 + 26, page_h - 318}, "Declarative API")
    |> PrawnEx.set_font("Helvetica", 9)
    |> PrawnEx.text_at({margin + (page_w - 2 * margin - 24) / 3 + 26, page_h - 338}, "Pipe-friendly, immutable.")
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({margin + 2 * ((page_w - 2 * margin - 24) / 3 + 12) + 14, page_h - 318}, "PDF 1.4 compliant")
    |> PrawnEx.set_font("Helvetica", 9)
    |> PrawnEx.text_at({margin + 2 * ((page_w - 2 * margin - 24) / 3 + 12) + 14, page_h - 338}, "Standard, portable.")
    # —— Block quote / tagline ——
    |> PrawnEx.set_stroking_gray(0.9)
    |> PrawnEx.rectangle(margin, page_h - 480, page_w - 2 * margin, 52)
    |> PrawnEx.stroke()
    |> PrawnEx.set_non_stroking_gray(0.35)
    |> PrawnEx.set_font("Helvetica", 10)
    |> PrawnEx.text_at({margin + 16, page_h - 455}, "The library you can drop in to replace HTML-to-PDF or heavy stacks.")
    |> PrawnEx.set_non_stroking_gray(0)
    # —— Footer ——
    |> PrawnEx.set_stroking_gray(0.8)
    |> PrawnEx.line({margin, footer_y + 20}, {page_w - margin, footer_y + 20})
    |> PrawnEx.stroke()
    |> PrawnEx.set_font("Helvetica", 9)
    |> PrawnEx.text_at({margin, footer_y}, "Generated with PrawnEx — prawn-ex")
  end)

IO.puts("Demo PDF written to: #{path}")
IO.puts("Open it with your PDF viewer.")
