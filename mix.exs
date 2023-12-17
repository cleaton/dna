defmodule Dna.MixProject do
  use Mix.Project

  def project do
    [
      app: :dna,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :os_mon],
      mod: {Dna.Application, []},
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "config", "priv"],
      maintainers: ["Jesper Lundgren"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/cleaton/dna"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_scylla, "~> 0.5.0"},
      {:cachex, "~> 3.6"},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:benchee, "~> 1.0", only: [:bench], runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
