defmodule Discordirc.IRC do
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

    Client.add_handler(client, self())

    Logger.debug(
      "connecting #{
        if state.ssl? do
          "ssl"
        else
          "unsecured"
        end
      } on #{state.network} (#{state.server} #{state.port})"
    )

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

  def handle_info({:discordmsg, msg}, state) do
    channel = ChannelMap.irc(msg.channel_id)
    response = Formatter.from_discord(msg.author, msg.content)

    case channel do
      {:ok, _, chan} ->
        case response do
          x when is_binary(x) ->
            ExIRC.Client.msg(state.client, :privmsg, chan, x)

          x when is_list(x) ->
            for m <- x, do: ExIRC.Client.msg(state.client, :privmsg, chan, m)
        end
    end

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
        DiscordAPI.create_message(x, fmsg)
    end

    {:noreply, state}
  end

  def handle_info({:me, msg, %SenderInfo{:nick => nick}, channel}, state) do
    discordid = ChannelMap.discord(state.network, channel)
    fmsg = Formatter.from_irc(nick, msg, true)

    case discordid do
      {:ok, x} ->
        DiscordAPI.create_message(x, fmsg)
    end

    {:noreply, state}
  end

  def handle_info(_event, state) do
    {:noreply, state}
  end

  def terminate(_, state) do
    Logger.debug("Qutting..")
    Client.quit(state.client, "discordirc.ex")
    Client.stop!(state.client)
    :ok
  end
end
