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

## Running
This is still in heavy development so i haven't handled running it as
a release or anything special like that you can still run it with iex.

```shell
$ iex -S mix
```

This does have advantages, for example, if you need to upgrade your
bot you can just type `recompile` and update it without restarting.

