defmodule Discordirc.DiscordHandler do
  use Nostrum.Consumer
  alias Nostrum.Api
  alias Discordirc.ChannelMap

  def start_link do
    Consumer.start_link(__MODULE__)
  end


  def is_me_or_my_webhook(msg) do
    {:ok, me} = Api.get_current_user()

    is_me = msg.author.username == me.username and msg.author.discriminator == me.discriminator
    is_webhook = msg.webhook_id != nil

    is_my_webhook =
      if is_webhook do
        {:ok, wh} = Api.get_webhook(msg.webhook_id)
        wh.user.id == Nostrum.Snowflake.dump(me.id)
      else
        false
      end

    is_me or is_my_webhook
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    {:ok, me} = Api.get_current_user()

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
