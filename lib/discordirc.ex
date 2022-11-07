defmodule Discordirc do
  @moduledoc """
  Entrypoint
  """
  use Application

  alias Discordirc.IRC

  def start(_type, _args) do
    import Supervisor.Spec

    ircnets =
      Application.get_env(:discordirc, :networks)
      |> Enum.map(fn net -> worker(IRC, [net], id: net.network) end)

    children =
      ircnets ++
        [
          Discordirc.DiscordHandler,
          Discordirc.WebhookService
        ]

    options = [strategy: :one_for_one, name: Discordirc.Supervisor]
    Supervisor.start_link(children, options)
  end
end
