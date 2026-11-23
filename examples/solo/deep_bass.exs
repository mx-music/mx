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
    repeat(
      form([ballad: 2, groove: 2, high: 1, ending: 1], fn section, %{pass: pass} ->
        part(:deep_bass, deep_bass(section, pass))
      end)
    )
  end

  # A pass of the form as its 16 beats: each note at its beat, lasting its sustain.
  defp deep_bass(section, pass), do: at(notes(section, pass), 16)

  # Roots held a bar each and played soft, walking down a step a bar: C, B, A and G, then F, E,
  # the low D, and G to lead into the groove.
  defp notes(:ballad, pass) do
    roots = if rem(pass, 2) == 0, do: [36, 35, 33, 31], else: [29, 28, 26, 31]

    for {root, bar} <- Enum.with_index(roots), do: {bar * 4, root, 3.9, vel: 0.5}
  end

  # A minor and D, a bar each: the root held on the one, the octave off the beat, the fifth on
  # three and the seventh on four, then a note a semitone from the next root; the second pass
  # plucks the roots harder.
  defp notes(:groove, pass) do
    root = if rem(pass, 2) == 0, do: 0.75, else: 0.9

    for bar <- 0..3,
        {beat, note, sustain, vel: vel} <- groove_bar(rem(bar, 2), root),
        do: {bar * 4 + beat, note, sustain, vel: vel}
  end

  # A phrase in E minor high up the neck, rising to D sharp over B and falling back down to the
  # E an octave and a half below.
  defp notes(:high, _pass) do
    [
      {0, 52, 1, vel: 0.6},
      {1, 55, 0.5, vel: 0.6},
      {1.5, 57, 0.5, vel: 0.6},
      {2, 59, 1.5, vel: 0.7},
      {3.5, 62, 0.5, vel: 0.75},
      {4, 63, 1.5, vel: 0.8},
      {5.5, 59, 0.5, vel: 0.6},
      {6, 57, 1, vel: 0.6},
      {7, 54, 1, vel: 0.6},
      {8, 55, 2, vel: 0.65},
      {10, 52, 2, vel: 0.6},
      {12, 47, 2, vel: 0.6},
      {14, 40, 2, vel: 0.6}
    ]
  end

  # C and B a bar each, then the low D leading into the low E, plucked hard and left to ring.
  defp notes(:ending, _pass) do
    [
      {0, 36, 3.9, vel: 0.55},
      {4, 35, 3.9, vel: 0.55},
      {8, 26, 0.9, vel: 0.7},
      {9, 28, 6.5, vel: 1.0}
    ]
  end

  defp groove_bar(0, root) do
    [
      {0, 33, 1.4, vel: root},
      {1.5, 45, 0.4, vel: 0.55},
      {2, 40, 0.9, vel: 0.65},
      {3, 43, 0.4, vel: 0.6},
      {3.5, 37, 0.4, vel: 0.6}
    ]
  end

  defp groove_bar(1, root) do
    [
      {0, 38, 1.4, vel: root},
      {1.5, 50, 0.4, vel: 0.55},
      {2, 45, 0.9, vel: 0.65},
      {3, 48, 0.4, vel: 0.6},
      {3.5, 34, 0.4, vel: 0.6}
    ]
  end
end
