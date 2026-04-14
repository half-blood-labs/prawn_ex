# Run with: mix run scripts/invoice.exs
# Writes a minimal invoice PDF to output/invoice.pdf.
#
# Uses PrawnEx.Layout for the body (heading, paragraph, table) so you avoid
# repeating page_h - N coordinates; totals use Layout.escape/2 for one-off positions.

output_dir = Path.join(File.cwd!(), "output")
File.mkdir_p!(output_dir)
path = Path.join(output_dir, "invoice.pdf")

page_w = 595

rows = [
  ["Description", "Qty", "Unit Price", "Amount"],
  ["Widget Pro", "2", "$25.00", "$50.00"],
  ["Gadget Basic", "5", "$12.50", "$62.50"],
  ["Support (1 year)", "1", "$99.00", "$99.00"]
]

subtotal = "$211.50"
tax = "$21.15"
total = "$232.65"

:ok =
  PrawnEx.build(path, [
    footer: fn doc, page_num ->
      doc
      |> PrawnEx.set_font("Helvetica", 9)
      |> PrawnEx.set_non_stroking_gray(0.5)
      |> PrawnEx.text_at({50, 30}, "Thank you for your business.")
      |> PrawnEx.text_at({page_w - 50 - 50, 30}, "Page #{page_num}")
      |> PrawnEx.set_non_stroking_gray(0)
    end
  ], fn doc ->
    doc
    |> PrawnEx.add_page()
    |> PrawnEx.Layout.attach(page_size: :a4, margins: %{top: 60, left: 50, right: 50, bottom: 50})
    |> PrawnEx.Layout.heading("INVOICE", font_size: 24, lead: 1.0, gap_after: 6)
    |> PrawnEx.Layout.paragraph(
      "Acme Inc.\n123 Main St\nInvoice #001 | Date: 2025-02-08",
      font_size: 10,
      line_height: 15,
      gap_after: 6
    )
    |> PrawnEx.Layout.table(rows,
      column_widths: [220, 60, 80, 80],
      header: true,
      align: [:left, :center, :right, :right],
      clearance: 74,
      after_gap: 12
    )
    |> PrawnEx.Layout.escape(fn d, ctx ->
      x = ctx.page_w - ctx.margins.right - 180
      cy = ctx.cursor_y

      d =
        d
        |> PrawnEx.set_font("Helvetica", 10)
        |> PrawnEx.text_at({x, cy - 12}, "Subtotal: #{subtotal}")
        |> PrawnEx.text_at({x, cy - 30}, "Tax: #{tax}")
        |> PrawnEx.set_font("Helvetica", 12)
        |> PrawnEx.text_at({x, cy - 57}, "Total: #{total}")

      {d, cy - 62}
    end)
    |> PrawnEx.Layout.to_doc()
  end)

IO.puts("Wrote #{path}")
