defmodule Discordirc.Formatter do
  alias Nostrum.Api, as: DiscordAPI

  def from_irc(nick, msg, ctcp \\ false) do
    # strip or replace IRC formatting.
    fmsg =
      msg
      |> :re.replace("\x02(.*?)\x02", "**\\g1**", [:global])
      |> :re.replace("\x02(.*)", "**\\g1**")
      |> :re.replace("\x01|\x03[0123456789]*(,[0123456789]*)?", "", [:global])

    case ctcp do
      true ->
        case fmsg do
          x when is_binary(x) -> "_#{x}_"
          x when is_list(x) -> "_#{List.to_string(x)}_"
        end

      false ->
        case fmsg do
          x when is_binary(x) -> "#{x}"
          x when is_list(x) -> "#{List.to_string(x)}"
        end
    end
  end

  defmodule DiscordUserInfo do
    defstruct id: nil, username: nil, discriminator: nil, nickname: nil

    def from_id(id, guild) do
      case DiscordAPI.get_user(id) do
        {:ok, user} ->
          case DiscordAPI.get_guild_member(guild, user.id()) do
            {:error, _} ->
              nil

            {:ok, member} ->
              %DiscordUserInfo{
                id: id,
                username: user.username,
                discriminator: user.discriminator,
                nickname: member.nick
              }
          end

        {:error, _} ->
          nil
      end
    end
  end

  defmodule DiscordChannelInfo do
    defstruct id: nil, channel: nil

    def from_id(id) do
      case DiscordAPI.get_channel(id) do
        {:ok, channel} ->
          %DiscordChannelInfo{
            id: id,
            channel: channel.name
          }

        {:error, _} ->
          nil
      end
    end
  end

  def tryreplace(s, m) do
    case m do
      %{dui: nil} ->
        s

      %{cui: nil} ->
        s

      %{str: r, dui: dui} ->
        if String.match?(s, ~r/\<\@\!(\d+)\>/) do
          if s == r do
            if is_binary(dui.nickname) do
              String.replace(s, r, "@" <> dui.nickname)
            else
              String.replace(s, r, "@" <> dui.username <> "#" <> dui.discriminator)
            end
          else
            nil
          end
        else
          s
        end

      %{str: r, cui: cui} ->
        if String.match?(s, ~r/\<#(\d+)\>/) do
          if s == r do
            String.replace(s, r, "#" <> cui.channel)
          else
            nil
          end
        else
          s
        end
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

  def fixdiscordidstrings(%{:content => content, :guild_id => guild}) do
    pattern = ~r/\<(\@\!|#)(\d+)\>/um

    matches =
      Regex.scan(pattern, content)
      |> Enum.uniq()
      |> Enum.map(fn
        [fst, "@!", lst] ->
          %{str: fst, id: lst, dui: DiscordUserInfo.from_id(String.to_integer(lst), guild)}

        [fst, "#", lst] ->
          %{str: fst, id: lst, cui: DiscordChannelInfo.from_id(String.to_integer(lst))}
      end)

    unless matches == [] do
      doallreplacements(
        Regex.split(pattern, content, include_captures: true),
        matches,
        {"", matches}
      )
    else
      content
    end
  end

  def from_discord(msg) do
    %{attachments: attachments, author: user, guild_id: guild} = msg

    usr =
      case DiscordAPI.get_guild_member(guild, user.id) do
        {:ok, %{nick: nick}} when is_binary(nick) -> nick
        _ -> "#{user.username}\##{user.discriminator}"
      end

    cpart =
      msg
      |> fixdiscordidstrings
      |> String.split("\n")

    apart =
      attachments
      |> Enum.map(& &1.url)

    messages =
      (cpart ++ apart)
      |> Enum.filter(&(&1 != ""))

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
