# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :prestige, base_url: "http://kdp-kubernetes-data-platform-presto.kdp:8080"

# Configures the endpoint
config :discovery_api, DiscoveryApiWeb.Endpoint,
  secret_key_base: "7Qfvr6quFJ6Qks3FGiLMnm/eNV8K66yMVpkU46lCZ2rKj0YR9ksjxsB+SX3qHZre",
  render_errors: [view: DiscoveryApiWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: DiscoveryApi.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [DiscoveryApiWeb.Endpoint.Instrumenter],
  http: [port: 4000]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :discovery_api,
  collector: StreamingMetrics.PrometheusMetricCollector

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
