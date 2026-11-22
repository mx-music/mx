defmodule Cosmonauta do
  @moduledoc """
  Cosmonauta, a cumbia in A minor at 96 bpm for three Karoryfer Samples libraries, each under
  Creative Commons 0: Caveman Cosmonaut, Swagbass and Swirly Drums.
  Caveman Cosmonaut is a transistor organ of the 1970s, the instrument that led Peruvian and
  Mexican cumbia bands, and here its reed stop plays the tune through an echo and its flute stop
  the chords off the beat.
  The bass plays the cumbia's long root, then the fifth and the root again.
  Swirly Drums plays the rest: the cowbell on the beats, the hi-hat the long and two short strokes
  a güiro scrapes, the djembe the open tone on two and four, the bongos between, and the snare the
  fills.
  The verse goes between A minor and E seventh, and the chorus down through D minor, A minor and E
  seventh with the tune in thirds.
  The organ's recordings last about three seconds and do not loop, so no note here is longer than
  that.
  The files are fetched as the song loads, about 60 MB.
  """

  use Mx.Song, tempo: 96

  @organ :karoryfer_caveman_cosmonaut
  @bass :karoryfer_swag_bass
  @drums :karoryfer_swirly_drums

  file = fn collection, path -> {collection, path} end

  # The organ names its notes as mx does; the bass names them an octave above.
  key = fn name, octaves -> pitch(name) + 12 * octaves end

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

  part :lead,
    synth: stop.("trompette"),
    defaults: [attack: 0.01, release: 0.08],
    fx: [
      level: [amp: 0.5],
      tremolo: [phase: 0.16, depth: 0.25],
      echo: [phase: 0.375, decay: 2, mix: 0.25],
      reverb: [decay_seconds: 1.8, mix: 0.2],
      pan: [pan: 0.15]
    ]

  part :second,
    synth: stop.("trompette"),
    defaults: [attack: 0.01, release: 0.08],
    fx: [
      level: [amp: 0.35],
      tremolo: [phase: 0.16, depth: 0.25],
      reverb: [decay_seconds: 1.8, mix: 0.2],
      pan: [pan: 0.3]
    ]

  part :chords,
    synth: stop.("flutes"),
    defaults: [release: 0.05],
    fx: [level: [amp: 0.3], reverb: [decay_seconds: 1.5, mix: 0.15], pan: [pan: -0.35]]

  part :bass, synth: sampled(@swag), defaults: [release: 0.1], fx: [level: [amp: 1.7]]

  part :kick,
    synth: kit.("marching_kick", "marching_kick", 22, "_beater"),
    defaults: @hit,
    fx: [level: [amp: 0.75]]

  part :cowbell,
    synth: kit.("cowbell", "cowbell", 9, ""),
    defaults: @hit,
    fx: [level: [amp: 5.0], pan: [pan: 0.3]]

  part :guiro,
    synth: kit.("hat_tight", "hh_tight", 15, ""),
    defaults: [sustain: 0.5, release: 0.2],
    fx: [level: [amp: 5.0], pan: [pan: -0.3]]

  part :djembe,
    synth: kit.("djembe", "djembe", 12, ""),
    defaults: @hit,
    fx: [level: [amp: 1.4], pan: [pan: -0.15]]

  part :high_bongo,
    synth: kit.("hbongo", "hbongo", 10, ""),
    defaults: @hit,
    fx: [level: [amp: 5.0], pan: [pan: 0.4]]

  part :low_bongo,
    synth: kit.("lbongo", "lbongo", 10, ""),
    defaults: @hit,
    fx: [level: [amp: 5.0], pan: [pan: 0.25]]

  part :snare,
    synth: kit.("snare_main", "snare_hit", 12, "_top"),
    defaults: @hit,
    fx: [level: [amp: 1.0], reverb: [decay_seconds: 1.2, mix: 0.15]]

  part :crash,
    synth: kit.("crash", "crash", 12, ""),
    defaults: [sustain: 8, release: 4],
    fx: [level: [amp: 4.0]]

  @chords %{
    am: {:a2, :e2, [:e4, :a4, :c5]},
    e7: {:e2, :b2, [:e4, :gs4, :d5]},
    dm: {:d3, :a2, [:f4, :a4, :d5]}
  }

  @verse ~w(am am e7 e7 e7 e7 am am)a
  @chorus ~w(dm am e7 am dm am e7 am)a

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

  def song do
    seq([intro(), verse(), chorus(), drums_alone(), verse(-12), chorus(), ending()])
  end

  # The percussion one by one, then the bass and the chords.
  defp intro do
    together(
      cowbell: drum(~MX"7...5...7...5..."s, 6),
      guiro: seq([rest(4), drum(~MX"7.557.557.557.55"s, 5)]),
      djembe: seq([rest(8), drum(~MX"....7.......7.6."s, 4)]),
      kick: seq([rest(8), drum(~MX"7.......6......."s, 4)]),
      bass: seq([rest(8), bass(~w(am am e7 am)a)]),
      chords: seq([rest(8), skank(~w(am am e7 am)a)]),
      snare: seq([rest(20), drum(~MX"........6.66.6.7"s)])
    )
  end

  defp verse(up \\ 0) do
    tune =
      for {name, beats} <- @verse_tune,
          do: {if(name == :r, do: :r, else: pitch(name) + up), beats}

    together(
      [
        lead: line(tune),
        bass: bass(@verse),
        chords: skank(@verse),
        snare: seq([rest(28), drum(~MX"........6.66.6.7"s)])
      ] ++
        percussion(8) ++ bongos(8)
    )
  end

  defp chorus do
    together(
      [
        lead: repeat(line(@chorus_tune), 2),
        second: repeat(line(@chorus_thirds), 2),
        bass: bass(@chorus),
        chords: skank(@chorus),
        crash: drum(~MX"7..............."s),
        snare: seq([rest(28), drum(~MX"....6.6.7.77.7.8"s)])
      ] ++ percussion(8) ++ bongos(8)
    )
  end

  # Four bars for the drums over the bass.
  defp drums_alone do
    together(
      [
        bass: bass(~w(am am e7 am)a),
        high_bongo: drum([~MX"5.55.5.55.5.5.55"s, ~MX"5.5.55.5.55.5555"s], 2),
        low_bongo: drum([~MX"...6...6...6..6."s, ~MX"..6...6..6..6.66"s], 2),
        crash: drum(~MX"7..............."s),
        snare: seq([rest(12), drum(~MX"6.6.6.667.777788"s)])
      ] ++ percussion(4)
    )
  end

  # Two chords and a stop.
  defp ending do
    together(
      lead: line(e5: 0.5, gs5: 0.5, b5: 0.5, d6: 0.5, c6: 1, a5: 3, r: 2),
      chords: seq([note([:e4, :gs4, :d5], 2), note([:e4, :a4, :c5], 4, sustain: 3), rest(2)]),
      bass: seq([note(:e2, 2, dyn(0.8)), note(:a2, 6, dyn(0.9))]),
      cowbell: drum(~MX"7...5...7......."s),
      kick: drum([~MX"7.......8......."s, ~MX"................"s]),
      crash: seq([rest(2), drum(~MX"8......."s)]),
      snare: drum(~MX"7.77.7.7........"s)
    )
  end

  # Bars of a drum in sixteenths, a character to each: a digit is a stroke of that strength, a dot
  # is silence.
  defp drum(patterns, bars \\ 1)

  defp drum([%{} | _] = pattern, bars), do: drum([pattern], bars)

  defp drum(patterns, bars) do
    bar = fn pattern -> steps(pattern, 4 / length(pattern), strokes: strokes()) end
    repeat(seq(patterns, bar), bars)
  end

  # The bass: the root for two beats, then the fifth and the root.
  defp bass(chords) do
    seq(chords, fn chord ->
      {root, fifth, _} = @chords[chord]

      seq([
        note(root, 2, dyn(0.8) ++ [sustain: 1.6]),
        note(fifth, 1, dyn(0.6) ++ [sustain: 0.8]),
        note(root, 1, dyn(0.6) ++ [sustain: 0.8])
      ])
    end)
  end

  # The flute stop's chords, short, on the second half of every beat.
  defp skank(chords) do
    seq(
      for chord <- chords, _ <- 1..4 do
        {_, _, notes} = @chords[chord]
        seq([rest(0.5), note(notes, 0.5, sustain: 0.2)])
      end
    )
  end

  # A line of notes and rests, each a name and a length in beats.
  defp line(notes) do
    seq(notes, fn {name, beats} -> if(name == :r, do: rest(beats), else: note(name, beats)) end)
  end

  defp percussion(bars) do
    [
      cowbell: drum(~MX"7...5...7...5..."s, bars),
      guiro: drum(~MX"7.557.557.557.55"s, bars),
      djembe: drum(~MX"....7.......7.6."s, bars),
      kick: drum(~MX"7.......6......."s, bars)
    ]
  end

  defp bongos(bars) do
    [
      high_bongo: drum([~MX"..5...5...5...55"s, ~MX"..5...5...5.5.5."s], div(bars, 2)),
      low_bongo: drum([~MX"............6..."s, ~MX"..........6....6"s], div(bars, 2))
    ]
  end

  # A stroke from 1, the softest, to 9: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp strokes do
    for {stroke, strength} <- Enum.zip(~w(1 2 3 4 5 6 7 8 9)a, 1..9) do
      {stroke, dyn(strength / 9)}
    end
  end

  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]
end
