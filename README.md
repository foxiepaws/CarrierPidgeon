# Discordirc

## Installation

you need to configure this with a config.exs
```elixir
import Config

config :discordirc,
  channels: [
    %{ircnetwork: "net1",
      ircchannel: "#mychannel",
      discordid: 123456789234}
  ],
  networks: [
    %{
      network: "net1",
      server: "irc.example.net",
      pass: "",
      port: 6697,
      ssl?: true,
      nick: "discordirc",
      user: "discord",
      name: "Relay bot for my discord"
    }
  ]

config :nostrum,
  # The token of your bot as a string
  token: "666",
  # The number of shards you want to run your bot under, or :auto.
  num_shards: :auto
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/discordirc](https://hexdocs.pm/discordirc).

