import Mx

# Cosmonauta, a cumbia in A minor at 96 bpm for three Karoryfer Samples libraries, each under Creative Commons 0: Caveman Cosmonaut, Swagbass and Swirly Drums.
# Caveman Cosmonaut is a transistor organ of the 1970s, the instrument that led Peruvian and Mexican cumbia bands, and here its reed stop plays the tune through an echo and its flute stop the chords off the beat.
# The bass plays the cumbia's long root, then the fifth and the root again.
# Swirly Drums plays the rest: the cowbell on the beats, the hi-hat the long and two short strokes a güiro scrapes, the djembe the open tone on two and four, the bongos between, and the snare the fills.
# The verse goes between A minor and E seventh, and the chorus down through D minor, A minor and E seventh with the tune in thirds.
# The organ's recordings last about three seconds and do not loop, so no note here is longer than that.
# The files are fetched as the song loads, about 60 MB.
defmodule Cosmonauta do
  import Mx

  @organ {"sfzinstruments/karoryfer.caveman-cosmonaut",
          "9de9bcfcbc6d2b20bea5c1116cd07a310febc339"}
  @bass {"sfzinstruments/karoryfer.swagbass", "9d10fcae71af1975988ddecd5af1c95d372c7355"}
  @drums {"sfzinstruments/karoryfer.swirly-drums", "c40dafe0011cb2e54c0c220ff0fa308a11fc60f5"}

  file = fn {repo, commit}, path -> {:github, repo, commit, path} end

  # The organ names its notes as mx does; the bass names them an octave above.
  key = fn name, octaves -> pitch(String.to_atom(name)) + 12 * octaves end

  @organ_notes ~w(a3 bb3 b3 c4 db4 d4 eb4 e4 f4 gb4 g4 ab4 a4 bb4 b4 c5 db5 d5 eb5 e5 f5 gb5 g5 ab5 a5 bb5 b5 c6 db6 d6 eb6 e6 f6 gb6 g6 ab6 a6)

  stop = fn name ->
    sampled(
      for note <- @organ_notes,
          do: {file.(@organ, "Samples/#{name}_#{note}.wav"), note: key.(note, 0)}
    )
  end

  # The bass, a note every minor third: soft, hard and hardest, four takes of each.
  @swag for name <- ~w(a1 c2 eb2 gb2 a2 c3 eb3 gb3 a3 c4 eb4 gb4 a4),
            {dynamic, strength} <- [{"p", 1}, {"f", 2}, {"fff", 3}],
            take <- 1..4,
            do:
              {file.(@bass, "notes/#{name}_#{dynamic}_rr#{take}.wav"),
               note: key.(name, -1), strength: strength, take: take}

  # A drum of the kit: its strengths, four takes of each, and the microphone when it has two.
  kit = fn folder, stroke, strengths, mic ->
    sampled(
      for strength <- 1..strengths, take <- 1..4 do
        {file.(@drums, "Samples/#{folder}/#{stroke}_vl#{strength}_rr#{take}#{mic}.wav"),
         strength: strength, take: take}
      end
    )
  end

  @hit [sustain: 1.5, release: 0.5]

  @parts [
    lead: [
      synth: stop.("trompette"),
      defaults: [attack: 0.01, release: 0.08],
      fx: [
        level: [amp: 0.5],
        tremolo: [phase: 0.16, depth: 0.25],
        echo: [phase: 0.375, decay: 2, mix: 0.25],
        reverb: [room: 0.6, mix: 0.2],
        pan: [pan: 0.15]
      ]
    ],
    second: [
      synth: stop.("trompette"),
      defaults: [attack: 0.01, release: 0.08],
      fx: [
        level: [amp: 0.35],
        tremolo: [phase: 0.16, depth: 0.25],
        reverb: [room: 0.6, mix: 0.2],
        pan: [pan: 0.3]
      ]
    ],
    chords: [
      synth: stop.("flutes"),
      defaults: [release: 0.05],
      fx: [level: [amp: 0.3], reverb: [room: 0.5, mix: 0.15], pan: [pan: -0.35]]
    ],
    bass: [synth: sampled(@swag), defaults: [release: 0.1], fx: [level: [amp: 1.7]]],
    kick: [
      synth: kit.("marching_kick", "marching_kick", 22, "_beater"),
      defaults: @hit,
      fx: [level: [amp: 0.75]]
    ],
    cowbell: [
      synth: kit.("cowbell", "cowbell", 9, ""),
      defaults: @hit,
      fx: [level: [amp: 5.0], pan: [pan: 0.3]]
    ],
    guiro: [
      synth: kit.("hat_tight", "hh_tight", 15, ""),
      defaults: [sustain: 0.5, release: 0.2],
      fx: [level: [amp: 5.0], pan: [pan: -0.3]]
    ],
    djembe: [
      synth: kit.("djembe", "djembe", 12, ""),
      defaults: @hit,
      fx: [level: [amp: 1.4], pan: [pan: -0.15]]
    ],
    high_bongo: [
      synth: kit.("hbongo", "hbongo", 10, ""),
      defaults: @hit,
      fx: [level: [amp: 5.0], pan: [pan: 0.4]]
    ],
    low_bongo: [
      synth: kit.("lbongo", "lbongo", 10, ""),
      defaults: @hit,
      fx: [level: [amp: 5.0], pan: [pan: 0.25]]
    ],
    snare: [
      synth: kit.("snare_main", "snare_hit", 12, "_top"),
      defaults: @hit,
      fx: [level: [amp: 1.0], reverb: [room: 0.4, mix: 0.15]]
    ],
    crash: [
      synth: kit.("crash", "crash", 12, ""),
      defaults: [sustain: 8, release: 4],
      fx: [level: [amp: 4.0]]
    ]
  ]

  def play(voices) do
    together(for {name, music} <- voices, do: part(name, music, @parts[name]))
  end

  # A stroke from 1, the softest, to 9: the strength picks the recording, and the level is left nearly as recorded.
  defp stroke(strength), do: dyn(strength / 9)
  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]

  # Bars of a drum in sixteenths, a character to each: a digit is a stroke of that strength, a dot is silence.
  def drum(patterns, bars \\ 1) do
    bar = fn pattern ->
      hits =
        for {cell, index} <- Enum.with_index(String.graphemes(pattern)),
            cell != ".",
            do: {index / 4, hit(stroke(String.to_integer(cell)))}

      at(hits, 4)
    end

    repeat(seq(Enum.map(List.wrap(patterns), bar)), bars)
  end

  def percussion(bars) do
    [
      cowbell: drum("7...5...7...5...", bars),
      guiro: drum("7.557.557.557.55", bars),
      djembe: drum("....7.......7.6.", bars),
      kick: drum("7.......6.......", bars)
    ]
  end

  def bongos(bars) do
    [
      high_bongo: drum(["..5...5...5...55", "..5...5...5.5.5."], div(bars, 2)),
      low_bongo: drum(["............6...", "..........6....6"], div(bars, 2))
    ]
  end

  @chords %{
    am: {:a2, :e2, [:e4, :a4, :c5]},
    e7: {:e2, :b2, [:e4, :gs4, :d5]},
    dm: {:d3, :a2, [:f4, :a4, :d5]}
  }

  @verse ~w(am am e7 e7 e7 e7 am am)a
  @chorus ~w(dm am e7 am dm am e7 am)a

  # The bass: the root for two beats, then the fifth and the root.
  def bass(chords) do
    seq(
      for chord <- chords do
        {root, fifth, _} = @chords[chord]

        seq([
          note(root, 2, dyn(0.8) ++ [sustain: 1.6]),
          note(fifth, 1, dyn(0.6) ++ [sustain: 0.8]),
          note(root, 1, dyn(0.6) ++ [sustain: 0.8])
        ])
      end
    )
  end

  # The flute stop's chords, short, on the second half of every beat.
  def skank(chords) do
    seq(
      for chord <- chords, _ <- 1..4 do
        {_, _, notes} = @chords[chord]
        seq([rest(0.5), note(notes, 0.5, sustain: 0.2)])
      end
    )
  end

  # A line of notes and rests, each a name and a length in beats.
  def line(notes) do
    seq(for {name, beats} <- notes, do: if(name == :r, do: rest(beats), else: note(name, beats)))
  end

  @verse_tune [
    r: 0.5,
    e5: 0.5,
    a5: 0.5,
    c6: 0.5,
    b5: 0.5,
    a5: 0.5,
    e5: 1,
    c6: 1,
    b5: 0.5,
    a5: 0.5,
    e5: 2,
    r: 0.5,
    e5: 0.5,
    gs5: 0.5,
    b5: 0.5,
    a5: 0.5,
    gs5: 0.5,
    e5: 1,
    b5: 1,
    a5: 0.5,
    gs5: 0.5,
    e5: 2,
    r: 0.5,
    d5: 0.5,
    e5: 0.5,
    gs5: 0.5,
    b5: 1,
    d6: 1,
    c6: 0.5,
    b5: 0.5,
    gs5: 0.5,
    e5: 0.5,
    d5: 2,
    r: 0.5,
    c5: 0.5,
    e5: 0.5,
    a5: 0.5,
    c6: 1,
    b5: 0.5,
    a5: 0.5,
    a5: 3,
    r: 1
  ]

  @chorus_tune [
    f5: 1.5,
    e5: 0.5,
    d5: 1,
    a5: 1,
    e5: 1.5,
    d5: 0.5,
    c5: 2,
    d5: 1.5,
    c5: 0.5,
    b4: 1,
    gs5: 1,
    a5: 2,
    r: 2
  ]

  @chorus_thirds [
    d5: 1.5,
    c5: 0.5,
    a4: 1,
    f5: 1,
    c5: 1.5,
    b4: 0.5,
    a4: 2,
    b4: 1.5,
    a4: 0.5,
    gs4: 1,
    e5: 1,
    c5: 2,
    r: 2
  ]

  # The percussion one by one, then the bass and the chords.
  def intro do
    play(
      cowbell: drum("7...5...7...5...", 6),
      guiro: seq([rest(4), drum("7.557.557.557.55", 5)]),
      djembe: seq([rest(8), drum("....7.......7.6.", 4)]),
      kick: seq([rest(8), drum("7.......6.......", 4)]),
      bass: seq([rest(8), bass(~w(am am e7 am)a)]),
      chords: seq([rest(8), skank(~w(am am e7 am)a)]),
      snare: seq([rest(20), drum("........6.66.6.7")])
    )
  end

  def verse(up \\ 0) do
    tune =
      for {name, beats} <- @verse_tune,
          do: {if(name == :r, do: :r, else: pitch(name) + up), beats}

    play(
      [
        lead: line(tune),
        bass: bass(@verse),
        chords: skank(@verse),
        snare: seq([rest(28), drum("........6.66.6.7")])
      ] ++
        percussion(8) ++ bongos(8)
    )
  end

  def chorus do
    play(
      [
        lead: repeat(line(@chorus_tune), 2),
        second: repeat(line(@chorus_thirds), 2),
        bass: bass(@chorus),
        chords: skank(@chorus),
        crash: drum("7..............."),
        snare: seq([rest(28), drum("....6.6.7.77.7.8")])
      ] ++ percussion(8) ++ bongos(8)
    )
  end

  # Four bars for the drums over the bass.
  def drums_alone do
    play(
      [
        bass: bass(~w(am am e7 am)a),
        high_bongo: drum(["5.55.5.55.5.5.55", "5.5.55.5.55.5555"], 2),
        low_bongo: drum(["...6...6...6..6.", "..6...6..6..6.66"], 2),
        crash: drum("7..............."),
        snare: seq([rest(12), drum("6.6.6.667.777788")])
      ] ++ percussion(4)
    )
  end

  # Two chords and a stop.
  def ending do
    play(
      lead: line(e5: 0.5, gs5: 0.5, b5: 0.5, d6: 0.5, c6: 1, a5: 3, r: 2),
      chords: seq([note([:e4, :gs4, :d5], 2), note([:e4, :a4, :c5], 4, sustain: 3), rest(2)]),
      bass: seq([note(:e2, 2, dyn(0.8)), note(:a2, 6, dyn(0.9))]),
      cowbell: drum("7...5...7......."),
      kick: drum(["7.......8.......", "................"]),
      crash: seq([rest(2), drum("8.......")]),
      snare: drum("7.77.7.7........")
    )
  end

  def music do
    seq([intro(), verse(), chorus(), drums_alone(), verse(-12), chorus(), ending()])
  end
end

song(tempo: 96, music: Cosmonauta.music())
