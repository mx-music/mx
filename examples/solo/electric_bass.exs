defmodule ElectricBass do
  @moduledoc """
  A solo for the electric bass written for mx: a funk line in E in sixteenths, short notes around
  the low E with its octave, then a walking line in quarters through D minor, G, C and A, then a
  ballad's long notes left to ring, and a last funk bar that ends on the low E.
  """

  use Mx.Song, tempo: 96

  part :electric_bass, synth: :electric_bass

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section of four bars.
  defp form do
    sections =
      for {section, count} <- [funk: 2, walk: 2, ballad: 1, ending: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:electric_bass, electric_bass(section, pass))
    end)
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp electric_bass(section, pass) do
    notes =
      for {beat, note, vel, sustain} <- notes(section, pass),
          do: {beat, note(note, 0, vel: vel, sustain: sustain)}

    at(notes, 16)
  end

  # Each bar lands hard on the low E on the one, answers with the octave and the seventh off the
  # beat, and climbs back through G, A and B; every second bar ends on a run up to the octave.
  defp notes(:funk, _pass) do
    for bar <- 0..3,
        {beat, note, vel, sustain} <- funk_bar(rem(bar, 2)),
        do: {bar * 4 + beat, note, vel, sustain}
  end

  # Quarters through the chords, a bar each: the root on the one, plucked harder, chord notes on
  # two and three, and a note a semitone from the next root on four; the second pass walks down.
  defp notes(:walk, pass) do
    lines = if rem(pass, 2) == 0, do: walk_up(), else: walk_down()

    for {bar, at} <- Enum.with_index(lines),
        {note, beat} <- Enum.with_index(bar),
        do: {at * 4 + beat, note, if(beat == 0, do: 0.8, else: 0.6), 0.9}
  end

  # Roots held a bar each and played soft, the third bar answering its root an octave up.
  defp notes(:ballad, _pass) do
    [
      {0, 36, 0.5, 3.9},
      {4, 33, 0.5, 3.9},
      {8, 29, 0.5, 1.9},
      {10, 41, 0.45, 1.9},
      {12, 31, 0.5, 3.9}
    ]
  end

  # Two funk bars, then the low E, plucked hard and left to ring.
  defp notes(:ending, _pass) do
    bars =
      for bar <- 0..1,
          {beat, note, vel, sustain} <- funk_bar(bar),
          do: {bar * 4 + beat, note, vel, sustain}

    bars ++ [{8, 28, 1.0, 7.5}]
  end

  defp funk_bar(0) do
    [
      {0, 28, 0.95, 0.4},
      {0.75, 28, 0.5, 0.1},
      {1.5, 40, 0.8, 0.15},
      {1.75, 38, 0.6, 0.15},
      {2, 28, 0.85, 0.3},
      {2.5, 31, 0.6, 0.15},
      {2.75, 33, 0.65, 0.15},
      {3.25, 35, 0.7, 0.15},
      {3.5, 38, 0.75, 0.3}
    ]
  end

  defp funk_bar(1) do
    [
      {0, 28, 0.95, 0.4},
      {0.75, 28, 0.5, 0.1},
      {1.5, 40, 0.8, 0.15},
      {1.75, 38, 0.6, 0.15},
      {2, 28, 0.85, 0.3},
      {2.75, 33, 0.65, 0.15},
      {3, 34, 0.65, 0.15},
      {3.25, 35, 0.7, 0.15},
      {3.5, 38, 0.75, 0.15},
      {3.75, 39, 0.8, 0.15}
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
