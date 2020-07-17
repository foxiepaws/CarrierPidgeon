defmodule Discordirc.Formatter do
  alias Nostrum.Api, as: DiscordAPI

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

  defmodule DiscordUserInfo do
    defstruct id: nil, username: nil, discriminator: nil, nickname: nil

    def from_id(id) do
      {:ok, user} = DiscordAPI.get_user(id)
      # currently we'll just use the first guild we're connected to to resolve nicks.
      # TODO: implement mutli-guild functionality
      g = DiscordAPI.get_current_user_guilds!() |> List.first()
      {:ok, member} = DiscordAPI.get_guild_member(g.id(), user.id())

      %DiscordUserInfo{
        id: id,
        username: user.username,
        discriminator: user.discriminator,
        nickname: member.nick
      }
    end
  end

  def tryreplace(s, m) do
    pattern = ~r/\<\@\!(\d+)\>/um
    dui = m[:dui]
    r = m[:str]

    if String.match?(s, pattern) do
      if s == r do
        if is_binary(dui.nickname) do
          String.replace(s, r, dui.nickname)
        else
          String.replace(s, r, dui.username <> "#" <> dui.discriminator)
        end
      else
        nil
      end
    else
      s
    end
  end

  def doallreplacements(split, matches, acc) do
    [shead | stail] = split
    {str, [m | mtail]} = acc

    s = tryreplace(shead, m)

    if is_nil(s) do
      doallreplacements(split, matches, {str, mtail})
    else
      if stail == [] do
        str <> s
      else
        doallreplacements(stail, matches, {str <> s, matches})
      end
    end
  end

  def fixdiscordidstrings(content, bare \\ false) do
    pattern = ~r/\<\@\!(\d+)\>/um

    matches =
      Regex.scan(pattern, content)
      |> Enum.uniq()
      |> Enum.map(fn x ->
        [
          str: List.first(x),
          id: List.last(x),
          dui: DiscordUserInfo.from_id(String.to_integer(List.last(x)))
        ]
      end)

    unless matches == [] do
      if bare do
        doallreplacements(
          Regex.split(pattern, content, include_captures: true),
          matches,
          {"", matches}
        )
      else
        doallreplacements(
          Regex.split(pattern, content, include_captures: true),
          matches,
          {"@", matches}
        )
      end
    else
      content
    end
  end

  def from_discord(user, msg) do
    usr = "#{user.username}\##{user.discriminator}"

    messages =
      msg
      |> String.split("\n")
      |> Enum.map(&fixdiscordidstrings(&1))

    # discord may give... many lines. split and format.
    case Enum.count(messages) do
      0 ->
        "<#{usr}> #{messages[0]}"

      _ ->
        messages
        |> Enum.map(fn m -> "<#{usr}> #{m}" end)
    end
  end
end
