defmodule Discordirc.DiscordHandler do
  use Nostrum.Consumer
  alias Nostrum.Api
  alias Discordirc.ChannelMap

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    unless msg.author.username == "discord-irc" and msg.author.discriminator == "8465" do
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
