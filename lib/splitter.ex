defmodule Discordirc.ByteSplit do
  @moduledoc """
  Module that splits text by bytes, Unicode Aware.
  """
  # use 510 to \r\n newline in mind
  @irclen 510

  @doc """
  split a string into a number `bytes`, optionally subtracting a number of `hold` bytes for prefix/suffix
  """
  def byte_split(str, bytes, hold \\ 0) do
    case byte_size(str) do
      n when is_integer(n) and n > bytes ->
        str
        |> String.split("")
        |> Enum.chunk_while(
          [],
          fn ele, acc ->
            if Enum.join(Enum.reverse([ele | acc])) |> byte_size() > bytes - hold do
              {:cont, Enum.reverse(acc), [ele]}
            else
              {:cont, [ele | acc]}
            end
          end,
          fn
            [] -> {:cont, []}
            acc -> {:cont, Enum.reverse(acc), []}
          end
        )
        |> Enum.map(&Enum.join(&1))

      _ ->
        str
    end
  end

  def ircsplit(str, pfxlen) do
    str
    |> String.split(" ")
    |> Enum.chunk_while(
      [],
      fn ele, acc ->
        if Enum.join(Enum.reverse([ele | acc]), " ") |> byte_size() > @irclen - pfxlen do
          {:cont, Enum.reverse(acc), [ele]}
        else
          {:cont, [ele | acc]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
    |> Enum.map(fn x -> Enum.join(x, " ") end)
    |> Enum.map(fn x ->
      case byte_size(x) do
        n when is_integer(n) and n > @irclen - pfxlen ->
          byte_split(x, @irclen - pfxlen)

        _ ->
          x
      end
    end)
    |> List.flatten()
    |> Enum.filter(&(&1 !== ""))
  end
end
