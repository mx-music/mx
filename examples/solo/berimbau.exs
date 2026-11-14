# A solo for the berimbau as a capoeira roda plays it: the toque of Angola with its variations,
# São Bento Pequeno, São Bento Grande speeding up, and Benguela to calm the game.
# The toques and variations are the transcriptions of Wikipedia's "Capoeira toques",
# https://en.wikipedia.org/wiki/Capoeira_toques, a bar of 4/4 each, the same strokes Lelé's list
# of toques gives, https://lelecapoeira.com/2025/capoeira-toques-updated/.
# Every toque ends its bar on two buzzed strokes, the coin resting on the wire with the gourd
# against the belly.
# The tempo and the buzzes' spacing come from "Toque-de-angola.ogg" on Wikimedia Commons, in the
# public domain: its bar of Angola lasts 2.03 seconds, 119 bpm, and its two buzzes are 0.1 seconds
# apart, about a sixteenth, closer than the transcriptions' eighths.
# In seven bars of that recording the same stroke lands within about 15 to 25 ms of where it lands
# in the others, and its peak varies by 2 to 3 dB, so each word here moves up to 0.05 beat either
# way and each stroke's vel up to 0.1, and the gourd's pace moves a little from stroke to stroke.
# The other toques keep their order from slow to fast around it: Benguela slower, São Bento
# Pequeno faster, São Bento Grande fastest and speeding up.
defmodule Berimbau do
  use Mx.Song, tempo: 120

  part :berimbau, synth: :berimbau, fx: [reverb: [room: 0.35, mix: 0.1]]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section, and the tempo each toque is played at between them.
  defp form do
    angola =
      ~w(angola angola angola variation_1 angola angola variation_2 angola angola variation_3 angola angola)a

    sections =
      [tempo(120)] ++
        angola ++
        [tempo(136)] ++
        List.duplicate(:sao_bento_pequeno, 6) ++
        [tempo(150), :sao_bento_grande, :sao_bento_grande, tempo(172, over: 64)] ++
        List.duplicate(:sao_bento_grande, 12) ++
        [tempo(108)] ++ List.duplicate(:benguela, 6)

    {music, _pass} =
      Enum.map_reduce(sections, 0, fn
        section, pass when is_atom(section) -> {pass(section, pass), pass + 1}
        change, pass -> {change, pass}
      end)

    music
  end

  defp pass(section, pass) do
    part(:berimbau, berimbau(section, pass))
  end

  # A pass of the berimbau, as 8 beats.
  defp berimbau(section, _pass) do
    hits =
      for {bar, first} <- Enum.zip(bars(section), [0, 4]),
          {beat, opts} <- strokes(bar),
          do: {first + beat, hit(opts)}

    at(hits, 8)
  end

  # Each pass is two bars.
  defp bars(:angola), do: [:angola, :angola]
  defp bars(:sao_bento_pequeno), do: [:sao_bento_pequeno, :sao_bento_pequeno]
  defp bars(:sao_bento_grande), do: [:sao_bento_grande, :sao_bento_grande]
  defp bars(:benguela), do: [:benguela, :benguela]
  defp bars(variation), do: [variation, :angola]

  # The strokes of a bar from its first beat, as {beat, options}.
  defp strokes(bar) do
    bar
    |> bar()
    |> String.split()
    |> Enum.flat_map_reduce(0, fn word, beat ->
      {cell, length} =
        if String.starts_with?(word, "[") do
          {String.trim(word, "[") |> String.trim("]"), 2}
        else
          {word, 1}
        end

      symbols = String.graphemes(cell)
      step = if cell == "xx", do: 0.25, else: length / length(symbols)

      off = between(-0.05, 0.05)

      hits =
        for {symbol, index} <- Enum.with_index(symbols),
            symbol != ".",
            at = beat + index * step,
            do: {max(at + off, 0), loosen(stroke(symbol, at))}

      {hits, beat + length}
    end)
    |> elem(0)
  end

  # A word to each beat: O strikes the open string, C the string with the coin pressed, x a buzz,
  # and . rests; a word of two splits its beat in two.
  # xx is the pair of buzzes, a sixteenth apart, and a word in brackets is a triplet over two
  # beats.
  defp bar(:angola), do: "O C . xx"
  defp bar(:sao_bento_pequeno), do: "C O . xx"
  defp bar(:sao_bento_grande), do: "C O O xx"
  defp bar(:benguela), do: "O C C xx"

  # Angola's variations each take the first bar of two, and the toque comes back in the second.
  defp bar(:variation_1), do: "O xx C xx"
  defp bar(:variation_2), do: "OO OO [OOx]"
  defp bar(:variation_3), do: "O CO CO .x"

  defp loosen(opts) do
    vel = Float.round(opts[:vel] + between(-0.1, 0.1), 2)
    Keyword.merge(opts, vel: vel, gourd: between(2, 2.6))
  end

  # The stroke on the bar's first beat leads, and the second buzz of a pair leans into the stroke
  # after it.
  defp stroke("O", beat) when beat == 0, do: [vel: 0.85]
  defp stroke("C", beat) when beat == 0, do: [vel: 0.8, coin: 1]
  defp stroke("O", _beat), do: [vel: 0.72]
  defp stroke("C", _beat), do: [vel: 0.68, coin: 1]
  defp stroke("x", beat) when beat - trunc(beat) == 0, do: [vel: 0.38, buzz: 1]
  defp stroke("x", _beat), do: [vel: 0.5, buzz: 1]
end
