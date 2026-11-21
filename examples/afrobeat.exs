defmodule Afrobeat do
  @moduledoc """
  An afrobeat groove for a double bass and a drum set, mixed as a dub: the drums lead, and their
  strokes are sent into echoes.
  The drum set is Virtuosity Drums, the jazz kit recorded by Versilian Studios, and the keyboard
  is FreePats' FM piano, both under Creative Commons 0; the bass is mx's double bass, plucked for
  the line and bowed for the theme.
  It plays at 100 bpm in G with a flat second, on a vamp of two bars over G that the drop lifts to
  A flat.
  The bass drum is strong on one and three with softer strokes just after two and four, the snare
  answers it in ghost notes, and the hi-hat stays closed and soft.
  A rimshot is thrown into an echo of three sixteenths that crosses from side to side, twice in a
  section, and the snare and the tuned tom echo more quietly at the same length.
  In the drop the snare leaves the groove to the bass drum and the hi-hat, and the keyboard holds
  two chords under a tremolo.
  The floor tom, tuned to the bass's G and D, repeats a stroke every beat and a half against the
  bar of four beats, and meets the bar again only where a section ends.
  The theme falls from D to the low G, bowed near the bridge with a tremolo, quietly, over the
  plucked line, and the solo is the drummer's: one run on the tuned tom that gains a stroke in
  every bar, from three strokes to ten, each ending on the rimshot.
  It ends by thinning out over four bars, the echoes left to themselves, before a last chord.
  The files are fetched as the song loads.
  """

  use Mx.Song, tempo: 100

  @hall [reverb: [room: 0.85, damp: 0.4, mix: 0.3]]
  @throw [ping_pong: [phase: 0.75, feedback: 0.7, mix: 0.65]]
  @trail [ping_pong: [phase: 0.75, feedback: 0.5, mix: 0.2]]

  # Each voice of the kit: its drum, its stroke, the strengths and takes recorded, how many beats
  # it rings and fades over, the part and level of each microphone, and its effects.
  @kit [
    kick:
      {"kick", "snon", 4, 4, {0.75, 0.5},
       [{:kick_kickmic, :kickmic, 0.75}, {:kick_oh, :oh, 0.45}, {:kick_room, :room, 0.4}], []},
    snare:
      {"snare", "center", 36, nil, {0.75, 0.5},
       [{:snare_snaremic, :snaremic, 0.9}, {:snare_oh, :oh, 0.8}, {:snare_room, :room, 0.6}],
       @trail ++ [reverb: [room: 0.7, mix: 0.2]]},
    rimshot:
      {"snare", "rimshot", 12, nil, {1.5, 1},
       [{:rimshot_snaremic, :snaremic, 0.6}, {:rimshot_oh, :oh, 0.6}], @throw ++ @hall},
    hat: {"hh", "closed", 4, 4, {0.4, 0.2}, [{:hat_oh, :oh, 2.5}], []},
    high_tom:
      {"htom", "center", 16, nil, {1.5, 1},
       [{:high_tom_oh, :oh, 0.8}, {:high_tom_room, :room, 0.6}], @hall},
    low_tom:
      {"ltom", "center", 16, nil, {2, 1}, [{:low_tom_oh, :oh, 0.8}, {:low_tom_room, :room, 0.6}],
       @hall}
  ]

  # The FM piano was recorded at three strengths on every sixth key.
  @keys for name <- ~w(F#1 C2 F#2 C3 F#3 C4 F#4 C5 F#5 C6 F#6 C7),
            {layer, strength} <- [{60, 1}, {80, 2}, {100, 3}],
            note = name |> String.downcase() |> String.replace("#", "s") |> pitch(),
            do:
              {{:freepats_fm_piano, "samples/#{name}v#{layer}.flac"},
               note: note, strength: strength}

  # The bass twice, the plucked line and a second part for the bow, and the keyboard.
  # The bow plays near the bridge, pressed hard and swayed by the rosin, under a tremolo, so the
  # theme is a rough sound more than a tune.
  # A drum's files through one microphone, at each strength and take recorded.
  kit_files = fn mic, drum, stroke, strengths, takes ->
    for strength <- 1..strengths,
        take <- if(takes, do: Enum.map(1..takes, &"_rr#{&1}"), else: [""]) do
      path = "Samples/#{mic}/#{drum}/#{mic}_#{drum}_#{stroke}_vl#{strength}#{take}.flac"
      {:virtuosity_drums, path}
    end
  end

  # Each voice of the kit is a part for each of its microphones.
  for {_voice, {drum, stroke, strengths, takes, {ring, fade}, mics, fx}} <- @kit,
      {name, mic, level} <- mics do
    part name,
      synth: sampled(kit_files.(mic, drum, stroke, strengths, takes)),
      defaults: [sustain: ring, release: fade],
      fx: fx ++ [level: [amp: level]]
  end

  # The floor tom as a tuned drum: its stroke sounds at 113 Hz, halfway from A2 to B flat 2,
  # played faster or slower to each pitch as a timpani would be tuned.
  for {name, mic, level} <- [{:tuned_tom_oh, :oh, 0.7}, {:tuned_tom_room, :room, 0.4}] do
    files = for file <- kit_files.(mic, "ltom", "center", 16, nil), do: {file, note: 45.49}

    part name,
      synth: sampled(files),
      defaults: [sustain: 1.5, release: 1, pan: -0.25],
      fx: [echo: [phase: 0.75, decay: 6, mix: 0.5]] ++ @hall ++ [level: [amp: level]]
  end

  part :bass, synth: :double_bass, defaults: [pizz: 1, vel: 0.9, amp: 1.2]

  part :lead,
    synth: :double_bass,
    defaults: [
      vel: 0.6,
      amp: 0.7,
      vibrato: 0.05,
      bow_position: 0.08,
      bow_force: 1.3,
      rosin: 1.0,
      pan: 0.1
    ],
    fx: [
      tremolo: [phase: 0.25, depth: 0.7],
      echo: [phase: 1.5, decay: 6, mix: 0.35],
      reverb: [room: 0.85, mix: 0.4]
    ]

  part :keys,
    synth: sampled(@keys),
    defaults: [vel: 0.5, amp: 0.24, release: 2],
    fx: [
      tremolo: [phase: 0.5, depth: 0.5],
      echo: [phase: 0.75, decay: 6, mix: 0.35],
      reverb: [room: 0.9, mix: 0.45]
    ]

  # Each section is four bars, two turns of the vamp, and the ending is a chord held for two bars.
  # Two silent bars follow the last chord, for the echoes to die away in.
  def song do
    sections =
      for {section, count} <- [
            drums: 1,
            line: 2,
            theme: 2,
            drop: 1,
            solo: 1,
            solo_on: 1,
            drop: 1,
            theme_again: 2,
            way_out: 1,
            ending: 1
          ],
          _ <- 1..count,
          do: section

    played =
      for {section, coming} <- Enum.zip(sections, tl(sections) ++ [nil]),
          do: section(section, coming)

    seq(played ++ [rest(8)])
  end

  # A section, which plays the bar that ends it differently when another section is coming.
  defp section(section, coming) do
    together([
      drums(section, coming),
      tuned_tom_mics(tuned_tom(section)),
      part(:bass, bass(section)),
      part(:lead, lead(section)),
      part(:keys, keys(section))
    ])
  end

  # Four bars of the kit: the two bars of the groove twice, the last bar the fill when a new
  # section follows.
  # Under the solo the snare keeps only its ghost notes, and in the drop it plays only the fill.
  defp drums(:ending, _coming) do
    silent = silent()

    play(
      kick: strokes(["9... .... .... ....", silent]),
      rimshot: strokes(["8... .... .... ....", silent])
    )
  end

  # In the way out the bass drum keeps one, softer in each bar, the hi-hat thins and stops, and
  # two rimshots are thrown.
  defp drums(:way_out, _coming) do
    silent = silent()

    play(
      kick:
        strokes([
          "8... .... .... ....",
          "7... .... .... ....",
          "6... .... .... ....",
          "5... .... .... ...."
        ]),
      hat: strokes(["5.3. 5.3. 5.3. 5.3.", "5.3. 5.3. 5.3. 5.3.", "4.2. 4.2. 3... 2...", silent]),
      rimshot: thrown(:way_out)
    )
  end

  defp drums(section, coming) do
    last = if coming != section, do: 2, else: 1

    voices =
      for {voice, bars} <- groove() do
        bars = for index <- [0, 1, 0, last], do: elem(bars, index)

        bars =
          cond do
            voice == :snare and section in [:solo, :solo_on] ->
              Enum.map(bars, &String.replace(&1, "6", "."))

            voice == :snare and section == :drop ->
              List.duplicate(silent(), 3) ++ [List.last(bars)]

            true ->
              bars
          end

        {voice, strokes(bars)}
      end

    play(voices ++ [rimshot: thrown(section)])
  end

  # The groove's two bars for each voice of the kit, then the bar that ends a section before a new
  # one, with its fill on the toms.
  defp groove do
    [
      kick: {"8... .4.. 7.5. .4..", "8... .4.. 7... .4.5", "8... .4.. 7.5. ...."},
      snare: {".... 6..2 .2.. 6.2.", "..2. 6..2 .2.6 ..2.", "..2. 6..2 .26. ...."},
      hat: {"5.3. 5.3. 5.3. 5.3.", "5.3. 5.3. 5.34 5.3.", "5.3. 5.3. 5.3. ...."},
      high_tom: {silent(), silent(), ".... .... .... 6.6."},
      low_tom: {silent(), silent(), ".... .... .... .5.7"}
    ]
  end

  # The rimshots thrown into the echo, as the beats of the section's four bars they fall on.
  # In the solo each one ends a bar's run.
  defp thrown(section) do
    beats =
      case section do
        :drums -> [14]
        section when section in [:drop, :way_out] -> [1, 9]
        :solo -> for bar <- 0..3, do: bar * 4 + 0.5 + (2 + bar) / 4
        :solo_on -> for bar <- 0..3, do: bar * 4 + 0.5 + (6 + bar) / 4
        _ -> [6.75, 14.75]
      end

    hits = for beat <- beats, do: {beat, hit(stroke(7))}
    at(hits, 16)
  end

  # The tuned tom's cycle: G every beat and a half, ten times, and D twice in the last beat, which
  # turns the section round.
  defp tuned_tom(section) when section in [:drop, :theme_again] do
    low = for stroke <- 0..9, do: {stroke * 1.5, note(:g2, 0, vel: 0.5, amp: 1.4)}
    high = for beat <- [15, 15.5], do: {beat, note(:d3, 0, vel: 0.45, amp: 1.4)}
    at(low ++ high, 16)
  end

  # The solo: a run on the tuned tom in each bar, which plays more of it, from its first three
  # strokes to all ten, growing to its end.
  defp tuned_tom(section) when section in [:solo, :solo_on] do
    run = [:g2, :bb2, :c3, :d3, :f3, :g3, :ab3, :g3, :f3, :d3]
    first = if section == :solo, do: 3, else: 7

    entries =
      for bar <- 0..3,
          count = first + bar,
          {name, index} <- Enum.with_index(Enum.take(run, count)) do
        vel = Float.round(0.45 + 0.4 * (index + 1) / count, 2)
        {bar * 4 + 0.5 + index / 4, note(name, 0, vel: vel, amp: 1.6, sustain: 0.6, release: 0.4)}
      end

    at(entries, 16)
  end

  # In the way out the cycle fades stroke by stroke, and its last three strokes fall on the last
  # chord.
  defp tuned_tom(:way_out) do
    strokes =
      for stroke <- 0..9 do
        amp = Float.round(1.4 - stroke * 0.08, 2)
        {stroke * 1.5, note(:g2, 0, vel: 0.5, amp: amp)}
      end

    at(strokes, 16)
  end

  defp tuned_tom(:ending) do
    strokes =
      for {beat, amp} <- [{0, 0.6}, {1.5, 0.45}, {3, 0.3}],
          do: {beat, note(:g2, 0, vel: 0.4, amp: amp)}

    at(strokes, 8)
  end

  defp tuned_tom(_section), do: rest(16)

  defp bass(:drums), do: rest(16)
  defp bass(:ending), do: note(:g1, 8, sustain: 6, release: 1.5)

  # In the drop the line's rhythm stands on A flat.
  defp bass(:drop) do
    vamp([
      {0, :ab2, 0.6},
      {0.75, :ab2, 0.2},
      {1.5, :eb2, 0.4},
      {2, :ab2, 0.5},
      {2.75, :c3, 0.4},
      {3.5, :bb2, 0.4},
      {4, :ab2, 0.6},
      {4.75, :ab2, 0.2},
      {5.5, :eb2, 0.4},
      {6, :f2, 0.6},
      {6.75, :eb2, 0.4},
      {7.5, :f2, 0.3}
    ])
  end

  # Under the solo and in the way out the line thins to the root on one and the push before two.
  defp bass(section) when section in [:solo, :solo_on, :way_out] do
    vamp([{0, :g2, 0.6}, {4, :g2, 0.6}, {7.5, :f2, 0.3}])
  end

  # The bass line: the root on one and pushed again before two, and the flat second leading back
  # to it; the second bar goes down to D.
  defp bass(_section) do
    vamp([
      {0, :g2, 0.6},
      {0.75, :g2, 0.2},
      {1.5, :f2, 0.4},
      {2, :g2, 0.5},
      {2.75, :bb2, 0.4},
      {3.5, :ab2, 0.4},
      {4, :g2, 0.6},
      {4.75, :g2, 0.2},
      {5.5, :d2, 0.4},
      {6, :f2, 0.6},
      {6.75, :d2, 0.4},
      {7.5, :f2, 0.3}
    ])
  end

  # Notes placed on the vamp's two bars as beat, note and beats held, repeated to four bars.
  defp vamp(notes) do
    entries = for {beat, pitch, held} <- notes, do: {beat, note(pitch, 0, sustain: held)}
    repeat(at(entries, 8), 2)
  end

  # The theme, bowed: each phrase is its beat, the beats it lasts and its notes, each at the beat
  # it comes after the first.
  # A phrase is one bow, a held note that slides from each note to the next, and the last falls an
  # octave to the low G.
  defp lead(section) when section in [:theme, :theme_again] do
    theme = [
      {0.5, 3.5, [{0, :d4}, {0.75, :c4}, {1.5, :bb3}, {2.5, :ab3}]},
      {4, 3, [{0, :g3}, {1.5, :f3}, {2.25, :g3}]},
      {8.5, 3.5, [{0, :c4}, {0.75, :bb3}, {1.5, :ab3}, {2.5, :g3}]},
      {12, 3.5, [{0, :f3}, {0.75, :eb3}, {1.5, :d3}, {2.5, :g2}]}
    ]

    phrases =
      for {beat, held, [{0, first} | others]} <- theme do
        slides = for {at, name} <- others, do: {at, note: pitch(name), note_slide: 0.08}
        {beat, note(first, 0, sustain: held - 0.3, release: 0.3, changes: slides)}
      end

    at(phrases, 16)
  end

  defp lead(:ending), do: note(:g2, 8, sustain: 5, release: 2.5)
  defp lead(_section), do: rest(16)

  # The keyboard in the drop: A flat with its major seventh for two bars, then the same chord a
  # third higher, with its ninth.
  defp keys(:drop) do
    chords = [{0, [:ab3, :c4, :eb4, :g4]}, {8, [:c4, :eb4, :g4, :bb4]}]
    chords = for {beat, chord} <- chords, do: {beat, note(chord, 0, sustain: 7)}
    at(chords, 16)
  end

  # In the way out it holds G minor with its seventh and then the drop's A flat, which falls back
  # to G on the last chord.
  defp keys(:way_out) do
    chords = [{0, [:g3, :bb3, :d4, :f4]}, {8, [:ab3, :c4, :eb4, :g4]}]
    chords = for {beat, chord} <- chords, do: {beat, note(chord, 0, sustain: 7)}
    at(chords, 16)
  end

  defp keys(:ending), do: note([:g3, :bb3, :d4, :f4], 8, sustain: 6)
  defp keys(_section), do: rest(16)

  # The tuned tom through both its microphones.
  defp tuned_tom_mics(music) do
    together([part(:tuned_tom_oh, music), part(:tuned_tom_room, music)])
  end

  # The music on a voice of the kit through each of its microphones.
  defp on(voice, music) do
    {_, _, _, _, _, mics, _} = @kit[voice]
    together(for {name, _mic, _level} <- mics, do: part(name, music))
  end

  defp play(voices), do: together(for {name, music} <- voices, do: on(name, music))

  # Bars of strokes in sixteenths, a character to each: a digit is a stroke of that strength, a
  # dot is silence, and spaces are left out.
  defp strokes(bars) do
    strokes = for strength <- 1..9, do: {Integer.to_string(strength), stroke(strength)}
    steps(bars, 0.25, strokes: strokes)
  end

  # A stroke from 1, the softest, to 9: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp stroke(strength) do
    vel = strength / 9
    [vel: vel, amp: Float.round(:math.pow(vel, -0.7), 2)]
  end

  defp silent, do: ".... .... .... ...."
end
