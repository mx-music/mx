defmodule Xylophone do
  @moduledoc """
  A solo for the xylophone written for mx: fast runs over two octaves, a note struck again and
  again as a melody moves over it, its brightest bars, and a run to its top note.
  """

  use Mx.Song, tempo: 126

  part :xylophone, synth: :xylophone

  def song do
    repeat(
      form([runs: 2, repeats: 1, bright: 1, ending: 1], fn section, %{pass: pass} ->
        part(:xylophone, xylophone(section, pass))
      end)
    )
  end

  # A pass of xylophone, as 8 beats.
  defp xylophone(section, pass), do: at(strokes(section, pass), 8)

  # Sixteenths up two octaves from a starting note and back down, the second pass a fifth higher.
  defp strokes(:runs, pass) do
    from = Enum.find_index(scale(), &(&1 == 72 + 7 * pass))
    up = Enum.slice(scale(), from, 15)
    notes = up ++ tl(Enum.reverse(up)) ++ [hd(up)]

    notes
    |> Enum.with_index()
    |> Enum.map(fn {note, index} ->
      {index / 4, note, 0, vel: if(rem(index, 4) == 0, do: 0.8, else: 0.6)}
    end)
  end

  # G5 struck every sixteenth, louder on the beat, while a melody on the other mallet moves under
  # it each beat.
  defp strokes(:repeats, _pass) do
    melody = [76, 77, 76, 74, 72, 74, 76, 72]

    repeated =
      for index <- 0..31, do: {index / 4, 79, 0, vel: if(rem(index, 4) == 0, do: 0.75, else: 0.5)}

    repeated ++ Enum.with_index(melody, fn note, beat -> {beat, note, 0, vel: 0.7} end)
  end

  # A melody in eighths on the top two octaves.
  defp strokes(:bright, _pass) do
    melody = [96, 100, 103, 100, 98, 96, 93, 91, 93, 96, 98, 100, 103, 105, 103, 100]
    Enum.with_index(melody, fn note, index -> {index / 2, note, 0, vel: 0.7} end)
  end

  # A run up the scale in thirty-seconds to C8, the top bar, and the last C struck in three
  # octaves at once.
  defp strokes(:ending, _pass) do
    run = Enum.filter(scale(), &(&1 >= 84))
    rising = Enum.with_index(run, fn note, index -> {index / 8, note, 0, vel: 0.6} end)
    last = length(run) / 8
    rising ++ [{last, 108, 0, vel: 0.9}] ++ Enum.map([72, 84, 96], &{last + 1, &1, 0, vel: 0.9})
  end

  # The C major scale from F4, the xylophone's lowest bar, to B7, a bar below its highest.
  defp scale, do: Enum.filter(65..107, &(rem(&1, 12) in [0, 2, 4, 5, 7, 9, 11]))
end
