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
    repeat(
      form([chords: 2, melody: 2, low: 1, high: 1], fn section, %{pass: pass} ->
        part(:electric_piano, electric_piano(section, pass))
      end)
    )
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp electric_piano(section, pass), do: at(notes(section, pass), 16)

  # Each chord struck softly on the one and left to ring; the second pass strikes it again on
  # the and of three.
  defp notes(:chords, pass) do
    for {chord, bar} <- Enum.with_index(chords()),
        {beat, sustain} <- strikes(pass),
        do: {bar * 4 + beat, chord, sustain, vel: 0.3}
  end

  # The chords held soft under a melody struck harder, a phrase a bar; the second pass answers
  # an octave up.
  defp notes(:melody, pass) do
    up = if rem(pass, 2) == 0, do: 0, else: 12

    chords = for {chord, bar} <- Enum.with_index(chords()), do: {bar * 4, chord, 3.9, vel: 0.25}

    melody =
      for {beat, note, sustain, vel: vel} <- melody(),
          do: {beat, [note + up], sustain, vel: vel}

    chords ++ melody
  end

  # Octaves in the left hand walking down to the low E, each answered by a soft chord.
  defp notes(:low, _pass) do
    [
      {0, [38, 50], 1.4, vel: 0.7},
      {1.5, [62, 65, 69, 72], 2.4, vel: 0.3},
      {4, [31, 43], 1.4, vel: 0.7},
      {5.5, [59, 65, 69, 71], 2.4, vel: 0.3},
      {8, [36, 48], 1.4, vel: 0.7},
      {9.5, [59, 64, 67, 71], 2.4, vel: 0.3},
      {12, [28, 40], 3.9, vel: 0.85},
      {13.5, [56, 62, 67, 71], 2.4, vel: 0.3}
    ]
  end

  # A phrase climbing in eighths to the top E, then a soft chord to end on.
  defp notes(:high, _pass) do
    climb =
      for {note, index} <- Enum.with_index([69, 72, 74, 76, 79, 81, 84, 86, 88]),
          do: {index * 0.5, [note], 0.6, vel: 0.5 + index * 0.04}

    climb ++ [{6, [88], 2, vel: 0.85}, {8, [50, 57, 60, 64, 65], 7.9, vel: 0.35}]
  end

  # D minor 9, G 13, C major 9 and A 7 with a flat ninth, voiced around middle C.
  defp strikes(pass) when rem(pass, 2) == 0, do: [{0, 3.9}]
  defp strikes(_pass), do: [{0, 2.4}, {2.5, 1.4}]

  defp chords do
    [[50, 60, 64, 65, 69], [43, 59, 64, 65, 69], [48, 59, 62, 64, 67], [45, 58, 61, 67, 70]]
  end

  defp melody do
    [
      {0, 76, 1, vel: 0.75},
      {1, 74, 0.5, vel: 0.6},
      {1.5, 72, 1.5, vel: 0.6},
      {4, 74, 1, vel: 0.75},
      {5, 77, 0.5, vel: 0.65},
      {5.5, 76, 1.5, vel: 0.6},
      {8, 79, 1.5, vel: 0.8},
      {9.5, 76, 0.5, vel: 0.6},
      {10, 74, 1.5, vel: 0.6},
      {12, 73, 1, vel: 0.75},
      {13, 76, 1, vel: 0.65},
      {14, 74, 2, vel: 0.6}
    ]
  end
end
