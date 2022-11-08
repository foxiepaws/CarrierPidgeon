defmodule Discordirc.IRC do
  @moduledoc """
  IRC bot portion
  """
  use GenServer
  require Logger

  defmodule State do
    defstruct server: nil,
              ssl?: nil,
              port: nil,
              pass: nil,
              nick: nil,
              user: nil,
              name: nil,
              channels: nil,
              client: nil,
              network: nil

    def from_params(params) when is_map(params) do
      Enum.reduce(params, %State{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  alias ExIRC.Client
  alias ExIRC.SenderInfo
  alias Discordirc.ChannelMap
  alias Discordirc.Formatter
  alias Nostrum.Api, as: DiscordAPI

  def start_link(%{:network => network} = params) when is_map(params) do
    state = %State{State.from_params(params) | :channels => ChannelMap.getircchannels(network)}
    GenServer.start_link(__MODULE__, [state], name: String.to_atom(network))
  end

  def init([state]) do
    {:ok, client} = ExIRC.start_link!()
    Process.flag(:trap_exit, true)
    Client.add_handler(client, self())

    Logger.debug("connecting #{if state.ssl? do
      "ssl"
    else
      "unsecured"
    end} on #{state.network} (#{state.server} #{state.port})")

    if state.ssl? do
      Client.connect_ssl!(client, state.server, state.port)
    else
      Client.connect!(client, state.server, state.port)
    end

    {:ok, %State{state | :client => client}}
  end

  def handle_info(:logged_in, state) do
    Logger.debug("Logged in to #{state.server}:#{state.port}")
    for c <- state.channels, do: Client.join(state.client, c)
    {:noreply, state}
  end

  def ircsplit(str, pfxlen) do
    str
    |> String.split(" ")
    |> Enum.chunk_while(
      [],
      fn ele, acc ->
        if Enum.join(Enum.reverse([ele | acc]), " ") |> byte_size() > 512 - pfxlen do
          {:cont, Enum.reverse(acc), [ele]}
        else
          {:cont, [ele | acc]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
    |> Enum.map(fn x -> Enum.join(x, " ") end)
    |> Enum.map(fn x ->
      case byte_size(x) do
        n when is_integer(n) and n > 512 ->
          x
          |> String.to_charlist()
          |> Enum.chunk_every(512 - pfxlen)
          |> Enum.map(&List.to_string(&1))

        _ ->
          x
      end
    end)
    |> List.flatten()
    |> Enum.filter(&(&1 !== ""))
  end

  def discord_ircsplit(msg, nick, target) do
    pfx = "PRIVMSG #{target} :" |> byte_size()
    nkl = "<#{nick}> " |> byte_size()

    msg
    |> String.split("\n")
    |> Enum.map(&ircsplit(&1, pfx + nkl))
    |> List.flatten()
  end

  def handle_info({:discordmsg, msg}, state) do
    channel = ChannelMap.irc(msg.channel_id)
    {usr, response} = Formatter.from_discord(msg)

    case channel do
      {:ok, _, chan} ->
        # irc messages can only be 512b in length 
        split_response =
          case response do
            x when is_binary(x) ->
              discord_ircsplit(x, usr, chan)

            x when is_list(x) ->
              x
              |> Enum.map(&discord_ircsplit(&1, usr, chan))
              |> List.flatten()
          end

        case split_response do
          x when is_binary(x) ->
            ExIRC.Client.msg(state.client, :privmsg, chan, "<#{usr}> #{x}")

          x when is_list(x) ->
            for m <- x, do: ExIRC.Client.msg(state.client, :privmsg, chan, "<#{usr}> #{m}")
        end
    end

    {:noreply, state}
  end

  def handle_info({:discord_cmd, :kick, users}) do
  end

  def handle_info({:discord_cmd, :ban, users}) do
  end

  def handle_info({:discord_cmd, :mode, modestr}) do
  end

  def handle_info({:discord_cmd, :topic, topic}) do
  end

  def handle_info({:connected, server, port}, state) do
    Logger.debug("Connected to #{server}:#{port}")
    Logger.debug("Logging to #{server}:#{port} as #{state.nick}..")
    Client.logon(state.client, state.pass, state.nick, state.user, state.name)
    {:noreply, state}
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}, channel}, state) do
    discordid = ChannelMap.discord(state.network, channel)
    fmsg = Formatter.from_irc(nick, msg, false)

    case discordid do
      {:ok, x} ->
        send(
          :WebhookService,
          {:irc, %{channel_id: x, nick: "#{nick}@#{state.network}", content: fmsg}}
        )
    end

    {:noreply, state}
  end

  def handle_info({:me, msg, %SenderInfo{:nick => nick}, channel}, state) do
    discordid = ChannelMap.discord(state.network, channel)
    fmsg = Formatter.from_irc(nick, msg, true)

    case discordid do
      {:ok, x} ->
        send(
          :WebhookService,
          {:irc, %{channel_id: x, nick: "#{nick}@#{state.network}", content: fmsg}}
        )
    end

    {:noreply, state}
  end

  # lets try using the supervisor instead... 
  def handle_info(:disconnected, state) do
    Logger.debug("Disconnected, throwing self to hell.")
    {:stop, "disconnection", state}
  end

  #  def handle_info(:disconnected, state) do
  #    if state.ssl? do
  #      Client.connect_ssl!(state.client, state.server, state.port)
  #    else
  #      Client.connect!(state.client, state.server, state.port)
  #    end
  #
  #    {:noreply, state}
  #  end

  def handle_info(_event, state) do
    {:noreply, state}
  end

  def terminate(_, state) do
    Logger.debug("Qutting...")
    Client.quit(state.client, "discordirc.ex")
    Client.stop!(state.client)
    :ok
  end
end
