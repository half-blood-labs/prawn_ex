# A chart-dense analytics one-pager, three ways. prawn_ex uses its
# built-in chart functions; Typst has no charts without the cetz
# package (unavailable inside the NIF), so imprintor's version is
# hand-drawn geometry in Typst markup; folio gets a fenced typst block
# if its markdown supports one.

months = ~w(Oct Nov Dec Jan Feb Mar Apr May Jun Jul Aug Sep)

charges = [186, 171, 190, 172, 168, 179, 175, 181, 169, 173, 196, 188]
collections = [98, 91, 103, 95, 92, 99, 96, 101, 93, 95, 108, 104]
denials = [45, 39, 52, 41, 38, 47, 43, 40, 36, 42, 55, 48]

payers = [
  {"Medicare", 32},
  {"BCBS", 24},
  {"UnitedHealthcare", 16},
  {"Aetna", 11},
  {"Cigna", 8},
  {"Self-pay", 5}
]

kpis = [
  {"COLLECTIONS TTM", "$1.17M"},
  {"NET COLLECTION", "94.7%"},
  {"DENIAL RATE", "10.8%"},
  {"DAYS IN A/R", "31.4"}
]

teal = {11 / 255, 91 / 255, 104 / 255}
orange = {235 / 255, 104 / 255, 52 / 255}

## ── 1. prawn_ex: built-in charts ──────────────────────────────────────

{us, _} =
  :timer.tc(fn ->
    :ok =
      PrawnEx.build("charts-prawn_ex.pdf", [], fn doc ->
        doc = %{doc | opts: Keyword.put(doc.opts, :page_size, :letter)}
        {tr, tg, tb} = teal

        doc =
          doc
          |> PrawnEx.add_page()
          |> PrawnEx.set_non_stroking_rgb(tr, tg, tb)
          |> PrawnEx.rectangle(0, 786, 612, 6)
          |> PrawnEx.fill()
          |> PrawnEx.set_non_stroking_gray(0.0)
          |> PrawnEx.set_font("Helvetica-Bold", 18)
          |> PrawnEx.text_at({54, 742}, "Practice Analytics")
          |> PrawnEx.set_non_stroking_gray(0.4)
          |> PrawnEx.set_font("Helvetica", 9)
          |> PrawnEx.text_at({54, 726}, "Twelve months at a glance · Riverside Family Medicine")

        doc =
          kpis
          |> Enum.with_index()
          |> Enum.reduce(doc, fn {{label, value}, i}, doc ->
            x = 54 + i * 128

            doc
            |> PrawnEx.set_non_stroking_gray(0.97)
            |> PrawnEx.set_stroking_gray(0.85)
            |> PrawnEx.rounded_rectangle(x, 664, 120, 44, 6)
            |> PrawnEx.fill_stroke()
            |> PrawnEx.set_non_stroking_gray(0.45)
            |> PrawnEx.set_font("Helvetica-Bold", 6)
            |> PrawnEx.text_at({x + 8, 692}, label)
            |> PrawnEx.set_non_stroking_gray(0.0)
            |> PrawnEx.set_font("Helvetica-Bold", 12)
            |> PrawnEx.text_at({x + 8, 672}, value)
          end)

        # Multi-line chart with area tint under collections
        chart_top = 630
        chart_h = 150
        plot_left = 54 + 12
        plot_bottom = chart_top - chart_h + 12
        plot_w = 504 - 24
        plot_h = chart_h - 24
        mx = Enum.max(charges)
        n = length(collections)

        doc =
          doc
          |> PrawnEx.set_non_stroking_gray(0.0)
          |> PrawnEx.set_font("Helvetica-Bold", 11)
          |> PrawnEx.text_at({54, chart_top + 14}, "Charges vs collections ($k)")

        doc =
          collections
          |> Enum.with_index()
          |> Enum.reduce(
            doc
            |> PrawnEx.set_opacity(0.1)
            |> PrawnEx.set_non_stroking_rgb(tr, tg, tb)
            |> PrawnEx.move_to({plot_left, plot_bottom}),
            fn {v, i}, doc ->
              PrawnEx.line_to(doc, {plot_left + i / (n - 1) * plot_w, plot_bottom + v / mx * plot_h})
            end
          )
          |> PrawnEx.line_to({plot_left + plot_w, plot_bottom})
          |> PrawnEx.close_path()
          |> PrawnEx.fill()
          |> PrawnEx.set_opacity(1.0)

        doc =
          PrawnEx.multi_line_chart(
            doc,
            [
              %{data: charges, color: orange, label: "Charges"},
              %{data: collections, color: teal, label: "Collections"}
            ],
            at: {54, chart_top},
            width: 504,
            height: chart_h,
            from_zero: true
          )

        doc =
          months
          |> Enum.with_index()
          |> Enum.reduce(doc, fn {m, i}, doc ->
            doc
            |> PrawnEx.set_non_stroking_gray(0.5)
            |> PrawnEx.set_font("Helvetica", 6)
            |> PrawnEx.text_at({plot_left + i / (n - 1) * plot_w - 6, chart_top - chart_h - 2}, m)
          end)

        # Bar chart: denials
        doc =
          doc
          |> PrawnEx.set_non_stroking_gray(0.0)
          |> PrawnEx.set_font("Helvetica-Bold", 11)
          |> PrawnEx.text_at({54, 436}, "Denied claims by month")
          |> PrawnEx.bar_chart(Enum.zip(months, denials),
            at: {54, 420},
            width: 504,
            height: 130,
            bar_color: teal,
            corner_radius: 3,
            value_labels: true,
            value_font_size: 6,
            label_font_size: 6
          )

        # Horizontal payer bars
        doc =
          doc
          |> PrawnEx.set_non_stroking_gray(0.0)
          |> PrawnEx.set_font("Helvetica-Bold", 11)
          |> PrawnEx.text_at({54, 246}, "Payer mix — share of collections")

        pmax = payers |> Enum.map(&elem(&1, 1)) |> Enum.max()

        payers
        |> Enum.with_index()
        |> Enum.reduce(doc, fn {{payer, pct}, i}, doc ->
          y = 222 - i * 24
          bar_w = pct / pmax * 300

          doc
          |> PrawnEx.set_non_stroking_gray(0.3)
          |> PrawnEx.set_font("Helvetica", 8.5)
          |> PrawnEx.text_at({54, y}, payer)
          |> PrawnEx.set_non_stroking_rgb(tr, tg, tb)
          |> PrawnEx.rounded_rectangle(190, y - 2, bar_w, 11, 4)
          |> PrawnEx.fill()
          |> PrawnEx.set_non_stroking_gray(0.0)
          |> PrawnEx.set_font("Helvetica-Bold", 8.5)
          |> PrawnEx.text_at({190 + bar_w + 6, y}, "#{pct}%")
        end)
      end)
  end)

