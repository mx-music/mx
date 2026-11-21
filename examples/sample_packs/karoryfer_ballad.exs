defmodule SmallHours do
  @moduledoc """
  Small Hours, a slow ballad in D minor at 72 bpm for five Karoryfer Samples libraries, each under
  Creative Commons 0: Weresax, Shinyguitar, Sneakybass, the Karoryfer and Bigcat cello, and Big
  Rusty Drums.
  The alto saxophone plays the tune, softly the first time and harder the second, over an archtop
  guitar, a double bass and brushes.
  The drummer stirs a brush round the snare the whole way through, a recording of nine seconds
  started again every two bars, and taps the other brush on two and four.
  The cello joins under the second time through, then holds the chords while the guitar takes the
  middle four bars alone.
  Every beat is split in three, the long note first, as a slow ballad is played.
  Download them with mx samples download
  "karoryfer_weresax:Samples/alto", and
  the same for the other folders named below.
  """

  use Mx.Song, tempo: 72

  @sax :karoryfer_weresax
  @guitar :karoryfer_shiny_guitar
  @bass :karoryfer_sneaky_bass
  @cello :karoryfer_bigcat_cello
  @drums :karoryfer_big_rusty_drums

  file = fn collection, path -> {collection, path} end

  # The libraries name their notes in different octaves: the saxophone and the cello an octave
  # below the pitch mx names, the bass an octave above, the guitar the same.
  key = fn name, octaves -> Mx.Notes.parse(String.downcase(name)) + 12 * octaves end

  # The saxophone through its condenser microphone: soft and hard, two takes of each.
  @alto for name <-
              ~w(d2 eb2 e2 f2 gb2 g2 ab2 a2 bb2 b2 c3 db3 d3 eb3 e3 f3 gb3 g3 ab3 a3 bb3 b3 c4 db4 d4 eb4 e4 f4 gb4 g4 ab4),
            {dynamic, strength} <- [{"p", 1}, {"f", 2}],
            take <- 1..2,
            do:
              {file.(@sax, "Samples/alto/#{name}_#{dynamic}_rr#{take}_cnd.wav"),
               note: key.(name, 1), strength: strength, take: take}

  # The archtop through its pickup, a note every minor third: four strengths, four takes of each.
  @archtop for name <- ~w(db2 e2 gb2 a2 c3 eb3 gb3 a3 c4 eb4 gb4 a4 c5 eb5 gb5 a5 c6),
               strength <- 1..4,
               take <- 1..4,
               do:
                 {file.(@guitar, "Samples/electric/#{name}_vl#{strength}_rr#{take}_2.wav"),
                  note: key.(name, 0), strength: strength, take: take}

  @upright for name <-
                 ~w(c2 db2 d2 eb2 e2 f2 gb2 g2 ab2 a2 bb2 b2 c3 db3 d3 eb3 e3 f3 gb3 g3 ab3 a3 bb3 b3 c4),
               take <- 1..4,
               do:
                 {file.(@bass, "Samples/finger/sneakybass_#{name}_finger_rr#{take}.wav"),
                  note: key.(name, -1), take: take}

  # The cello bowed, a note every minor third: four strengths, a down bow and an up bow of each.
  @bowed for name <- ~w(C1 Eb1 Gb1 A1 C2 Eb2 Gb2 A2 C3 Eb3 Gb3 A3 C4 Eb4 Gb4 A4 C5),
             {dynamic, strength} <- [{"p", 1}, {"mp", 2}, {"mf", 3}, {"f", 4}],
             {bow, take} <- [{"d", 1}, {"g", 2}],
             do:
               {file.(@cello, "Samples/sus/#{name}_#{dynamic}_#{bow}.wav"),
                note: key.(name, 1), strength: strength, take: take}

  # The brush stirred round the snare, from the overhead microphones: the two middle strengths of
  # four.
  @stir for {layer, strength} <- [{2, 1}, {3, 2}],
            take <- 1..4,
            do:
              {file.(@drums, "Samples/snare_14/bstir/oh/sn_stir_dl#{layer}_rr#{take}.wav"),
               strength: strength, take: take}

  drum = fn folder -> sampled(file.(@drums, "Samples/#{folder}")) end

  part :sax,
    synth: sampled(@alto),
    defaults: [attack: 0.03, release: 0.3],
    fx: [level: [amp: 1.0], reverb: [room: 0.75, mix: 0.3], pan: [pan: 0.1]]

  part :guitar,
    synth: sampled(@archtop),
    defaults: [release: 0.5],
    fx: [level: [amp: 0.9], reverb: [room: 0.6, mix: 0.2], pan: [pan: -0.4]]

  part :solo,
    synth: sampled(@archtop),
    defaults: [release: 0.5],
    fx: [level: [amp: 1.8], reverb: [room: 0.7, mix: 0.3], pan: [pan: -0.2]]

  part :bass, synth: sampled(@upright), defaults: [release: 0.3], fx: [level: [amp: 2.4]]

  part :cello,
    synth: sampled(@bowed),
    defaults: [attack: 0.15, release: 0.6],
    fx: [level: [amp: 2.0], reverb: [room: 0.75, mix: 0.3], pan: [pan: 0.45]]

  part :stir, synth: sampled(@stir), defaults: [attack: 1, release: 1.5], fx: [level: [amp: 8.0]]

  part :tap,
    synth: drum.("snare_14/brush/oh"),
    defaults: [sustain: 1.5, release: 0.5],
    fx: [level: [amp: 2.0]]

  part :dig,
    synth: drum.("snare_14/bdig/oh"),
    defaults: [sustain: 1.5, release: 0.5],
    fx: [level: [amp: 3.0]]

  part :foot,
    synth: drum.("hihat_14/chik/oh"),
    defaults: [sustain: 1, release: 0.5],
    fx: [level: [amp: 0.5]]

  part :ride,
    synth: drum.("ride_22/brush/oh"),
    defaults: [sustain: 3, release: 3],
    fx: [level: [amp: 7.0]]

  part :sizzle,
    synth: drum.("ride_sizzle_19/brush/oh"),
    defaults: [sustain: 8, release: 4],
    fx: [level: [amp: 3.0]]

  part :kick,
    synth: drum.("kick_24/kick/oh"),
    defaults: [sustain: 1.5, release: 1],
    fx: [level: [amp: 1.0]]

  @chords %{
    dm6: [:f3, :b3, :d4, :a4],
    dm7: [:f3, :c4, :d4, :a4],
    em7b5: [:e3, :bb3, :d4, :g4],
    a7: [:g3, :cs4, :e4, :bb4],
    gm7: [:f3, :bb3, :d4, :g4],
    c9: [:e3, :bb3, :d4, :g4],
    fmaj7: [:f3, :a3, :c4, :e4],
    bb9: [:d3, :ab3, :c4, :f4]
  }

  @tune_chords [
    [:dm6],
    [:em7b5, :a7],
    [:dm7],
    [:gm7, :c9],
    [:fmaj7],
    [:bb9],
    [:em7b5, :a7],
    [:dm6]
  ]
  @last_chords [[:dm6], [:bb9], [:em7b5, :a7], [:dm6]]

  @tune [
    r: 1,
    a4: 1,
    d5: 2,
    bb4: 2,
    a4: 1,
    g4: 2 / 3,
    e4: 1 / 3,
    f4: 3,
    r: 2 / 3,
    d4: 1 / 3,
    g4: 2 / 3,
    a4: 1 / 3,
    bb4: 1,
    d5: 1,
    c5: 2 / 3,
    bb4: 1 / 3,
    a4: 3,
    r: 1 + 2 / 3,
    f4: 1 / 3,
    ab4: 1,
    bb4: 2 / 3,
    ab4: 1 / 3,
    f4: 1,
    e4: 1,
    g4: 2 / 3,
    bb4: 1 / 3
  ]

  @falling [a4: 2 / 3, g4: 1 / 3, e4: 2 / 3, cs4: 1 / 3, d4: 3, r: 1]
  @rising [cs5: 1, e5: 2 / 3, f5: 1 / 3, d5: 3, r: 1]

  @tune_bass [
    {:d2, :a1},
    {:e2, :a1},
    {:d2, :c2, :a1},
    {:g1, :c2},
    {:f1, :a1},
    {:bb1, :d2, :f2},
    {:e2, :a1},
    {:d2, :a1, :cs2}
  ]

  part :slowing, []

  def song do
    seq([intro(), tune(), tune_again(), middle(), last_time()])
  end

  # Two bars of brushes, bass and guitar.
  defp intro do
    play(
      stir: stir(2),
      foot: drum(~MX"...2.....2.."s, 2),
      bass: in_two([{:d2, :a1}, {:e2, :a1, :cs2}]),
      guitar: comp([[:dm6], [:em7b5, :a7]])
    )
  end

  # The tune, the saxophone soft.
  defp tune do
    play(
      [
        sax: line(@tune ++ @falling, 0.4),
        guitar: comp(@tune_chords),
        bass: in_two(@tune_bass),
        dig: drum([~MX"............"s, ~MX"...........3"s], 4)
      ] ++ brushes(8)
    )
  end

  # The tune again and harder, ending upward: the bass walks, the ride joins, and the cello holds
  # a line under it.
  defp tune_again do
    play(
      [
        sax: line(@tune ++ @rising, 0.8),
        guitar: comp(@tune_chords),
        bass:
          walk(
            ~w(d2 e2 f2 a2 e2 bb1 a1 cs2 d2 f2 a2 ab2 g2 f2 e2 c2 f1 a1 c2 b1 bb1 d2 f2 eb2 e2 bb1 a1 cs2 d2 a1 d2 fs2)a
          ),
        cello:
          line(
            [f3: 4, g3: 4, f3: 4, f3: 2, e3: 2, e3: 4, d3: 4, d3: 2, cs3: 2, d3: 4],
            0.3
          ),
        ride: drum(~MX"4..3.24..3.2"s, 8)
      ] ++ brushes(8)
    )
  end

  # The middle four bars: the guitar alone on top, the cello holding two notes of each chord.
  defp middle do
    play(
      [
        solo:
          line(
            [
              d4: 1,
              f4: 2 / 3,
              g4: 1 / 3,
              bb4: 2,
              a4: 2 / 3,
              g4: 1 / 3,
              e4: 1,
              g4: 2,
              a4: 1,
              c5: 2 / 3,
              a4: 1 / 3,
              e4: 2,
              d4: 2 / 3,
              e4: 1 / 3,
              g4: 1,
              e4: 1,
              cs4: 1
            ],
            0.7
          ),
        cello:
          seq([
            note([:bb2, :f3], 4, dyn(0.4)),
            note([:bb2, :e3], 4, dyn(0.4)),
            note([:a2, :e3], 4, dyn(0.4)),
            note([:g2, :d3], 2, dyn(0.4)),
            note([:g2, :cs3], 2, dyn(0.4))
          ]),
        bass: walk(~w(g1 bb1 d2 cs2 c2 e2 g2 fs2 f2 c2 a1 f1 e2 bb1 a1 cs2)a),
        ride: drum(~MX"4..3.24..3.2"s, 4),
        kick: drum(~MX"2.....2....."s, 4)
      ] ++ brushes(4)
    )
  end

  # The first bar of the tune, its sixth and its ending, soft again, then two chords and the last
  # one, slowing.
  defp last_time do
    play(
      sax:
        line(
          Enum.take(@tune, 3) ++
            Enum.slice(@tune, 17..21) ++
            [e4: 1, g4: 2 / 3, bb4: 1 / 3, a4: 2, d5: 4, r: 1, ab4: 1, g4: 1, e4: 1, d4: 8],
          0.4
        ),
      guitar:
        seq([
          comp(@last_chords),
          comp([[:bb9, :a7]]),
          note([:d3, :a3, :b3, :e4, :a4], 8, dyn(0.45) ++ [strum: 0.12, release: 4])
        ]),
      bass:
        seq([
          in_two([{:d2, :a1}, {:bb1, :f1}, {:e2, :a1}, {:d2, :a1}, {:bb1, :a1}]),
          note(:d2, 8, dyn(0.8))
        ]),
      cello: seq([rest(20), note([:d2, :a2], 8, dyn(0.3) ++ [release: 2])]),
      stir: stir(6),
      tap: seq([drum(~MX"...4.....5.."s, 5), rest(8)]),
      foot: seq([drum(~MX"...3.....3.."s, 5), rest(8)]),
      sizzle: seq([rest(20), drum(~MX"3..........."s), rest(4)])
    )
    |> then(&together([&1, part(:slowing, seq([rest(16), tempo(54, over: 6)]))]))
  end

  defp play(voices) do
    together(for {name, music} <- voices, do: part(name, music))
  end

  # The stir, started again every two bars, each fading in under the end of the one before.
  defp stir(bars, vel \\ 0.3) do
    seq(for _ <- 1..div(bars, 2), do: at([{0, hit(dyn(vel) ++ [sustain: 8.5])}], 8))
  end

  # Bars of a drum in triplets, a character to each third of a beat: a digit is a stroke of that
  # strength, a dot is silence.
  defp drum(patterns, bars \\ 1)

  defp drum([%{} | _] = pattern, bars), do: drum([pattern], bars)

  defp drum(patterns, bars) do
    bar = fn pattern -> steps(pattern, 4 / length(pattern), strokes: strokes()) end
    repeat(seq(Enum.map(patterns, bar)), bars)
  end

  # The bass in two: a note on one and on three, and now and then a short one leading into the
  # next bar.
  defp in_two(bars) do
    seq(
      for bar <- bars do
        case bar do
          {first, second} ->
            seq([note(first, 2, dyn(0.8)), note(second, 2, dyn(0.7))])

          {first, second, lead} ->
            seq([
              note(first, 2, dyn(0.8)),
              note(second, 1 + 2 / 3, dyn(0.7)),
              note(lead, 1 / 3, dyn(0.6))
            ])
        end
      end
    )
  end

  # The guitar under the tune: each chord strummed slowly and left to ring, and a soft answer on
  # the last third of two when the chord lasts the bar.
  defp comp(bars) do
    seq(
      for bar <- bars do
        case bar do
          [chord] ->
            seq([
              note(@chords[chord], 1 + 2 / 3, dyn(0.45) ++ [strum: 0.06]),
              note(Enum.drop(@chords[chord], 1), 2 + 1 / 3, dyn(0.2) ++ [strum: 0.03])
            ])

          [first, second] ->
            seq([
              note(@chords[first], 2, dyn(0.45) ++ [strum: 0.06]),
              note(@chords[second], 2, dyn(0.45) ++ [strum: 0.06])
            ])
        end
      end
    )
  end

  # A line of notes and rests, each a name and a length in beats.
  defp line(notes, vel, options \\ []) do
    seq(
      for {name, beats} <- notes do
        if name == :r, do: rest(beats), else: note(name, beats, dyn(vel) ++ options)
      end
    )
  end

  defp brushes(bars) do
    [
      stir: stir(bars),
      tap: drum(~MX"...4.....5.."s, bars),
      foot: drum(~MX"...3.....3.."s, bars)
    ]
  end

  # The bass walking, a note to each beat.
  defp walk(notes), do: seq(for name <- notes, do: note(name, 1, dyn(0.8)))

  # A note at a strength from 0 to 1: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp strokes, do: for(strength <- 1..9, do: {:"#{strength}", dyn(strength / 9)})

  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]
end
