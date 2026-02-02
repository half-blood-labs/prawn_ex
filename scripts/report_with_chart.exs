# Run with: mix run scripts/report_with_chart.exs
# Writes a one-page report (table + bar chart) to output/report_with_chart.pdf.

output_dir = Path.join(File.cwd!(), "output")
File.mkdir_p!(output_dir)
path = Path.join(output_dir, "report_with_chart.pdf")

page_w = 595
page_h = 842
margin = 50

rows = [
  ["Region", "Q1", "Q2", "Q3", "Q4"],
  ["North", "42", "55", "48", "62"],
  ["South", "38", "52", "61", "58"],
  ["East", "45", "48", "52", "70"],
  ["West", "30", "44", "55", "48"]
]

chart_data = [{"Q1", 42}, {"Q2", 55}, {"Q3", 48}, {"Q4", 62}]

:ok =
  PrawnEx.build(path, fn doc ->
    doc
    |> PrawnEx.add_page()
    |> PrawnEx.set_font("Helvetica", 20)
    |> PrawnEx.text_at({margin, page_h - 60}, "Sales report")
    |> PrawnEx.set_font("Helvetica", 10)
    |> PrawnEx.set_non_stroking_gray(0.5)
    |> PrawnEx.text_at({margin, page_h - 85}, "Summary by region and quarter")
    |> PrawnEx.set_non_stroking_gray(0)
    |> PrawnEx.table(rows, at: {margin, page_h - 180},
      column_widths: [100, 70, 70, 70, 70],
      header: true,
      align: [:left, :center, :center, :center, :center]
    )
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({margin, page_h - 320}, "North region quarterly view")
    |> PrawnEx.bar_chart(chart_data,
      at: {margin, page_h - 520},
      width: page_w - 2 * margin,
      height: 160,
      bar_color: 0.4,
      labels: true,
      axis: true
    )
  end)

IO.puts("Wrote #{path}")
