defmodule Discordirc.IrcNetworkSupervisor do
  @moduledoc """
  Supervises all of the IRC networks.
  """

  use Supervisor

  alias Discordirc.IRC

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    networks =
      Application.get_env(:discordirc, :networks)
      |> Enum.map(&%{start: {IRC, :start_link, [&1]}, id: &1.network})

    Supervisor.init(networks, strategy: :one_for_one)
  end
end
