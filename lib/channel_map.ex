defmodule Discordirc.ChannelMap do
  def discord(network, channel) do
    cmap = Application.fetch_env!(:discordirc, :channels)

    id =
      cmap
      |> Enum.filter(&(&1.ircnetwork == network and &1.ircchannel == channel))
      |> List.first()

    case id do
      x when is_map(x) ->
        {:ok, Map.get(x, :discordid)}

      nil ->
        {:error, "no mapping"}
    end
  end

  def irc(id) do
    cmap = Application.fetch_env!(:discordirc, :channels)

    channel =
      cmap
      |> Enum.filter(&(&1.discordid == id))
      |> List.first()

    case channel do
      x when is_map(x) ->
        {:ok, channel.ircnetwork, channel.ircchannel}

      nil ->
        {:error, "no mapping"}
    end
  end

  def getircchannels(network) do
    Application.fetch_env!(:discordirc, :channels)
    |> Enum.filter(&(&1.ircnetwork == network))
    |> Enum.map(& &1.ircchannel)
  end
end
