# Run with: mix run scripts/layout_phases_demo.exs
# Writes output/layout_phases_demo.pdf - exercises PrawnEx.Layout Phase A-D on one document.
#
# Use ASCII punctuation only (built-in Helvetica is PDF WinAnsi; Unicode en-dash / bullets
# can render as garbled characters in some viewers).
#
# Phase A - Flow: attach, heading, paragraph, spacer, table (cursor; no manual page_h).
# Phase B - vstack / hstack: vertical tuple blocks; horizontal fixed-width columns.
# Phase C - Region: region floor_y + on_overflow :new_page (spacer crosses pages).
# Phase D - Markup: PrawnEx.Layout.Markup (#/## headings, - bullets, blank lines).

output_dir = Path.join(File.cwd!(), "output")
File.mkdir_p!(output_dir)
path = Path.join(output_dir, "layout_phases_demo.pdf")

margin = 48

:ok =
  PrawnEx.build(path, fn doc ->
    doc
    |> PrawnEx.add_page()
    |> PrawnEx.Layout.attach(
      page_size: :a4,
      margins: %{top: 52, left: margin, right: margin, bottom: 52},
      region: %{floor_y: 100},
      on_overflow: :new_page
    )
    |> PrawnEx.Layout.heading("PrawnEx layout phases (A-D)", font_size: 22, gap_after: 14)
    |> PrawnEx.Layout.paragraph(
      "This PDF is generated with PrawnEx.Layout and Layout.Markup. Each section is labelled by phase. Coordinates use the PDF bottom-left origin.",
      font_size: 10,
      line_height: 14,
      gap_after: 12
    )
    |> PrawnEx.Layout.heading("Phase A - Flow primitives", font_size: 15, level: 2, gap_after: 10)
    |> PrawnEx.Layout.paragraph(
      "Phase A provides attach/2, heading/3, paragraph/3, spacer/2, table/3, escape/2, and to_doc/1. You work inside a margin box with a vertical cursor instead of repeating page_h minus constants.",
      font_size: 10,
      line_height: 14,
      gap_after: 12
    )
    |> PrawnEx.Layout.table(
      [
        ["Phase", "What it does"],
        ["A", "Margin + cursor flow"],
        ["B", "vstack tuple blocks; hstack columns"],
        ["C", "region floor_y; spacer/new page"],
        ["D", "Markup.parse + Markup.apply"]
      ],
      column_widths: [80, 400],
      header: true,
      clearance: 20,
      after_gap: 16,
      row_height: 22,
      font_size: 9
    )
    |> PrawnEx.Layout.heading("Phase B - vstack", font_size: 15, level: 2, gap_after: 10)
    |> PrawnEx.Layout.paragraph(
      "vstack/3 runs a list of {:heading, ...}, {:paragraph, ...}, {:spacer, ...}, {:table, ...}, or {:run, fn l -> l end}. Optional gap: inserts spacer between blocks.",
      font_size: 10,
      line_height: 14,
      gap_after: 12
    )
    |> PrawnEx.Layout.vstack(
      [
        {:paragraph, "vstack child 1", font_size: 10, line_height: 13, gap_after: 8},
        {:paragraph, "vstack child 2", font_size: 10, line_height: 13, gap_after: 8},
        {:spacer, 8},
        {:paragraph, "After intra-stack spacer and vstack gap.", font_size: 10, line_height: 13, gap_after: 10}
      ],
      gap: 8
    )
    |> PrawnEx.Layout.spacer(6)
    |> PrawnEx.Layout.heading("Phase B - hstack", font_size: 15, level: 2, gap_after: 10)
    |> PrawnEx.Layout.hstack(
      [
        {200,
         fn col ->
           PrawnEx.Layout.paragraph(
             col,
             "Left: fixed width 200 pt. Text wraps inside the column.",
             font_size: 9,
             line_height: 12,
             gap_after: 6
           )
         end},
        {200,
         fn col ->
           PrawnEx.Layout.paragraph(
             col,
             "Right: same row, independent column body.",
             font_size: 9,
             line_height: 12,
             gap_after: 6
           )
         end}
      ],
      gap: 12,
      row_gap_after: 16
    )
    |> PrawnEx.Layout.spacer(8)
    |> PrawnEx.Layout.heading("Phase D - Markup (line DSL)", font_size: 15, level: 2, gap_after: 10)
    |> PrawnEx.Layout.paragraph(
      "The following block was built from a string via Layout.Markup.apply/3 (parse + vstack):",
      font_size: 10,
      line_height: 14,
      gap_after: 10
    )
    |> PrawnEx.Layout.Markup.apply(
      """
      ## From markup

      Hash headings and bullet lines:
      - First bullet
      - Second bullet

      Plain lines join until a blank line ends the paragraph.
      """,
      gap: 8
    )
    |> PrawnEx.Layout.spacer(8)
    |> PrawnEx.Layout.heading("Phase C - Region + automatic new page",
      font_size: 15,
      level: 2,
      gap_after: 10
    )
    |> PrawnEx.Layout.paragraph(
      "attach/2 sets region: %{floor_y: 100} and on_overflow: :new_page. Content must stay at or above y = 100. The next spacer(720) is larger than the remaining vertical band on this page, so Layout inserts add_page/1 and continues counting down on the next page.",
      font_size: 9,
      line_height: 12,
      gap_after: 10
    )
    |> PrawnEx.Layout.spacer(720)
    |> PrawnEx.Layout.paragraph(
      "If you are reading this after a page break, Phase C worked: spacer split across pages and the cursor reset under the top margin.",
      font_size: 10,
      line_height: 14,
      gap_after: 10
    )
    |> PrawnEx.Layout.paragraph(
      "End of layout_phases_demo. Compare with mix run scripts/gen_demo.exs (page 5 has a shorter Layout teaser).",
      font_size: 9,
      line_height: 12,
      gap_after: 6
    )
    |> PrawnEx.Layout.to_doc()
  end)

IO.puts("Wrote #{path} (open in a PDF viewer; expect at least 2 pages for Phase C).")
