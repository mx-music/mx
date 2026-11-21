defmodule ElectricPiano do
  @moduledoc """
  A solo for the electric piano written for mx: soft ninth chords through D minor, G, C and A
  left to ring a bar each, then the same chords under a melody struck harder, then a bass line
  down to the low E with chords answering it, and a last phrase that climbs to the top E and
  ends on a soft chord.
  """

  use Mx.Song, tempo: 72

  part :electric_piano, synth: :electric_piano

  def song do
    repeat(form())
  end

  # The form, each of its passes a section of four bars.
  defp form do
    form([chords: 2, melody: 2, low: 1, high: 1], fn section, %{pass: pass} ->
      part(:electric_piano, electric_piano(section, pass))
    end)
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp electric_piano(section, pass) do
    notes =
      for {beat, notes, vel, sustain} <- notes(section, pass),
          do: {beat, note(notes, 0, vel: vel, sustain: sustain)}

    at(notes, 16)
  end

  # Each chord struck softly on the one and left to ring; the second pass strikes it again on
  # the and of three.
  defp notes(:chords, pass) do
    for {chord, bar} <- Enum.with_index(chords()),
        {beat, sustain} <- strikes(pass),
        do: {bar * 4 + beat, chord, 0.3, sustain}
  end

  # The chords held soft under a melody struck harder, a phrase a bar; the second pass answers
  # an octave up.
  defp notes(:melody, pass) do
    up = if rem(pass, 2) == 0, do: 0, else: 12

    chords = for {chord, bar} <- Enum.with_index(chords()), do: {bar * 4, chord, 0.25, 3.9}

    melody =
      for {beat, note, vel, sustain} <- melody(),
          do: {beat, [note + up], vel, sustain}

    chords ++ melody
  end

  # Octaves in the left hand walking down to the low E, each answered by a soft chord.
  defp notes(:low, _pass) do
    [
      {0, [38, 50], 0.7, 1.4},
      {1.5, [62, 65, 69, 72], 0.3, 2.4},
      {4, [31, 43], 0.7, 1.4},
      {5.5, [59, 65, 69, 71], 0.3, 2.4},
      {8, [36, 48], 0.7, 1.4},
      {9.5, [59, 64, 67, 71], 0.3, 2.4},
      {12, [28, 40], 0.85, 3.9},
      {13.5, [56, 62, 67, 71], 0.3, 2.4}
    ]
  end

  # A phrase climbing in eighths to the top E, then a soft chord to end on.
  defp notes(:high, _pass) do
    climb =
      for {note, index} <- Enum.with_index([69, 72, 74, 76, 79, 81, 84, 86, 88]),
          do: {index * 0.5, [note], 0.5 + index * 0.04, 0.6}

    climb ++ [{6, [88], 0.85, 2}, {8, [50, 57, 60, 64, 65], 0.35, 7.9}]
  end

  # D minor 9, G 13, C major 9 and A 7 with a flat ninth, voiced around middle C.
  defp strikes(pass) when rem(pass, 2) == 0, do: [{0, 3.9}]
  defp strikes(_pass), do: [{0, 2.4}, {2.5, 1.4}]

  defp chords do
    [[50, 60, 64, 65, 69], [43, 59, 64, 65, 69], [48, 59, 62, 64, 67], [45, 58, 61, 67, 70]]
  end

  defp melody do
    [
      {0, 76, 0.75, 1},
      {1, 74, 0.6, 0.5},
      {1.5, 72, 0.6, 1.5},
      {4, 74, 0.75, 1},
      {5, 77, 0.65, 0.5},
      {5.5, 76, 0.6, 1.5},
      {8, 79, 0.8, 1.5},
      {9.5, 76, 0.6, 0.5},
      {10, 74, 0.6, 1.5},
      {12, 73, 0.75, 1},
      {13, 76, 0.65, 1},
      {14, 74, 0.6, 2}
    ]
  end
end
