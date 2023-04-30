import Config

config :dna, :cluster, "dev"
config :dna, :scylla,
  known_nodes: "127.0.0.1:9042",
  keyspace: "dna"

import_config "#{config_env()}.exs"