IO.puts("prawn_ex: #{File.stat!("charts-prawn_ex.pdf").size} bytes / #{div(us, 1000)} ms")

## ── 2. imprintor: charts hand-drawn in Typst ──────────────────────────

typst = """
#set page(paper: "us-letter", margin: 54pt)
#set text(font: "Libertinus Serif", size: 9.5pt)
#let teal = rgb("#0b5b68")
#let orange = rgb("#eb6834")
#let data = sys.inputs.elixir_data

#rect(fill: teal, width: 100%, height: 6pt)
#v(2pt)
= Practice Analytics
Twelve months at a glance · Riverside Family Medicine

#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 8pt,
  ..data.kpis.map(k => rect(stroke: 0.5pt + luma(200), radius: 6pt, inset: 8pt, width: 100%)[
    #text(size: 6pt, fill: gray)[#k.label] \\
    #text(size: 12pt, weight: "bold")[#k.value]
  ])
)

== Charges vs collections (\\$k)
// No chart primitives without the cetz package, which the embedded
// compiler cannot download — so this is hand-computed geometry.
#let W = 470pt
#let H = 120pt
#let mx = calc.max(..data.charges)
#let n = data.charges.len()
#let pt-x(i) = W * i / (n - 1)
#let pt-y(v) = H - H * v / mx
#box(width: W, height: H + 14pt, {
  // area under collections
  place(top + left, polygon(fill: teal.transparentize(88%),
    (0pt, H),
    ..range(n).map(i => (pt-x(i), pt-y(data.collections.at(i)))),
    (W, H)
  ))
  // the two series as segment chains
  for i in range(n - 1) {
    place(top + left, line(start: (pt-x(i), pt-y(data.charges.at(i))),
      end: (pt-x(i + 1), pt-y(data.charges.at(i + 1))), stroke: 1.5pt + orange))
    place(top + left, line(start: (pt-x(i), pt-y(data.collections.at(i))),
      end: (pt-x(i + 1), pt-y(data.collections.at(i + 1))), stroke: 1.5pt + teal))
  }
  for i in range(n) {
    place(top + left, dx: pt-x(i) - 5pt, dy: H + 3pt, text(size: 5.5pt, fill: gray)[#data.months.at(i)])
  }
})
#box(baseline: 20%, rect(width: 8pt, height: 8pt, fill: orange)) Charges
#h(10pt)
#box(baseline: 20%, rect(width: 8pt, height: 8pt, fill: teal)) Collections

== Denied claims by month
#let dmx = calc.max(..data.denials)
#stack(dir: ltr, spacing: 6pt,
  ..range(data.denials.len()).map(i =>
    stack(dir: ttb, spacing: 2pt,
      align(center, text(size: 5.5pt)[#data.denials.at(i)]),
      box(height: 80pt, width: 32pt,
        align(bottom, rect(width: 100%, height: 80pt * data.denials.at(i) / dmx, fill: teal, radius: 2pt))),
      align(center, text(size: 5.5pt, fill: gray)[#data.months.at(i)])
    ))
)

== Payer mix — share of collections
#let pmx = calc.max(..data.payers.map(p => p.pct))
#for p in data.payers [
  #grid(columns: (110pt, 1fr, 30pt), gutter: 6pt, row-gutter: 0pt,
    text(size: 8.5pt)[#p.name],
    box(height: 10pt, align(left + horizon, rect(width: 100% * p.pct / pmx, height: 9pt, fill: teal, radius: 4pt))),
    text(size: 8.5pt, weight: "bold")[#p.pct%]
  )
]
"""

