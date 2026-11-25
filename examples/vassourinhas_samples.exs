defmodule VassourinhasSamples do
  @moduledoc """
  Vassourinhas, the frevo de rua Matias da Rocha and Joana Batista Ramos wrote in Recife in 1909,
  in the public domain, played by a street band of recorded instruments; examples/vassourinhas.exs
  is the same tune as a score for mx's own winds.
  The trumpet and the trombone are those of VSCO 2 Community Edition, Versilian Studios' chamber
  orchestra, the tenor saxophone is VCSL's, and the alto saxophone and the tuba are Karoryfer
  Samples' Weresax and War Tuba, all under Creative Commons 0.
  The drums are Virtuosity Drums, a jazz kit played by Austin McMahon and recorded by Versilian
  Studios, also under Creative Commons 0.
  The drummer plays the caixa's part on the snare, ghost strokes between its accents and a press
  roll into every other bar, and the surdo's on the bass drum and the floor tom, light on the
  first beat and open on the second, with the hi-hat closing between the beats.
  A beat is a quarter note of 2/4, so a bar is two beats and each part of the tune is 32.
  The first part is the brass's fanfare and the second the saxophones' tune, as a frevo de rua has
  them ask and answer.
  The form is an opening on the caixa, the first part, the second part from the saxophones and
  then from the trumpet over their runs, the first part handed from player to player over a
  lighter kit, then both parts a tone higher with the whole band, and a last chord.
  The files are fetched as the song loads, about 210 MB.
  """

  use Mx.Song, tempo: 148

  @vsco :vsco
  @vcsl :vcsl
  @weresax :karoryfer_weresax
  @war_tuba :karoryfer_war_tuba

  file = fn collection, path -> {collection, path} end

  # Every library names its keys an octave below the pitch mx names them by.
  key = fn name ->
    note = name |> String.downcase() |> String.replace("#", "s") |> pitch()
    note + 12
  end

  # The recorded keys of each brass part, each with the dB that bring it level with the others.
  # The trumpet's and the trombone's short notes are their loudest, two takes of each; the held
  # notes are the ones that speak at once.
  @keys %{
    trumpet: [{"G3", 8}, {"A#3", 3}, {"D4", 0}, {"F4", -2}, {"A4", 0}, {"C5", -3}],
    trumpet_held: [{"G3", 0}, {"A#3", 3}, {"D4", -2}, {"F4", 2}, {"A4", -3}, {"C5", -1}],
    trombone: [{"A#1", 0}, {"F2", 3}, {"A#2", 0}, {"D3", -2}, {"F3", -1}],
    trombone_held: [{"D2", 8}, {"C#3", 1}, {"F3", 0}]
  }

  @levels Map.new(@keys, fn {part, keys} ->
            levels = for {name, db} <- keys, do: {key.(name), db}
            {part, levels}
          end)

  @trumpet for {name, _} <- @keys.trumpet,
               take <- 1..2,
               do:
                 {file.(@vsco, "Brass/Trumpet/stac/Sum_SHTrumpet_stac_#{name}_v3_rr#{take}.wav"),
                  note: key.(name), take: take}

  @trumpet_held for {name, _} <- @keys.trumpet_held,
                    do:
                      {file.(@vsco, "Brass/Trumpet/sus/Sum_SHTrumpet_sus_#{name}_v3_rr1.wav"),
                       note: key.(name)}

  # One take of the trombone's A#2 is named r2.
  @trombone for {name, _} <- @keys.trombone,
                {take, word} <- [{1, "rr1"}, {2, "rr2"}],
                word = if(name == "A#2" and take == 2, do: "r2", else: word),
                path = "Brass/Tenor Trombone/stac/tenortbn_stac_#{name}_v4_#{word}.wav",
                do: {file.(@vsco, path), note: key.(name), take: take}

  @trombone_held for {name, _} <- @keys.trombone_held,
                     do:
                       {file.(@vsco, "Brass/Tenor Trombone/sus/tenortbn_sus_#{name}_v3_1.wav"),
                        note: key.(name)}

  # The alto played hard through its condenser microphone, two takes of each key.
  @alto for name <-
              ~w(d2 eb2 e2 f2 gb2 g2 ab2 a2 bb2 b2 c3 db3 d3 eb3 e3 f3 gb3 g3 ab3 a3 bb3 b3 c4 db4 d4 eb4 e4 f4 gb4 g4 ab4),
            take <- 1..2,
            do:
              {file.(@weresax, "Samples/alto/#{name}_f_rr#{take}_cnd.wav"),
               note: pitch(name) + 12, take: take}

  @tenor for octave <- 2..4,
             name <- ~w(C D E F# G# A#),
             do:
               {file.(
                  @vcsl,
                  "Aerophones/Reed Aerophones/Tenor Saxophone/Non-Vibrato/BrettTenor_NV_Main_#{name}#{octave}_vl3_rr1.wav"
                ), note: key.("#{name}#{octave}")}

  # The tuba's short notes at their hardest, three takes of each.
  @tuba for name <-
              ~w(f0 gb0 g0 ab0 a0 bb0 b0 c1 db1 d1 eb1 e1 f1 gb1 g1 ab1 a1 bb1 b1 c2 db2 d2 eb2 e2 f2 gb2 g2),
            take <- 1..3,
            do:
              {file.(@war_tuba, "Samples/#{name}_s_vl4_rr#{take}_cnd.wav"),
               note: pitch(name) + 12, take: take}

  @drums :virtuosity_drums

  # Each voice of the kit: its drum, its stroke, the strengths and takes recorded, how many beats
  # it rings and fades over, and the part and level of each microphone.
  @kit [
    snare:
      {"snare", "center", 36, nil, {0.5, 0.4},
       [{:snare_snaremic, :snaremic, 0.8}, {:snare_oh, :oh, 0.8}, {:snare_room, :room, 0.5}]},
    rimshot:
      {"snare", "rimshot", 12, nil, {1.5, 1},
       [{:rimshot_snaremic, :snaremic, 0.5}, {:rimshot_oh, :oh, 0.5}, {:rimshot_room, :room, 0.5}]},
    buzz:
      {"snare", "buzz", 12, nil, {0.5, 0.4},
       [{:buzz_snaremic, :snaremic, 0.6}, {:buzz_oh, :oh, 0.6}]},
    kick:
      {"kick", "snon", 4, 4, {1.5, 1},
       [{:kick_kickmic, :kickmic, 0.45}, {:kick_oh, :oh, 0.3}, {:kick_room, :room, 0.2}]},
    low_tom:
      {"ltom", "center", 16, nil, {2, 1}, [{:low_tom_oh, :oh, 0.55}, {:low_tom_room, :room, 0.4}]},
    pedal: {"hh", "pedal", 3, 4, {1, 0.5}, [{:pedal_oh, :oh, 4.5}]},
    crash: {"crash", "crash", 3, 4, {10, 6}, [{:crash_oh, :oh, 0.9}, {:crash_room, :room, 0.5}]}
  ]

  @kit_files (for {voice, {drum, stroke, strengths, takes, _, mics}} <- @kit,
                  {_, mic, _} <- mics,
                  into: %{} do
                files =
                  for strength <- 1..strengths,
                      take <- if(takes, do: Enum.map(1..takes, &"_rr#{&1}"), else: [""]) do
                    name = "#{mic}_#{drum}_#{stroke}_vl#{strength}#{take}.flac"
                    file.(@drums, "Samples/#{mic}/#{drum}/#{name}")
                  end

                {{voice, mic}, files}
              end)

  @room [decay_seconds: 1.5, mix: 0.2]

  part :trumpet, synth: sampled(@trumpet), fx: [level: [amp: 1.2], reverb: @room, pan: [pan: 0.3]]

  part :trumpet_held,
    synth: sampled(@trumpet_held),
    fx: [level: [amp: 0.3], reverb: @room, pan: [pan: 0.3]]

  part :trombone,
    synth: sampled(@trombone),
    fx: [level: [amp: 1.3], reverb: @room, pan: [pan: -0.35]]

  part :trombone_held,
    synth: sampled(@trombone_held),
    fx: [level: [amp: 1.4], reverb: @room, pan: [pan: -0.35]]

  part :alto, synth: sampled(@alto), fx: [level: [amp: 0.45], reverb: @room, pan: [pan: -0.12]]
  part :tenor, synth: sampled(@tenor), fx: [level: [amp: 1.0], reverb: @room, pan: [pan: 0.12]]
  part :tuba, synth: sampled(@tuba), fx: [level: [amp: 0.75]]

  # Each player's part for notes of up to a beat, its part for longer ones, and the beats it plays
  # late.
  # The brass's recordings take longest to speak, so the others wait for them, and the drums
  # longest; the hi-hat's pedal is recorded from the foot's first movement, 0.12 beats before the
  # cymbals close.
  @players %{
    trumpet: {:trumpet, :trumpet_held, 0.02},
    trombone: {:trombone, :trombone_held, 0},
    alto: {:alto, :alto, 0.06},
    tenor: {:tenor, :tenor, 0.06},
    tuba: {:tuba, :tuba, 0.05}
  }
  @drums_late 0.1
  @pedal_early 0.12

  # Each voice of the kit is a part for each of its microphones.
  for {voice, {_, _, _, _, {ring, fade}, mics}} <- @kit, {name, mic, level} <- mics do
    part name,
      synth: sampled(@kit_files[{voice, mic}]),
      defaults: [sustain: ring, release: fade],
      fx: [level: [amp: level]]
  end

  def song do
    :rand.seed(:exsss, {1909, 1, 6})

    band([
      opening(),
      fanfare(:on, 0, 0.8),
      tune(:on, 0, 0.75),
      wind(:back, 0, 0.8),
      handed_round(:higher),
      everyone(:back, 2, 0.9),
      fanfare(:last, 2, 0.9),
      last_chord(2)
    ])
  end

  # The opening: the snare alone, then the feet and the tuba on the dominant, the brass's chords
  # over them, and the tune's first notes from everyone.
  defp opening do
    dominant = List.duplicate(:G7, 4)
    line = for {beat, note, held} <- bass(dominant, 0, 38), do: {beat + 4, note, held}

    call = fn place, around ->
      for {beat, note, held} <- stabs([:G7, :G7], 0, place, around, [1.5, 2.5, 3.5]),
          do: {beat + 8, note, held}
    end

    pickup = for {beat, note, held} <- notes(lead_in()), do: {beat + 12, note, held}
    # The snare alone through the first two bars, with no crash to start.
    drums =
      8
      |> drums()
      |> List.flatten()
      |> Enum.reject(fn {voice, {beat, _}} ->
        voice == :crash or (voice not in [:snare, :buzz, :rimshot] and beat < 4)
      end)

    section(16, [
      tongued(:tuba, line, 0, 0.8),
      tongued(:trumpet, call.(1, 74) ++ call.(3, 77), 0, 0.6),
      tongued(:trombone, call.(2, 62) ++ call.(0, 55), 0, 0.6),
      tongued(:trumpet, pickup, 0, 0.85),
      tongued(:trombone, pickup, -12, 0.85),
      slurred(:alto, pickup, 0, 0.8, 2),
      slurred(:tenor, pickup, -12, 0.8, 2),
      drums
    ])
  end

  # The first part as a frevo de rua plays it: the trumpet's fanfare with the trombone an octave
  # under it, the saxophones answering.
  defp fanfare(ending, key, vel) do
    chords = chords(:first) ++ chords(ending)
    tune = notes(first_part() <> " " <> ending(ending))
    last = if ending == :last, do: [{30, near(74, 1), 0.5}, {31, near(74, 1), 0.5}], else: []

    section(
      32,
      [
        tongued(:trumpet, tune ++ last, key, vel),
        tongued(:trombone, tune ++ last, key - 12, vel),
        saxes_answer(chords, key, vel - 0.1),
        low(chords, key, vel),
        drums(16)
      ]
    )
  end

  # The second part: the saxophones sing the tune in octaves, and the trombones answer with chords
  # off the beat.
  defp tune(ending, key, vel) do
    chords = chords(:second) ++ chords(ending)
    melody = notes(second_part() <> " " <> ending(ending))

    section(
      32,
      [
        slurred(:alto, melody, key, vel, 4),
        slurred(:tenor, melody, key - 12, vel, 4),
        trombones_answer(chords, key, vel - 0.15),
        low(chords, key, vel),
        drums(16)
      ]
    )
  end

  # The second part again as a frevo-ventania: the trumpet plays the tune, the saxophones run it
  # in sixteenths an octave under, and the trombones' chords grow louder.
  defp wind(ending, key, vel) do
    chords = chords(:second) ++ chords(ending)
    melody = notes(second_part() <> " " <> ending(ending))
    close = Enum.filter(melody, fn {beat, _, _} -> beat >= 28 end)
    running = ventania(melody, chords, key)

    section(
      32,
      [
        tongued(:trumpet, melody, key, vel),
        slurred(:alto, running, -12, vel - 0.1, 1),
        slurred(:tenor, running, -12, vel - 0.25, 1),
        slurred(:alto, close, key, vel, 2),
        slurred(:tenor, close, key - 12, vel, 2),
        trombones_answer(chords, key, vel - 0.1),
        low(chords, key, vel),
        drums(16)
      ]
    )
  end

  # The first part handed round: two bars to each player in turn over the tuba and a lighter kit,
  # and its ending from them all.
  defp handed_round(ending) do
    chords = chords(:first) ++ chords(ending)
    tune = notes(first_part() <> " " <> ending(ending))
    turns = [trumpet: 0, alto: 0, trombone: -12, tenor: -12, trumpet: 0, alto: 0, trombone: -12]

    during = fn from, to ->
      Enum.filter(tune, fn {beat, _, _} -> beat >= from and beat < to end)
    end

    solos =
      for {{player, shift}, turn} <- Enum.with_index(turns) do
        mine = during.(turn * 4, turn * 4 + 4)

        if player in [:alto, :tenor] do
          slurred(player, mine, shift, 0.8, 2)
        else
          tongued(player, mine, shift, 0.75)
        end
      end

    close = during.(28, 32)

    section(
      32,
      [
        solos,
        tongued(:trumpet, close, 0, 0.9),
        tongued(:trombone, close, -12, 0.9),
        slurred(:alto, close, 0, 0.85, 2),
        slurred(:tenor, close, -12, 0.85, 2),
        low(chords, 0, 0.7),
        drums(16, 0.75)
      ]
    )
  end

  # The second part from the whole band a tone up: the trumpet and the trombone play it
  # syncopated, and the saxophones run under them.
  defp everyone(ending, key, vel) do
    chords = chords(:second) ++ chords(ending)
    melody = notes(second_part() <> " " <> ending(ending))
    close = Enum.filter(melody, fn {beat, _, _} -> beat >= 28 end)
    running = ventania(melody, chords, key)

    section(
      32,
      [
        tongued(:trumpet, syncopated(melody), key, vel),
        tongued(:trombone, syncopated(melody), key - 12, vel),
        slurred(:alto, running, -12, vel - 0.1, 1),
        slurred(:tenor, running, -12, vel - 0.25, 1),
        slurred(:alto, close, key, vel, 2),
        slurred(:tenor, close, key - 12, vel, 2),
        low(chords, key, vel),
        drums(16)
      ]
    )
  end

  # The last chord: the tonic with its sixth and ninth from the whole band over a roll on the
  # snare, and one short chord to close.
  defp last_chord(key) do
    voices = [
      trumpet: {7, 79},
      trumpet: {4, 76},
      alto: {2, 74},
      alto: {9, 69},
      tenor: {4, 64},
      trombone: {7, 57},
      trombone: {0, 62},
      tuba: {0, 38}
    ]

    chord =
      for {player, {tone, around}} <- voices do
        note = near(around, tone + key)

        [
          sound(player, 0, note, 2.6, 0.9, sustain: 2.6, release: 0.15),
          sound(player, 3, note, 0.5, 1, sustain: 0.4, release: 0.12)
        ]
      end

    roll = for step <- 0..23, do: drum(:buzz, step * 0.125, 0.3 + step * 0.02)

    stroke =
      for {voice, strength} <- [rimshot: 0.95, kick: 0.9, low_tom: 0.8, crash: 0.9],
          do: drum(voice, 3, strength)

    section(6, [chord, drum(:crash, 0, 0.7), drum(:kick, 0, 0.8), roll, stroke])
  end

  # The saxophones under the fanfare: chords on the off-beats, a run up under its long note, and a
  # run down into its ending.
  defp saxes_answer(chords, key, vel) do
    for {player, {place, around}} <- [alto: {1, 72}, tenor: {3, 62}] do
      offs = stabs(chords, key, place, around, [0.5, 1.5, 2.5, 3.5])
      offs = Enum.reject(offs, fn {beat, _, _} -> trunc(beat) in [20, 21, 28, 29] end)
      up = run(near(around - 5, 2 + key), 6, 1, key, 20.5)
      down = run(near(around + 7, 7 + key), 8, -1, key, 28)
      [tongued(player, offs, 0, vel - 0.15), slurred(player, up ++ down, 0, vel, 1)]
    end
  end

  defp trombones_answer(chords, key, vel) do
    [
      tongued(:trombone, stabs(chords, key, 2, 58, [1.5, 2.5, 3.5]), 0, vel),
      tongued(:trombone, stabs(chords, key, 1, 63, [1.5, 2.5, 3.5]), 0, vel)
    ]
  end

  # The tuba's bass under everything.
  defp low(chords, key, vel), do: tongued(:tuba, bass(chords, key, 38), 0, vel)

  # The tune in C as note names, an eighth each unless a length in beats follows the colon; r is a
  # rest.
  defp lead_in, do: "r:1 g5 fs5 g5 fs5 g5 a5"

  defp first_part do
    "g5:1 c5 c5 c5 c5 b4 c5 d5:1 f5 e5 f5 e5 f5 g5 f5:1 d5 d5 d5 d5 c5 d5 e5:1 g5 fs5 g5 fs5 g5 a5 " <>
      "g5 f5 e5 d5 cs5 as4 a4 g4 f4:1.5 a4 a4 f5 e5 d5 d5 c5 g4 c5 c5 b4 a4 b4"
  end

  defp second_part do
    "f5:1 b4:1 e5:1 d5:1 c5:1 g4:1 d5:1 c5:1 b4:1 d5:1 g5:1 fs5:1 g5:1 e5:1 f5:1 e5:1 " <>
      "a4:1 d5:1 e5:1 d5:1 g4:1 c5:1 d5:1 c5:1 b4:1 a5:1 g5:1 b4:1"
  end

  # How a part ends: on into the second part, on into it a tone higher, back to the first part, or
  # for good.
  defp ending(:on), do: "c5:1 a5:2 g5:1"
  defp ending(:higher), do: "c5:1 b5:2 a5:1"
  defp ending(:back), do: "c5 g5:1 fs5 g5 fs5 g5 a5"
  defp ending(:last), do: "c5:1 c5:1 r:2"

  # The chord of each bar of a part, and of the two bars each ending takes.
  defp chords(:first), do: ~w(C C G7 G7 G7 G7 C C C A7 Dm G7 C G7)a
  defp chords(:second), do: ~w(G7 G7 C C G7 G7 C C F F C C G7 G7)a
  defp chords(:on), do: [:C, :C]
  defp chords(:higher), do: [:C, :A7]
  defp chords(:back), do: [:C, :C]
  defp chords(:last), do: [:C, :Db7]

  # A chord's tones as semitones above C: its root, third, fifth, and the sixth or seventh that
  # colours it.
  defp tones(:C), do: [0, 4, 7, 9]
  defp tones(:F), do: [5, 9, 0, 2]
  defp tones(:G7), do: [7, 11, 2, 5]
  defp tones(:A7), do: [9, 1, 4, 7]
  defp tones(:Dm), do: [2, 5, 9, 0]
  defp tones(:Db7), do: [1, 5, 8, 11]

  # The tune's notes as {beat, note, beats}.
  defp notes(words) do
    {notes, _} =
      words
      |> String.split()
      |> Enum.flat_map_reduce(0, fn word, beat ->
        {name, held} =
          case String.split(word, ":") do
            [name] -> {name, 0.5}
            [name, held] -> {name, elem(Float.parse(held), 0)}
          end

        if name == "r" do
          {[], beat + held}
        else
          {[{beat, pitch(name), held}], beat + held}
        end
      end)

    notes
  end

  # The note nearest `around` that is `tone` semitones above some C.
  defp near(around, tone), do: around + Integer.mod(tone - around + 6, 12) - 6

  # A chord's tone by its place, 0 the root, in `key` semitones above C.
  defp tone(chord, place, key), do: Enum.at(tones(chord), place) + key

  # Where a player puts a note written at `beat`: the sixteenth after the beat a little late and
  # the one before the next a little early, as the caixa leans, and never quite where another
  # player puts it.
  defp placed(beat, loose) do
    lean =
      case Float.round(beat - Float.floor(beat * 1.0), 2) do
        0.25 -> 0.012
        0.75 -> -0.02
        _ -> 0
      end

    max(beat + lean + (:rand.uniform() - 0.5) * 2 * loose, 0)
  end

  # How hard a note is played: around `vel`, a little harder the higher it is in its line.
  defp played(vel, note, notes) do
    pitches = for {_, pitch, _} <- notes, do: pitch
    middle = Enum.sum(pitches) / length(notes)
    lift = (note - middle) / 12 * 0.08
    min(max(vel + lift + (:rand.uniform() - 0.5) * 0.08, 0.1), 1)
  end

  # The level that brings a part's note level with its others: that of the recorded key nearest
  # the note.
  defp level(part, note) do
    case @levels[part] do
      nil ->
        1

      keys ->
        {_, db} = Enum.min_by(keys, fn {key, _} -> {abs(key - note), key} end)
        :math.pow(10, db / 20)
    end
  end

  # One note of a player as its part and the moment and sound it plays there.
  defp sound(player, beat, note, held, vel, opts) do
    {short, long, late} = @players[player]
    part = if held <= 1, do: short, else: long
    opts = Keyword.merge([vel: vel, amp: level(part, note)], opts)
    {part, {beat + late, note(note, 0, opts)}}
  end

  # A line played tongued: eighths short, longer notes held to just before the next.
  defp tongued(player, notes, shift, vel) do
    for {beat, note, held} <- notes do
      sustain = if held <= 0.5, do: held * 0.8, else: held - 0.15
      opts = [sustain: sustain, release: 0.12]
      sound(player, placed(beat, 0.012), note + shift, held, played(vel, note, notes), opts)
    end
  end

  # A line played slurred: the notes that follow one another within each `span` beats are one
  # breath, each held into the next and all but the first started softly, and a note repeated is
  # tongued again.
  defp slurred(player, notes, shift, vel, span) do
    notes
    |> Enum.chunk_while(
      [],
      fn
        note, [] ->
          {:cont, [note]}

        {beat, pitch, _} = note, [{before, last, held} | _] = breath ->
          joined = pitch != last and abs(before + held - beat) < 0.01 and held < 1.5
          same_span = trunc(beat / span) == trunc(elem(List.last(breath), 0) / span)

          if joined and same_span do
            {:cont, [note | breath]}
          else
            {:cont, Enum.reverse(breath), [note]}
          end
      end,
      fn breath -> {:cont, Enum.reverse(breath), []} end
    )
    |> Enum.reject(&(&1 == []))
    |> Enum.flat_map(fn breath ->
      last = length(breath) - 1

      for {{beat, note, held}, place} <- Enum.with_index(breath) do
        sustain = if place == last, do: held - min(0.15, held * 0.35), else: held + 0.04
        attack = if place == 0, do: 0.01, else: 0.07
        loud = played(vel, note, notes)
        loud = if place == 0, do: loud, else: loud * 0.9
        opts = [attack: attack, sustain: sustain, release: 0.12]
        sound(player, placed(beat, 0.01), note + shift, 0, loud, opts)
      end
    end)
  end

  # The second part with the second note of each bar come an eighth early, the sincopada
  # brasileira.
  defp syncopated(notes) do
    for {beat, note, held} <- notes do
      cond do
        held == 1 and Integer.mod(trunc(beat), 2) == 0 and beat < 28 -> {beat, note, 0.5}
        held == 1 and Integer.mod(trunc(beat), 2) == 1 and beat < 28 -> {beat - 0.5, note, 1.5}
        true -> {beat, note, held}
      end
    end
  end

  # The frevo-ventania: each quarter of the second part as four sixteenths, the note, the chord's
  # tone under it, the note and the scale's step over it.
  defp ventania(notes, chords, key) do
    scale = for step <- [0, 2, 4, 5, 7, 9, 11], do: Integer.mod(step + key, 12)

    for {beat, note, held} <- notes, held == 1, beat < 28 do
      note = note + key
      chord = Enum.at(chords, div(trunc(beat), 2))

      unders =
        for tone <- tones(chord), under = near(note - 4, tone + key), under < note, do: under

      under = Enum.max(unders)
      over = Enum.find((note + 1)..(note + 3), &(Integer.mod(&1, 12) in scale))

      for {step, sixteenth} <- Enum.with_index([note, under, note, over]) do
        {beat + sixteenth * 0.25, step, 0.25}
      end
    end
    |> List.flatten()
  end

  # A run of sixteenths up or down the key's scale from a note.
  defp run(from, count, direction, key, beat) do
    scale = for step <- [0, 2, 4, 5, 7, 9, 11], do: Integer.mod(step + key, 12)

    from
    |> Stream.iterate(&(&1 + direction))
    |> Stream.filter(&(Integer.mod(&1, 12) in scale))
    |> Enum.take(count)
    |> Enum.with_index(fn note, i -> {beat + i * 0.25, note, 0.25} end)
  end

  # The bass, the root on the first beat of the bar and the fifth on the second, stepping up a
  # semitone into each new chord.
  defp bass(chords, key, around) do
    roots = for chord <- chords, do: near(around, tone(chord, 0, key))

    roots
    |> Enum.zip(tl(roots) ++ [List.last(roots)])
    |> Enum.with_index()
    |> Enum.flat_map(fn {{root, coming}, bar} ->
      fifth = if root + 7 <= around + 7, do: root + 7, else: root - 5

      if coming == root do
        [{bar * 2, root, 0.75}, {bar * 2 + 1, fifth, 0.75}]
      else
        [{bar * 2, root, 0.75}, {bar * 2 + 1, fifth, 0.5}, {bar * 2 + 1.5, coming - 1, 0.5}]
      end
    end)
  end

  # Short chords off the beat, one voice of them: the chord's tone at `place` nearest `around`, on
  # the beats given of every two bars, the last already in the chord to come.
  defp stabs(chords, key, place, around, beats) do
    for unit <- 0..(div(length(chords), 2) - 1), beat <- beats do
      at = unit * 4 + beat

      bar =
        min(
          if(beat >= 3.5, do: div(trunc(at), 2) + 1, else: div(trunc(at), 2)),
          length(chords) - 1
        )

      {at, near(around, tone(Enum.at(chords, bar), place, key)), 0.3}
    end
  end

  # Where the drummer puts a stroke: the second sixteenth of a beat a little late and the third
  # and fourth early, the fourth most, as a caixa leans, and never twice in the same place.
  defp swung(beat) do
    lean =
      case Float.round(beat - Float.floor(beat * 1.0), 2) do
        0.25 -> 0.015
        0.5 -> -0.01
        0.75 -> -0.035
        _ -> 0
      end

    beat + lean + (:rand.uniform() - 0.5) * 0.012
  end

  # One stroke on a voice of the kit at a strength from 0 to 1: the strength picks the recording,
  # and the level is left nearly as recorded.
  defp drum(voice, beat, strength) do
    vel = min(max(strength + (:rand.uniform() - 0.5) * 0.06, 0.03), 1)
    late = if voice == :pedal, do: @drums_late - @pedal_early, else: @drums_late
    {voice, {swung(beat) + late, hit(vel: vel, amp: :math.pow(vel, -0.7))}}
  end

  # The caixa's two bars on the snare: twelve sixteenths, the first, fourth and seventh accented
  # and then the eleventh, with ghost strokes between them, and a press roll through the last beat
  # that grows into the next bar; every fourth time the second bar has an accent more.
  defp caixa(unit, level) do
    accents = if rem(unit, 4) == 3, do: [0, 3, 6, 8, 10], else: [0, 3, 6, 10]

    taps =
      for step <- 0..11 do
        strength = if step in accents, do: 0.8, else: 0.17 - rem(step, 2) * 0.04
        drum(:snare, unit * 4 + step * 0.25, strength * level)
      end

    roll =
      for {strength, step} <- Enum.with_index([0.5, 0.35, 0.5, 0.65]),
          do: drum(:buzz, unit * 4 + 3 + step * 0.25, strength * level)

    taps ++ roll
  end

  # The turn into the next section in place of the roll: four sixteenths that grow, the last two
  # rimshots.
  defp turn(beat, level) do
    for {{voice, strength}, step} <-
          Enum.with_index(snare: 0.55, snare: 0.7, rimshot: 0.8, rimshot: 0.95),
        do: drum(voice, beat + step * 0.25, strength * level)
  end

  # The surdo's part on the feet and the floor tom: the bass drum light on the first beat of the
  # bar and hard on the second with the floor tom open under it, a light stroke before the second
  # beat of every other bar and one more into every eighth bar, and the hi-hat closed between the
  # beats.
  defp surdo(bar, level) do
    more = if rem(bar, 8) == 7, do: [{1.5, 0.55}], else: []
    before = if rem(bar, 2) == 1, do: [{0.75, 0.3}], else: []

    kicks =
      for {beat, strength} <- [{0, 0.2}, {1, 0.8}] ++ before ++ more,
          do: drum(:kick, bar * 2 + beat, strength * level)

    [
      kicks,
      drum(:low_tom, bar * 2 + 1, 0.45 * level),
      drum(:pedal, bar * 2 + 0.5, 0.6),
      drum(:pedal, bar * 2 + 1.5, 0.6)
    ]
  end

  # The kit through some bars: a crash and the bass drum on the first beat, the caixa's part and
  # the surdo's, and the turn at the end.
  defp drums(bars, level \\ 1) do
    units = div(bars, 2)

    caixa =
      for unit <- 0..(units - 1) do
        strokes = caixa(unit, level)

        if unit == units - 1 do
          Enum.filter(strokes, fn {voice, _} -> voice == :snare end) ++
            turn(bars * 2 - 1, level)
        else
          strokes
        end
      end

    crash = drum(:crash, 0, 0.7 * level)
    kick = drum(:kick, 0, 0.7 * level)
    surdo = for bar <- 0..(bars - 1), do: surdo(bar, level)
    [crash, kick, caixa, surdo]
  end

  # A section as its length in beats and each part's sounds.
  defp section(beats, sounds) do
    {beats, sounds |> List.flatten() |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))}
  end

  # The sections one after another, each part playing its sounds of every section, and each voice
  # of the kit through each of its microphones.
  defp band(sections) do
    {starts, total} =
      Enum.map_reduce(sections, 0, fn {beats, _}, start -> {start, start + beats} end)

    played = fn name ->
      sounds =
        for {{_, parts}, start} <- Enum.zip(sections, starts),
            {beat, sound} <- Map.get(parts, name, []),
            do: {start + beat, sound}

      at(sounds, total + 1)
    end

    winds = [:trumpet, :trumpet_held, :trombone, :trombone_held, :alto, :tenor, :tuba]
    wind_parts = for name <- winds, do: part(name, played.(name))

    drum_parts =
      for {voice, {_, _, _, _, _, mics}} <- @kit,
          {name, _, _} <- mics,
          do: part(name, played.(voice))

    together(wind_parts ++ drum_parts)
  end
end
