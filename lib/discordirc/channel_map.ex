defmodule Discordirc.ChannelMap do
  @moduledoc """
  maps discord channels to irc channels
  """
  def discord(network, channel) do
    id =
      Application.fetch_env!(:discordirc, :channels)
      |> Enum.filter(&(&1.ircnetwork == network and &1.ircchannel == channel))
      |> List.first()

    case id do
      %{discordid: discordid} ->
        {:ok, discordid}

      _ ->
        {:error, "no mapping"}
    end
  end

  def irc(id) do
    channel =
      Application.fetch_env!(:discordirc, :channels)
      |> Enum.filter(&(&1.discordid == id))
      |> List.first()

    case channel do
      %{ircnetwork: net, ircchannel: chan} ->
        {:ok, net, chan}

      _ ->
        {:error, "no mapping"}
    end
  end

  def getircchannels(network) do
    Application.fetch_env!(:discordirc, :channels)
    |> Enum.filter(&(&1.ircnetwork == network))
    |> Enum.map(& &1.ircchannel)
  end
end
