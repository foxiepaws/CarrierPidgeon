defmodule CarrierPidgeon.DiscordHandler do
  @moduledoc """
  discord bot
  """
  use Nostrum.Consumer
  alias Nostrum.Api
  alias CarrierPidgeon.ChannelMap

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def is_me_or_my_webhook(msg) do
    {:ok, me} = Api.get_current_user()

    case msg do
      %{author: %{username: u, discriminator: d}}
      when u == me.username and d == me.discriminator ->
        true

      %{webhook_id: wh} ->
        case Api.get_webhook(wh) do
          {:ok, webhook} ->
            webhook.user.id == Nostrum.Snowflake.dump(me.id)

          {:error, _e} ->
            false
        end

      _ ->
        false
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    unless is_me_or_my_webhook(msg) do
      case ChannelMap.irc(msg.channel_id) do
        {:ok, net, _} ->
          pid = String.to_atom(net)
          send(pid, {:discordmsg, msg})

        _ ->
          :ignore
      end
    end
  end

  def handle_event(_event) do
    :noop
  end
end
