defmodule RustWave do
  @moduledoc """
  Rust Wave, a surf instrumental at 164 bpm for three Karoryfer Samples libraries, each under
  Creative Commons 0: Black And Green Guitars, Growlybass and Big Rusty Drums.
  The green Gretsch plays the lead: a riff of muted strokes on the low strings, then the tune
  tremolo-picked in sixteenths, as surf guitar plays a melody, through a long reverb.
  The black Hofner strums the chords, Em, D, C and B, the Andalusian cadence most surf tunes in a
  minor key go round.
  The Jazz Bass drives in eighths, and the drums play the surf beat, the snare on two, the and of
  two, and four, then move to the floor tom.
  The tremolo picking never plays one recording twice in a row: each note has four takes at each
  of three strengths.
  Download them with mx samples download
  "karoryfer_black_and_green_guitars:Samples/green/ord",
  and the same for the other folders named below.
  """

  use Mx.Song, tempo: 164

  @guitars :karoryfer_black_and_green_guitars
  @bass :karoryfer_growly_bass
  @drums :karoryfer_big_rusty_drums

  file = fn collection, path -> {collection, path} end

  # Karoryfer names each note an octave above the pitch mx names it by: its e3 is the guitar's low
  # E.
  key = fn name -> pitch(name) - 12 end

  @frets ~w(e3 f3 gb3 g3 ab3 a3 bb3 b3 c4 db4 d4 eb4 e4 f4 gb4 g4 ab4 a4 bb4 b4 c5 db5 d5 eb5 e5 f5 gb5 g5 ab5 a5 bb5 b5 c6 db6 d6 eb6 e6)

  # A guitar's open strokes: soft in two takes, medium and hard in four.
  twang = fn guitar ->
    for name <- @frets,
        {dynamic, strength, takes} <- [{"p", 1, 2}, {"mf", 2, 4}, {"f", 3, 4}],
        take <- 1..takes do
      {file.(@guitars, "Samples/#{guitar}/ord/twang_#{name}_#{dynamic}_rr#{take}.wav"),
       note: key.(name), strength: strength, take: take}
    end
  end

  @green twang.("green")
  @black twang.("black")
  @muted for name <- @frets,
             take <- 1..4,
             do:
               {file.(@guitars, "Samples/green/stac/staccato_#{name}_rr#{take}.wav"),
                note: key.(name), take: take}

  @growly for name <- ~w(db2 e2 gb2 a2 c3 eb3 gb3 a3 c4 eb4 gb4 a4 c5 eb5),
              {dynamic, strength} <- [{"pp", 1}, {"p", 2}, {"f", 3}, {"ff", 4}],
              take <- 1..4,
              do:
                {file.(@bass, "sustain/#{name}_#{dynamic}_rr#{take}.wav"),
                 note: key.(name), strength: strength, take: take}

  drum = fn folder -> sampled(file.(@drums, "Samples/#{folder}")) end

  part :lead,
    synth: sampled(@green),
    defaults: [release: 0.4],
    fx: [level: [amp: 1.6], reverb: [decay_seconds: 4, mix: 0.4], pan: [pan: 0.2]]

  part :harmony,
    synth: sampled(@green),
    defaults: [release: 0.4],
    fx: [level: [amp: 1.1], reverb: [decay_seconds: 4, mix: 0.4], pan: [pan: -0.5]]

  part :riff,
    synth: sampled(@muted),
    defaults: [release: 0.2],
    fx: [level: [amp: 0.6], reverb: [decay_seconds: 3.2, mix: 0.35], pan: [pan: 0.2]]

  part :rhythm,
    synth: sampled(@black),
    defaults: [release: 0.6],
    fx: [
      level: [amp: 0.9],
      tremolo: [phase: 0.5, depth: 0.5, wave: 3],
      reverb: [decay_seconds: 1.8, mix: 0.25],
      pan: [pan: -0.35]
    ]

  part :bass, synth: sampled(@growly), defaults: [release: 0.15], fx: [level: [amp: 0.6]]

  part :kick,
    synth: drum.("kick_24/kick/kick"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 0.61]]

  part :kick_overhead,
    synth: drum.("kick_24/kick/oh"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 0.34]]

  part :snare,
    synth: drum.("snare_14/center/top"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 0.41]]

  part :snare_overhead,
    synth: drum.("snare_14/center/oh"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 0.41]]

  part :rimshot,
    synth: drum.("snare_14/rimshot/top"),
    defaults: [sustain: 3, release: 1],
    fx: [level: [amp: 0.41]]

  part :rimshot_overhead,
    synth: drum.("snare_14/rimshot/oh"),
    defaults: [sustain: 3, release: 1],
    fx: [level: [amp: 0.41]]

  part :hat,
    synth: drum.("hihat_14/cl/oh"),
    defaults: [sustain: 1, release: 0.5],
    fx: [level: [amp: 0.54]]

  part :open_hat,
    synth: drum.("hihat_14/ho/oh"),
    defaults: [sustain: 1, release: 0.5],
    fx: [level: [amp: 0.41]]

  part :ride,
    synth: drum.("ride_22/rd/oh"),
    defaults: [sustain: 3, release: 3],
    fx: [level: [amp: 0.68]]

  part :bell,
    synth: drum.("ride_22/bl/oh"),
    defaults: [sustain: 3, release: 3],
    fx: [level: [amp: 0.48]]

  part :high_tom,
    synth: drum.("tom_15/center/oh"),
    defaults: [sustain: 3, release: 2],
    fx: [level: [amp: 0.54]]

  part :floor_tom,
    synth: drum.("tom_18/center/oh"),
    defaults: [sustain: 3, release: 2],
    fx: [level: [amp: 0.54]]

  part :crash,
    synth: drum.("crash_17/cr/oh"),
    defaults: [sustain: 12, release: 6],
    fx: [level: [amp: 0.41]]

  @both [kick: :kick_overhead, snare: :snare_overhead, rimshot: :rimshot_overhead]

  # The four chords, two bars each: the bass's root and fifth, and the Hofner's four strings.
  @chords [
    {:e1, :b1, [:e3, :g3, :b3, :e4]},
    {:d2, :a1, [:d3, :fs3, :a3, :d4]},
    {:c2, :g1, [:c3, :e3, :g3, :c4]},
    {:b1, :fs1, [:b2, :ds3, :fs3, :b3]}
  ]

  @tune [
    e3: 2,
    g3: 2,
    b3: 3,
    a3: 1,
    a3: 2,
    fs3: 2,
    d3: 3,
    e3: 1,
    g3: 2,
    e3: 2,
    c3: 2,
    e3: 1,
    g3: 1,
    fs3: 2,
    ds3: 2,
    b2: 4
  ]

  @harmony [
    g3: 2,
    b3: 2,
    e4: 3,
    c4: 1,
    d4: 2,
    a3: 2,
    fs3: 3,
    a3: 1,
    c4: 2,
    g3: 2,
    e3: 2,
    g3: 1,
    c4: 1,
    b3: 2,
    fs3: 2,
    ds3: 4
  ]

  @surf_beat [kick: ~MX"9...97.."s, snare: ~MX"..97..8."s, hat: ~MX"75757575"s]

  def song do
    seq([intro(), tune(), tune_in_thirds(), bridge(), tune_again(), ending()])
  end

  # The floor tom alone, growing, then the riff over it.
  defp intro do
    play(
      floor_tom:
        seq([
          eighths([~MX"5.5.5.5."s, ~MX"6.6.6.6."s, ~MX"66666666"s, ~MX"77778899"s]),
          eighths(~MX"9.7.9.7."s, 8)
        ]),
      kick: seq([rest(16), eighths(~MX"9...9..."s, 8)]),
      snare: seq([rest(16), eighths(~MX"......8."s, 8)]),
      crash: seq([rest(16), eighths(~MX"8......."s)]),
      riff: seq([rest(16), riff(1)]),
      bass: seq([rest(16), bass(1)])
    )
  end

  # The tune, tremolo-picked on the Gretsch's low strings.
  defp tune do
    play([lead: tremolo(@tune), rhythm: strums(1), bass: bass(1)] ++ beat(8))
  end

  # The tune again with a second guitar a third above it.
  defp tune_in_thirds do
    play(
      [lead: tremolo(@tune), harmony: tremolo(@harmony), rhythm: strums(1), bass: bass(1)] ++
        beat(8)
    )
  end

  # The riff again, the Hofner answering it, over the floor tom.
  defp bridge do
    play(
      riff: riff(1),
      rhythm: strums(1),
      bass: bass(1),
      floor_tom: eighths(~MX"9.7.9.7."s, 8),
      kick: eighths(~MX"9...9..."s, 8),
      rimshot: eighths(~MX"..8...8."s, 8),
      crash: eighths(~MX"8......."s)
    )
  end

  # The tune an octave up, the second guitar now under it, over the ride.
  defp tune_again do
    play(
      [lead: tremolo(@tune, 12), harmony: tremolo(@harmony), rhythm: strums(1), bass: bass(1)] ++
        beat(8, :ride)
    )
  end

  # A bar of drums alone, the last chord, and its ring.
  defp ending do
    play(
      snare: seq([sixteenths(~MX"9.779.77........"s), rest(12)]),
      high_tom: seq([sixteenths(~MX"........8.88...."s), rest(12)]),
      floor_tom: seq([sixteenths(~MX"............8899"s), sixteenths(~MX"9..."s), rest(11)]),
      kick: seq([rest(4), sixteenths(~MX"9..."s), rest(11)]),
      crash: seq([rest(4), sixteenths(~MX"9..."s), rest(11)]),
      rhythm:
        seq([
          rest(4),
          note([:e2, :b2, :e3, :g3, :b3, :e4], 12, dyn(0.9) ++ [strum: 0.06, release: 6])
        ]),
      lead: seq([rest(4), tremolo(e3: 3), note(:e3, 9, dyn(0.9) ++ [release: 6])]),
      bass: seq([rest(4), note(:e1, 12, dyn(0.9) ++ [sustain: 6, release: 3])])
    )
  end

  # The music on each voice, a drum with two microphones playing through both.
  defp play(voices) do
    together(
      for {name, music} <- voices, part <- [name | List.wrap(@both[name])] do
        part(part, music)
      end
    )
  end

  defp eighths(patterns, bars \\ 1), do: repeat(drum(patterns, 2), bars)
  defp sixteenths(patterns), do: drum(patterns, 4)

  # The riff on the low strings, muted: two bars, played on each chord's root.
  defp riff(cycles) do
    steps = [0, 0, 3, 0, 5, 0, 3, 0, 0, 0, 3, 0, 7, 5, 3, 0]

    bars =
      for {root, _, _} <- @chords do
        seq(Enum.with_index(steps), fn {step, index} ->
          note(
            pitch(root) + 12 + step,
            0.5,
            dyn(if(rem(index, 2) == 0, do: 0.9, else: 0.7))
          )
        end)
      end

    repeat(seq(bars), cycles)
  end

  # The bass in eighths: the root, with the fifth on the and of three and on four.
  defp bass(cycles) do
    bar = fn root, fifth ->
      seq(
        [
          {root, 0.9},
          {root, 0.6},
          {root, 0.7},
          {root, 0.6},
          {root, 0.9},
          {fifth, 0.7},
          {fifth, 0.8},
          {root, 0.6}
        ],
        fn {note, vel} -> note(note, 0.5, dyn(vel) ++ [sustain: 0.4]) end
      )
    end

    repeat(seq(for {root, fifth, _} <- @chords, _ <- 1..2, do: bar.(root, fifth)), cycles)
  end

  # A line tremolo-picked in sixteenths: each note struck again every quarter of a beat, harder on
  # the beat.
  defp tremolo(notes, up \\ 0) do
    seq(
      for {name, beats} <- notes, index <- 0..(round(beats * 4) - 1) do
        note(pitch(name) + up, 0.25, dyn(if(rem(index, 4) == 0, do: 0.95, else: 0.7)))
      end
    )
  end

  # The Hofner: the chord strummed down on one and held, then up on the and of two and down on
  # four.
  defp strums(cycles) do
    bar = fn chord ->
      seq([
        note(chord, 1.5, dyn(0.8) ++ [strum: 0.03]),
        note(Enum.reverse(chord), 1.5, dyn(0.5) ++ [strum: 0.02]),
        note(chord, 1, dyn(0.7) ++ [strum: 0.03])
      ])
    end

    repeat(seq(for {_, _, chord} <- @chords, _ <- 1..2, do: bar.(chord)), cycles)
  end

  defp beat(bars, cymbal \\ :hat) do
    [
      kick: eighths(@surf_beat[:kick], bars),
      snare: eighths(@surf_beat[:snare], bars),
      crash: eighths(~MX"8......."s)
    ] ++ [{cymbal, eighths(if(cymbal == :hat, do: ~MX"75757575"s, else: ~MX"85858585"s), bars)}]
  end

  # A note at a strength from 0 to 1, likewise.
  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]

  # Bars of a drum, a character to each step: a digit is a stroke of that strength, a dot is
  # silence.
  defp drum(patterns, per_beat)

  defp drum([%{} | _] = pattern, per_beat), do: drum([pattern], per_beat)

  defp drum(patterns, per_beat) do
    seq(patterns, fn pattern -> steps(pattern, 1 / per_beat, strokes: strokes()) end)
  end

  # A stroke from 1, the softest, to 9: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp strokes, do: for(strength <- 1..9, do: {:"#{strength}", dyn(strength / 9)})
end
