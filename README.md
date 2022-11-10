# CarrierPidgeon

Relay your discord server to irc via avian carrier. 

## Installation

you need to configure this with a dev.exs / prod.exs like such
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
  token: "YOUR TOKEN HERE",
```

## Running
```shell
$ MIX_ENV="prod" mix run --no-halt
```

if you're going to be hacking on it, or want the ability to update without restarting, I recommend you run it in iex.

```shell
$ iex -S mix
```

to update your bot while running in iex just type `recompile`.

