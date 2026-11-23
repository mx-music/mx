defmodule ElectricGuitar do
  @moduledoc """
  A solo for the electric guitar written for mx: open chords through A minor, F, C and G strummed
  down and left to ring, then a picked line in A minor over the open A, then muted sixteenths on
  the low strings answered by chord stabs, and a last phrase that climbs to the high D and ends
  on the low E strummed and left to ring.
  """

  use Mx.Song, tempo: 96

  part :electric_guitar, synth: :electric_guitar

  def song do
    repeat(
      form([strum: 2, line: 2, muted: 1, high: 1], fn section, %{pass: pass} ->
        part(:electric_guitar, electric_guitar(section, pass))
      end)
    )
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp electric_guitar(section, pass), do: at(notes(section, pass), 16)

  # Each chord strummed down on the one and left to ring; the second pass strums it again, up
  # and softer, on the and of two.
  defp notes(:strum, pass) do
    for {chord, bar} <- Enum.with_index(chords()),
        {beat, direction, vel, sustain} <- strums(pass),
        note <- strum(bar * 4 + beat, chord, direction, vel, sustain),
        do: note
  end

  # A line picked in eighths over the open A held low, the second pass an octave up.
  defp notes(:line, pass) do
    up = if rem(pass, 2) == 0, do: 0, else: 12

    line =
      for {note, index} <- Enum.with_index(line()),
          note != nil,
          do: {index * 0.5, note + up, 0.45, vel: if(rem(index, 2) == 0, do: 0.7, else: 0.55)}

    [{0, 45, 7.9, vel: 0.6}, {8, 45, 7.9, vel: 0.6} | line]
  end

  # The low E and A muted in sixteenths, each bar answered by a chord stab cut short.
  defp notes(:muted, _pass) do
    for bar <- 0..3,
        note <- muted_bar(bar),
        do: note
  end

  # A phrase climbing to the high D, then the low E strummed and left to ring.
  defp notes(:high, _pass) do
    climb =
      for {note, index} <- Enum.with_index([69, 72, 74, 76, 79, 81, 84, 86]),
          do: {index * 0.5, note, 0.45, vel: 0.6 + index * 0.04}

    climb ++ [{4, 86, 3.5, vel: 0.95}] ++ strum(8, [40, 47, 52, 55, 59, 64], :down, 0.9, 7.5)
  end

  defp strums(pass) when rem(pass, 2) == 0, do: [{0, :down, 0.8, 3.9}]
  defp strums(_pass), do: [{0, :down, 0.8, 1.4}, {1.5, :up, 0.5, 2.4}]

  # A strum sounds the strings one after another, 30 ms apart at this tempo, low to high going
  # down and high to low coming up.
  defp strum(beat, chord, direction, vel, sustain) do
    strings = if direction == :down, do: chord, else: Enum.reverse(chord)

    for {note, index} <- Enum.with_index(strings),
        do: {beat + index * 0.05, note, Float.round(sustain - index * 0.05, 2), vel: vel}
  end

  defp muted_bar(bar) do
    root = if rem(bar, 2) == 0, do: 40, else: 45
    stab = if rem(bar, 2) == 0, do: [52, 55, 59], else: [57, 60, 64]

    sixteenths =
      for step <- 0..9,
          do: {bar * 4 + step * 0.25, root, 0.12, vel: if(rem(step, 4) == 0, do: 0.8, else: 0.5)}

    sixteenths ++ strum(bar * 4 + 2.75, stab, :down, 0.85, 0.3)
  end

  # A minor, F, C and G, as open chords from the low string up.
  defp chords do
    [
      [45, 52, 57, 60, 64],
      [41, 48, 53, 57, 60, 65],
      [48, 52, 55, 60, 64],
      [43, 47, 50, 55, 59, 67]
    ]
  end

  # Two bars of eighths in A minor, a rest written as nil.
  defp line do
    [69, 72, 74, 72, 76, 74, 72, 69, 67, 69, 72, nil, 74, 76, 77, 76] ++
      [79, 77, 76, 74, 76, 72, 74, 69, 72, 71, 69, nil, 67, 69, nil, nil]
  end
end
