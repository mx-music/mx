defmodule Choro do
  @moduledoc """
  Ernesto Nazareth's Apanhei-te, cavaquinho, a polca of 1914 that choro took for its own, played
  by a regional: flute, clarinet, cavaquinho, 7-string guitar and pandeiro.
  Its form is A A B B A C C A: A in G major, B in its relative minor, E minor, and C, the trio, in
  its subdominant, C major.
  The flute and the clarinet take the pianist's right hand in turns and then together, an octave
  apart, and the cavaquinho strums the left hand's rhythm.
  The melody and the harmony are transcribed from Musica Brasilis' edition, whose right hand the
  piano plays an octave above where it is written; the guitar's bass lines and the pandeiro are
  the regional's own, and the music itself is in the public domain.
  """

  use Mx.Song, tempo: 104, key: :g

  part :flute,
    synth: :flute,
    defaults: [amp: 0.9, vibrato: 0.03, pan: 0.15],
    fx: [reverb: [decay_seconds: 1.3, mix: 0.25]]

  part :clarinet,
    synth: :clarinet,
    defaults: [amp: 0.8, pan: -0.25],
    fx: [reverb: [decay_seconds: 1.1, mix: 0.2]]

  part :cavaquinho,
    synth: :cavaquinho,
    defaults: [pan: 0.35],
    fx: [reverb: [decay_seconds: 1, mix: 0.15]]

  part :guitar,
    synth: :guitar,
    defaults: [amp: 0.55, pan: -0.1],
    fx: [reverb: [decay_seconds: 1, mix: 0.15]]

  part :pandeiro_thumb, synth: :pandeiro_thumb, defaults: [amp: 0.5]
  part :pandeiro_jingles, synth: :pandeiro_jingles, defaults: [amp: 0.5]
  part :pandeiro_heel, synth: :pandeiro_heel, defaults: [amp: 0.5]
  part :pandeiro_slap, synth: :pandeiro_slap, defaults: [amp: 0.5]

  # Each pass plays one strain of sixteen bars, in the order of the form.
  def song do
    repeat(
      form(
        [a: 2, b: 2, a: 1, c: 2, a: 1],
        fn section, %{pass: pass, coming: coming} -> strain(pass, section, coming) end,
        round: true
      )
    )
  end

  # A strain, given its pass of the form and the strain that follows.
  defp strain(pass, section, coming) do
    pandeiro =
      for synth <- [:pandeiro_thumb, :pandeiro_jingles, :pandeiro_heel, :pandeiro_slap] do
        part(synth, pandeiro(section, synth))
      end

    together(
      [
        part(:flute, flute(pass, section, coming)),
        part(:clarinet, clarinet(pass, section, coming)),
        part(:cavaquinho, cavaquinho(section)),
        part(:guitar, guitar(section, coming))
      ] ++ pandeiro
    )
  end

  # The melody, a bar to each line and a sixteenth to each note: a number after a colon holds a
  # note that many sixteenths, a dot rests,
  # ~ plays the note with a mordent, and a note in brackets is a grace note before the one it
  # leads to.
  defp melody(:a) do
    phrase = [
      "~e6 d6 cs6 d6 fs6 e6 d6 c6",
      "~c6 b5 as5 b5 e6 d6 c6 b5",
      "~b5 a5 gs5 a5 d6 c6 b5 a5",
      "~a5 g5 fs5 g5 c6 b5 a5 g5",
      "~fs5 e5 ds5 e5 a5 g5 fs5 e5",
      "~e5 d5 cs5 d5 e5 fs5 g5 a5"
    ]

    phrase ++
      ["b5 c6 cs6 d6 fs6 e6 d6 c6", "as5 b5 e6 d6 . g6 fs6 e6"] ++
      phrase ++ ["b5 c6 cs6 d6 ds6 e6 f6 fs6"]
  end

  defp melody(:b) do
    [
      "as5 b5 e6 fs6 g6 b5 g6 b5",
      "g6 as5 cs6 fs6 fs6 as5 fs6 as5",
      "g6 a5 b5 fs6 fs6 a5 fs6 a5",
      "fs6 g5 b5 e6 . b5 (d6)c6 b5",
      "as5 b5 e6 fs6 g6 b5 g6 b5",
      "g6 b5 fs6 b5 e6 b5 d6 b5",
      "d6 e5 fs5 cs6 cs6 e5 cs6 e5",
      "c6 ds5 fs5 b5 . b5 (d6)c6 b5",
      "as5 b5 e6 fs6 g6 b5 g6 b5",
      "g6 as5 cs6 fs6 fs6 as5 fs6 as5",
      "g6 a5 b5 fs6 fs6 a5 fs6 a5",
      "f6 gs5 b5 e6 . ds6:2 e6",
      "f6 a5 e6 a5 d6 a5 c6 a5",
      "c6 e5 g5 b5 . as5:2 b5",
      "c6 b5 as5 b5 e6 ds6 g6 fs6"
    ]
  end

  defp melody(:c) do
    [
      "a6 g6 e6 c6 a5 g5 e5 c5",
      "a5:3 a5 .:2 a5:2",
      ". g5:2 a5 b5 c6:2 d6",
      "e6:3 e6 .:2 e6:2",
      ". e6 ds6 e6 f6 e6 ds6 e6",
      "c6 e6 b5 e6 a5 e6 g5 e6",
      ". d6 cs6 d6 e6 d6 cs6 d6",
      "e6 d6 b5 g6 . g6 fs6 g6",
      "a6 g6 e6 c6 a5 g5 e5 c5",
      "a5:3 a5 .:2 a5:2",
      ". g5:2 a5 b5 c6:2 d6",
      "e6:3 e6 .:2 e6:2",
      ". ds6:2 e6 f6 e6 ds6 e6",
      "a6:3 a6 .:2 a6:2",
      ". g6 f6 d6 b5 g5 f5 d5"
    ]
  end

  # A strain's last bar lands on its tonic and picks up into the strain that follows.
  defp landing(:a), do: "g6:4"
  defp landing(:b), do: "e6:4"
  defp landing(:c), do: "c5:3 c6"

  defp pickup(:c, :c), do: ". g6 fs6 g6"
  defp pickup(_section, :a), do: ". g6 fs6 e6"
  defp pickup(_section, :b), do: ". b5 (d6)c6 b5"
  defp pickup(_section, :c), do: ". g6 fs6 g6"

  # The bars of the trio where the whole regional strikes the pianist's chords together.
  defp tutti, do: [1, 3, 9, 11, 13]

  # A strain's notes as maps of the beat, the note, the beats held, the bar, and its ornaments.
  defp notes(section, coming) do
    bars = melody(section) ++ [landing(section) <> " " <> pickup(section, coming)]

    for {bar, index} <- Enum.with_index(bars),
        note <- bar_notes(bar),
        do: Map.put(%{note | beat: index * 2 + note.beat}, :bar, index)
  end

  defp bar_notes(bar) do
    {notes, _} =
      Enum.flat_map_reduce(String.split(bar), 0, fn token, slot ->
        {name, held} =
          case String.split(token, ":") do
            [name] -> {name, 1}
            [name, held] -> {name, String.to_integer(held)}
          end

        [_, mordent, grace, name] = Regex.run(~r/^(~?)(?:\((\w+)\))?(.+)$/, name)

        note =
          if name == "." do
            []
          else
            [
              %{
                beat: slot / 4,
                note: pitch(name),
                beats: held / 4,
                mordent: mordent == "~",
                grace: if(grace != "", do: pitch(grace))
              }
            ]
          end

        {note, slot + held}
      end)

    notes
  end

  # A wind tongues the first note of each bar and slurs the rest of the bar to it, and tongues
  # again a note it repeats or one after a rest.
  defp breaths(notes) do
    Enum.chunk_while(
      notes,
      [],
      fn note, breath ->
        case breath do
          [] ->
            {:cont, [note]}

          [last | _] ->
            joined = abs(last.beat + last.beats - note.beat) < 0.001

            if joined and last.bar == note.bar and last.note != note.note do
              {:cont, [note | breath]}
            else
              {:cont, Enum.reverse(breath), [note]}
            end
        end
      end,
      fn breath -> {:cont, Enum.reverse(breath), []} end
    )
  end

  # One breath as a held note whose pitch the fingers change at once, without a glide: a mordent
  # flicks to the note above in the key and back, and a grace note is touched on the way in.
  # The breath starts lead beats early, the time the instrument takes to speak, and plays down
  # semitones below the written note.
  defp breath([first | _] = notes, section, vel, down, lead) do
    start = max(swing(first.beat) - lead, 0)
    last = List.last(notes)
    held = last.beat + last.beats - start

    changes =
      notes
      |> Enum.with_index()
      |> Enum.flat_map(fn {note, index} ->
        at = swing(note.beat) - start
        above = Enum.find(key(section), &(&1 > note.note))
        arrives = note.grace || note.note

        arrive = if index > 0, do: [{at, note: arrives - down, note_slide: 0.005}], else: []

        land =
          if note.grace, do: [{at + 0.06, note: note.note - down, note_slide: 0.005}], else: []

        mordent =
          if note.mordent do
            [
              {at + 0.07, note: above - down, note_slide: 0.005},
              {at + 0.14, note: note.note - down, note_slide: 0.005}
            ]
          else
            []
          end

        arrive ++ land ++ mordent
      end)

    {start,
     note((first.grace || first.note) - down, held,
       vel: vel,
       sustain: Float.round(held - 0.12, 3),
       release: 0.04,
       changes: changes
     )}
  end

  # A strain's notes in breaths for a wind, louder on a breath that starts on the beat.
  defp wind(notes, section, vel, down, lead) do
    breaths =
      for [first | _] = breath <- breaths(notes) do
        accent = if first.beat == trunc(first.beat), do: 0.08, else: 0
        breath(breath, section, vel + accent, down.(first), lead)
      end

    at(breaths, 32)
  end

  # Whether a note is in the pickup to the strain that follows.
  defp pickup?(note), do: note.bar == 15 and note.beat >= 31

  # The flute plays an octave below the piano, and at the piano's pitch where the clarinet joins
  # it, in the repeat of B and the last A.
  defp flute_down(pass) when pass in [3, 7], do: 0
  defp flute_down(_pass), do: 12

  # The flute leads A and B, leaves the repeat of A and of the trio to the clarinet, joining only
  # for the tutti chords and the pickups, and plays the repeat of B and the last A above it.
  defp flute(pass, section, coming) do
    loud = %{a: 0.75, b: 0.65, c: 0.8}

    plays =
      case pass do
        1 -> &pickup?/1
        6 -> &(&1.bar in tutti() or pickup?(&1))
        _ -> fn _note -> true end
      end

    # A pickup is played where the strain it leads to is.
    down = fn note ->
      if pickup?(note), do: flute_down(rem(pass + 1, 8)), else: flute_down(pass)
    end

    section |> notes(coming) |> Enum.filter(plays) |> wind(section, loud[section], down, 0.08)
  end

  # The clarinet plays an octave below the piano, as the flute does when it plays alone.
  defp clarinet(pass, section, coming) when pass in [1, 3, 6, 7] do
    section |> notes(coming) |> wind(section, 0.65, fn _note -> 12 end, 0.03)
  end

  defp clarinet(_pass, _section, _coming), do: rest(32)

  # The cavaquinho strums the pianist's left hand, an eighth, two sixteenths and two eighths to
  # the bar, down on the eighths and up between,
  # and strikes the trio's tutti chords with the flute.
  defp cavaquinho(section) do
    # Each tone of the chord placed between D4 and C#5, as the four strings reach; a five-note
    # chord leaves out its root.
    voicing = fn beat ->
      voice(chord(chord_at(chart(section), 2, beat), from: :d4), from: 62, to: 73, limit: 4)
    end

    pattern = [
      {0, 0.02, 0.75, 0.3},
      {0.5, 0.02, 0.5, 0.12},
      {0.75, -0.015, 0.45, 0.12},
      {1, 0.02, 0.6, 0.25},
      {1.5, 0.02, 0.55, 0.25}
    ]

    struck = [{0, 0.02, 0.85, 0.6}, {0.75, -0.015, 0.6, 0.15}, {1.5, 0.02, 0.8, 0.3}]

    played = fn bar -> if section == :c and bar in tutti(), do: struck, else: pattern end

    strums =
      for bar <- 0..15,
          {offset, strum, vel, held} <- played.(bar),
          do: {bar * 2 + offset, strum, vel, held}

    strums =
      for {beat, strum, vel, held} <- strums do
        notes = voicing.(trunc(beat))

        # The first string the pick meets sounds loudest: the lowest going down, the highest
        # coming up.
        down = Enum.map(Enum.take([1, 0.9, 0.85, 0.8], length(notes)), &Float.round(&1 * vel, 2))
        vels = if strum > 0, do: down, else: Enum.reverse(down)

        {swing(beat) + abs(strum),
         note(notes, held, strum: strum, vel: vels, sustain: held, release: 0.06, amp: 0.32)}
      end

    at(strums, 32)
  end

  # The 7-string guitar: the root on the beat, the chord's fifth and a note leading to the next
  # chord, and a run down to it at the end of each phrase of four bars.
  defp guitar(section, coming) do
    # The chord at a beat, reading on into the strain that follows, its root between B1 and A#2,
    # so the low B string of the 7-string guitar gets used.
    chord = fn beat -> chord(chord_at(chart(section) ++ chart(coming), 2, beat), from: :b1) end

    bars =
      for bar <- 0..15 do
        [root | _] = chord.(bar * 2)
        [target | _] = chord.(bar * 2 + 2)

        if rem(bar, 4) == 3 do
          # A baixaria: the root, then sixteenths down the key towards the next chord's root.
          steps =
            key(section)
            |> Enum.filter(&(&1 > target and &1 < root + 12))
            |> Enum.reverse()
            |> Enum.take(-6)

          steps =
            if length(steps) < 6, do: Enum.to_list((target + 6)..(target + 1)//-1), else: steps

          seq([
            note(root, 0.5, vel: 0.75, sustain: 0.4, release: 0.1)
            | Enum.map(steps, &note(&1, 0.25, vel: 0.6, sustain: 0.18, release: 0.06))
          ])
        else
          leading = target + if(rem(bar, 2) == 0, do: -1, else: 1)

          seq([
            note(root, 1, vel: 0.7, sustain: 0.8, release: 0.1),
            note(Enum.at(chord.(bar * 2 + 1), 2), 0.5,
              vel: 0.5,
              sustain: 0.35,
              release: 0.08,
              amp: 0.45
            ),
            note(leading, 0.5, vel: 0.55, sustain: 0.35, release: 0.08, amp: 0.45)
          ])
        end
      end

    seq(bars)
  end

  # The pandeiro, written as its hand's rocking, a sixteenth to each cell, as Odeon writes it.
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

  # A strain of one of the pandeiro's strokes.
  defp pandeiro(section, synth) do
    entries =
      for {beat, ^synth, vel, muted} <- pandeiro_strokes(section),
          do: {beat, hit(vel: vel, muted: muted)}

    at(entries, 32)
  end

  # Every player reads the same chart, a word to each bar of two beats, and two chords in a bar
  # each half of it.
  defp chart(:a) do
    ~MX"D7 G B7 Em Am:1/2 C#dim7:1/2 G D7 G  D7 G B7 Em Am:1/2 C#dim7:1/2 G D7 G"
  end

  defp chart(:b) do
    ~MX"Em F#7 B7 Em Em Bm F#7 B7  Em F#7 B7 E7 Am Em F#7:1/2 B7:1/2 Em"
  end

  defp chart(:c), do: ~MX"C D#dim7 G7 C E7 Am D7 G7  C D#dim7 G7 E7 Am Dm G7 C"

  defp key(:a), do: scale(:g1, :major, octaves: 5)
  defp key(:b), do: scale(:e1, :harmonic_minor, octaves: 5)
  defp key(:c), do: scale(:c1, :major, octaves: 5)

  # Choro's swing: a beat where the pandeiro's rocking places its sixteenth.
  defp swing(beat), do: beat + Enum.at(push(), rem(round(beat * 4), 4))

  # How early each sixteenth of a beat is played, in beats, as the pandeiro's rocking places them:
  # the third and the fourth a little ahead.
  defp push, do: [0, 0, -0.02, -0.03]

  # How much louder or softer the pandeiro's jingles sound on each sixteenth: the hand swings
  # widest into the second, and wide again on the way back.
  defp lean, do: [0.85, 1.25, 1.0, 0.8]
end
