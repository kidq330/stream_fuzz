defmodule StreamFuzz.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-testing/stream_fuzz"

  def project do
    [
      app: :stream_fuzz,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      description: description(),
      docs: docs(),
      name: "StreamFuzz",
      source_url: @source_url,
      preferred_cli_env: [stream_fuzz: :test],
      dialyzer: [plt_add_apps: [:mix, :ex_unit]]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:stream_data, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Coverage-guided fuzzing for StreamData / ExUnitProperties."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE DESIGN-hypofuzz-stream-data.md .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "StreamFuzz",
      extras: ["README.md", "DESIGN-hypofuzz-stream-data.md"]
    ]
  end
end
