defmodule Discordirc.DiscordInfo do
  @moduledoc """
  helper functions for discord text things
  """
  alias Nostrum.Api

  def get_nick_by_id(guild_id, id) do
    case Api.get_guild_member(guild_id, id) do
      {:ok, x = %{nick: nil}} ->
        "#{x.user.username}##{x.user.discriminator}"

      {:ok, %{nick: n}} ->
        n
    end
  end

  def get_username_by_id(id) do
    {:ok, %{username: u, discriminator: d}} = Api.get_user(id)
    "#{u}##{d}"
  end

  def get_channel_name_by_id(id) do
    {:ok, %{name: c}} = Api.get_channel(id)
    c
  end

  def get_role_name_by_id(guild_id, id) do
    {:ok, roles} = Api.get_guild_roles(guild_id)

    roles
    |> Enum.filter(fn %{id: i} -> i == id end)
    |> List.first()
    |> Map.get(:name)
  end
end
