defmodule HomingPigeon do
  @moduledoc """
  Entrypoint
  """
  use Application

  alias HomingPigeon.IrcNetworkSupervisor
  alias HomingPigeon.DiscordHandler
  alias HomingPigeon.WebhookService

  def start(_type, _args) do
    children = [
      {DiscordHandler, []},
      {WebhookService, []},
      {IrcNetworkSupervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
