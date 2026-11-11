import Mx

# A solo for the organ written for mx: chords held on the quiet set over a walking bass, then the same on the loud set, and a last chord on both.

defmodule Organ do
  import Mx

  # C major, A minor, D minor and G major, a bar each.
  def chords, do: [[60, 64, 67], [57, 60, 64], [62, 65, 69], [59, 62, 67]]

  # The bass walks up each chord in quarters, an octave and more below it.
  def bass, do: [36, 40, 43, 45, 33, 36, 40, 43, 38, 41, 45, 48, 31, 35, 38, 41]

  def strokes(section) when section in [:quiet, :loud] do
    loud = if section == :loud, do: 1, else: 0

    held =
      for {chord, bar} <- Enum.with_index(chords()), note <- chord, do: {bar * 4, note, loud, 3.8}

    walking = for {note, beat} <- Enum.with_index(bass()), do: {beat, note, loud, 0.9}
    held ++ walking
  end

  def strokes(:both) do
    chord = [36, 48, 55, 64, 72]
    for loud <- [0, 1], note <- chord, do: {0, note, loud, 15}
  end

  # A pass of organ, as 16 beats.
  def organ(section, _pass) do
    notes =
      for {beat, note, loud, sustain} <- strokes(section),
          do: {beat, note(note, sustain, loud: loud)}

    at(notes, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [quiet: 2, loud: 2, both: 1, quiet: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:organ, organ(section, pass), synth: :organ)
    end)
  end
end

song(tempo: 72, music: repeat(seq(Organ.form())))
