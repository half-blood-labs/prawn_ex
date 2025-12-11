defmodule PrawnEx do
  @moduledoc """
  Prawn-style declarative PDF generation for Elixir.

  Pure Elixir, no Chrome or HTML. Build a document spec and emit PDF 1.4 binary.

  ## Example

      PrawnEx.build("out.pdf", fn doc ->
        doc
        |> PrawnEx.set_font("Helvetica", 12)
        |> PrawnEx.text("Hello, PDF!")
        |> PrawnEx.rectangle(100, 400, 200, 50)
        |> PrawnEx.stroke()
      end)

  See module docs for `PrawnEx.Document` and `PrawnEx.Units`.
  """
end
