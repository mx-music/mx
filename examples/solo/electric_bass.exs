defmodule ElectricBass do
  @moduledoc """
  A solo for the electric bass written for mx: a funk line in E in sixteenths around the low E
  with its octave, each note held until the next, then a walking line in quarters through D minor,
  G, C and A, then a ballad's long notes left to ring, and a last funk bar that ends on the low E.
  """

  use Mx.Song, tempo: 96

  part :electric_bass, synth: :electric_bass

  def song do
    repeat(
      form([funk: 2, walk: 2, ballad: 1, ending: 1], fn section, %{pass: pass} ->
        part(:electric_bass, electric_bass(section, pass))
      end)
    )
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp electric_bass(section, pass), do: at(notes(section, pass), 16)

  # Each bar lands hard on the low E on the one, answers with the octave and the seventh off the
  # beat, and climbs back through G, A and B; every second bar ends on a run up to the octave.
  defp notes(:funk, _pass) do
    for bar <- 0..3,
        {beat, note, sustain, vel: vel} <- funk_bar(rem(bar, 2)),
        do: {bar * 4 + beat, note, sustain, vel: vel}
  end

  # Quarters through the chords, a bar each: the root on the one, plucked harder, chord notes on
  # two and three, and a note a semitone from the next root on four; the second pass walks down.
  defp notes(:walk, pass) do
    lines = if rem(pass, 2) == 0, do: walk_up(), else: walk_down()

    for {bar, at} <- Enum.with_index(lines),
        {note, beat} <- Enum.with_index(bar),
        do: {at * 4 + beat, note, 0.9, vel: if(beat == 0, do: 0.8, else: 0.6)}
  end

  # Roots held a bar each and played soft, the third bar answering its root an octave up.
  defp notes(:ballad, _pass) do
    [
      {0, 36, 3.9, vel: 0.5},
      {4, 33, 3.9, vel: 0.5},
      {8, 29, 1.9, vel: 0.5},
      {10, 41, 1.9, vel: 0.45},
      {12, 31, 3.9, vel: 0.5}
    ]
  end

  # Two funk bars, then the low E, plucked hard and left to ring.
  defp notes(:ending, _pass) do
    bars =
      for bar <- 0..1,
          {beat, note, sustain, vel: vel} <- funk_bar(bar),
          do: {bar * 4 + beat, note, sustain, vel: vel}

    bars ++ [{8, 28, 7.5, vel: 1.0}]
  end

  defp funk_bar(0) do
    [
      {0, 28, 0.75, vel: 0.95},
      {0.75, 28, 0.75, vel: 0.5},
      {1.5, 40, 0.25, vel: 0.8},
      {1.75, 38, 0.25, vel: 0.6},
      {2, 28, 0.5, vel: 0.85},
      {2.5, 31, 0.25, vel: 0.6},
      {2.75, 33, 0.5, vel: 0.65},
      {3.25, 35, 0.25, vel: 0.7},
      {3.5, 38, 0.5, vel: 0.75}
    ]
  end

  defp funk_bar(1) do
    [
      {0, 28, 0.75, vel: 0.95},
      {0.75, 28, 0.75, vel: 0.5},
      {1.5, 40, 0.25, vel: 0.8},
      {1.75, 38, 0.25, vel: 0.6},
      {2, 28, 0.75, vel: 0.85},
      {2.75, 33, 0.25, vel: 0.65},
      {3, 34, 0.25, vel: 0.65},
      {3.25, 35, 0.25, vel: 0.7},
      {3.5, 38, 0.25, vel: 0.75},
      {3.75, 39, 0.25, vel: 0.8}
    ]
  end

  # D minor, G, C and A: each bar ends a semitone above or below the next root.
  defp walk_up do
    [[38, 41, 45, 44], [43, 47, 50, 49], [48, 52, 55, 46], [45, 49, 52, 39]]
  end

  defp walk_down do
    [[38, 36, 33, 32], [31, 35, 38, 37], [36, 40, 43, 34], [33, 37, 40, 39]]
  end
end
