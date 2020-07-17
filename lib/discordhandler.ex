defmodule Discordirc.DiscordHandler do
  use Nostrum.Consumer
  alias Nostrum.Api
  alias Discordirc.ChannelMap

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    {:ok, me} = Api.get_current_user()

    unless msg.author.username == me.username and msg.author.discriminator == me.discriminator do
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
