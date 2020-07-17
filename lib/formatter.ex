defmodule Discordirc.Formatter do
  def from_irc(nick, msg) do
    from_irc(nick, msg, false)
  end

  def from_irc(nick, msg, ctcp) do
    # strip or replace IRC formatting.
    fmsg =
      msg
      |> :re.replace("\x02(.*?)\x02", "**\\g1**", [:global])
      |> :re.replace("\x02(.*)", "**\\g1**")
      |> :re.replace("\x01|\x03[0123456789]*(,[0123456789]*)?", "", [:global])

    case ctcp do
      true ->
        case fmsg do
          x when is_binary(x) -> "\\* #{nick} _#{x}_"
          x when is_list(x) -> "\\* #{nick} _#{List.to_string(x)}_"
        end

      false ->
        case fmsg do
          x when is_binary(x) -> "<#{nick}> #{x}"
          x when is_list(x) -> "<#{nick}> #{List.to_string(x)}"
        end
    end
  end

  def from_discord(user, msg) do
    usr = "#{user.username}\##{user.discriminator}"
    messages = String.split(msg, "\n")

    # discord may give... many lines. split and format.
    case Enum.count(messages) do
      0 ->
        "<#{usr}> #{messages[0]}"

      x ->
        messages
        |> Enum.map(fn m -> "<#{usr}> #{m}" end)
    end
  end
end
