defmodule Dna.MixProject do
  use Mix.Project

  def project do
    [
      app: :dna,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Dna.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_scylla, git: "https://github.com/cleaton/ex_scylla.git", branch: "next"},
      {:cachex, "~> 3.6"},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:benchee, "~> 1.0", only: [:dev], runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
