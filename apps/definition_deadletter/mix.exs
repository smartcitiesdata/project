defmodule DefinitionDeadletter.MixProject do
  use Mix.Project

  def project do
    [
      app: :definition_deadletter,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev]}
    ]
  end
end
