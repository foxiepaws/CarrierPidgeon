defmodule CarrierPidgeon.WebhookService do
  @moduledoc """
  This module manages the webhooks that we output
  to discord channels with
  """
  use GenServer
  require Logger
  alias Nostrum.Api, as: DiscordAPI

  defmodule State do
    defstruct hooks: nil

    def clear_old_hooks(channel_id) do
      {:ok, webhooks} = DiscordAPI.get_channel_webhooks(channel_id)

      deadhooks =
        webhooks
        |> Enum.filter(fn wh ->
          wh.user.id == Nostrum.Snowflake.dump(DiscordAPI.get_current_user!().id)
        end)

      for h <- deadhooks, do: DiscordAPI.delete_webhook(h.id, "clearing old hooks")

      :ok
    end

    def create_hook(state, channel_id, retry \\ 0) do
      avatar = Base.encode64(File.read!("priv/defaultavatar.jpg"))

      case DiscordAPI.create_webhook(
             channel_id,
             %{name: "irc relay hook", avatar: avatar},
             "irc relay hook"
           ) do
        {:ok, hook} ->
          case state.hooks do
            nil ->
              {:ok, %State{state | :hooks => %{channel_id => hook}}}

            %{} ->
              hooks = Map.put(state.hooks, channel_id, hook)
              {:ok, %State{state | :hooks => hooks}}
          end

        {:error, e} ->
          case e.response.code do
            10_003 ->
              raise "unknown channel"

            30_007 when retry < 1 ->
              clear_old_hooks(channel_id)
              create_hook(state, channel_id, retry + 1)

            30_007 when retry >= 1 ->
              raise "too many webhooks"

            40_001 ->
              raise "no permissions"

            50_035 ->
              raise "invalid form body"
          end
      end
    end

    def get_channel_hook(state, channel_id) do
      case state.hooks[channel_id] do
        nil ->
          {:ok, newstate} = create_hook(state, channel_id)
          get_channel_hook(newstate, channel_id)

        x ->
          {x, state}
      end
    end
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [%State{}], name: :WebhookService)
  end

  def init([state]) do
    {:ok, state}
  end

  # relay from an IRC channel.
  def handle_info({:irc, msgargs}, state) do
    {wh, state} = State.get_channel_hook(state, msgargs.channel_id)
    args = %{tts: false, username: msgargs.nick, avatar_url: nil, content: msgargs.content}

    try do
      DiscordAPI.execute_webhook(wh.id, wh.token, args)
    rescue
      e in MatchError ->
        Logger.warn("MatchError from nostrum workaround in place. e: #{inspect(e)}")

      e in FunctionClauseError ->
        Logger.warn("FunctionClauseError from nostrum workaround in place. #{inspect(e)}")
    end

    {:noreply, state}
  end
end
