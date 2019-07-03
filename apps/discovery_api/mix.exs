defmodule DiscoveryApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_api,
      compilers: [:phoenix, :gettext | Mix.compilers()],
      version: "0.11.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: test_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      mod: {DiscoveryApi.Application, []},
      extra_applications: [:logger, :runtime_tools, :corsica, :prestige]
    ]
  end

  defp deps do
    [
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0", git: "https://github.com/ex-aws/ex_aws_s3", ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"},
      {:paddle, "~> 0.1.4"},
      {:sweet_xml, "~> 0.6"},
      {:cachex, "~> 3.0"},
      {:corsica, "~> 1.0"},
      {:cowboy, "~> 1.0"},
      {:csv, "~> 1.4.0"},
      {:credo, "~> 0.10", only: [:dev, :test, :integration], runtime: false},
      {:checkov, "~> 0.4.0", only: [:test, :integration]},
      {:distillery, "~> 2.0"},
      {:divo, "~> 1.1"},
      {:ex_json_schema, "~> 0.5.7", only: [:test, :integration]},
      {:guardian, "~> 1.2.1"},
      {:gettext, "~> 0.11"},
      {:httpoison, "~> 1.5"},
      {:faker, "~> 0.12.0"},
      {:jason, "~> 1.1"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:patiently, "~> 0.2.0"},
      {:phoenix, "~> 1.3.3"},
      {:phoenix_pubsub, "~> 1.0"},
      {:placebo, "~> 1.2.1", only: [:dev, :test]},
      {:plug_cowboy, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:prestige, "~> 0.3.4"},
      {:prometheus_plugs, "~> 1.1.1"},
      {:prometheus_phoenix, "~>1.2.0"},
      {:quantum, "~>2.3"},
      {:redix, "~> 0.9.3"},
      {:streaming_metrics, "~> 2.1.4"},
      {:smart_city_registry, "~> 2.6"},
      {:smart_city_test, "~> 0.2.4", only: [:test, :integration]},
      {:temporary_env, "~> 2.0", only: :test, runtime: false},
      {:timex, "~>3.0"},
      {:sobelow, "~> 0.8.0"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration", "test/utils"]
  defp test_paths(_), do: ["test/unit", "test/utils"]

  defp elixirc_paths(:test), do: ["test/utils", "lib"]
  defp elixirc_paths(:integration), do: ["test/utils", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
