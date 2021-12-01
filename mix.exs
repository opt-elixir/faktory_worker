defmodule FaktoryWorker.MixProject do
  use Mix.Project

  def project do
    [
      app: :faktory_worker,
      version: "1.6.0",
      elixir: "~> 1.8",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :ssl, :logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:broadway, "~> 1.0.0"},
      {:certifi, "~> 2.5"},
      {:excoveralls, "~> 0.10", only: :test},
      {:jason, "~> 1.1"},
      {:poolboy, "~> 1.5"},
      {:telemetry, "~> 0.4.0 or ~> 1.0"},
      {:ex_doc, "~> 0.26.0", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp docs() do
    [
      name: "Faktory Worker",
      main: "faktory-worker",
      extras: doc_extras(),
      source_url: "https://github.com/SeatedInc/faktory_worker"
    ]
  end

  defp doc_extras() do
    [
      "README.md": [filename: "faktory-worker"],
      "docs/configuration.md": [title: "Configuration"],
      "docs/logging.md": [title: "Logging"],
      "docs/sandbox-testing.md": [title: "Sandbox Testing"]
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
