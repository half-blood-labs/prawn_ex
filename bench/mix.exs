defmodule PrawnExBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :prawn_ex_bench,
      version: "0.1.0",
      elixir: "~> 1.16",
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # The two Typst wrappers ship precompiled NIFs, so no Rust toolchain
  # is needed to run the comparison.
  defp deps do
    [
      {:folio, "~> 0.4"},
      {:imprintor, "~> 0.6"},
      {:prawn_ex, path: ".."}
    ]
  end
end
