defmodule CarrierPidgeon.IRC do
  @moduledoc """
  IRC bot portion
  """
  use GenServer
  require Logger
  import CarrierPidgeon.ByteSplit

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
              network: nil,
              me: nil

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
  alias ExIRC.Whois
  alias CarrierPidgeon.ChannelMap
  alias CarrierPidgeon.Formatter

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
    Client.whois(state.client, state.nick)
    for c <- state.channels, do: Client.join(state.client, c)
    {:noreply, state}
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

  def handle_info({:whois, whois = %Whois{:hostname => host}}, state) do
    case whois do
      %Whois{nick: n, user: user} when n == state.nick ->
        me = "#{state.nick}!#{user}@#{host}"
        Logger.debug("Setting host to #{me} #{inspect(whois)}")
        {:noreply, %State{state | :me => me}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:unrecognized, "396", %{args: _args}}, state) do
    Logger.debug("Received UnrealIRCD host change notification, double checking host")
    Client.whois(state.client, state.nick)
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

  def handle_info({:discordmsg, msg}, state) do
    channel = ChannelMap.irc(msg.channel_id)

    try do
      {:ok, usr, response} = Formatter.from_discord(msg)

      case channel do
        {:ok, _, chan} ->
          pfx = ":#{state.me} PRIVMSG #{chan} :" |> byte_size()
          nkl = "<#{usr}> " |> byte_size()
          prefixlen = pfx + nkl
          # irc messages can only be 512b in length 
          split_response =
            case response do
              x when is_list(x) ->
                x

              x when is_binary(x) ->
                [x]
            end
            |> Enum.map(fn x ->
              x
              |> String.split("\n")
              |> Enum.map(&ircsplit(&1, prefixlen))
              |> List.flatten()
            end)
            |> List.flatten()

          case split_response do
            x when is_binary(x) ->
              ExIRC.Client.msg(state.client, :privmsg, chan, "<#{usr}> #{x}")

            x when is_list(x) ->
              for m <- x, do: ExIRC.Client.msg(state.client, :privmsg, chan, "<#{usr}> #{m}")
          end
      end
    rescue
      e ->
        Logger.error("TODO: handle errors instead of using exception\ne: #{inspect(e)}")
    end

    {:noreply, state}
  end

  def handle_info({:discord_cmd, :kick, _users}, state) do
    {:noreply, state}
  end

  def handle_info({:discord_cmd, :ban, _users}, state) do
    {:noreply, state}
  end

  def handle_info({:discord_cmd, :mode, _modestr}, state) do
    {:noreply, state}
  end

  def handle_info({:discord_cmd, :topic, _topic}, state) do
    {:noreply, state}
  end

  # this MUST be the last handle_info.
  def handle_info(event, state) do
    Logger.debug("unknown event: inspect output: " <> inspect(event))
    {:noreply, state}
  end

  def terminate(_, state) do
    Logger.debug("Qutting...")
    Client.quit(state.client, "discordirc.ex")
    Client.stop!(state.client)
    :ok
  end
end
