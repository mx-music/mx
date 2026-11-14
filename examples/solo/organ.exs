defmodule Organ do
  @moduledoc """
  A solo for the organ written for mx: chords held on the quiet set over a walking bass, then the
  same on the loud set, and a last chord on both.
  """

  use Mx.Song, tempo: 72

  part :organ, synth: :organ

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [quiet: 2, loud: 2, both: 1, quiet: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:organ, organ(section, pass))
    end)
  end

  # A pass of organ, as 16 beats.
  defp organ(section, _pass) do
    notes =
      for {beat, note, loud, sustain} <- strokes(section),
          do: {beat, note(note, sustain, loud: loud)}

    at(notes, 16)
  end

  defp strokes(section) when section in [:quiet, :loud] do
    loud = if section == :loud, do: 1, else: 0

    held =
      for {chord, bar} <- Enum.with_index(chords()), note <- chord, do: {bar * 4, note, loud, 3.8}

    walking = for {note, beat} <- Enum.with_index(bass()), do: {beat, note, loud, 0.9}
    held ++ walking
  end

  defp strokes(:both) do
    chord = [36, 48, 55, 64, 72]
    for loud <- [0, 1], note <- chord, do: {0, note, loud, 15}
  end

  # C major, A minor, D minor and G major, a bar each.
  defp chords, do: [[60, 64, 67], [57, 60, 64], [62, 65, 69], [59, 62, 67]]

  # The bass walks up each chord in quarters, an octave and more below it.
  defp bass, do: [36, 40, 43, 45, 33, 36, 40, 43, 38, 41, 45, 48, 31, 35, 38, 41]
end
