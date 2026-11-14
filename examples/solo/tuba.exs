# A solo for the tuba written for mx: an oom-pah bass in Bb major in short notes, then a walking
# bass under the same chords, a melody high in its range, a long note at its softest and then its
# loudest, and a run down to a held low F1.
defmodule Tuba do
  use Mx.Song, tempo: 100

  part :tuba, synth: :tuba

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [oompah: 1, walking: 1, melody: 1, extremes: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:tuba, tuba(section, pass))
    end)
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  defp tuba(section, _pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # Root on the first beat and fifth on the third, short, as an oom-pah band's bass plays.
  defp strokes(:oompah) do
    for {{root, fifth}, bar} <- Enum.with_index(chords()),
        {beat, note} <- [{0, root}, {2, fifth}],
        do: {bar * 4 + beat, note, 0.75, sustain: 0.3, release: 0.05}
  end

  # A note on every beat walking up the chord and back, held to just before the next.
  defp strokes(:walking) do
    for {{root, _fifth}, bar} <- Enum.with_index(chords()),
        {beat, up} <- [{0, 0}, {1, 4}, {2, 7}, {3, 4}],
        do: {bar * 4 + beat, root + up, 0.65, sustain: 0.8, release: 0.1}
  end

  # A melody high in its range, up to C4, as beat, note and beats held.
  defp strokes(:melody) do
    for {beat, note, held} <- [
          {0, 53, 2},
          {2, 58, 2},
          {4, 57, 1},
          {5, 55, 1},
          {6, 53, 2},
          {8, 55, 1},
          {9, 57, 1},
          {10, 58, 2},
          {12, 60, 2},
          {14, 58, 2}
        ],
        do: {beat, note, 0.6, sustain: held - 0.15, release: 0.2}
  end

  # F2 then Bb2 held at its softest, then the same at its loudest.
  defp strokes(:extremes) do
    for {vel, from} <- [{0.2, 0}, {1, 8}],
        {beat, note} <- [{0, 41}, {4, 46}],
        do: {from + beat, note, vel, sustain: 3.6, release: 0.3}
  end

  # A run down the Bb major chord in eighths from F3 to a held low F1.
  defp strokes(:ending) do
    run = [53, 50, 46, 41, 38, 34]

    Enum.with_index(run, fn note, i -> {i / 2, note, 0.75, sustain: 0.3, release: 0.05} end) ++
      [{length(run) / 2, 29, 0.85, sustain: 16 - length(run) / 2 - 0.5, release: 0.5}]
  end

  # The chords as each bar's root and fifth below it: Bb, Eb, F and Bb.
  defp chords, do: [{34, 29}, {39, 34}, {41, 36}, {34, 29}]
end
