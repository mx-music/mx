# A solo for the marimba written for mx: its whole range, a melody held with rolls over ringing
# bass bars, its warm low bars against its bright high ones, and a last chord.
defmodule Marimba do
  use Mx.Song, tempo: 80

  part :marimba, synth: :marimba

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [sweep: 1, melody: 2, low_high: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:marimba, marimba(section, pass))
    end)
  end

  # A pass of marimba, as 8 beats.
  defp marimba(section, pass) do
    notes = for {beat, note, vel} <- strokes(section, pass), do: {beat, note(note, 0, vel: vel)}
    at(notes, 8)
  end

  defp strokes(:sweep, _pass) do
    notes = keyboard() ++ Enum.reverse(keyboard())

    notes
    |> Enum.with_index()
    |> Enum.map(fn {note, index} -> {index * 8 / length(notes), note, 0.6} end)
  end

  # Two mallets roll each note of the melody, one on the note and one a sixth below it, in turn
  # every thirty-second note.
  defp strokes(:melody, pass) do
    {melody, bass} = phrase(rem(pass - 1, 2))

    rolls =
      for {beat, note, held} <- melody, step <- 0..(held * 8 - 1) do
        if rem(step, 2) == 0 do
          {beat + step / 8, note, 0.5}
        else
          {beat + step / 8, sixth_below(note), 0.4}
        end
      end

    Enum.with_index(bass, fn note, half -> {half * 4, note, 0.7} end) ++ rolls
  end

  # The same arpeggio on the low bars and then on the high ones.
  defp strokes(:low_high, _pass) do
    low = for {note, index} <- Enum.with_index([36, 40, 43, 48]), do: {index, note, 0.7}
    high = for {note, index} <- Enum.with_index([84, 88, 91, 96]), do: {4 + index, note, 0.7}
    low ++ high
  end

  defp strokes(:ending, _pass) do
    for {note, index} <- Enum.with_index([29, 36, 48, 55, 64, 72, 79, 84]),
        do: {index / 8, note, 0.65}
  end

  # Every C, E, G and A from F1 to C7, the marimba's lowest and highest bars.
  defp keyboard, do: [29 | Enum.filter(30..96, &(rem(&1, 12) in [0, 4, 7, 9]))]

  # Each phrase's notes as beat, note and beats held, with the bass bar under each half.
  defp phrase(0), do: {[{0, 76, 2}, {2, 74, 1}, {3, 72, 1}, {4, 69, 2}, {6, 72, 2}], [36, 33]}
  defp phrase(1), do: {[{0, 77, 2}, {2, 76, 1}, {3, 74, 1}, {4, 72, 4}], [29, 31]}

  # The sixth below a note in C major: a major sixth when that is in the key, or else a minor one.
  defp sixth_below(note) do
    if(rem(note - 9, 12) in [0, 2, 4, 5, 7, 9, 11], do: note - 9, else: note - 8)
  end
end
