defmodule Discordirc.WebhookService do
  use GenServer
  require Logger
  alias Nostrum.Api, as: DiscordAPI
  alias Nostrum.Cache, as: DiscordCache
  alias Nostrum.Error.ApiError

  defmodule State do
    defstruct hooks: nil

    def clear_old_hooks(channel_id) do
      {:ok, webhooks} = DiscordAPI.get_channel_webhooks(channel_id)

      webhooks
      |> Enum.filter(fn wh ->
        wh.user.id == Nostrum.Snowflake.dump(DiscordAPI.get_current_user!().id)
      end)
      |> Enum.map(&DiscordAPI.delete_webhook(&1.id, "clearing old hooks"))

      :ok
    end

    def create_hook(state, channel_id, retry \\ 0) do
      avatar = Base.encode64(File.read!("defaultavatar.jpg"))

      case DiscordAPI.create_webhook(
             channel_id,
             %{name: "discordirc hook", avatar: avatar},
             "discordirc proxy hook"
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
            10003 ->
              raise "unknown channel"

            30007 ->
              if retry < 1 do
                clear_old_hooks(channel_id)
                create_hook(state, channel_id, retry + 1)
              else
                raise "too many webhooks"
              end

            40001 ->
              raise "no permissions"
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
        Logger.warn("MatchError from nostrum workaround in place.")

      e in FunctionClauseError ->
        Logger.warn("FunctionClauseError from nostrum workaround in place.")
    end

    {:noreply, state}
  end
end
