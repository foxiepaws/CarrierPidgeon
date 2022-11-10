defmodule CarrierPidgeon do
  @moduledoc """
  Entrypoint
  """
  use Application

  alias CarrierPidgeon.IrcNetworkSupervisor
  alias CarrierPidgeon.DiscordHandler
  alias CarrierPidgeon.WebhookService

  def start(_type, _args) do
    children = [
      {DiscordHandler, []},
      {WebhookService, []},
      {IrcNetworkSupervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
