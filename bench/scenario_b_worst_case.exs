# Global Elixir here is 1.16; Date.shift arrived in 1.17.
shift_month = fn date, offset ->
  total = date.year * 12 + date.month - 1 + offset
  {:ok, shifted} = Date.new(div(total, 12), rem(total, 12) + 1, 1)
  shifted
end

months =
  for back <- 47..0//-1 do
    month = shift_month.(Date.utc_today() |> Date.beginning_of_month(), -back)
    seed = :erlang.phash2({month.year, month.month}, 1000) / 1000
    charges = round(16_000_00 + seed * 60_000_00)
    adjustments = round(charges * 0.42)
    collections = round((charges - adjustments) * (0.90 + seed * 0.08))

    %{
      label: Calendar.strftime(month, "%b %Y"),
      charges: charges,
      collections: collections,
      adjustments: adjustments,
      claims: 300 + round(seed * 200),
      denied: 20 + round(seed * 40)
    }
  end

usd = fn cents -> "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}" end

kpis = [
  {"COLLECTIONS TTM", usd.(months |> Enum.take(-12) |> Enum.map(& &1.collections) |> Enum.sum())},
  {"AVG DAYS IN A/R", "31.4"},
  {"NET COLLECTION", "94.7%"},
  {"DENIAL RATE", "10.8%"}
]

