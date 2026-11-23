defmodule Odeon do
  @moduledoc """
  Ernesto Nazareth's Odeon, a tango brasileiro of 1909 in C sharp minor: its first strain, played
  slowly by a choro regional.
  The melody is the pianist's left hand, low and singing, so the trombone sings it and the flute
  answers with the right hand's phrases; on the repeat the cello sings and the tenor saxophone
  answers.
  The pandeiro plays as its hand rocks, with a muted and an open bass, ghost notes, slaps and
  rolls, and every other part swings where its rocking places the sixteenths.
  The notes are transcribed from Musica Brasilis' edition, revised against Nazareth's manuscript;
  the music itself is in the public domain.
  """

  use Mx.Song, tempo: 72

  part :trombone,
    synth: :trombone,
    defaults: [amp: 2],
    fx: [reverb: [decay_seconds: 1.8, mix: 0.3]]

  part :cello, synth: :cello, defaults: [amp: 2], fx: [reverb: [decay_seconds: 1.8, mix: 0.3]]

  part :flute,
    synth: :flute,
    defaults: [amp: 1.8, pan: 0.2],
    fx: [reverb: [decay_seconds: 1.8, mix: 0.3]]

  part :tenor_sax,
    synth: :tenor_sax,
    defaults: [amp: 1.6, pan: 0.2],
    fx: [reverb: [decay_seconds: 1.8, mix: 0.3]]

  part :guitar,
    synth: :guitar,
    defaults: [amp: 0.9, pan: -0.25],
    fx: [reverb: [decay_seconds: 1.5, mix: 0.2]]

  part :cavaquinho,
    synth: :cavaquinho,
    defaults: [amp: 0.4, pan: 0.3],
    fx: [reverb: [decay_seconds: 1.5, mix: 0.2]]

  part :pandeiro_thumb,
    synth: :pandeiro_thumb,
    defaults: [amp: 0.6, pan: 0.1],
    fx: [reverb: [decay_seconds: 1.2, mix: 0.12]]

  part :pandeiro_jingles,
    synth: :pandeiro_jingles,
    defaults: [amp: 0.5, pan: 0.1],
    fx: [reverb: [decay_seconds: 1.2, mix: 0.12]]

  part :pandeiro_heel,
    synth: :pandeiro_heel,
    defaults: [amp: 0.5, pan: 0.1],
    fx: [reverb: [decay_seconds: 1.2, mix: 0.12]]

  part :pandeiro_slap,
    synth: :pandeiro_slap,
    defaults: [amp: 0.4, pan: 0.1],
    fx: [reverb: [decay_seconds: 1.2, mix: 0.12]]

  part :shaker, synth: :shaker, defaults: [amp: 0.35, pan: -0.35]

  def song do
    together([
      part(:trombone, loop(32, fn pass, _ -> trombone(pass) end)),
      part(:cello, loop(32, fn pass, _ -> cello(pass) end)),
      part(:flute, loop(32, fn pass, _ -> flute(pass) end)),
      part(:tenor_sax, loop(32, fn pass, _ -> tenor_sax(pass) end)),
      part(:guitar, loop(32, fn _, _ -> guitar() end)),
      part(:cavaquinho, loop(32, fn _, _ -> cavaquinho() end)),
      part(:pandeiro_thumb, loop(32, fn pass, _ -> pandeiro(pass, :pandeiro_thumb) end)),
      part(:pandeiro_jingles, loop(32, fn pass, _ -> pandeiro(pass, :pandeiro_jingles) end)),
      part(:pandeiro_heel, loop(32, fn pass, _ -> pandeiro(pass, :pandeiro_heel) end)),
      part(:pandeiro_slap, loop(32, fn pass, _ -> pandeiro(pass, :pandeiro_slap) end)),
      part(:shaker, loop(32, fn _, _ -> shaker() end))
    ])
  end

  # The left hand's melody as beat, note and beats held: down the scale from E3 to F#2, up the F
  # sharp minor chord, down again from F#4, and the pickup to the next pass.
  defp low do
    descent = Enum.with_index([52, 51, 49, 47, 45, 44], fn note, beat -> dotted(beat, note) end)

    climb = [
      {6, 42, 0.75},
      {6.75, 45, 0.25},
      {7, 49, 0.25},
      {7.25, 54, 0.25},
      {7.5, 57, 0.25},
      {7.75, 61, 0.25}
    ]

    fall = Enum.with_index([66, 64, 63, 61], fn note, beat -> dotted(8 + beat, note) end)

    pickup = fn beat ->
      [{beat + 0.25, 56, 0.25}, {beat + 0.5, 55, 0.25}, {beat + 0.75, 54, 0.25}]
    end

    again =
      Enum.with_index([52, 51, 49, 47, 45, 44, 42, 40], fn note, beat ->
        dotted(16 + beat, note)
      end)

    List.flatten([descent, climb, fall, dotted(12, 60), pickup.(15), again, pickup.(31)])
  end

  # The right hand's answers as beat, note and beats held: a turn over G#7 falling to C#m, then
  # sighs a semitone down a sixteenth after each beat, settling on C#4.
  defp answer do
    turn =
      [{13.25, 68, 0.25}, {13.5, 76, 0.25}, {13.75, 72, 0.25}] ++
        Enum.with_index([75, 73, 76, 73, 68, 64, 61, 60], fn note, i ->
          {14 + i * 0.25, note, 0.25}
        end)

    sighs =
      Enum.with_index([{69, 68}, {76, 75}, {75, 73}, {71, 69}, {69, 68}, {64, 63}], fn {from, to},
                                                                                       i ->
        [{24.25 + i, from, 0.5}, {24.75 + i, to, 0.25}]
      end)

    List.flatten([turn, sighs, {30, 61, 1.5}])
  end

  # The melody is low on even passes, so the trombone sings and the flute answers; on odd ones the
  # cello sings and the tenor saxophone answers.
  defp trombone(pass) when rem(pass, 2) == 0 do
    at(phrased(low(), 0.2), 32, held: 0.85, release: 0.15)
  end

  defp trombone(_pass), do: rest(32)

  defp cello(pass) when rem(pass, 2) == 1, do: at(phrased(low()), 32, held: 0.9, release: 0.2)

  defp cello(_pass), do: rest(32)

  defp flute(pass) when rem(pass, 2) == 0 do
    notes =
      for {beat, note, length, vel: vel} <- phrased(answer()),
          do:
            {beat, note, length,
             vel: vel, held: 0.85, release: 0.15, vibrato: if(length > 0.4, do: 0.15, else: 0)}

    at(notes, 32)
  end

  defp flute(_pass), do: rest(32)

  defp tenor_sax(pass) when rem(pass, 2) == 1 do
    notes =
      for {beat, note, length, vel: vel} <- phrased(answer()),
          do:
            {beat, note, length,
             vel: Float.round(vel * 0.9, 2),
             held: 0.85,
             release: 0.15,
             vibrato: if(length > 0.4, do: 0.5, else: 0)}

    at(notes, 32)
  end

  defp tenor_sax(_pass), do: rest(32)

  # The 7-string guitar: the piano's chords off each beat while the melody is low, and the left
  # hand's bass line while the melody is high.
  defp guitar do
    chords = harmony()

    # Under the melody in the opening bars, above it where it climbs to F#4.
    offbeats =
      for beat <- Enum.to_list(0..11) ++ Enum.to_list(16..23),
          do: {feel(beat + 0.5), Enum.at(chords, beat), if(beat in 8..11, do: 66, else: 55)}

    offbeats =
      for {beat, {root, quality}, from} <- offbeats,
          do:
            {beat,
             note(voice(chord(root, quality), from: from, to: from + 11), 0.35,
               strum: 0.03,
               vel: between(0.45, 0.55),
               sustain: 0.35,
               release: 0.1
             )}

    bass =
      List.flatten([
        {12, 44, 1},
        {13, 39, 1},
        {14, 37, 1.25},
        dotted(24, 39),
        dotted(25, 44),
        dotted(26, 37),
        {27, 42, 0.75},
        {27.75, 43, 0.25},
        dotted(28, 44),
        dotted(29, 39),
        {30, 37, 1.5}
      ])

    bass =
      for {beat, note, length, _vel} <- phrased(bass),
          do:
            {beat, note, length,
             vel: if(length < 0.3, do: 0.5, else: 0.65), held: 0.9, release: 0.1}

    at(offbeats ++ bass, 32)
  end

  # The cavaquinho strums close chords softly, down on the eighths and up on the sixteenths
  # between, its pattern changing from bar to bar, and lets each strain's last chord ring.
  defp cavaquinho do
    chords = harmony()

    patterns = [
      [{0, 0.45}, {0.5, 0.55}, {0.75, 0.35}, {1.25, 0.35}, {1.5, 0.55}],
      [{0.5, 0.55}, {0.75, 0.35}, {1.5, 0.55}, {1.75, 0.3}],
      [{0, 0.45}, {0.75, 0.45}, {1.5, 0.55}]
    ]

    strums =
      for bar <- 0..15,
          {offset, vel} <- if(bar in [7, 15], do: [{0, 0.5}], else: pick(patterns)) do
        {feel(bar * 2 + offset), Enum.at(chords, bar * 2 + trunc(offset)), vel,
         rem(round(offset * 4), 2) == 1, bar in [7, 15]}
      end

    strums =
      for {beat, {root, quality}, vel, up, last} <- strums do
        sustain = if last, do: 1.5, else: 0.2

        {beat,
         note(voice(chord(root, quality), from: 62, to: 73, limit: 4), sustain,
           strum: if(up, do: -0.02, else: 0.025),
           vel: Float.round(vel + between(-0.05, 0.05), 2),
           sustain: sustain,
           release: 0.1
         )}
      end

    at(strums, 32)
  end

  # The pandeiro, written as its hand's rocking, a sixteenth to each cell, as the pandeiro solo in
  # mxs's examples writes it.
  # T is the thumb's bass with the head muted by the holding hand and O the open one, o the
  # fingertips' open bass, h the wrist and f the fingertips on the rim, S a slap and R a roll;
  # a dot is a ghost note, where the drum rocks and nothing strikes, _ is silence, > accents a
  # cell, and several strokes in a cell split it evenly.
  # Each phrase is two bars and its loudness: the choro groove under the trombone, with a roll of
  # two fingers now and then, a call where the flute answers, and the tamborim's line under the
  # sighs.
  defp pandeiro_phrases(pass) when rem(pass, 2) == 0 do
    [
      {"T f h f  O f h f  T f h f  O f h o", 0.7},
      {"T f h f  O ff h f  T f h f  O f h o", 0.75},
      {"T f h f  O f h f  T f h f  O f h o", 0.8},
      {">O f h >S  f h >O f  T f h f  O f h o", 0.85},
      {"T f h f  O f h f  T f h f  O f h o", 0.75},
      {"T f h f  O ff h f  T f h f  O f h o", 0.8},
      {"T f >h f  O f h o  T o h S  O o h f", 0.8},
      {"T f h f  O f h f  >S _ . f  O f h o", 0.7}
    ]
  end

  # Under the cello it leans to samba: a slap before the second beat, the fingertips' bass pushing
  # into each beat, and a roll into the next pass.
  defp pandeiro_phrases(_pass) do
    [
      {"T f h S  O f h o  T f h o  O f h o", 0.85},
      {"T f h S  O ff h o  T f h o  O f h o", 0.9},
      {"T f >h f  O f h o  T o h S  O o h f", 0.9},
      {">O f h >S  f h >O f  >S _ . f  O f h o", 0.95},
      {"T f h S  O f h o  T f h o  O f h o", 0.9},
      {"T f >h f  O f h o  T o h S  O o >S o", 0.95},
      {"T f h f  O ff h f  T f h f  O f h o", 0.85},
      {"T f h f  O f h f  T f h f  R R R R", 0.8}
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

  # Every stroke of a pass as {beat, synth, vel, muted}: only the jingles take the lean of the
  # rocking, a stroke split from another in its cell is lighter, and a bass on the beat is a
  # little late.
  defp pandeiro_strokes(pass) do
    cells =
      for {phrase, loudness} <- pandeiro_phrases(pass),
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

  # A pass of one of the pandeiro's strokes.
  defp pandeiro(pass, synth) do
    entries =
      for {beat, ^synth, vel, muted} <- pandeiro_strokes(pass),
          do: {beat, hit(vel: vel, muted: muted)}

    at(entries, 32)
  end

  # A shaker under it all in sixteenths, down on each eighth and up between, leaning as the
  # pandeiro's jingles do, barely there.
  defp shaker do
    strokes =
      for sixteenth <- 0..127,
          do: {feel(sixteenth / 4), rem(sixteenth, 2), Enum.at(lean(), rem(sixteenth, 4))}

    entries =
      for {beat, up, lean} <- strokes,
          do: {beat, hit(vel: Float.round(0.22 * lean + between(-0.04, 0.04), 2), up: up)}

    at(entries, 32)
  end

  # Each note as its beat with the swing, note, beats held and vel: louder the higher it goes,
  # softer on the sixteenths, and louder by louder: for an instrument that sings over the others.
  defp phrased(notes, louder \\ 0) do
    for {beat, note, held} <- notes do
      vel = 0.42 + (note - 40) * 0.006

      {feel(beat), note, held,
       vel: Float.round(if(held < 0.3, do: vel * 0.85, else: vel), 2) + louder}
    end
  end

  # Choro's swing: each sixteenth where the pandeiro's rocking places it, and every stroke a few
  # milliseconds off.
  defp feel(beat) do
    push = Enum.at(push(), rem(round(beat * 4), 4))
    max(beat + push + between(-0.01, 0.01), 0)
  end

  # A note held a dotted eighth and struck again a sixteenth before the next beat, the left hand's
  # rhythm.
  defp dotted(beat, note), do: [{beat, note, 0.75}, {beat + 0.75, note, 0.25}]

  # The chord on each of the strain's 32 beats, two to a bar.
  defp harmony do
    opening = [
      {:cs3, :minor},
      {:gs2, :major},
      {:cs3, :minor},
      {:cs3, :dom7},
      {:fs2, :minor},
      {:cs3, :dom7}
    ]

    first = [
      {:fs2, :minor},
      {:fs2, :minor},
      {:fs2, :minor},
      {:fs2, :minor},
      {:b2, :dom7},
      {:a2, :dom7},
      {:gs2, :dom7},
      {:gs2, :dom7},
      {:cs3, :minor},
      {:cs3, :minor}
    ]

    second = [
      {:fs2, :minor},
      {:fs2, :half_dim7},
      {:ds3, :dim7},
      {:gs2, :dom7},
      {:cs3, :minor},
      {:fs2, :minor},
      {:cs3, :minor},
      {:gs2, :dom7},
      {:cs3, :minor},
      {:cs3, :minor}
    ]

    opening ++ first ++ opening ++ second
  end

  # How early each sixteenth of a beat is played, in beats, as the pandeiro's rocking places them:
  # the third and the fourth a little ahead.
  defp push, do: [0, 0, -0.03, -0.04]

  # How much louder or softer the pandeiro's jingles sound on each sixteenth: the hand swings
  # widest into the second, and wide again on the way back.
  defp lean, do: [0.85, 1.25, 1.0, 0.8]
end
