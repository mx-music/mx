# Scott Joplin's Maple Leaf Rag, of 1899, on the four pianos of VCSL, Versilian Studios' Versilian
# Community Sample Library, under Creative Commons 0.
# A rag is a march in form: strains of sixteen bars, each played twice, here the first, the
# second, the first again, the trio and the last.
# Each strain has its own piano so that they can be compared on the same music: the Knight upright
# for the first strain each time it comes, the Yamaha upright for the second, the Kawai grand for
# the trio and the Steinway B grand for the last.
# The notes are imported by mix mx.import from the encoding of the rag in music21's corpus,
# maple_leaf_rag.mxl.
# VCSL names the keys of the uprights and of the Kawai an octave below the pitch mx names them by,
# and the Steinway's at their pitch, and records the Yamaha only at every C and G.
# One strength of each piano is used, of the two to four recorded, and only the keys its strain
# needs; the files are fetched as the song loads, about 480 MB.
defmodule MapleLeafRag do
  use Mx.Song, tempo: 96

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
  @folder "Chordophones/Zithers"

  tones = fn keys, octaves, more ->
    more ++ for octave <- octaves, key <- keys, do: "#{key}#{octave}"
  end

  # Each piano's folder, how its files are named, how far its names are from the pitch, and the
  # keys used.
  @pianos [
    knight:
      {"Upright Piano, Knight/Sustains", "Player_vl2_rr1_", "", 12,
       tones.(~w(C# D# F G A B), 1..4, ~w(A0 B0 C#5 D#5 F5 G5 A5))},
    yamaha:
      {"Upright Piano, Yamaha/Sustains", "Upright1_Sus_", "_vl2_rr1", 12,
       tones.(~w(C G), 1..5, [])},
    kawai:
      {"Grand Piano, Kawai/Sustains", "GPiano_sus_", "_v3_rr1_Player", 12,
       tones.(~w(C D E F# G# A#), 2..4, ~w(A0 C1 D#1 F#1 A1 B4 C5 D#5))},
    steinway:
      {"Grand Piano, Steinway B/Sus", "JHPiano_Sus_Close_", "_vl3_rr1", 0,
       tones.(~w(C D E F# G# A#), 2..5, ~w(G#1 A#1 C6))}
  ]

  # The pianos are recorded at very different levels, so each has its own.
  @levels [knight: 0.65, yamaha: 1.2, kawai: 1.4, steinway: 0.4]

  # A piano's part: its recorded keys, each with the pitch it sounds, and its level.
  piano = fn name ->
    {folder, prefix, suffix, octave, keys} = @pianos[name]

    files =
      for key <- keys do
        note = key |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
        path = "#{@folder}/#{folder}/#{prefix}#{key}#{suffix}.wav"
        {{:github, @repo, @commit, path}, note: note + octave}
      end

    [
      synth: sampled(files),
      defaults: [release: 0.3],
      fx: [level: [amp: @levels[name]], reverb: [room: 0.4, mix: 0.12]]
    ]
  end

  part :knight, piano.(:knight)
  part :yamaha, piano.(:yamaha)
  part :kawai, piano.(:kawai)
  part :steinway, piano.(:steinway)

  # The strains in the order the score plays them, its repeats taken with their first and second
  # endings.
  def song do
    seq([
      strain(:knight, [0..0, 1..15, 16..16, 1..15, 17..17]),
      strain(:yamaha, [18..32, 33..33, 18..32, 34..34]),
      strain(:knight, [35..50]),
      strain(:kawai, [51..65, 66..66, 51..65, 67..67]),
      strain(:steinway, [68..82, 83..83, 68..82, 84..84])
    ])
  end

  # Bars of the score on one of the pianos.
  defp strain(name, bars) do
    part(name, seq(Enum.map(Enum.concat(bars), &bar/1)))
  end

  defp bar(0), do: together([seq(r: 0.5), seq([note([:eb2, :eb3], 0.5)])])

  defp bar(1) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note([:eb4, :eb5], 0.25),
        note(:ab4, 0.25),
        note(:c5, 0.25),
        note([:eb4, :eb5], 0.5),
        note(:g4, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(2) do
    together([
      seq([
        note([:eb4, :eb5], 0.25),
        note(:g4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :eb5], 0.25, sustain: [1.25, 1.25]),
        rest(1)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(3) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note([:eb4, :eb5], 0.25),
        note(:ab4, 0.25),
        note(:c5, 0.25),
        note([:eb4, :eb5], 0.5),
        note(:g4, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(4) do
    together([
      seq([
        note([:eb4, :eb5], 0.25),
        note(:g4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :eb5], 0.25, sustain: [0.75, 0.75]),
        rest(0.5),
        rest(0.25),
        note([:eb4, :eb5], 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(5) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note(:cb5, 0.25),
        note([:fb4, :fb5], 0.25),
        rest(0.25),
        note([:eb4, :eb5], 0.25),
        rest(0.25),
        note([:eb4, :eb5], 0.25)
      ]),
      seq([note([:fb2, :fb3], 1), note([:eb2, :eb3], 0.5), note([:eb2, :eb3], 0.5)])
    ])
  end

  defp bar(6) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note(:cb5, 0.25),
        note([:fb4, :fb5], 0.25),
        rest(0.25),
        note([:eb4, :eb5], 0.25),
        rest(0.5)
      ]),
      seq([note([:fb2, :fb3], 1), note([:eb2, :eb3], 0.5), rest(0.5)])
    ])
  end

  defp bar(7) do
    together([
      seq(r: 2),
      seq(r: 0.25, ab2: 0.25, cb3: 0.25, ab3: 0.25, r: 0.25, ab3: 0.25, cb4: 0.25, ab4: 0.25),
      seq(ab1: 0.5, r: 0.5, ab2: 0.5, r: 0.5)
    ])
  end

  defp bar(8) do
    together([
      seq(r: 0.25, ab4: 0.25, cb5: 0.25, ab5: 0.25, r: 0.25, ab5: 0.25, cb6: 0.25, ab6: 0.25),
      seq(ab3: 0.5, r: 0.5, ab4: 0.5, r: 0.5)
    ])
  end

  defp bar(9) do
    together([
      seq([
        note([:ab5, :ab6], 0.5),
        note([:ab5, :ab6], 0.5),
        note([:ab5, :ab6], 0.5),
        note([:ab5, :ab6], 0.25),
        note([:ab5, :ab6], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:d4, :f4, :ab4, :b4], 0.5),
        note([:d4, :f4, :ab4, :b4], 0.5),
        note([:d4, :f4, :ab4, :b4], 0.5),
        note([:d4, :f4, :ab4, :b4], 0.5)
      ])
    ])
  end

  defp bar(10) do
    together([
      seq([
        rest(0.25),
        note(:eb6, 0.25),
        note(:f6, 0.25),
        note(:c6, 0.25),
        note(:eb6, 0.25),
        note([:ab5, :f6], 0.5),
        note([:fb5, :ab5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5)
      ])
    ])
  end

  defp bar(11) do
    together([
      seq([
        rest(0.25),
        note(:bb5, 0.25),
        note([:fb5, :cb6], 0.25),
        note(:ab5, 0.25),
        note(:bb5, 0.25),
        note([:eb5, :c6], 0.5),
        note(:ab5, 0.25)
      ]),
      seq([
        note([:fb4, :ab4, :cb5], 0.5),
        note([:fb4, :ab4, :cb5], 0.5),
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5)
      ])
    ])
  end

  defp bar(12) do
    together([
      seq([
        note([:eb5, :c6], 0.25),
        note(:ab5, 0.25),
        note([:eb5, :bb5], 0.5),
        note([:eb5, :ab5], 0.5),
        rest(0.25),
        note([:ab4, :ab5], 0.25, sustain: [0.75, 0.75])
      ]),
      seq([
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :g4, :db5], 0.5),
        note([:ab4, :c5], 0.5),
        rest(0.5)
      ])
    ])
  end

  defp bar(13) do
    together([
      seq([
        rest(0.5),
        note([:ab4, :ab5], 0.5),
        note([:ab4, :ab5], 0.5),
        note([:ab4, :ab5], 0.25),
        note([:ab4, :ab5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:d3, :f3, :ab3, :b3], 0.5),
        note([:d3, :f3, :ab3, :b3], 0.5),
        note([:d3, :f3, :ab3, :b3], 0.5),
        note([:d3, :f3, :ab3, :b3], 0.5)
      ])
    ])
  end

  defp bar(14) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.5),
        note([:fb4, :ab4], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(15) do
    together([
      seq([
        rest(0.25),
        note(:bb4, 0.25),
        note([:fb4, :cb5], 0.25),
        note(:ab4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :c5], 0.5),
        note(:ab4, 0.25)
      ]),
      seq([
        note([:fb3, :ab3, :cb4], 0.5),
        note([:fb3, :ab3, :cb4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(16) do
    together([
      seq([
        note([:eb4, :c5], 0.25),
        note(:ab4, 0.25),
        note([:eb4, :bb4], 0.5),
        note([:eb4, :ab4], 0.5),
        rest(0.5)
      ]),
      seq([
        note([:eb3, :g3, :c4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(17) do
    together([
      seq([
        note([:eb4, :c5], 0.25),
        note(:ab4, 0.25),
        note([:eb4, :bb4], 0.5),
        note([:eb4, :ab4], 0.5),
        rest(0.5)
      ]),
      seq([
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:ab3, :c4], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(18) do
    together([
      seq([
        rest(0.25),
        note(:g5, 0.25),
        note([:eb5, :eb6], 0.25),
        note(:g5, 0.25),
        note(:bb5, 0.25),
        note([:d5, :d6], 0.5),
        note(:g5, 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.25),
        rest(0.25),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :g3, :db4], 0.5)
      ])
    ])
  end

  defp bar(19) do
    together([
      seq([
        note([:db5, :db6], 0.25),
        note(:g5, 0.25),
        note(:bb5, 0.25),
        note([:c5, :c6], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:eb5, 0.25),
        note([:bb4, :bb5], 0.25),
        note(:eb5, 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:g2, :g3], 0.5)
      ])
    ])
  end

  defp bar(20) do
    together([
      seq([
        rest(0.25),
        note(:c5, 0.25),
        note([:ab4, :ab5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:f4, :f5], 0.5),
        note(:c5, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(21) do
    together([
      seq([
        note([:ab4, :ab5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:f4, :f5], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:c5, 0.25),
        note([:f4, :f5], 0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:ab2, :ab3], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(22) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:g4, :g5], 0.25),
        note(:bb4, 0.25),
        note(:db5, 0.25),
        note([:f4, :f5], 0.5),
        note(:eb5, 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :g3, :db4], 0.5)
      ])
    ])
  end

  defp bar(23) do
    together([
      seq([
        note([:g4, :g5], 0.25),
        note(:bb4, 0.25),
        note(:db5, 0.25),
        note([:f4, :f5], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:db5, 0.25),
        note([:f4, :f5], 0.5)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:bb2, :bb3], 0.5),
        note([:b2, :b3], 0.5)
      ])
    ])
  end

  defp bar(24) do
    together([
      seq([
        rest(0.25),
        note(:c5, 0.25),
        note([:ab4, :ab5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:f4, :f5], 0.5),
        note(:c5, 0.25)
      ]),
      seq([
        note([:c3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(25) do
    together([
      seq([
        note([:ab4, :ab5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:f4, :f5], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:c5, 0.25),
        note([:f4, :f5], 0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:ab2, :ab3], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(26) do
    together([
      seq([
        rest(0.25),
        note(:g5, 0.25),
        note([:eb5, :eb6], 0.25),
        note(:g5, 0.25),
        note(:bb5, 0.25),
        note([:d5, :d6], 0.5),
        note(:g5, 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :g3, :db4], 0.5)
      ])
    ])
  end

  defp bar(27) do
    together([
      seq([
        note([:db5, :db6], 0.25),
        note(:g5, 0.25),
        note(:bb5, 0.25),
        note([:c5, :c6], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:eb5, 0.25),
        note([:bb4, :bb5], 0.25),
        note(:eb5, 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:g2, :g3], 0.5)
      ])
    ])
  end

  defp bar(28) do
    together([
      seq([
        rest(0.25),
        note(:c5, 0.25),
        note([:ab4, :ab5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:f4, :f5], 0.5),
        note(:c5, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(29) do
    together([
      seq([
        note([:ab4, :ab5], 0.5),
        note([:ab4, :ab5], 0.5),
        note([:g4, :g5], 0.5),
        note([:gb4, :gb5], 0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:ab2, :ab3], 0.5),
        note([:g2, :g3], 0.5),
        note([:gb2, :gb3], 0.5)
      ])
    ])
  end

  defp bar(30) do
    together([
      seq(r: 0.25, f4: 0.25, a4: 0.25, c5: 0.25, f5: 0.25, c5: 0.25, a4: 0.25, f4: 0.25),
      seq([
        note([:f2, :f3], 0.5),
        note([:f2, :f3], 0.5),
        note([:a2, :a3], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(31) do
    together([
      seq([
        rest(0.25),
        note(:f4, 0.25),
        note(:bb4, 0.25),
        note(:db5, 0.25),
        note([:f4, :f5], 0.5),
        note([:f4, :bb4, :db5], 0.5)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:f3, :bb3, :db4], 0.5),
        note([:f3, :bb3, :db4], 0.5),
        note([:f3, :bb3, :db4], 0.5)
      ])
    ])
  end

  defp bar(32) do
    together([
      seq([
        note([:d4, :f4, :ab4, :c5], 0.5),
        rest(0.25),
        note([:d4, :f4, :ab4, :c5], 0.25),
        rest(0.25),
        note([:db4, :bb4], 0.5),
        note(:eb4, 0.25)
      ]),
      seq([
        note([:bb2, :f3, :bb3], 0.5),
        note([:bb2, :f3, :bb3], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:g2, :g3], 0.5)
      ])
    ])
  end

  defp bar(33) do
    together([
      seq([
        note([:c4, :ab4], 0.5),
        note([:eb4, :eb5], 0.5),
        note([:eb4, :eb5], 0.5),
        note([:eb4, :eb5], 0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(34) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :ab5], 0.5),
        rest(0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:ab3, :c4, :eb4], 0.5),
        note([:ab3, :c4, :eb4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(35) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note([:eb4, :eb5], 0.25),
        note(:ab4, 0.25),
        note(:c5, 0.25),
        note([:eb4, :eb5], 0.5),
        note(:g4, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(36) do
    together([
      seq([
        note([:eb4, :eb5], 0.25),
        note(:g4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :eb5], 0.25, sustain: [1.25, 1.25]),
        rest(1)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(37) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note([:eb4, :eb5], 0.25),
        note(:ab4, 0.25),
        note(:c5, 0.25),
        note([:eb4, :eb5], 0.5),
        note(:g4, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(38) do
    together([
      seq([
        note([:eb4, :eb5], 0.25),
        note(:g4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :eb5], 0.25, sustain: [0.75, 0.75]),
        rest(0.5),
        rest(0.25),
        note([:eb4, :eb5], 0.25)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(39) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note(:cb5, 0.25),
        note([:fb4, :fb5], 0.25),
        rest(0.25),
        note([:eb4, :eb5], 0.25),
        rest(0.25),
        note([:eb4, :eb5], 0.25)
      ]),
      seq([note([:fb2, :fb3], 1), note([:eb2, :eb3], 0.5), note([:eb2, :eb3], 0.5)])
    ])
  end

  defp bar(40) do
    together([
      seq([
        rest(0.25),
        note(:ab4, 0.25),
        note(:cb5, 0.25),
        note([:fb4, :fb5], 0.25),
        rest(0.25),
        note([:eb4, :eb5], 0.25),
        rest(0.5)
      ]),
      seq([note([:fb2, :fb3], 1), note([:eb2, :eb3], 0.5), rest(0.5)])
    ])
  end

  defp bar(41) do
    together([
      seq(r: 2),
      seq(r: 0.25, ab2: 0.25, cb3: 0.25, ab3: 0.25, r: 0.25, ab3: 0.25, cb4: 0.25, ab4: 0.25),
      seq(ab1: 0.5, r: 0.5, ab2: 0.5, r: 0.5)
    ])
  end

  defp bar(42) do
    together([
      seq(r: 0.25, ab4: 0.25, cb5: 0.25, ab5: 0.25, r: 0.25, ab5: 0.25, cb6: 0.25, ab6: 0.25),
      seq(ab3: 0.5, r: 0.5, ab4: 0.5, r: 0.5)
    ])
  end

  defp bar(43) do
    together([
      seq([
        note([:ab5, :ab6], 0.5),
        note([:ab5, :ab6], 0.5),
        note([:ab5, :ab6], 0.5),
        note([:ab5, :ab6], 0.25),
        note([:ab5, :ab6], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:d4, :f4, :ab4, :b4], 0.5),
        note([:d4, :f4, :ab4, :b4], 0.5),
        note([:d4, :f4, :ab4, :b4], 0.5),
        note([:d4, :f4, :ab4, :b4], 0.5)
      ])
    ])
  end

  defp bar(44) do
    together([
      seq([
        rest(0.25),
        note(:eb6, 0.25),
        note(:f6, 0.25),
        note(:c6, 0.25),
        note(:eb6, 0.25),
        note([:ab5, :f6], 0.5),
        note([:fb5, :ab5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5)
      ])
    ])
  end

  defp bar(45) do
    together([
      seq([
        rest(0.25),
        note(:bb5, 0.25),
        note([:fb5, :cb6], 0.25),
        note(:ab5, 0.25),
        note(:bb5, 0.25),
        note([:eb5, :c6], 0.5),
        note(:ab5, 0.25)
      ]),
      seq([
        note([:fb4, :ab4, :cb5], 0.5),
        note([:fb4, :ab4, :cb5], 0.5),
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :ab4, :c5], 0.5)
      ])
    ])
  end

  defp bar(46) do
    together([
      seq([
        note([:eb5, :c6], 0.25),
        note(:ab5, 0.25),
        note([:eb5, :bb5], 0.5),
        note([:eb5, :ab5], 0.5),
        rest(0.25),
        note([:ab4, :ab5], 0.25, sustain: [0.75, 0.75])
      ]),
      seq([
        note([:eb4, :ab4, :c5], 0.5),
        note([:eb4, :g4, :db5], 0.5),
        note([:ab4, :c5], 0.5),
        rest(0.5)
      ])
    ])
  end

  defp bar(47) do
    together([
      seq([
        rest(0.5),
        note([:ab4, :ab5], 0.5),
        note([:ab4, :ab5], 0.5),
        note([:ab4, :ab5], 0.25),
        note([:ab4, :ab5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:d3, :f3, :ab3, :b3], 0.5),
        note([:d3, :f3, :ab3, :b3], 0.5),
        note([:d3, :f3, :ab3, :b3], 0.5),
        note([:d3, :f3, :ab3, :b3], 0.5)
      ])
    ])
  end

  defp bar(48) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.5),
        note([:fb4, :ab4], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(49) do
    together([
      seq([
        rest(0.25),
        note(:bb4, 0.25),
        note([:fb4, :cb5], 0.25),
        note(:ab4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :c5], 0.5),
        note(:ab4, 0.25)
      ]),
      seq([
        note([:fb3, :ab3, :cb4], 0.5),
        note([:fb3, :ab3, :cb4], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(50) do
    together([
      seq([
        note([:eb4, :c5], 0.25),
        note(:ab4, 0.25),
        note([:eb4, :bb4], 0.5),
        note([:eb4, :ab4], 0.5),
        note([:ab4, :ab5], 0.5)
      ]),
      seq([
        note([:eb3, :g3, :c4], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:ab3, :c4], 0.5),
        rest(0.5)
      ])
    ])
  end

  defp bar(51) do
    together([
      seq([
        note([:ab4, :c5, :eb5, :ab5], 0.75),
        note([:bb4, :c5, :eb5, :ab5], 0.25, sustain: [0.5, 0.5, 0.5, 0.5]),
        rest(0.25),
        note([:c5, :eb5], 0.25),
        note(:bb4, 0.5)
      ]),
      seq([
        note([:eb2, :eb3], 0.5),
        note([:ab3, :c4, :gb4], 0.5),
        note([:gb2, :gb3], 0.5),
        note([:ab3, :c4, :gb4], 0.5)
      ])
    ])
  end

  defp bar(52) do
    together([
      seq([
        note([:ab4, :c5, :eb5, :ab5], 0.75),
        note([:bb4, :c5, :eb5, :ab5], 0.25, sustain: [0.5, 0.5, 0.5, 0.5]),
        rest(0.25),
        note([:c5, :eb5], 0.25),
        note(:bb4, 0.25),
        note([:c5, :eb5], 0.25)
      ]),
      seq([
        note([:f2, :f3], 0.5),
        note([:ab3, :c4, :gb4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:c2, :c3], 0.5)
      ])
    ])
  end

  defp bar(53) do
    together([
      seq(ab4: 0.25, db5: 0.25, bb4: 0.25, db5: 0.25, f5: 0.25, ab4: 0.25, db5: 0.25, f5: 0.25),
      seq([
        note([:db2, :db3], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:ab2, :ab3], 0.5),
        note([:ab3, :db4, :f4], 0.5)
      ])
    ])
  end

  defp bar(54) do
    together([
      seq([
        note(:bb4, 0.25),
        note(:db5, 0.25),
        note(:f5, 0.25),
        note(:ab4, 0.25, sustain: 0.5),
        rest(0.25),
        note(:f5, 0.25),
        note(:bb4, 0.25),
        note(:f5, 0.25)
      ]),
      seq([
        note([:f2, :f3], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:db2, :db3], 0.5),
        note([:d2, :d3], 0.5)
      ])
    ])
  end

  defp bar(55) do
    together([
      seq([
        note([:ab4, :c5, :eb5, :ab5], 0.75),
        note([:bb4, :c5, :eb5, :ab5], 0.25, sustain: [0.5, 0.5, 0.5, 0.5]),
        rest(0.25),
        note([:c5, :eb5], 0.25),
        note(:bb4, 0.5)
      ]),
      seq([
        note([:eb2, :eb3], 0.5),
        note([:ab3, :c4, :gb4], 0.5),
        note([:gb2, :gb3], 0.5),
        note([:ab3, :c4, :gb4], 0.5)
      ])
    ])
  end

  defp bar(56) do
    together([
      seq([
        note([:ab4, :c5, :eb5, :ab5], 0.75),
        note([:bb4, :c5, :eb5, :ab5], 0.25, sustain: [0.5, 0.5, 0.5, 0.5]),
        rest(0.25),
        note([:c5, :eb5], 0.25),
        note(:bb4, 0.25),
        note([:c5, :eb5], 0.25)
      ]),
      seq([
        note([:f2, :f3], 0.5),
        note([:ab3, :c4, :gb4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:c2, :c3], 0.5)
      ])
    ])
  end

  defp bar(57) do
    together([
      seq(ab4: 0.25, db5: 0.25, bb4: 0.25, db5: 0.25, f5: 0.25, ab4: 0.25, db5: 0.25, f5: 0.25),
      seq([
        note([:db2, :db3], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:ab2, :ab3], 0.5),
        note([:ab3, :db4, :f4], 0.5)
      ])
    ])
  end

  defp bar(58) do
    together([
      seq([
        note(:bb4, 0.25),
        note(:db5, 0.25),
        note(:f5, 0.25),
        note(:ab4, 0.25, sustain: 0.5),
        rest(0.25),
        note(:f5, 0.25),
        note(:a4, 0.25),
        note([:eb5, :f5], 0.25)
      ]),
      seq([
        note([:f2, :f3], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:db2, :db3], 0.5),
        note([:c2, :c3], 0.5)
      ])
    ])
  end

  defp bar(59) do
    together([
      seq([
        note([:bb4, :d5, :f5, :bb5], 0.75),
        note([:c5, :d5, :f5, :bb5], 0.25, sustain: [0.5, 0.5, 0.5, 0.5]),
        rest(0.25),
        note([:d5, :f5], 0.25),
        note(:c5, 0.5)
      ]),
      seq([
        note([:bb1, :bb2], 0.5),
        note([:bb3, :d4, :ab4], 0.5),
        note([:d2, :d3], 0.5),
        note([:bb3, :d4, :ab4], 0.5)
      ])
    ])
  end

  defp bar(60) do
    together([
      seq([
        note([:bb4, :d5, :f5, :bb5], 0.75),
        note([:c5, :d5, :f5, :bb5], 0.25, sustain: [0.5, 0.5, 0.5, 0.5]),
        rest(0.25),
        note([:d5, :f5], 0.25),
        note(:c5, 0.25),
        note([:d5, :f5], 0.25)
      ]),
      seq([
        note([:f2, :f3], 0.5),
        note([:bb3, :d4, :ab4], 0.5),
        note([:bb1, :bb2], 0.5),
        note([:bb3, :d4, :ab4], 0.5)
      ])
    ])
  end

  defp bar(61) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:bb4, :bb5], 0.25),
        note(:eb5, 0.25),
        note(:gb5, 0.25),
        note([:c5, :c6], 0.5),
        note(:eb5, 0.25)
      ]),
      seq([
        note([:eb2, :eb3], 0.5),
        note([:bb3, :eb4, :gb4], 0.5),
        note([:bb2, :bb3], 0.5),
        note([:bb3, :eb4, :gb4], 0.5)
      ])
    ])
  end

  defp bar(62) do
    together([
      seq([
        note([:bb4, :bb5], 0.25),
        note(:eb5, 0.25),
        note(:gb5, 0.25),
        note([:c5, :c6], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:eb5, 0.25),
        note([:bb4, :bb5], 0.5)
      ]),
      seq([
        note([:eb2, :eb3], 0.5),
        note([:bb3, :eb4, :gb4], 0.5),
        note([:gb2, :gb3], 0.5),
        note([:bb3, :eb4, :gb4], 0.5)
      ])
    ])
  end

  defp bar(63) do
    together([
      seq([
        note([:db5, :fb5, :db6], 0.5),
        note([:db5, :fb5, :db6], 0.5),
        note([:c5, :fb5, :c6], 0.5),
        note([:c5, :fb5, :bb5], 0.5)
      ]),
      seq(g3: 0.25, bb3: 0.5, db4: 0.25, fb4: 0.25, db4: 0.25, bb3: 0.25, g3: 0.25)
    ])
  end

  defp bar(64) do
    together([
      seq([
        note([:ab4, :f5], 0.25),
        note(:db5, 0.25),
        note(:eb5, 0.25),
        note([:bb4, :gb5], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:bb4, 0.25),
        note([:ab4, :f5], 0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note(:bb2, 0.5),
        note([:ab3, :bb3, :d4], 0.5)
      ])
    ])
  end

  defp bar(65) do
    together([
      seq([
        note([:g4, :f5], 0.25),
        note(:db5, 0.25),
        note(:eb5, 0.25),
        note([:gb4, :f5], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:c5, 0.25),
        note([:gb4, :eb5], 0.25),
        note([:f4, :db5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:eb3, :bb3, :db4], 0.5),
        note([:eb3, :bb3, :db4], 0.5),
        note([:ab3, :c4], 0.5),
        note([:ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(66) do
    together([
      seq([
        rest(0.25),
        note([:ab4, :ab5], 0.5),
        note(:f5, 0.25),
        note([:ab4, :ab5], 0.25),
        note(:f5, 0.25),
        note([:ab4, :ab5], 0.25),
        note(:f5, 0.25)
      ]),
      seq([
        note([:db3, :db4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:d2, :d3], 0.5)
      ])
    ])
  end

  defp bar(67) do
    together([
      seq([
        rest(0.25),
        note(:db5, 0.25),
        note(:f5, 0.25),
        note(:ab5, 0.25),
        note([:db5, :db6], 0.5),
        rest(0.5)
      ]),
      seq([
        note([:db3, :db4], 0.5),
        note([:ab2, :ab3], 0.5),
        note([:db2, :db3], 0.5),
        note([:c3, :c4], 0.5)
      ])
    ])
  end

  defp bar(68) do
    together([
      seq([
        note([:ab4, :ab5], 0.5),
        note([:ab4, :f5], 0.5),
        note([:ab4, :ab5], 0.5),
        note([:ab4, :f5], 0.5)
      ]),
      seq([
        note([:db3, :db4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:c3, :c4], 0.5)
      ])
    ])
  end

  defp bar(69) do
    together([
      seq([
        note([:f5, :ab5], 0.5),
        note([:f5, :bb5], 0.25),
        note([:f5, :c6], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:bb5, 0.25),
        note(:ab5, 0.25),
        note(:f5, 0.25)
      ]),
      seq([
        note([:db3, :db4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:bb2, :bb3], 0.5),
        note([:b2, :b3], 0.5)
      ])
    ])
  end

  defp bar(70) do
    together([
      seq([
        note(:eb5, 0.25),
        note(:f5, 0.5),
        note([:ab4, :c5], 0.25, sustain: [1.25, 1.25]),
        rest(1)
      ]),
      seq([
        note([:c3, :c4], 0.5),
        note([:ab3, :c4, :eb4], 0.5),
        note([:ab3, :c4, :eb4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(71) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.5),
        note(:c5, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(72) do
    together([
      seq([
        note([:g4, :eb5], 0.5),
        note(:f5, 0.25),
        note([:g4, :bb4], 0.25, sustain: [1.25, 1.25]),
        rest(1)
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:a2, :a3], 0.5)
      ])
    ])
  end

  defp bar(73) do
    together([
      seq([
        rest(0.25),
        note(:db5, 0.25),
        note([:g4, :f5], 0.25),
        note(:bb4, 0.25),
        note(:db5, 0.25),
        note([:g4, :f5], 0.5),
        note([:ab4, :c5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:bb2, :bb3], 0.5),
        note([:eb3, :g3, :db4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:g2, :g3], 0.5)
      ])
    ])
  end

  defp bar(74) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.5),
        note([:ab4, :c5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(75) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.5),
        note(:eb5, 0.25)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:bb2, :bb3], 0.5),
        note([:c3, :c4], 0.5)
      ])
    ])
  end

  defp bar(76) do
    together([
      seq([
        note([:ab4, :ab5], 0.5),
        note([:ab4, :f5], 0.5),
        note([:ab4, :ab5], 0.5),
        note([:ab4, :f5], 0.5)
      ]),
      seq([
        note([:db3, :db4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:c3, :c4], 0.5)
      ])
    ])
  end

  defp bar(77) do
    together([
      seq([
        note([:f5, :ab5], 0.5),
        note([:f5, :bb5], 0.25),
        note([:f5, :c6], 0.25, sustain: [0.5, 0.5]),
        rest(0.25),
        note(:bb5, 0.25),
        note(:ab5, 0.25),
        note(:f5, 0.25)
      ]),
      seq([
        note([:db3, :db4], 0.5),
        note([:ab3, :db4, :f4], 0.5),
        note([:bb2, :bb3], 0.5),
        note([:b2, :b3], 0.5)
      ])
    ])
  end

  defp bar(78) do
    together([
      seq([
        note(:ab5, 0.5),
        note(:f5, 0.5),
        note(:eb5, 0.25),
        note(:ab5, 0.5),
        note([:ab4, :c5], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:c3, :c4], 0.5),
        note([:ab3, :c4, :eb4], 0.5),
        note([:ab3, :c4, :eb4], 0.5),
        note([:eb2, :eb3], 0.5)
      ])
    ])
  end

  defp bar(79) do
    together([
      seq([
        rest(0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.25),
        note(:c5, 0.25),
        note(:eb5, 0.25),
        note([:ab4, :f5], 0.5),
        note([:f4, :ab4], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:eb3, :ab3, :c4], 0.5)
      ])
    ])
  end

  defp bar(80) do
    together([
      seq([
        rest(0.25),
        note(:bb4, 0.25),
        note([:f4, :ab4], 0.5),
        note([:fb4, :ab4], 0.5),
        note([:fb4, :bb4], 0.25),
        note([:eb4, :ab4], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:db2, :db3], 0.5),
        note([:db2, :db3], 0.5),
        note([:bb1, :bb2], 0.5),
        note([:d2, :d3], 0.5)
      ])
    ])
  end

  defp bar(81) do
    together([
      seq([
        rest(0.25),
        note(:bb4, 0.25),
        note([:eb4, :c5], 0.25),
        note(:ab4, 0.25),
        note(:bb4, 0.25),
        note([:eb4, :c5], 0.5),
        note([:d4, :ab4], 0.25, sustain: [0.5, 0.5])
      ]),
      seq([
        note([:eb2, :eb3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:eb2, :eb3], 0.5),
        note([:e2, :e3], 0.5)
      ])
    ])
  end

  defp bar(82) do
    together([
      seq([
        rest(0.25),
        note(:bb4, 0.25),
        note([:d4, :c5], 0.25),
        note(:ab4, 0.25),
        rest(0.25),
        note([:db4, :bb4], 0.5),
        note(:eb4, 0.25)
      ]),
      seq([
        note([:f2, :f3], 0.5),
        note([:f2, :f3], 0.5),
        note([:g2, :g3], 0.5),
        note([:g2, :g3], 0.5)
      ])
    ])
  end

  defp bar(83) do
    together([
      seq([
        note([:c4, :ab4], 0.5),
        note([:eb4, :eb5], 0.5),
        note([:eb4, :eb5], 0.5),
        note([:eb4, :eb5], 0.5)
      ]),
      seq([
        note([:ab2, :ab3], 0.5),
        note([:eb3, :ab3, :c4], 0.5),
        note([:bb2, :bb3], 0.5),
        note([:c3, :c4], 0.5)
      ])
    ])
  end

  defp bar(84) do
    together([
      seq([
        note([:c4, :ab4], 0.5),
        note([:g4, :db5, :eb5], 0.5),
        note([:ab4, :c5, :eb5, :ab5], 0.5),
        rest(0.5)
      ]),
      seq([note([:ab2, :ab3], 0.5), note([:eb2, :eb3], 0.5), note([:ab1, :ab2], 0.5), rest(0.5)])
    ])
  end
end
