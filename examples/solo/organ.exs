defmodule Organ do
  @moduledoc """
  A solo for the organ written for mx: chords held on the quiet set over a walking bass, then the
  same on the loud set, and a last chord on both.
  """

  use Mx.Song, tempo: 72

  part :organ, synth: :organ

  def song do
    repeat(
      form([quiet: 2, loud: 2, both: 1, quiet: 1], fn section, %{pass: pass} ->
        part(:organ, organ(section, pass))
      end)
    )
  end

  # A pass of organ, as 16 beats.
  defp organ(section, _pass), do: at(strokes(section), 16)

  defp strokes(section) when section in [:quiet, :loud] do
    loud = if section == :loud, do: 1, else: 0

    held =
      for {chord, bar} <- Enum.with_index(chords()),
          note <- chord,
          do: {bar * 4, note, 3.8, loud: loud}

    walking = for {note, beat} <- Enum.with_index(bass()), do: {beat, note, 0.9, loud: loud}
    held ++ walking
  end

  defp strokes(:both) do
    chord = [36, 48, 55, 64, 72]
    for loud <- [0, 1], note <- chord, do: {0, note, 15, loud: loud}
  end

  # C major, A minor, D minor and G major, a bar each.
  defp chords, do: [[60, 64, 67], [57, 60, 64], [62, 65, 69], [59, 62, 67]]

  # The bass walks up each chord in quarters, an octave and more below it.
  defp bass, do: [36, 40, 43, 45, 33, 36, 40, 43, 38, 41, 45, 48, 31, 35, 38, 41]
end
