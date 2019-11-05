use Mix.Config

config :libcluster,
  topologies: [
    valkyrie_cluster: [
      strategy: Elixir.Cluster.Strategy.Epmd,
      config: [
        hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]
      ]
    ]
  ]

config :husky,
  pre_commit: "./scripts/git_pre_commit_hook.sh"
