defmodule Andi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        AndiWeb.Endpoint,
        ecto_repo(),
        {Brook, Application.get_env(:andi, :brook)},
        Andi.DatasetCache,
        Andi.Migration.Migrations,
        {TelemetryMetricsPrometheus, metrics_config()}
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Andi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ecto_repo do
    Application.get_env(:andi, Andi.Repo)
    |> case do
      nil -> []
      _ -> Supervisor.Spec.worker(Andi.Repo, [])
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AndiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def metrics_config, do: [port: Application.get_env(:andi, :telemetry_port), metrics: Andi.TelemetryHelper.metrics()]
end
