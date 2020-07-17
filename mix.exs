defmodule ExSel.MixProject do
  use Mix.Project

  @version "0.0.2"
  @url "https://github.com/slapers/ex_sel"

  def project do
    [
      app: :ex_sel,
      version: @version,
      elixir: "~> 1.5",
      name: "ExSel",
      description: "A simple expression language for elixir",
      deps: deps(),
      package: package(),
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
        flags: [:race_conditions, :unknown, :unmatched_returns]
      ]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:nimble_parsec, "~> 0.6.0"},
      {:stream_data, "~> 0.1", only: :test},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    %{
      licenses: ["Apache 2"],
      maintainers: ["Stefan Lapers"],
      links: %{"GitHub" => @url}
    }
  end
end
