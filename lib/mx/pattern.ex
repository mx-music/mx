defmodule Mx.Pattern do
  @moduledoc """
  Music written as words, which `~MX` reads when the song compiles and `Mx.steps/3` gives its sounds.

  Each word lasts one step, and the pattern says nothing of what a word sounds like.
  `_` is silence, `-` holds the word before it one step longer, and a number after a colon is a word's length in steps, as in `g4:2`.
  Words joined by a slash sound together, as in `g5/b4`, and the words in brackets share one step evenly, as in `[f f]`.
  A word after `~` is not struck: the note before it glides to it and lasts through it, as in `eb2:2 ~g2:2`.
  A bar line, `|`, is only for reading.
  With the modifier `s`, as in `~MX"9..5 x..."s`, each character lasts one step instead: a dot is silence, and spaces and bar lines are left out.

  A pattern is a list of cells in order, each a map of its `tokens`, none for silence, and its length in `steps`, so two patterns join with `++`.
  A cell that glides has `glide: true` as well.
  """

  @doc "The cells of a pattern's text, read a character to a step."
  def parse_steps(text) when is_binary(text) do
    for char <- String.graphemes(String.replace(text, ~r/[\s|]/, "")) do
      %{tokens: if(char == ".", do: [], else: [char]), steps: 1}
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
      {cells, []} -> cells
      {_cells, ["]" | _]} -> raise ArgumentError, "a ] closes no ["
    end
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

  defp cells([word | words], cells) do
    {name, steps} = word_length(word)

    case {name, cells} do
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

  defp word_length(word) do
    case String.split(word, ":") do
      [name] when name != "" ->
        {name, 1}

      [name, written] when name != "" ->
        case Float.parse(written) do
          {steps, ""} when steps > 0 ->
            whole = trunc(steps)
            {name, if(whole == steps, do: whole, else: steps)}

          _ ->
            raise ArgumentError, "#{word} takes its length as a number of steps above 0"
        end

      _ ->
        raise ArgumentError, "#{word} is not a word and its length, such as g4:2"
    end
  end
end
