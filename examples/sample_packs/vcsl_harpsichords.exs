defmodule Prelude do
  @moduledoc """
  Bach's Prelude in C, BWV 846, the first of the Well-Tempered Clavier, on the harpsichords and
  organs of VCSL, Versilian Studios' Versilian Community Sample Library, under Creative Commons 0.
  The prelude is one figure through 34 bars: two notes held in the left hand and three in the
  right played twice over them, so each bar is written here as its five notes, checked against
  music21's encoding of the score.
  It changes instrument at its cadences so that each can be heard alone: the Italian harpsichord
  to the cadence in G, the French to the cadence in C, the English with its lute stop for the four
  bars that leave C, and the Flemish over the long G in the bass and to the end.
  From the French harpsichord on, the Renaissance organ's 8-foot stop holds the two left-hand
  notes, and under the Flemish the pipe organ's quiet pedal holds the bass.
  VCSL names each key an octave below the pitch mx names it by, and records each instrument at
  every second or third key.
  The files are fetched as the song loads, about 320 MB.
  """

  use Mx.Song, tempo: 72

  # Every octave's keys of a whole-tone row, with the keys that are recorded outside it.
  rows = fn keys, octaves, more ->
    more ++ for octave <- octaves, key <- keys, do: "#{key}#{octave}"
  end

  tones = ~w(C D E F# G# A#)

  # Each instrument's folder, how its files are named, and the keys it was recorded at.
  @instruments [
    italian:
      {"Chordophones/Zithers/Harpsichord, Italian/Sustains/stop1", "Harpsichord_stop1_", "_1",
       rows.(~w(C# D# E F# G# A# B), 1..4, ~w(F#0 G#0 A#0 B0))},
    french:
      {"Chordophones/Zithers/Harpsichord, French/Sustains", "Harpsi2_Normal_", "_rr1_Main",
       rows.(tones, 1..4, ~w(D0 G#0 A#0 C5))},
    english:
      {"Chordophones/Zithers/Harpsichord, English/Sustains/Lute", "ZuckermannKitHarpsi_Lute_Sus_",
       "_rr1", rows.(tones, 1..4, ~w(A#0 C5 D5 E5)) -- ["C2"]},
    flemish:
      {"Chordophones/Zithers/Harpsichord, Flemish/Sustains/Low", "HarpsiRH_Low_Far_", "_rr1",
       rows.(tones, 1..4, ~w(F#0 G#0 A#0 C5))},
    organ:
      {"Aerophones/Edge-blown Aerophones/Renaissance Organ/8'", "RenOrgan_8foot_Room_", "_rr1",
       rows.(tones, 1..4, ~w(C5 D5 E5))},
    pedal:
      {"Aerophones/Edge-blown Aerophones/Pipe Organ/Quiet Pedal", "NT5_PedalQuiet_", "_rr1",
       rows.(~w(C D# F# A), 1..2, ~w(C3 D#3 F#3))}
  ]

  @harpsichord [defaults: [release: 0.25], reverb: [decay_seconds: 1.5, mix: 0.15]]

  @settings [
    italian: [level: 1.8] ++ @harpsichord,
    french: [level: 2.1] ++ @harpsichord,
    english: [level: 2.1] ++ @harpsichord,
    flemish: [level: 2.0] ++ @harpsichord,
    organ: [
      level: 1.0,
      defaults: [attack: 0.05, release: 0.3],
      reverb: [decay_seconds: 2.3, mix: 0.25]
    ],
    pedal: [
      level: 1.5,
      defaults: [attack: 0.05, release: 0.4],
      reverb: [decay_seconds: 2.3, mix: 0.25]
    ]
  ]

  # A part's options: its instrument's recorded keys, an octave below the pitch mx names them by,
  # and its settings.
  options = fn name ->
    {folder, prefix, suffix, keys} = @instruments[name]
    settings = @settings[name]

    files =
      for key <- keys do
        note = key |> String.downcase() |> String.replace("#", "s") |> pitch()
        path = "#{folder}/#{prefix}#{key}#{suffix}.wav"
        {{:vcsl, path}, note: note + 12}
      end

    [
      synth: sampled(files),
      defaults: settings[:defaults],
      fx: [level: [amp: settings[:level]], reverb: settings[:reverb]]
    ]
  end

  part :italian, options.(:italian)
  part :french, options.(:french)
  part :english, options.(:english)
  part :flemish, options.(:flemish)
  part :organ, options.(:organ)
  part :pedal, options.(:pedal)

  # Bars 1 to 31, each as the two held notes and the three above them.
  @bars [
    ~w(c4 e4 g4 c5 e5)a,
    ~w(c4 d4 a4 d5 f5)a,
    ~w(b3 d4 g4 d5 f5)a,
    ~w(c4 e4 g4 c5 e5)a,
    ~w(c4 e4 a4 e5 a5)a,
    ~w(c4 d4 fs4 a4 d5)a,
    ~w(b3 d4 g4 d5 g5)a,
    ~w(b3 c4 e4 g4 c5)a,
    ~w(a3 c4 e4 g4 c5)a,
    ~w(d3 a3 d4 fs4 c5)a,
    ~w(g3 b3 d4 g4 b4)a,
    ~w(g3 bb3 e4 g4 cs5)a,
    ~w(f3 a3 d4 a4 d5)a,
    ~w(f3 ab3 d4 f4 b4)a,
    ~w(e3 g3 c4 g4 c5)a,
    ~w(e3 f3 a3 c4 f4)a,
    ~w(d3 f3 a3 c4 f4)a,
    ~w(g2 d3 g3 b3 f4)a,
    ~w(c3 e3 g3 c4 e4)a,
    ~w(c3 g3 bb3 c4 e4)a,
    ~w(f2 f3 a3 c4 e4)a,
    ~w(fs2 c3 a3 c4 eb4)a,
    ~w(ab2 f3 b3 c4 d4)a,
    ~w(g2 f3 g3 b3 d4)a,
    ~w(g2 e3 g3 c4 e4)a,
    ~w(g2 d3 g3 b3 f4)a,
    ~w(g2 eb3 a3 c4 fs4)a,
    ~w(g2 e3 g3 c4 g4)a,
    ~w(g2 d3 g3 c4 f4)a,
    ~w(g2 d3 g3 b3 f4)a,
    ~w(c2 c3 g3 bb3 e4)a
  ]

  # Bars 32 and 33: the two held notes for the whole bar, and one run over them.
  @runs %{
    32 => {:c2, :c3, ~w(f3 a3 c4 f4 c4 a3 c4 a3 f3 a3 f3 d3 f3 d3)a},
    33 => {:c2, :b2, ~w(g4 b4 d5 f5 d5 b4 d5 b4 g4 b4 d4 f4 e4 d4)a}
  }

  def song do
    seq([
      together(italian: seq(1..11, &bar/1)),
      together(french: seq(12..19, &bar/1), organ: held(12..19)),
      together(english: seq(20..23, &bar/1), organ: held(20..23)),
      together(flemish: seq(24..34, &bar/1), organ: held(24..34), pedal: bass(24..34))
    ])
  end

  # The two held notes of each bar, for the whole bar.
  defp held(range) do
    seq(range, fn number ->
      case number do
        34 ->
          note([:c2, :c3], 8)

        number when number >= 32 ->
          run = Tuple.to_list(@runs[number])
          note(Enum.take(run, 2), 4)

        number ->
          bar = Enum.at(@bars, number - 1)
          note(Enum.take(bar, 2), 4)
      end
    end)
  end

  # The bass alone.
  defp bass(range) do
    seq(range, fn number ->
      note(if(number <= 30, do: :g2, else: :c2), if(number == 34, do: 8, else: 4))
    end)
  end

  # A bar as the harpsichord plays it: the figure twice, its first two notes held under the other
  # three.
  defp bar(number) when number <= 31 do
    [bass, tenor, first, second, third] = Enum.at(@bars, number - 1)
    upper = for name <- [first, second, third, first, second, third], do: note(name, 0.25)

    half =
      together([
        note(bass, 2),
        seq([rest(0.25), note(tenor, 0.75, sustain: 1.75), rest(1)]),
        seq([rest(0.5) | upper])
      ])

    seq([half, half])
  end

  defp bar(number) when number in [32, 33] do
    {bass, tenor, run} = @runs[number]

    together([
      note(bass, 4),
      seq([rest(0.25), note(tenor, 3.75)]),
      seq([rest(0.5) | Enum.map(run, &note(&1, 0.25))])
    ])
  end

  defp bar(34), do: note([:c2, :c3, :e4, :g4, :c5], 8, strum: 0.08)
end
