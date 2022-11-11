defmodule HomingPigeon.MixProject do
  use Mix.Project

  def project do
    [
      app: :homingpigeon,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [test: "test --no-start"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {HomingPigeon, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, "~> 0.4"},
      {:exirc, "~> 1.1.0"},
      {:ex_machina, "~> 2.4", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.5", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
