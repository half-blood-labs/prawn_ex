defmodule PrawnEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :prawn_ex,
      name: "prawn_ex",
      version: "0.1.0",
      elixir: "~> 1.16",
      description:
        "Prawn-style declarative PDF generation for Elixir. Pure Elixir, no Chrome or HTML.",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
