# Run with: mix run scripts/gen_demo.exs
# Opens or save a demo PDF (path shown in output).

path = Path.join(System.tmp_dir!(), "prawn_ex_demo.pdf")

:ok =
  PrawnEx.build(path, fn doc ->
    doc
    |> PrawnEx.set_font("Helvetica", 16)
    |> PrawnEx.text_at({100, 750}, "PrawnEx Demo")
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({100, 700}, "Pure Elixir PDF – no Chrome, no HTML.")
    |> PrawnEx.rectangle(100, 550, 400, 80)
    |> PrawnEx.stroke()
    |> PrawnEx.text_at({120, 600}, "A rectangle and some text.")
    |> PrawnEx.line({100, 500}, {500, 500})
    |> PrawnEx.stroke()
  end)

IO.puts("Demo PDF written to: #{path}")
IO.puts("Open it with your PDF viewer.")
