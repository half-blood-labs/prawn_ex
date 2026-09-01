# prawn_ex vs the Typst wrappers — an honest comparison

There are three realistic ways to generate PDFs from Elixir without a
headless browser in 2026:

- **prawn_ex** (this library) — pure Elixir, emits PDF 1.4 directly
- **[imprintor](https://github.com/mfeckie/imprintor)** — the Typst
  compiler embedded via a Rustler NIF; you write Typst markup, pass
  data through `sys.inputs`
- **[folio](https://github.com/dannote/folio)** — also Typst via
  Rustler NIF, but with a Markdown-first API

All three are good software. They sit at different points on the same
trade-off curve, and this guide maps that curve with measured numbers
rather than opinions. Everything below is reproducible with the
scripts in [`bench/`](../bench/).

## The headline numbers

Measured on Apple Silicon, warm caches, identical document content per
scenario. Three scenarios of increasing hostility:

**Scenario A — a small data report** (KPI row + one table):

| | Output | Time per doc |
|---|---|---|
| prawn_ex | 3.4 KB | 0.1 ms |
| folio | 15.9 KB | 0.3 ms |
| imprintor | 25.6 KB | 86 ms |

**Scenario B — the worst case** (five long justified paragraphs, a
chart, a 48-row ledger that must break across pages, footers with page
numbers — 3 pages):

| | Output | Time per doc |
|---|---|---|
| prawn_ex | 35 KB | 11 ms |
| imprintor | 110 KB | 105 ms |
| folio | 35 KB | 1,165 ms |

**Scenario C — chart-dense analytics** (two-series line chart with
area fill and legend, 12 value-labeled bars, horizontal payer bars,
KPI cards):

| | Output | Time per doc | How the charts got made |
|---|---|---|---|
| prawn_ex | 12 KB | 6 ms | built-in chart functions |
| imprintor | 31 KB | 287 ms | ~40 lines of hand-computed Typst geometry |
| folio | 33 KB | 2,004 ms | could not be made — see below |

**Deployment weight** is the other axis: the Typst wrappers each ship
the compiler as a native library of roughly **50 MB** (folio 51 MB,
imprintor 48 MB on aarch64-darwin). prawn_ex adds nothing beyond BEAM
bytecode.

## What the numbers mean, honestly

### Where Typst genuinely wins

Typst is a real typesetting engine, and it shows. Its output has
justified text, automatic hyphenation, proper line breaking, and
Libertinus by default — paragraph-for-paragraph the imprintor output
is the best-looking text of the three. If your document is *prose* —
contracts, letters, proposals, anything where text flows and pages
break where they must — Typst-based tools are the right choice, and
pretending otherwise would be silly.

### Where prawn_ex wins

Data-dense documents with a known structure: dashboards, statements,
monthly reports, anything with charts. Three reasons, all measured:

1. **Charts are built in.** Typst's chart ecosystem lives in the
   `cetz` package, and the embedded compiler inside a NIF cannot
   download packages. So a bar chart in imprintor means computing
   `x(i)` and `y(v)` yourself and placing every rect and line segment
   by hand. It works — scenario C proves it — but the same chart in
   prawn_ex is one function call.
2. **Speed and size.** 6–11 ms and kilobytes against hundreds of
   milliseconds and a 50 MB native dependency. For one report a month
   nobody cares; for thousands of documents, or for keeping a small VM
   small, it compounds.
3. **No native code.** A NIF crash takes the whole VM with it, and
   fixing a bug in the wrapper's Rust layer means a Rust toolchain,
   an upstream PR, and a release cycle. prawn_ex bugs are Elixir bugs.

### Where each wrapper stumbled

**imprintor** compiles the full template on every call — 86 ms for
even a trivial document. Fine for low volume; measurable at scale.
Data flows in cleanly through `sys.inputs`, and the Typst language is
genuinely pleasant once you accept you are writing Typst, not Elixir.

**folio** has the friendlier Elixir-first API, but that API is
Markdown, and Markdown cannot express a chart, a KPI card, or a brand
color. A fenced ` ```typst ` block in its Markdown renders as a
syntax-highlighted *code listing*, not as executed Typst — so in
scenario C folio produced tables where the charts should be. Its cold
compile on a large document was also the slowest of the three by an
order of magnitude (its excellent small-document times appear to come
from caching).

### Where prawn_ex stumbled — and what it bought

Scenario B was designed to hurt, and on the first run it did: stacked
paragraphs overlapped whenever `gap_after` was smaller than the line
height, and a table taller than the page broke to a new page once and
then ran off the bottom of it. Both were real layout bugs, both are
fixed (paragraphs advance a full line before the gap; tables paginate
by rows with the header repeated on every page), and both fixes
shipped in 0.5.0 with tests pinning them. A layout engine you own is
a layout engine you debug — that is the honest cost of this library's
approach, and the flip side of the three advantages above.

## Choosing, in one paragraph

If the document is mostly words that flow — pick a Typst wrapper, and
of the two, imprintor if you need data-driven templates, folio if
Markdown covers your needs. If the document is mostly numbers with a
designed layout — charts, cards, ledgers, brand colors — prawn_ex does
it in less code, a fraction of the time, a fraction of the size, and
with nothing native in your release. Mixing both in one application is
entirely reasonable; they solve different documents.

## Reproducing these numbers

```bash
cd bench
mix deps.get
mix run scenario_b_worst_case.exs
mix run scenario_c_charts.exs
```

The scripts generate the PDFs side by side and print sizes and
timings. Your absolute numbers will differ by machine; the ratios have
been stable everywhere we have run them.
