# Benchmarks against the Typst wrappers

The scripts behind the numbers in
[the comparison guide](../guides/typst-comparison.md). Each renders
the same document with prawn_ex, imprintor, and folio, then prints
sizes and timings and leaves the PDFs beside the script.

```bash
mix deps.get
mix run scenario_b_worst_case.exs
mix run scenario_c_charts.exs
```