typst_data = %{
  "kpis" => Enum.map(kpis, fn {l, v} -> %{"label" => l, "value" => v} end),
  "months" => months,
  "charges" => charges,
  "collections" => collections,
  "denials" => denials,
  "payers" => Enum.map(payers, fn {n, p} -> %{"name" => n, "pct" => p} end)
}

{us, _} =
  :timer.tc(fn ->
    config = Imprintor.Config.new(typst, typst_data)
    {:ok, pdf} = Imprintor.compile_to_pdf(config)
    File.write!("charts-imprintor.pdf", pdf)
  end)

IO.puts("imprintor: #{File.stat!("charts-imprintor.pdf").size} bytes / #{div(us, 1000)} ms")

## ── 3. folio: try a fenced typst block in markdown ────────────────────

markdown = """
# Practice Analytics

Twelve months at a glance · Riverside Family Medicine

| #{Enum.map_join(kpis, " | ", &elem(&1, 0))} |
|---|---|---|---|
| #{Enum.map_join(kpis, " | ", &elem(&1, 1))} |

## Charges vs collections ($k)

```typst
#let teal = rgb("#0b5b68")
#let vals = (#{Enum.join(collections, ", ")})
#let mx = #{Enum.max(charges)}
#stack(dir: ltr, spacing: 5pt,
  ..vals.pos().map(v =>
    box(height: 80pt, width: 30pt,
      align(bottom, rect(width: 100%, height: 80pt * v / mx, fill: teal, radius: 2pt))))
)
```

## Denied claims by month

| #{Enum.join(months, " | ")} |
|#{String.duplicate("---|", 12)}
| #{Enum.join(denials, " | ")} |

## Payer mix

| Payer | Share |
|---|---|
#{Enum.map_join(payers, "\n", fn {n, p} -> "| #{n} | #{p}% |" end)}
"""

{us, result} =
  :timer.tc(fn ->
    doc = Folio.parse_markdown!(markdown)
    Folio.to_pdf(doc)
  end)

case result do
  {:ok, pdf} ->
    File.write!("charts-folio.pdf", pdf)
    IO.puts("folio: #{File.stat!("charts-folio.pdf").size} bytes / #{div(us, 1000)} ms")

  other ->
    IO.puts("folio failed: #{inspect(other)}")
end