narrative = [
  ~s(This review covers four full years of billing performance for Riverside Family Medicine — every month from #{hd(months).label} through #{List.last(months).label}. The intent is not to bury the practice in numbers but to show the shape of the revenue cycle over time: where money moved quickly, where it aged, and which payers quietly changed their behaviour along the way.),
  ~s(Collections held remarkably steady across the period, with seasonal dips in the winter months that mirror visit volume rather than any billing failure. The net collection rate — measured, as always, against allowed amounts rather than gross charges — stayed above the 94% line for most of the period, which places the practice comfortably ahead of the specialty median we observe across comparable organisations.),
  ~s(Denials tell a more interesting story. The dominant reason remains CO-16, "claim lacks information," which is almost entirely preventable at the front desk. When eligibility verification was tightened in the spring, the CO-16 count fell by roughly a third within two statement cycles — direct evidence that the fix belongs at registration, not in the back office.),
  ~s(Aged receivables deserve continued attention. The share of open A/R older than ninety days drifted between 17% and 22% across the period. Most of the aged balance sits with two payers, and the pattern suggests slow adjudication rather than disputed claims: the money arrives, it simply arrives late. We recommend a standing weekly follow-up queue for both payers rather than ad-hoc chasing.),
  ~s(Finally, a note on method. Every figure in this document is computed from the monthly ledger reproduced in full below, so any number can be traced to its source month. Nothing here is estimated, annualised, or smoothed — where a month was weak, the table says so plainly.)
]

## ── 1. imprintor: full Typst ──────────────────────────────────────────

typst = """
#set page(paper: "us-letter", margin: (x: 54pt, y: 64pt),
  footer: context [
    #set text(size: 8pt, fill: gray)
    Riverside Family Medicine · Quarterly Review
    #h(1fr)
    Page #counter(page).display()
  ])
#set text(font: "Libertinus Serif", size: 9.5pt)
#set par(justify: true, leading: 0.65em)

#let data = sys.inputs.elixir_data

#rect(fill: rgb("#0b5b68"), width: 100%, height: 6pt)
#v(6pt)
#text(size: 8pt, fill: gray, tracking: 1pt)[QUARTERLY PRACTICE REVIEW]

= Riverside Family Medicine
Four-year revenue cycle review · prepared by Summit Billing Partners

#v(6pt)
#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 8pt,
  ..data.kpis.map(k => rect(stroke: 0.5pt + luma(200), radius: 6pt, inset: 9pt, width: 100%)[
    #text(size: 6.5pt, fill: gray)[#k.label] \\
    #text(size: 13pt, weight: "bold")[#k.value]
  ])
)

#v(10pt)
== Executive narrative
#for p in data.narrative [#par[#p]]

#v(10pt)
== Trailing 12 months — collections
#let vals = data.chart.map(c => c.value)
#let mx = calc.max(..vals)
#stack(dir: ltr, spacing: 7pt,
  ..data.chart.map(c =>
    stack(dir: ttb, spacing: 3pt,
      box(height: 90pt, width: 30pt,
        align(bottom, rect(width: 100%, height: 90pt * c.value / mx, fill: rgb("#0b5b68"), radius: 2pt))),
      align(center, text(size: 5.5pt)[#c.label])
    ))
)

#v(10pt)
== The monthly ledger, in full
#table(columns: (auto, 1fr, 1fr, 1fr, auto, auto),
  stroke: 0.4pt + luma(210), inset: 5pt,
  table.header([*Month*], [*Charges*], [*Collections*], [*Adjustments*], [*Claims*], [*Denied*]),
  ..data.ledger.map(m => (m.label, m.charges, m.collections, m.adjustments, str(m.claims), str(m.denied))).flatten()
)
"""

typst_data = %{
  "kpis" => Enum.map(kpis, fn {l, v} -> %{"label" => l, "value" => v} end),
  "narrative" => narrative,
  "chart" =>
    months |> Enum.take(-12) |> Enum.map(&%{"label" => String.slice(&1.label, 0, 3), "value" => &1.collections / 100}),
  "ledger" =>
    Enum.map(months, fn m ->
      %{
        "label" => m.label,
        "charges" => usd.(m.charges),
        "collections" => usd.(m.collections),
        "adjustments" => usd.(m.adjustments),
        "claims" => m.claims,
        "denied" => m.denied
      }
    end)
}

{us, _} =
  :timer.tc(fn ->
    config = Imprintor.Config.new(typst, typst_data)
    {:ok, pdf} = Imprintor.compile_to_pdf(config)
    File.write!("worst-imprintor.pdf", pdf)
  end)

IO.puts("imprintor: #{File.stat!("worst-imprintor.pdf").size} bytes / #{div(us, 1000)} ms")

## ── 2. folio: markdown API ────────────────────────────────────────────

markdown = """
# Riverside Family Medicine

Four-year revenue cycle review · prepared by Summit Billing Partners

| #{Enum.map_join(kpis, " | ", &elem(&1, 0))} |
|---|---|---|---|
| #{Enum.map_join(kpis, " | ", &elem(&1, 1))} |

## Executive narrative

#{Enum.join(narrative, "\n\n")}

## Trailing 12 months — collections

_(A drawn chart is not expressible through the markdown API; the same values follow as a table.)_

| Month | Collections |
|---|---|
#{months |> Enum.take(-12) |> Enum.map_join("\n", &"| #{&1.label} | #{usd.(&1.collections)} |")}

## The monthly ledger, in full

| Month | Charges | Collections | Adjustments | Claims | Denied |
|---|---|---|---|---|---|
#{Enum.map_join(months, "\n", &"| #{&1.label} | #{usd.(&1.charges)} | #{usd.(&1.collections)} | #{usd.(&1.adjustments)} | #{&1.claims} | #{&1.denied} |")}
"""

{us, _} =
  :timer.tc(fn ->
    doc = Folio.parse_markdown!(markdown)
    {:ok, pdf} = Folio.to_pdf(doc)
    File.write!("worst-folio.pdf", pdf)
  end)

IO.puts("folio: #{File.stat!("worst-folio.pdf").size} bytes / #{div(us, 1000)} ms")

## ── 3. prawn_ex: owned layout ─────────────────────────────────────────

alias PrawnEx.Layout

{us, _} =
  :timer.tc(fn ->
    :ok =
      PrawnEx.build(
        "worst-prawn_ex.pdf",
        [
          footer: fn doc, page ->
            doc
            |> PrawnEx.set_non_stroking_gray(0.55)
            |> PrawnEx.set_font("Helvetica", 8)
            |> PrawnEx.text_at({54, 34}, "Riverside Family Medicine · Quarterly Review")
            |> PrawnEx.text_at({500, 34}, "Page #{page}")
          end
        ],
        fn doc ->
          doc = %{doc | opts: Keyword.put(doc.opts, :page_size, :letter)}

          doc =
            doc
            |> PrawnEx.add_page()
            |> PrawnEx.set_non_stroking_rgb(11 / 255, 91 / 255, 104 / 255)
            |> PrawnEx.rectangle(0, 786, 612, 6)
            |> PrawnEx.fill()
            |> PrawnEx.set_non_stroking_gray(0.45)
            |> PrawnEx.set_font("Helvetica-Bold", 8)
            |> PrawnEx.text_at({54, 758}, "QUARTERLY PRACTICE REVIEW")
            |> PrawnEx.set_non_stroking_gray(0.0)
            |> PrawnEx.set_font("Helvetica-Bold", 20)
            |> PrawnEx.text_at({54, 732}, "Riverside Family Medicine")
            |> PrawnEx.set_non_stroking_gray(0.4)
            |> PrawnEx.set_font("Helvetica", 10)
            |> PrawnEx.text_at({54, 714}, "Four-year revenue cycle review · prepared by Summit Billing Partners")

          doc =
            kpis
            |> Enum.with_index()
            |> Enum.reduce(doc, fn {{label, value}, i}, doc ->
              x = 54 + i * 128

              doc
              |> PrawnEx.set_non_stroking_gray(0.97)
              |> PrawnEx.set_stroking_gray(0.85)
              |> PrawnEx.rounded_rectangle(x, 648, 120, 48, 6)
              |> PrawnEx.fill_stroke()
              |> PrawnEx.set_non_stroking_gray(0.45)
              |> PrawnEx.set_font("Helvetica-Bold", 6)
              |> PrawnEx.text_at({x + 8, 678}, label)
              |> PrawnEx.set_non_stroking_gray(0.0)
              |> PrawnEx.set_font("Helvetica-Bold", 12)
              |> PrawnEx.text_at({x + 8, 658}, value)
            end)

          chart_data =
            months |> Enum.take(-12) |> Enum.map(&{String.slice(&1.label, 0, 3), &1.collections / 100})

          layout =
            doc
            |> Layout.attach(
              page_size: :letter,
              margins: %{left: 54, right: 54, top: 792 - 630, bottom: 60},
              region: %{floor_y: 60},
              on_overflow: :new_page
            )
            |> Layout.heading("Executive narrative", font: "Helvetica-Bold", font_size: 12, gap_after: 8)

          layout =
            Enum.reduce(narrative, layout, fn para, layout ->
              Layout.paragraph(layout, para, line_height: 13, gap_after: 8)
            end)

          layout
          |> Layout.spacer(6)
          |> Layout.heading("Trailing 12 months — collections",
            font: "Helvetica-Bold",
            font_size: 12,
            gap_after: 6
          )
          |> Layout.escape(fn doc, ctx ->
            chart_h = 130

            doc =
              PrawnEx.bar_chart(doc, chart_data,
                at: {ctx.content_left, ctx.cursor_y},
                width: ctx.content_width,
                height: chart_h,
                bar_color: {11 / 255, 91 / 255, 104 / 255},
                corner_radius: 2,
                labels: true,
                label_font_size: 6
              )

            {doc, ctx.cursor_y - chart_h - 24}
          end)
          |> Layout.spacer(8)
          |> Layout.heading("The monthly ledger, in full",
            font: "Helvetica-Bold",
            font_size: 12,
            gap_after: 8
          )
          |> Layout.table(
            [["Month", "Charges", "Collections", "Adjustments", "Claims", "Denied"]] ++
              Enum.map(
                months,
                &[&1.label, usd.(&1.charges), usd.(&1.collections), usd.(&1.adjustments), "#{&1.claims}", "#{&1.denied}"]
              ),
            column_widths: [70, 100, 100, 100, 60, 60],
            header: true,
            font_size: 8,
            header_font_size: 8,
            row_height: 15,
            align: [:left, :right, :right, :right, :right, :right]
          )
          |> Layout.to_doc()
        end
      )
  end)

IO.puts("prawn_ex: #{File.stat!("worst-prawn_ex.pdf").size} bytes / #{div(us, 1000)} ms")
