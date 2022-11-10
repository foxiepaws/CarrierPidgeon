import Config

config :carrierpidgeon,
  channels: [
  ],
  networks: [
  ]

config :nostrum,
  # The token of your bot as a string
  token: "",
  # The number of shards you want to run your bot under, or :auto.
  num_shards: :auto,
  gateway_intents: :all


import_config "#{config_env()}.exs"
