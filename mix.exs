defmodule PrawnEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :prawn_ex,
      name: "prawn_ex",
      version: "0.1.1",
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
      licenses: ["MIT"],
      links: %{
        "HexDocs" => "https://hexdocs.pm/prawn_ex",
        "GitHub" => "https://github.com/prawn-ex/prawn_ex"
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
      extras: ["README.md"],
      source_url: "https://github.com/prawn-ex/prawn_ex"
    ]
  end
end
