defmodule FaktoryWorker.MixProject do
  use Mix.Project

  def project do
    [
      app: :faktory_worker,
      version: "0.1.0",
      elixir: "~> 1.8",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:broadway, "~> 0.3.0"},
      {:certifi, "~> 2.5"},
      {:ex_doc, "~> 0.20.0", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:jason, "~> 1.1"},
      {:poolboy, "~> 1.5"},
      {:mox, "~> 0.5", only: :test}
    ]
  end

  defp description do
    "A Faktory worker implementation for Elixir"
  end

  defp package do
    [
      name: :faktory_worker,
      maintainers: ["Stuart Welham", "John Griffin", "Peter Brown"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/SeatedInc/faktory_worker"}
    ]
  end
end
