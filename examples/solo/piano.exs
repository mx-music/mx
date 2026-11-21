defmodule Piano do
  @moduledoc """
  A solo for the piano written for mx: its whole range, chords softly and then hard, runs over a
  bass, and its lowest and highest notes.
  """

  use Mx.Song, tempo: 84

  part :piano, synth: :piano

  def song do
    repeat(
      form([sweep: 1, soft_chords: 1, loud_chords: 1, runs: 2, extremes: 1], fn section,
                                                                                %{pass: pass} ->
        part(:piano, piano(section, pass))
      end)
    )
  end

  # A pass of piano, as 8 beats.
  defp piano(section, _pass) do
    notes =
      for {beat, notes, vel, sustain} <- strokes(section),
          do: {beat, note(notes, sustain, vel: vel)}

    at(notes, 8)
  end

  defp strokes(:sweep) do
    notes = keyboard() ++ Enum.reverse(keyboard())

    notes
    |> Enum.with_index()
    |> Enum.map(fn {note, index} -> {index * 8 / length(notes), [note], 0.6, 0.5} end)
  end

  defp strokes(:soft_chords) do
    for {chord, index} <- Enum.with_index(chords()), do: {index * 2, chord, 0.2, 1.8}
  end

  defp strokes(:loud_chords) do
    for {chord, index} <- Enum.with_index(chords()),
        do: {index * 2, Enum.map(chord, &(&1 + 12)), 0.75, 1.8}
  end

  # The bass holds each chord's root an octave down while the right hand runs up and down its
  # notes in sixteenths.
  defp strokes(:runs) do
    for {chord, index} <- Enum.with_index(chords()), step <- 0..7 do
      tones = Enum.map(chord, &(&1 + 12)) ++ Enum.map(chord, &(&1 + 24))
      run = tones ++ Enum.reverse(tones)
      beat = index * 2 + step * 0.25

      if step == 0 do
        [{beat, [hd(chord) - 12], 0.7, 1.9}, {beat, [Enum.at(run, step)], 0.55, 0.3}]
      else
        [{beat, [Enum.at(run, step)], 0.5, 0.3}]
      end
    end
    |> List.flatten()
  end

  defp strokes(:extremes) do
    [
      {0, [21], 1, 3},
      {1, [108], 1, 2.5},
      {3, [108], 0.15, 2},
      {4, [21], 0.15, 3},
      {6, [48, 55, 60, 64, 67], 0.1, 2}
    ]
  end

  # Every C, E, G and A from A0 to C8, the piano's lowest and highest notes.
  defp keyboard, do: Enum.filter(21..108, &(rem(&1, 12) in [0, 4, 7, 9]))

  # C major, A minor, F major and G major, two beats each.
  defp chords, do: [[48, 55, 60, 64], [45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59]]
end
