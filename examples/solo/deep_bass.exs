defmodule DeepBass do
  @moduledoc """
  A solo for the deep bass written for mx: a ballad's long roots walking down from C to the low
  D and back up to G, then a slow groove on A minor and D with the octave off the beat, then a
  phrase high up the neck to D sharp, its highest note, and an ending that drops through the low
  D to the low E and leaves it ringing.
  """

  use Mx.Song, tempo: 66

  part :deep_bass, synth: :deep_bass

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section of four bars.
  defp form do
    sections =
      for {section, count} <- [ballad: 2, groove: 2, high: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:deep_bass, deep_bass(section, pass))
    end)
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp deep_bass(section, pass) do
    notes =
      for {beat, note, vel, sustain} <- notes(section, pass),
          do: {beat, note(note, 0, vel: vel, sustain: sustain)}

    at(notes, 16)
  end

  # Roots held a bar each and played soft, walking down a step a bar: C, B, A and G, then F, E,
  # the low D, and G to lead into the groove.
  defp notes(:ballad, pass) do
    roots = if rem(pass, 2) == 0, do: [36, 35, 33, 31], else: [29, 28, 26, 31]

    for {root, bar} <- Enum.with_index(roots), do: {bar * 4, root, 0.5, 3.9}
  end

  # A minor and D, a bar each: the root held on the one, the octave off the beat, the fifth on
  # three and the seventh on four, then a note a semitone from the next root; the second pass
  # plucks the roots harder.
  defp notes(:groove, pass) do
    root = if rem(pass, 2) == 0, do: 0.75, else: 0.9

    for bar <- 0..3,
        {beat, note, vel, sustain} <- groove_bar(rem(bar, 2), root),
        do: {bar * 4 + beat, note, vel, sustain}
  end

  # A phrase in E minor high up the neck, rising to D sharp over B and falling back down to the
  # E an octave and a half below.
  defp notes(:high, _pass) do
    [
      {0, 52, 0.6, 1},
      {1, 55, 0.6, 0.5},
      {1.5, 57, 0.6, 0.5},
      {2, 59, 0.7, 1.5},
      {3.5, 62, 0.75, 0.5},
      {4, 63, 0.8, 1.5},
      {5.5, 59, 0.6, 0.5},
      {6, 57, 0.6, 1},
      {7, 54, 0.6, 1},
      {8, 55, 0.65, 2},
      {10, 52, 0.6, 2},
      {12, 47, 0.6, 2},
      {14, 40, 0.6, 2}
    ]
  end

  # C and B a bar each, then the low D leading into the low E, plucked hard and left to ring.
  defp notes(:ending, _pass) do
    [
      {0, 36, 0.55, 3.9},
      {4, 35, 0.55, 3.9},
      {8, 26, 0.7, 0.9},
      {9, 28, 1.0, 6.5}
    ]
  end

  defp groove_bar(0, root) do
    [
      {0, 33, root, 1.4},
      {1.5, 45, 0.55, 0.4},
      {2, 40, 0.65, 0.9},
      {3, 43, 0.6, 0.4},
      {3.5, 37, 0.6, 0.4}
    ]
  end

  defp groove_bar(1, root) do
    [
      {0, 38, root, 1.4},
      {1.5, 50, 0.55, 0.4},
      {2, 45, 0.65, 0.9},
      {3, 48, 0.6, 0.4},
      {3.5, 34, 0.6, 0.4}
    ]
  end
end
