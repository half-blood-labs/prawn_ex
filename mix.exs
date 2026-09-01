defmodule PrawnEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :prawn_ex,
      name: "prawn_ex",
      version: "0.6.0",
      elixir: "~> 1.16",
      description:
        "Prawn-style declarative PDF generation for Elixir. Pure Elixir, no Chrome or HTML.",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  defp package do
    [
      # Hex's default file set has no idea about guides/; without this
      # the comparison page would 404 on hexdocs.
      files: ~w(lib guides mix.exs README.md LICENSE*),
      licenses: ["MIT"],
      links: %{
        "HexDocs" => "https://hexdocs.pm/prawn_ex",
        "GitHub" => "https://github.com/half-blood-labs/prawn_ex"
      }
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "guides/typst-comparison.md"],
      source_url: "https://github.com/half-blood-labs/prawn_ex"
    ]
  end
end
