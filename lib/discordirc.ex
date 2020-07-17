defmodule Discordirc do
  use Application

  alias Discordirc.IRC

  def start(_type, _args) do
    import Supervisor.Spec

    ircnets =
      Application.get_env(:discordirc, :networks) |> Enum.map(fn net -> worker(IRC, [net]) end)

    children =
      ircnets ++
        [
          Discordirc.DiscordHandler
        ]

    options = [strategy: :one_for_one, name: Discordirc.Supervisor]
    Supervisor.start_link(children, options)
  end
end
