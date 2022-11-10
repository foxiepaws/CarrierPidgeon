defmodule Discordirc do
  @moduledoc """
  Entrypoint
  """
  use Application

  alias Discordirc.IrcNetworkSupervisor
  alias Discordirc.DiscordHandler
  alias Discordirc.WebhookService

  def start(_type, _args) do
    children = [
      {DiscordHandler, []},
      {WebhookService, []},
      {IrcNetworkSupervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
