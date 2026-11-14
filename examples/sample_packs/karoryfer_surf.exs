# Rust Wave, a surf instrumental at 164 bpm for three Karoryfer Samples libraries, each under
# Creative Commons 0: Black And Green Guitars, Growlybass and Big Rusty Drums.
# The green Gretsch plays the lead: a riff of muted strokes on the low strings, then the tune
# tremolo-picked in sixteenths, as surf guitar plays a melody, through a long reverb.
# The black Hofner strums the chords, Em, D, C and B, the Andalusian cadence most surf tunes in a
# minor key go round.
# The Jazz Bass drives in eighths, and the drums play the surf beat, the snare on two, the and of
# two, and four, then move to the floor tom.
# The tremolo picking never plays one recording twice in a row: each note has four takes at each
# of three strengths.
# Download them with mx samples download
# "sfzinstruments/karoryfer.black-and-green-guitars@b3b3249d37dc977a1a297bd2dc053e6d9b6b805c:Samples/green/ord",
# and the same for the other folders named below.
defmodule RustWave do
  use Mx.Song, tempo: 164

  @guitars {"sfzinstruments/karoryfer.black-and-green-guitars",
            "b3b3249d37dc977a1a297bd2dc053e6d9b6b805c"}
  @bass {"sfzinstruments/karoryfer.growlybass", "4f483268fc66b5a6d5781d421c0d11b8d08d3fc6"}
  @drums {"sfzinstruments/karoryfer.big-rusty-drums", "f07ce00df34a46b6b08375be56fe116cf15782bc"}

  file = fn {repo, commit}, path -> {:github, repo, commit, path} end

  # Karoryfer names each note an octave above the pitch mx names it by: its e3 is the guitar's low
  # E.
  key = fn name -> Mx.Notes.parse(name) - 12 end

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
    fx: [level: [amp: 1.6], reverb: [room: 0.85, mix: 0.4], pan: [pan: 0.2]]

  part :harmony,
    synth: sampled(@green),
    defaults: [release: 0.4],
    fx: [level: [amp: 1.1], reverb: [room: 0.85, mix: 0.4], pan: [pan: -0.5]]

  part :riff,
    synth: sampled(@muted),
    defaults: [release: 0.2],
    fx: [level: [amp: 0.6], reverb: [room: 0.8, mix: 0.35], pan: [pan: 0.2]]

  part :rhythm,
    synth: sampled(@black),
    defaults: [release: 0.6],
    fx: [
      level: [amp: 0.9],
      tremolo: [phase: 0.5, depth: 0.5, wave: 3],
      reverb: [room: 0.6, mix: 0.25],
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

  @surf_beat [kick: "9...97..", snare: "..97..8.", hat: "75757575"]

  def song do
    seq([intro(), tune(), tune_in_thirds(), bridge(), tune_again(), ending()])
  end

  # The floor tom alone, growing, then the riff over it.
  defp intro do
    play(
      floor_tom:
        seq([eighths(["5.5.5.5.", "6.6.6.6.", "66666666", "77778899"]), eighths("9.7.9.7.", 8)]),
      kick: seq([rest(16), eighths("9...9...", 8)]),
      snare: seq([rest(16), eighths("......8.", 8)]),
      crash: seq([rest(16), eighths("8.......")]),
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
      floor_tom: eighths("9.7.9.7.", 8),
      kick: eighths("9...9...", 8),
      rimshot: eighths("..8...8.", 8),
      crash: eighths("8.......")
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
      snare: seq([sixteenths("9.779.77........"), rest(12)]),
      high_tom: seq([sixteenths("........8.88...."), rest(12)]),
      floor_tom: seq([sixteenths("............8899"), sixteenths("9..."), rest(11)]),
      kick: seq([rest(4), sixteenths("9..."), rest(11)]),
      crash: seq([rest(4), sixteenths("9..."), rest(11)]),
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
        seq(
          for {step, index} <- Enum.with_index(steps),
              do:
                note(
                  pitch(root) + 12 + step,
                  0.5,
                  dyn(if(rem(index, 2) == 0, do: 0.9, else: 0.7))
                )
        )
      end

    repeat(seq(bars), cycles)
  end

  # The bass in eighths: the root, with the fifth on the and of three and on four.
  defp bass(cycles) do
    bar = fn root, fifth ->
      seq(
        for {note, vel} <- [
              {root, 0.9},
              {root, 0.6},
              {root, 0.7},
              {root, 0.6},
              {root, 0.9},
              {fifth, 0.7},
              {fifth, 0.8},
              {root, 0.6}
            ],
            do: note(note, 0.5, dyn(vel) ++ [sustain: 0.4])
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
      crash: eighths("8.......")
    ] ++ [{cymbal, eighths(if(cymbal == :hat, do: "75757575", else: "85858585"), bars)}]
  end

  # A note at a strength from 0 to 1, likewise.
  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]

  # Bars of a drum, a character to each step: a digit is a stroke of that strength, a dot is
  # silence.
  defp drum(patterns, per_beat) do
    seq(
      for pattern <- List.wrap(patterns) do
        cells = pattern |> String.replace(" ", "") |> String.graphemes()

        hits =
          for {cell, index} <- Enum.with_index(cells),
              cell != ".",
              do: {index / per_beat, hit(stroke(String.to_integer(cell)))}

        if hits == [] do
          rest(length(cells) / per_beat)
        else
          at(hits, length(cells) / per_beat)
        end
      end
    )
  end

  # A stroke from 1, the softest, to 9: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp stroke(strength), do: dyn(strength / 9)
end
