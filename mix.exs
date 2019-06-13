defmodule Kolt.MixProject do
  use Mix.Project

  def project do
    [
      app: :kolt,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Kolt",
      source_url: "https://github.com/moskyb/kolt"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "Kolt: A Kafka Offset Lag Tracker"
  end

  defp package() do
    [
      name: "kolt",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/moskyb/kolt"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:brod, "~> 3.7"},
      {:telemetry, "~> 0.4.0"},
      {:mimic, "~> 0.3.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
