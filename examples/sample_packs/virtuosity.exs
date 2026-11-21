defmodule Virtuosity do
  @moduledoc """
  House Kit, a feature for Virtuosity Drums: a jazz kit played with sticks by Austin McMahon,
  recorded by Versilian Studios through six microphones, with its percussion, under Creative
  Commons 0.
  The kit plays a mambo, swings, trades fours with the band and comes back to the mambo, at 184
  bpm, over Dm7, G7, Cmaj7 and A7; the bass line is the floor tom, tuned to each note.
  In the mambo the right hand plays the cáscara on the floor tom's rim and then on the ride's
  bell, the left the son clave as cross-sticks, 2-3, and the feet the bombo and the hi-hat on two
  and four.
  In the swing the ride plays its beat with the hi-hat on two and four, the bass drum feathered
  under the walking bass and the snare comping in ghost notes.
  The first four is on the snare and toms in triplets, the second on the toms with the snares off,
  ending in a buzz roll.
  Every stroke picks one of the strengths the kit was recorded at, up to 36 for the snare, and the
  drums sound through their close, overhead and room microphones.
  Download the kit with mx samples download
  "virtuosity_drums:Samples/oh", and the
  same for kickmic, snaremic, room and perc/close.
  """

  use Mx.Song, tempo: 184

  # Each voice of the kit: its drum, its stroke, the strengths and takes recorded, how many beats
  # it rings and fades over, and the part and level of each microphone.
  @kit [
    kick:
      {"kick", "snon", 4, 4, {1.5, 1},
       [{:kick_kickmic, :kickmic, 0.8}, {:kick_oh, :oh, 0.5}, {:kick_room, :room, 0.4}]},
    snare:
      {"snare", "center", 36, nil, {1.5, 1},
       [{:snare_snaremic, :snaremic, 0.7}, {:snare_oh, :oh, 0.7}, {:snare_room, :room, 0.5}]},
    cross_stick:
      {"snare", "crossstick", 16, nil, {2, 1},
       [{:cross_stick_snaremic, :snaremic, 0.9}, {:cross_stick_oh, :oh, 1.0}]},
    rimshot:
      {"snare", "rimshot", 12, nil, {5, 2},
       [{:rimshot_snaremic, :snaremic, 0.5}, {:rimshot_oh, :oh, 0.5}, {:rimshot_room, :room, 0.5}]},
    flam:
      {"snare", "flam", 12, nil, {4, 1.5},
       [{:flam_snaremic, :snaremic, 0.6}, {:flam_oh, :oh, 0.6}, {:flam_room, :room, 0.5}]},
    buzz:
      {"snare", "buzz", 12, nil, {2, 1},
       [{:buzz_snaremic, :snaremic, 0.6}, {:buzz_oh, :oh, 0.6}, {:buzz_room, :room, 0.4}]},
    snares_off:
      {"snareoff", "center", 12, nil, {5, 2},
       [
         {:snares_off_snaremic, :snaremic, 0.6},
         {:snares_off_oh, :oh, 0.6},
         {:snares_off_room, :room, 0.6}
       ]},
    high_tom:
      {"htom", "center", 16, nil, {3, 2},
       [{:high_tom_oh, :oh, 0.8}, {:high_tom_room, :room, 0.6}]},
    low_tom:
      {"ltom", "center", 16, nil, {4, 2}, [{:low_tom_oh, :oh, 0.8}, {:low_tom_room, :room, 0.6}]},
    rim: {"ltom", "crossstick", 10, nil, {2, 1}, [{:rim_oh, :oh, 1.3}, {:rim_room, :room, 0.5}]},
    pedal: {"hh", "pedal", 3, 4, {1.5, 0.5}, [{:pedal_oh, :oh, 2.5}]},
    ride: {"ride", "ride", 3, 4, {4, 3}, [{:ride_oh, :oh, 3.0}]},
    bell: {"ride", "bell", 3, 3, {2, 2}, [{:bell_oh, :oh, 1.6}]},
    crash: {"crash", "crash", 3, 4, {16, 6}, [{:crash_oh, :oh, 0.9}, {:crash_room, :room, 0.5}]},
    sizzle:
      {"crash", "sizzle", 3, 4, {34, 6}, [{:sizzle_oh, :oh, 0.5}, {:sizzle_room, :room, 0.4}]}
  ]

  # Each percussion instrument: its files' names up to the take, softest first, its takes, how it
  # rings, its level and where it sits from left to right.
  @percussion [
    claves: {"claves/Claves1_Hit_v", ~w(1 2 3), 8, {1, 0.5}, 0.6, 0.4},
    cowbell: {"cowbell/Cowbell1_Normal_v", ~w(1 2 3), 7, {1, 0.5}, 0.5, -0.4},
    conga: {"conga/Conga_22_HitN_", ~w(1_50 51_100 101_127), 8, {2, 1}, 1.0, -0.2},
    conga_muted: {"conga/Conga_17_HitHM1_", ~w(1_70 71_127), 8, {1, 0.5}, 1.0, -0.2},
    tumba: {"tumba/Tumba_24_HitN_", ~w(1_40 41_70 71_100 101_127), 8, {3, 1}, 1.0, 0.1},
    guiro_long: {"guiro/Guiro_Med", [""], 8, {1.5, 0.5}, 0.45, 0.5},
    guiro_short: {"guiro/Guiro_Fast", [""], 8, {1, 0.5}, 0.45, 0.5}
  ]

  @clave ~MX"..7.7... 7..7..7."s
  @cascara ~MX"5.8.85.5 8.58.5.5"s
  @bell ~MX"5.9.95.5 9.59.5.5"s

  @walk [
    ~w(d2 f2 a2 ab2)a,
    ~w(g2 b2 d3 db3)a,
    ~w(c3 e3 g2 bb2)a,
    ~w(a2 cs3 e3 eb3)a,
    ~w(d3 c3 a2 f2)a,
    ~w(g2 a2 b2 db3)a,
    ~w(c3 b2 a2 g2)a,
    ~w(a2 g2 e2 cs2)a
  ]

  @ride ~MX"5..8.45..8.4"s
  @feet [pedal: ~MX"...5.....5.."s, kick: ~MX"3..3..3..3.."s]

  @comping [
    ~MX"........3..."s,
    ~MX".....4......"s,
    ~MX"..3........."s,
    ~MX"........5..3"s,
    ~MX"........3..."s,
    ~MX".....4.....3"s,
    ~MX"..3.....4..."s,
    ~MX".....5..3..."s
  ]

  @busier [
    ~MX"..3.....4..3"s,
    ~MX".....5......"s,
    ~MX"..4..3.....4"s,
    ~MX"........6..3"s,
    ~MX"..3..4......"s,
    ~MX".....3..5..3"s,
    ~MX"..4.....3..5"s,
    ~MX"...3.45.67.8"s
  ]

  # A drum's files through one microphone, at each strength and take recorded.
  kit_files = fn mic, drum, stroke, strengths, takes ->
    for strength <- 1..strengths,
        take <- if(takes, do: Enum.map(1..takes, &"_rr#{&1}"), else: [""]) do
      path = "Samples/#{mic}/#{drum}/#{mic}_#{drum}_#{stroke}_vl#{strength}#{take}.flac"
      {:virtuosity_drums, path}
    end
  end

  # Each voice of the kit is a part for each of its microphones.
  for {_voice, {drum, stroke, strengths, takes, {ring, fade}, mics}} <- @kit,
      {name, mic, level} <- mics do
    part name,
      synth: sampled(kit_files.(mic, drum, stroke, strengths, takes)),
      defaults: [sustain: ring, release: fade],
      fx: [level: [amp: level]]
  end

  # Each percussion instrument is a part, recorded close.
  for {name, {prefix, layers, takes, {ring, fade}, level, pan}} <- @percussion do
    files =
      for {layer, strength} <- Enum.with_index(layers, 1), take <- 1..takes do
        path = "Samples/perc/close/#{prefix}#{layer}_rr#{take}_Close.wav"
        {{:virtuosity_drums, path}, strength: strength, take: take}
      end

    part name,
      synth: sampled(files),
      defaults: [sustain: ring, release: fade],
      fx: [level: [amp: level], pan: [pan: pan]]
  end

  # The bass is the floor tom, whose stroke sounds at 113 Hz, halfway from A2 to B flat 2, played
  # faster or slower to each pitch as a timpani would be tuned.
  for {name, mic, level} <- [{:bass_oh, :oh, 0.8}, {:bass_room, :room, 0.35}] do
    files = for file <- kit_files.(mic, "ltom", "center", 16, nil), do: {file, note: 45.49}
    part name, synth: sampled(files), defaults: [vel: 0.6, amp: 1.4], fx: [level: [amp: level]]
  end

  # The last roll's recordings through each microphone.
  part :roll_snaremic, []
  part :roll_oh, []
  part :roll_room, []

  def song do
    seq([
      intro(),
      mambo(),
      mambo_bell(setup()),
      swing(Enum.to_list(0..7), @comping, feathered(8, %{0 => ~MX"7..3..3..3.."s})),
      swing(
        Enum.to_list(0..7),
        @busier,
        feathered(8, %{0 => ~MX"7..3..3..3.."s, 3 => ~MX"3..3....6..3"s, 5 => ~MX"3....6.3..3."s})
      ),
      first_four(),
      swing(Enum.to_list(0..3), Enum.take(@comping, 4), feathered(4, %{0 => ~MX"8..3..3..3.."s})),
      second_four(),
      swing(
        Enum.to_list(4..7),
        List.replace_at(Enum.take(@busier, 4), 3, ~MX"......6..7.8"s),
        feathered(4, %{0 => ~MX"8..3..3..3.."s})
      ),
      mambo_bell([]),
      ending()
    ])
  end

  # The kit alone, then the clave, the congas and the güiro, and the abanico, the timbalero's
  # rimshot and roll into the tune.
  defp intro do
    play(
      [
        rim: repeat(eighths(@cascara), 4),
        pedal: repeat(eighths(~MX"..5...5."s), 8),
        cross_stick: seq([rest(8), repeat(eighths(@clave), 3)]),
        kick: seq([rest(8), repeat(eighths(~MX"...5..3."s), 6)]),
        claves: seq([rest(16), repeat(eighths(@clave), 2)]),
        rimshot: seq([rest(28), eighths(~MX"....8..."s)]),
        buzz: seq([rest(28), eighths(~MX".....468"s)])
      ] ++ later(16, tumbao(2)) ++ later(24, guiro(2))
    )
  end

  # The mambo: the cáscara on the floor tom's rim.
  defp mambo do
    play(
      [
        crash: eighths(~MX"8......."s),
        rim: repeat(eighths(@cascara), 4),
        cross_stick: repeat(eighths(@clave), 4),
        kick: seq([eighths(~MX"8..6..4."s), repeat(eighths(~MX"...6..4."s), 7)]),
        pedal: repeat(eighths(~MX"..5...5."s), 8),
        claves: repeat(eighths(@clave), 4),
        bass: bass_tumbao(2)
      ] ++ tumbao(4) ++ guiro(8)
    )
  end

  # The mambo again with the cáscara on the ride's bell, the campana on the cowbell, and the left
  # hand between a cross-stick on two and the toms on four, as the congas go.
  defp mambo_bell(ending) do
    play(
      [
        crash: eighths(~MX"8......."s),
        bell: repeat(eighths(@bell), 4),
        cowbell: repeat(eighths(~MX"9.4.7.447.447.44"s), 4),
        cross_stick: repeat(eighths(~MX"..7....."s), 8),
        high_tom: seq([repeat(eighths(~MX"......6."s), 7), rest(4)]),
        low_tom: seq([repeat(eighths(~MX".......6"s), 7), rest(4)]),
        kick: seq([eighths(~MX"8..6..4."s), repeat(eighths(~MX"...6..4."s), 7)]),
        pedal: repeat(eighths(~MX"..5...5."s), 8),
        claves: repeat(eighths(@clave), 4),
        bass: bass_tumbao(2)
      ] ++ ending ++ tumbao(4) ++ guiro(8)
    )
  end

  # The fill out of the mambo, on the last bar's three and four.
  defp setup do
    [
      flam: seq([rest(28), eighths(~MX"....8..."s)]),
      snare: seq([rest(28), eighths(~MX"......68"s)])
    ]
  end

  # The swing: the ride's beat, the hi-hat on two and four, the bass drum feathered, and the snare
  # comping.
  defp swing(walk_bars, comping, kicks) do
    bars = length(walk_bars)

    play(
      crash: triplets(~MX"7..........."s),
      ride: repeat(triplets(@ride), bars),
      pedal: repeat(triplets(@feet[:pedal]), bars),
      kick: triplets(kicks),
      snare: triplets(comping),
      bass: walk(walk_bars)
    )
  end

  defp feathered(bars, bombs) do
    for bar <- 0..(bars - 1), do: Map.get(bombs, bar, @feet[:kick])
  end

  # The first four: accents on the snare over ghosted triplets, an answer on the toms, accents
  # every fourth triplet, and a run down the drums.
  defp first_four do
    play(
      pedal: repeat(triplets(@feet[:pedal]), 4),
      snare:
        triplets([
          ~MX"833 833 833 8.."s,
          ~MX".44 .44 8.. ..."s,
          "844 484 448 444",
          ~MX"678 ... ... ..."s
        ]),
      high_tom:
        triplets([
          ~MX"... ... ... ..."s,
          ~MX"8.. 8.. ... ..."s,
          ~MX"... ... ... ..."s,
          ~MX"... 678 ... ..."s
        ]),
      low_tom:
        triplets([
          ~MX"... ... ... ..."s,
          ~MX"... ... .88 8.."s,
          ~MX"... ... ... ..."s,
          ~MX"... ... 789 ..."s
        ]),
      kick:
        triplets([
          ~MX"... ... ... ..6"s,
          ~MX"... ... ... ..."s,
          ~MX"7.. ... ... ..."s,
          ~MX"... ... ... 9.."s
        ]),
      flam:
        triplets([
          ~MX"... ... ... ..."s,
          ~MX"... ... ... ..."s,
          ~MX"... ... ... ..."s,
          ~MX"... ... ... 9.."s
        ])
    )
  end

  # The second four, with the snares off: a tune on the floor tom, the snare drum and the high
  # tom, then a buzz roll that grows into the band.
  defp second_four do
    play(
      pedal: repeat(triplets(@feet[:pedal]), 3),
      low_tom:
        triplets([
          ~MX"7.. ... ... ..."s,
          ~MX"7.. ... ... ..."s,
          ~MX"... 7.. ... 8.."s,
          ~MX"... ... ... ..."s
        ]),
      snares_off:
        triplets([
          ~MX"... ..6 ... 6.."s,
          ~MX"... ..6 ... 6.6"s,
          ~MX"..7 ... ..7 ..."s,
          ~MX"... ... ... ..."s
        ]),
      high_tom:
        triplets([
          ~MX"... ... 7.. ..."s,
          ~MX"... ... 7.7 ..."s,
          ~MX"8.. ... 8.. ..."s,
          ~MX"... ... ... ..."s
        ]),
      kick:
        triplets([
          ~MX"... ... ... ..."s,
          ~MX"... ... ... ..."s,
          ~MX"... 6.. ... .6."s,
          ~MX"7.. ... ... ..."s
        ]),
      buzz:
        triplets([
          ~MX"... ... ... ..."s,
          ~MX"... ... ... ..."s,
          ~MX"... ... ... ..."s,
          "234 456 678 899"
        ])
    )
  end

  # The mambo's last chord: a roll on the snare that grows over two bars, and one stroke on
  # everything.
  defp ending do
    roll = fn name, mic, level ->
      layer = fn strength, opts ->
        sample(
          file("#{mic}/snare/#{mic}_snare_roll_vl#{strength}.wav"),
          0.5,
          [from: 1.0, amp: level] ++ opts
        )
      end

      part(
        name,
        at(
          [
            {0, layer.(3, attack: 1.5, sustain: 1.5, release: 1)},
            {2, layer.(4, attack: 1.5, sustain: 1.5, release: 1)},
            {4.5, layer.(5, attack: 2, sustain: 1.4, release: 0.1)}
          ],
          8
        )
      )
    end

    last = seq([rest(8), eighths(~MX"8......."s)])

    together([
      roll.(:roll_snaremic, "snaremic", 1.5),
      roll.(:roll_oh, "oh", 1.8),
      roll.(:roll_room, "room", 1.5),
      play(
        kick: last,
        rimshot: last,
        low_tom: last,
        sizzle: last,
        crash: last,
        bass:
          seq([
            rest(8),
            note(:d2, 4, vel: 0.9, sustain: 12, release: 4),
            rest(20)
          ])
      )
    ])
  end

  defp play(voices), do: together(for {name, music} <- voices, do: on(name, music))

  # The mambo is written in eighths, eight to a bar, and the swing in triplets, twelve to a bar.
  defp eighths(patterns), do: strokes(patterns, 2)
  defp triplets(patterns), do: strokes(patterns, 3)

  defp later(beats, voices) do
    for {name, music} <- voices, do: {name, seq([rest(beats), music])}
  end

  # The conga tumbao: soft tips, a slap on two and two open tones on four, the last of them on the
  # tumba every other bar.
  defp tumbao(cycles) do
    [
      conga_muted: repeat(eighths(~MX"338333.. 338333.."s), cycles),
      conga: repeat(eighths(~MX"......77 ......7."s), cycles),
      tumba: repeat(eighths(~MX"........ .......8"s), cycles)
    ]
  end

  # The güiro: a long scrape on each beat and two short ones after it.
  defp guiro(bars) do
    [
      guiro_long: repeat(eighths(~MX"6...6..."s), bars),
      guiro_short: repeat(eighths(~MX"..44..44"s), bars)
    ]
  end

  # The bass tumbao: the fifth on the and of two, and the next chord's root on four, held over the
  # bar line.
  defp bass_tumbao(cycles) do
    bars =
      for {fifth, next_root} <- [a2: :g2, d3: :c3, g2: :a2, e2: :d2] do
        seq([
          rest(1.5),
          note(fifth, 1.5, sustain: 1.5, release: 1),
          note(next_root, 1, sustain: 2.5, release: 1)
        ])
      end

    repeat(seq(bars), cycles)
  end

  defp walk(bars) do
    seq(
      for bar <- bars,
          pitch <- Enum.at(@walk, bar),
          do: note(pitch, 1, sustain: 1.2, release: 0.8)
    )
  end

  defp file(path), do: {:virtuosity_drums, "Samples/" <> path}

  # The music on a voice of the kit through each of its microphones, on a percussion instrument,
  # or on the bass.
  defp on(:bass, music), do: together([part(:bass_oh, music), part(:bass_room, music)])

  defp on(name, music) do
    # The hi-hat's pedal was recorded from the foot's first movement, 0.08 beats before the
    # cymbals close, so it starts that much early.
    music = if name == :pedal, do: Mx.swing(music, &(&1 - 0.08)), else: music

    case @kit[name] do
      {_, _, _, _, _, mics} -> together(for {mic_part, _, _} <- mics, do: part(mic_part, music))
      nil -> part(name, music)
    end
  end

  # Bars of strokes, a character to each step: a digit is a stroke of that strength, a dot is
  # silence, and spaces are left out.
  defp strokes(patterns, per_beat)

  defp strokes([%{} | _] = pattern, per_beat), do: strokes([pattern], per_beat)

  defp strokes(patterns, per_beat) do
    seq(for pattern <- patterns, do: steps(pattern, 1 / per_beat, strokes: strengths()))
  end

  # A stroke from 1, the softest, to 9: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp strengths do
    for strength <- 1..9 do
      vel = strength / 9
      {:"#{strength}", [vel: vel, amp: :math.pow(vel, -0.7)]}
    end
  end
end
