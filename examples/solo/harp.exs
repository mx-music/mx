# A solo for the harp written for mx: a joropo in A minor, the bass in 3/4 under arpeggios in 6/8,
# then chords left to ring, and a last arpeggio.
defmodule Harp do
  use Mx.Song, tempo: 168

  part :harp, synth: :harp

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections = for {section, count} <- [joropo: 4, ring: 1, ending: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:harp, harp(section, pass))
    end)
  end

  # A pass of harp, as 12 beats.
  defp harp(section, pass) do
    notes =
      for {beat, note, vel, sustain} <- strokes(section, pass),
          do: {beat, note(note, sustain, vel: vel)}

    at(notes, 12)
  end

  # The bass marks the three beats of each bar; the arpeggio runs in eighths in two groups of
  # three, accented at the start of each,
  # so the two hands cross as 3/4 against 6/8.
  defp strokes(:joropo, pass) do
    for {{bass, chord}, bar} <- Enum.with_index(chords()), reduce: [] do
      notes ->
        low =
          for beat <- 0..2,
              do: {bar * 3 + beat, if(beat == 0, do: bass, else: bass + 12), 0.7, 0.9}

        shape =
          if rem(pass, 2) == 0 do
            chord ++ Enum.map(chord, &(&1 + 12))
          else
            chord ++ [hd(chord) + 12 | Enum.reverse(tl(chord))]
          end

        high =
          for {note, index} <- Enum.with_index(shape),
              do: {bar * 3 + index / 2, note, if(rem(index, 3) == 0, do: 0.75, else: 0.5), 0.9}

        notes ++ low ++ high
    end
  end

  # Each chord struck once, low to high, and left to ring under the next.
  defp strokes(:ring, _pass) do
    for {{bass, chord}, bar} <- Enum.with_index(chords()),
        {note, index} <- Enum.with_index([bass, bass + 12 | chord]),
        do: {bar * 3 + index / 4, note, 0.6, 1000}
  end

  # A minor from A2 up to E6, left to ring.
  defp strokes(:ending, _pass) do
    for {note, index} <- Enum.with_index([45, 52, 57, 60, 64, 69, 72, 76, 81, 84, 88]),
        do: {index / 4, note, 0.6, 1000}
  end

  # A minor, D minor, E seven and A minor, a bar of three beats each, with each chord's bass note.
  defp chords do
    [{45, [69, 72, 76]}, {50, [69, 74, 77]}, {52, [68, 71, 74]}, {45, [69, 72, 76]}]
  end
end
