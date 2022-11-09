defmodule Discordirc.SplitterTest do
  use ExUnit.Case
  import Discordirc.ByteSplit
  doctest Discordirc.ByteSplit

  test "split by bytes" do
    assert byte_split("test", 2) == ["te", "st"]
  end

  test "split with emoji" do
    assert byte_split("test🦀", 4) == ["test", "🦀"]
  end

  test "ircsplit without emoji" do
    lorem_ipsum =
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam lorem nunc, vestibulum ac magna et, egestas accumsan felis. " <>
        "Morbi dolor quam, venenatis in molestie ullamcorper, fringilla nec tellus. Cras viverra purus ut ante iaculis consequat. " <>
        "Donec convallis id velit id vulputate. Nullam vel libero at sem consequat dapibus non in lectus. Nunc nec lectus aliquet, " <>
        "faucibus erat eget, feugiat justo. Duis imperdiet ligula at sem consectetur, porta semper massa sagittis. Duis sit amet risus sit amet nisi lectus."

    irc_result = [
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam lorem nunc, vestibulum ac magna et, egestas accumsan felis. " <>
        "Morbi dolor quam, venenatis in molestie ullamcorper, fringilla nec tellus. Cras viverra purus ut ante iaculis consequat. " <>
        "Donec convallis id velit id vulputate. Nullam vel libero at sem consequat dapibus non in lectus. Nunc nec lectus aliquet, " <>
        "faucibus erat eget, feugiat justo. Duis imperdiet ligula at sem consectetur, porta semper massa sagittis. Duis sit amet risus",
      "sit amet nisi lectus."
    ]

    prefix = "PRIVMSG #test :"
    prefix_len = prefix |> byte_size()
    irc_after_split = ircsplit(lorem_ipsum, prefix_len)
    assert irc_after_split == irc_result

    assert Enum.map(irc_after_split, &byte_size(prefix <> &1)) |> Enum.map(&(&1 <= 512)) == [
             true,
             true
           ]
  end

  test "ircsplit with emoji" do
    lorem_ipsum =
      "Lorem 📨🐰🐇🌀🕣👻 gravida enim suspendisse vel 💵 🔷🔃🌙🍦 blandit 🌝🎌🌈 quis 🐬🔫🐟 tincidunt odio quis a morbi ipsum, " <>
        "lectus at nunc, nunc 📖🍷 morbi amet velit mattis netus est id 👭🌛 mauris id massa massa lorem feugiat et 🌃🐥👇 📴 tellus. Purus " <>
        "pulvinar sed integer ipsum, porta 📕🏆 posuere nunc mauris, elit vitae volutpat lacinia nulla et pellentesque elit 💙💝🍍📗🐛🌰 🍑 " <>
        "hendrerit sit 💴📣💁 etiam 🐅🏈 📗 🌹 curabitur purus"

    irc_result = [
      "Lorem 📨🐰🐇🌀🕣👻 gravida enim suspendisse vel 💵 🔷🔃🌙🍦 blandit 🌝🎌🌈 quis 🐬🔫🐟 tincidunt odio quis a morbi ipsum, " <>
        "lectus at nunc, nunc 📖🍷 morbi amet velit mattis netus est id 👭🌛 mauris id massa massa lorem feugiat et 🌃🐥👇 📴 tellus. Purus " <>
        "pulvinar sed integer ipsum, porta 📕🏆 posuere nunc mauris, elit vitae volutpat lacinia nulla et pellentesque elit 💙💝🍍📗🐛🌰 🍑 " <>
        "hendrerit sit 💴📣💁 etiam 🐅🏈",
      "📗 🌹 curabitur purus"
    ]

    prefix = "PRIVMSG #test :"
    prefix_len = prefix |> byte_size()
    irc_after_split = ircsplit(lorem_ipsum, prefix_len)
    assert irc_after_split == irc_result

    assert Enum.map(irc_after_split, &byte_size(prefix <> &1)) |> Enum.map(&(&1 <= 512)) == [
             true,
             true
           ]
  end

  test "ircsplit only emoji" do
    crab = "🦀"
    crabs = for _ <- 1..129, into: "", do: crab

    good_split = [
      for(_ <- 1..123, into: "", do: crab),
      for(_ <- 1..6, into: "", do: crab)
    ]

    prefix = "PRIVMSG #test :"
    prefix_len = prefix |> byte_size()

    irc_split = ircsplit(crabs, prefix_len)
    assert irc_split == good_split
    assert Enum.map(irc_split, &byte_size(prefix <> &1)) |> Enum.map(&(&1 <= 512)) == [true, true]
  end
end
