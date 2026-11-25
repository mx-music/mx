defmodule Mx.Pattern do
  @moduledoc """
  Music written as words, which `~MX` reads when the song compiles and `Mx.steps/3` gives its sounds.

  Each word lasts one step, and the pattern says nothing of what a word sounds like.
  `_` is silence, `-` holds the word before it one step longer, and a number after a colon is a word's length in steps, as in `g4:2`.
  Words joined by a slash sound together, as in `g5/b4`, and the words in brackets share one step evenly, as in `[f f]`.
  A word after `~` is not struck: the note before it glides to it and lasts through it, as in `eb2:2 ~g2:2`.
  A word after `>` is accented, as in `>h`, and `Mx.steps/3` plays it with its `accent:`.
  A length can be a fraction, as in `g4:1/3`.
  A word after `^` is a grace note, as in `b5 ^d6 c6`: it takes no step, and `Mx.steps/3` plays it just before the word after it.
  A bar line, `|`, is only for reading.
  With the modifier `s`, as in `~MX"9..5 x..."s`, each character lasts one step instead: a dot is silence, and spaces and bar lines are left out.

  A pattern is a list of cells in order, each a map of its `tokens`, none for silence, and its length in `steps`, so two patterns join with `++`.
  A cell that glides has `glide: true` as well, an accented one `accent: true`, a grace note `grace: true` and no steps, and a cell read a character to a step `char: true`.
  """

  @doc "The cells of a pattern's text, read a character to a step."
  def parse_steps(text) when is_binary(text) do
    for char <- String.graphemes(String.replace(text, ~r/[\s|]/, "")) do
      %{tokens: if(char == ".", do: [], else: [char]), steps: 1, char: true}
    end
  end

  @doc "The cells of a pattern's text, read a word to a step."
  def parse(text) when is_binary(text) do
    words =
      text
      |> String.replace(["[", "]"], &" #{&1} ")
      |> String.split()
      |> Enum.reject(&(&1 == "|"))

    case cells(words, []) do
      {cells, []} -> graced(cells)
      {_cells, ["]" | _]} -> raise ArgumentError, "a ] closes no ["
    end
  end

  # Each grace note must come before a word that is struck, or before another grace note.
  defp graced(cells) do
    cells
    |> Enum.chunk_every(2, 1, [nil])
    |> Enum.each(fn
      [%{grace: true} = grace, next] ->
        if next == nil or next.tokens == [] or Map.has_key?(next, :glide) do
          word = "^" <> Enum.join(grace.tokens, "/")

          raise ArgumentError,
                "#{word} comes before no word that is struck; a grace note leads into one"
        end

      _ ->
        :ok
    end)

    cells
  end

  defp cells([], cells), do: {Enum.reverse(cells), []}
  defp cells(["]" | _] = words, cells), do: {Enum.reverse(cells), words}

  defp cells(["[" | words], cells) do
    case cells(words, []) do
      {inner, ["]" | words]} when inner != [] ->
        total = Enum.sum(Enum.map(inner, & &1.steps))
        shared = for cell <- inner, do: %{cell | steps: cell.steps / total}
        cells(words, Enum.reverse(shared) ++ cells)

      {[], ["]" | _]} ->
        raise ArgumentError, "[ ] holds no words"

      {_inner, []} ->
        raise ArgumentError, "a [ is never closed"
    end
  end

  defp cells([">" <> accented = word | words], cells) do
    case cells([accented], []) do
      {[%{tokens: [_ | _]} = cell], []} when not is_map_key(cell, :glide) ->
        cells(words, [Map.put(cell, :accent, true) | cells])

      _ ->
        raise ArgumentError, "#{word} accents what is not struck; > marks a word that sounds"
    end
  end

  defp cells(["^" <> graced = word | words], cells) do
    case cells([graced], []) do
      {[%{tokens: [_ | _], steps: 1} = cell], []}
      when not is_map_key(cell, :glide) and not is_map_key(cell, :accent) ->
        if String.contains?(graced, ":") do
          raise ArgumentError, "#{word} takes no length; a grace note takes no step"
        end

        cells(words, [Map.put(%{cell | steps: 0}, :grace, true) | cells])

      _ ->
        raise ArgumentError, "#{word} is no grace note; ^ marks a word that sounds"
    end
  end

  defp cells([word | words], cells) do
    {name, steps} = word_length(word)

    case {name, cells} do
      {"-", [%{grace: true} = grace | _]} ->
        word = "^" <> Enum.join(grace.tokens, "/")
        raise ArgumentError, "#{word} is held by -, and a grace note takes no step"

      {"-", [held | before]} ->
        cells(words, [%{held | steps: held.steps + steps} | before])

      {rest, _} when rest in ["-", "_"] ->
        cells(words, [%{tokens: [], steps: steps} | cells])

      {"~" <> glided, _} when glided != "" ->
        cells(words, [%{tokens: String.split(glided, "/"), steps: steps, glide: true} | cells])

      _ ->
        cells(words, [%{tokens: String.split(name, "/"), steps: steps} | cells])
    end
  end

  defp written_length(written) do
    case String.split(written, "/") do
      [number] ->
        with {steps, ""} <- Float.parse(number), do: steps

      [top, bottom] ->
        with {top, ""} <- Integer.parse(top),
             {bottom, ""} when bottom > 0 <- Integer.parse(bottom),
             do: top / bottom

      _ ->
        nil
    end
  end

  defp word_length(word) do
    case String.split(word, ":") do
      [name] when name != "" ->
        {name, 1}

      [name, written] when name != "" ->
        case written_length(written) do
          steps when is_number(steps) and steps > 0 ->
            whole = trunc(steps)
            {name, if(whole == steps, do: whole, else: steps)}

          _ ->
            raise ArgumentError,
                  "#{word} takes its length as a number of steps above 0, or a fraction such as 1/3"
        end

      _ ->
        raise ArgumentError, "#{word} is not a word and its length, such as g4:2"
    end
  end
end
