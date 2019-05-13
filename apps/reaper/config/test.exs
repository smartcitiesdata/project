use Mix.Config

config :logger,
  level: :info

config :phoenix, :json_library, Jason

config :yeet,
  topic: "dead-letters"

config :kaffe,
  producer: [
    endpoints: [],
    topics: []
  ]
