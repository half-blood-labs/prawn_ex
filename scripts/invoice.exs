# Run with: mix run scripts/invoice.exs
# Writes a minimal invoice PDF to output/invoice.pdf.

output_dir = Path.join(File.cwd!(), "output")
File.mkdir_p!(output_dir)
path = Path.join(output_dir, "invoice.pdf")

page_w = 595
page_h = 842
margin = 50

# Table: header row + line items (description, qty, unit price, amount)
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
      |> PrawnEx.text_at({margin, 30}, "Thank you for your business.")
      |> PrawnEx.text_at({page_w - margin - 50, 30}, "Page #{page_num}")
      |> PrawnEx.set_non_stroking_gray(0)
    end
  ], fn doc ->
    doc
    |> PrawnEx.add_page()
    |> then(fn d ->
      d
      |> PrawnEx.set_font("Helvetica", 24)
      |> PrawnEx.text_at({margin, page_h - 60}, "INVOICE")
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.text_at({margin, page_h - 90}, "Acme Inc.")
      |> PrawnEx.text_at({margin, page_h - 105}, "123 Main St")
      |> PrawnEx.text_at({margin, page_h - 120}, "Invoice #001 | Date: 2025-02-08")
      |> PrawnEx.table(rows, at: {margin, page_h - 200},
        column_widths: [220, 60, 80, 80],
        header: true,
        align: [:left, :center, :right, :right]
      )
      |> PrawnEx.set_font("Helvetica", 10)
      |> PrawnEx.text_at({page_w - margin - 180, page_h - 320}, "Subtotal: #{subtotal}")
      |> PrawnEx.text_at({page_w - margin - 180, page_h - 338}, "Tax: #{tax}")
      |> PrawnEx.set_font("Helvetica", 12)
      |> PrawnEx.text_at({page_w - margin - 180, page_h - 365}, "Total: #{total}")
    end)
  end)

IO.puts("Wrote #{path}")
