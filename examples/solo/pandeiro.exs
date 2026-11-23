defmodule Pandeiro do
  @moduledoc """
  The pandeiro on its own, playing the line it has under the choro of examples/choro.exs: three
  strains of sixteen bars in 2/4, in the order A A B B A C C A.
  Under A it plays the choro groove, the thumb's bass muted on each bar's first beat and open on
  its second, with the wrist and the fingertips rocking between them; under B it leans to samba,
  with a slap before the second beat; in C it strikes two accented basses and a slap every other
  phrase.
  A phrase of four bars ends on a slap and a push into the beat, and a strain on a roll.
  A beat is a quarter note, so a strain is 32 beats.
  """

  use Mx.Song, tempo: 104

  part :pandeiro_thumb, synth: :pandeiro_thumb, defaults: [amp: 0.8]
  part :pandeiro_jingles, synth: :pandeiro_jingles, defaults: [amp: 0.8]
  part :pandeiro_heel, synth: :pandeiro_heel, defaults: [amp: 0.8]
  part :pandeiro_slap, synth: :pandeiro_slap, defaults: [amp: 0.8]

  # Each pass plays one strain, in the order of the form.
  def song do
    repeat(form([a: 2, b: 2, a: 1, c: 2, a: 1], &strain/2))
  end

  defp strain(section, _) do
    together(
      for synth <- [:pandeiro_thumb, :pandeiro_jingles, :pandeiro_heel, :pandeiro_slap] do
        part(synth, pandeiro(section, synth))
      end
    )
  end

  # A strain of one of the pandeiro's strokes.
  defp pandeiro(section, synth) do
    entries =
      for {beat, ^synth, vel, muted} <- pandeiro_strokes(section),
          do: {beat, hit(vel: vel, muted: muted)}

    at(entries, 32)
  end

  # The pandeiro, written as its hand's rocking, a sixteenth to each cell, as examples/odeon.exs
  # writes it.
  # T is the thumb's bass with the head muted by the holding hand and O the open one, o the
  # fingertips' open bass, h the wrist and f the fingertips on the rim, S a slap and R a roll;
  # a dot is a ghost note, where the drum rocks and nothing strikes, _ is silence, > accents a
  # cell, and several strokes in a cell split it evenly.
  # Each phrase is two bars and its loudness: the choro groove, a slap and a push into the beat
  # where a phrase of four bars ends, and a roll into the strain that follows.
  defp pandeiro_phrases(:a) do
    [
      {"T f h f  O f h f  T f h f  O f h o", 0.8},
      {"T f h f  O ff h f  T f >h f  O f h o", 0.85},
      {"T f h f  O f h f  T f h f  O f h o", 0.8},
      {"T f >h f  O f h o  T o h S  O o h f", 0.9},
      {"T f h f  O f h f  T f h f  O f h o", 0.85},
      {"T f h f  O ff h f  T f >h f  O f h o", 0.9},
      {"T f h f  O f h f  T f h f  O f h o", 0.85},
      {"T f >h f  O f h o  >S _ . f  R R R R", 0.9}
    ]
  end

  # Under B it leans to samba, a slap before the second beat and the fingertips' bass pushing into
  # each beat.
  defp pandeiro_phrases(:b) do
    [
      {"T f h S  O f h o  T f h o  O f h o", 0.75},
      {"T f h S  O ff h o  T f h o  O f h o", 0.8},
      {"T f h S  O f h o  T f h o  O f h o", 0.8},
      {"T f >h f  O f h o  T o h S  O o h f", 0.85},
      {"T f h S  O f h o  T f h o  O f h o", 0.8},
      {"T f h S  O ff h o  T f h o  O f h o", 0.85},
      {"T f >h f  O f h o  T o h S  O o >S o", 0.9},
      {"T f h f  O f h f  >S _ . f  R R R R", 0.85}
    ]
  end

  # In the trio it strikes the tutti chords with the regional: the open bass, a slap a sixteenth
  # before the second beat, and the open bass on its off-beat.
  defp pandeiro_phrases(:c) do
    groove = "T f h f  O f h f"
    hit = ">O _ . >S  _ . >O f"

    [
      {groove <> "  " <> hit, 0.9},
      {groove <> "  " <> hit, 0.9},
      {"T f h f  O f h o  T f h f  O f h o", 0.85},
      {"T f >h f  O f h o  T o h S  O o h f", 0.9},
      {groove <> "  " <> hit, 0.9},
      {groove <> "  " <> hit, 0.95},
      {"T f h f  O f h o  " <> hit, 0.95},
      {"T f h S  O f h o  >O _ . >S  R R R R", 0.9}
    ]
  end

  # A letter's synth, whether the holding hand mutes the head, and its vel; a ghost note and a
  # roll are the fingertips on the jingles, very soft.
  defp stroke("T"), do: {:pandeiro_thumb, 1, 0.6}
  defp stroke("O"), do: {:pandeiro_thumb, 0, 0.75}
  defp stroke("o"), do: {:pandeiro_thumb, 0, 0.6}
  defp stroke("h"), do: {:pandeiro_heel, 0, 0.32}
  defp stroke("f"), do: {:pandeiro_jingles, 0, 0.38}
  defp stroke("S"), do: {:pandeiro_slap, 1, 0.7}
  defp stroke("."), do: {:pandeiro_jingles, 1, 0.1}
  defp stroke("r"), do: {:pandeiro_jingles, 1, 0.2}

  # A repeatable wobble between -0.5 and 0.5, so no two strokes are struck quite alike.
  defp wobble(count), do: rem(count * 31, 11) / 10 - 0.5

  # Every stroke of a strain as {beat, synth, vel, muted}: only the jingles take the lean of the
  # rocking, a stroke split from another in its cell is lighter, and a bass on the beat is a
  # little late.
  defp pandeiro_strokes(section) do
    cells =
      for {phrase, loudness} <- pandeiro_phrases(section),
          cell <- String.split(phrase),
          do: {cell, loudness}

    for {{cell, loudness}, index} <- Enum.with_index(cells),
        accent = if(String.starts_with?(cell, ">"), do: 0.25, else: 0),
        letters =
          cell |> String.trim_leading(">") |> String.replace("R", "rrrr") |> String.graphemes(),
        {letter, split} <- Enum.with_index(letters),
        letter != "_" do
      {synth, muted, vel} = stroke(letter)
      place = rem(index, 4)
      rim = synth in [:pandeiro_jingles, :pandeiro_heel]
      lean = if rim, do: Enum.at(lean(), place), else: 1
      lighter = if split > 0 and letter != "r", do: 0.85, else: 1
      touch = 1 + 0.15 * wobble(index * 4 + split)
      vel = clamp((vel * lean + accent) * lighter * loudness * touch, 0.02, 1)
      late = if synth == :pandeiro_thumb and place == 0, do: 0.01, else: 0
      loose = 0.008 * wobble(index * 4 + split + 1)
      beat = (index + split / length(letters)) * 0.25 + Enum.at(push(), place) + late + loose
      {max(beat, 0), synth, Float.round(vel, 2), muted}
    end
  end

  # How early each sixteenth of a beat is played, in beats, as the pandeiro's rocking places them:
  # the third and the fourth a little ahead.
  defp push, do: [0, 0, -0.02, -0.03]

  # How much louder or softer the pandeiro's jingles sound on each sixteenth: the hand swings
  # widest into the second, and wide again on the way back.
  defp lean, do: [0.85, 1.25, 1.0, 0.8]
end
