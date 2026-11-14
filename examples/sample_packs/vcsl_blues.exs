# Twelve Bars, a shuffle blues in C at 92 bpm for the band that VCSL holds, Versilian Studios'
# Versilian Community Sample Library, under Creative Commons 0: tenor saxophone, saxello, three
# harmonicas, the Knight upright piano and a drum kit of its bass drum, snare, hi-hat, toms and
# cymbals.
# It is four times round the twelve bars after the piano's introduction: the tenor plays a riff
# and the harmonicas answer it, the chromatic harmonica takes a chorus over the saxophones' short
# notes, the saxello takes one over the harmonicas' train rhythm, and the riff comes back with the
# saxello an octave above the tenor.
# A harmonica is recorded only at the notes it plays when blown, C, E and G on the C harmonica and
# the chromatic one and F, A and C on the F harmonica, so the C harmonica plays the chords of C
# and G and the F harmonica the chord of F.
# The pack has no bass, so the piano's left hand plays the boogie bass.
# VCSL names each key an octave below the pitch mx names it by, and records its instruments at
# very different levels, so each part is brought to its place by its own level.
# The files are fetched as the song loads, about 250 MB.
defmodule TwelveBars do
  use Mx.Song, tempo: 92

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"

  vcsl = fn path -> {:github, @repo, @commit, path} end

  # The files of one folder, each key between the two halves of its file's name, an octave above
  # its name.
  keys = fn folder, prefix, suffix, names ->
    for name <- names do
      key = name |> String.split("_") |> hd()
      note = key |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
      {vcsl.("#{folder}/#{prefix}#{name}#{suffix}.wav"), note: pitch(note) + 12}
    end
  end

  tones = fn octaves, more ->
    more ++ for octave <- octaves, key <- ~w(C D E F# G# A#), do: "#{key}#{octave}"
  end

  @saxophone "Aerophones/Reed Aerophones/Tenor Saxophone"
  @tenor keys.(
           "#{@saxophone}/Non-Vibrato",
           "BrettTenor_NV_Main_",
           "_vl3_rr1",
           tones.(2..4, ~w(G#1 A#1 C5 D5 E5))
         )
  @tenor_vibrato keys.(
                   "#{@saxophone}/Vibrato",
                   "BrettTenor_Vib_Main_",
                   "",
                   ~w(A#2_var4 C3_var1 D3_var1 E3_var3 F#3_var2 A#3_var3 C4_var2 D4_var1 E4_var4 G4_var3)
                 )
  @tenor_short keys.(
                 "#{@saxophone}/Staccato",
                 "BrettTenor_Staccato_Main_",
                 "",
                 ~w(C3_vl2_rr4 D3_vl2_rr5 E3_vl2_rr3 F#3_vl2_rr6 G#3_vl2_rr1 A#3_vl2_rr4 C4_vl2_rr3 D4_vl2_rr2 E4_vl2_rr4)
               )
  @saxello keys.(
             "Aerophones/Reed Aerophones/Saxello/Non-Vibrato",
             "BrettSaxello_SusNV_MainSpirit_",
             "_vl3_rr1",
             ~w(A#2 D3 F#3 A#3 D4 F#4 A#4 E5)
           )

  @harmonicas "Aerophones/Free Aerophones"
  @harp_c keys.(
            "#{@harmonicas}/Harmonica-Hohner-Special20-C/Sustains/Vib",
            "Hohner-Special20_Vib_",
            "",
            ~w(C3 E3 G3 C4 E4 G4 C5 E5 G5 C6)
          )
  @harp_f keys.(
            "#{@harmonicas}/Harmonica-Hohner-Special20-F/Sustains/Stac",
            "Hohner-Special20-F_Stac_",
            "_rr1",
            ~w(F3 A3 C4 F4 A4 C5 F5 A5 C6 F6)
          )
  @chromatic keys.(
               "#{@harmonicas}/Harmonica-Hohner-Super64/Sustains/Vib",
               "Hohner-Super64_Vib_",
               "",
               ~w(C3 E3 G3 C4 E4 G4 C5 E5 G5 C6)
             )

  player = for octave <- 1..4, key <- ~w(C# D# F G A B), do: "#{key}#{octave}"

  @piano keys.(
           "Chordophones/Zithers/Upright Piano, Knight/Sustains",
           "Player_vl2_rr1_",
           "",
           ~w(A0 B0) ++ player ++ ~w(C#5 D#5 F5)
         )

  @drums "Membranophones/Struck Membranophones"
  @cymbals "Idiophones/Struck Idiophones"
  @kit %{
    kick: vcsl.("#{@drums}/Bass Drum 1/BDrumNew_hit_v5_rr1_Sum.wav"),
    snare: vcsl.("#{@drums}/Snare Drum, Modern 1/Snare2_HitSN_v7_rr1_Mid.wav"),
    high_tom: vcsl.("#{@drums}/Tom 1/Stick/TomH_HitS_v3_rr1_Mid.wav"),
    low_tom: vcsl.("#{@drums}/Tom 2/Stick/TomL_HitS_v3_rr1_Mid.wav"),
    hat: vcsl.("#{@cymbals}/Hi-Hat Cymbal/HiHat_HitC_v4_rr1_Mid.wav"),
    ride: vcsl.("#{@cymbals}/Suspended Cymbal 2/susCymb2_hit_stick_mf1.wav"),
    crash: vcsl.("#{@cymbals}/Suspended Cymbal 1/susCymb1_hit_f1.wav")
  }

  @room [room: 0.5, mix: 0.15]

  part :tenor,
    synth: sampled(@tenor),
    defaults: [attack: 0.02, release: 0.1],
    fx: [level: [amp: 1.8], reverb: @room, pan: [pan: -0.2]]

  part :tenor_vibrato,
    synth: sampled(@tenor_vibrato),
    defaults: [attack: 0.03, release: 0.3],
    fx: [level: [amp: 6.0], reverb: @room, pan: [pan: -0.2]]

  part :tenor_short,
    synth: sampled(@tenor_short),
    fx: [level: [amp: 2.0], reverb: @room, pan: [pan: -0.2]]

  part :saxello,
    synth: sampled(@saxello),
    defaults: [attack: 0.02, release: 0.1],
    fx: [level: [amp: 0.8], reverb: @room, pan: [pan: 0.2]]

  part :harp_c,
    synth: sampled(@harp_c),
    defaults: [release: 0.1],
    fx: [level: [amp: 0.8], reverb: @room, pan: [pan: 0.4]]

  part :harp_f,
    synth: sampled(@harp_f),
    defaults: [release: 0.1],
    fx: [level: [amp: 1.0], reverb: @room, pan: [pan: 0.4]]

  part :chromatic,
    synth: sampled(@chromatic),
    defaults: [attack: 0.02, release: 0.12],
    fx: [level: [amp: 1.0], reverb: @room, pan: [pan: 0.1]]

  part :piano,
    synth: sampled(@piano),
    defaults: [release: 0.25],
    fx: [level: [amp: 0.6], reverb: @room, pan: [pan: -0.35]]

  part :bass,
    synth: sampled(@piano),
    defaults: [release: 0.2],
    fx: [level: [amp: 0.7], reverb: [room: 0.4, mix: 0.08]]

  part :drums, fx: [level: [amp: 1.15], reverb: [room: 0.4, mix: 0.1]]

  # A third of a beat: the shuffle's long note is two of them and its short note one.
  @pulse 1 / 3

  # The twelve bars' chords, and each chord's bass note, piano chord, harmonica and harmonica
  # chord.
  @changes ~w(c f c c f f c c g f c g)a
  @chords %{
    c: %{
      root: :c3,
      piano: [:bb3, :e4, :g4],
      harp: :harp_c,
      blown: [:c5, :e5, :g5],
      stab: {:e4, :bb4}
    },
    f: %{
      root: :f2,
      piano: [:a3, :eb4, :f4],
      harp: :harp_f,
      blown: [:a4, :c5, :f5],
      stab: {:eb4, :a4}
    },
    g: %{
      root: :g2,
      piano: [:b3, :f4, :g4],
      harp: :harp_c,
      blown: [:b4, :d5, :g5],
      stab: {:f4, :b4}
    }
  }

  # The riff: two bars on each chord, a turn through the last four, and the notes that lead back
  # in.
  @riff [
    [r: 2, eb4: 1, e4: 2, g4: 1, a4: 2, g4: 1, c5: 6, r: 9],
    [r: 2, eb4: 1, e4: 2, g4: 1, a4: 2, c5: 1, a4: 3, g4: 6, r: 6],
    [r: 2, ab4: 1, a4: 2, c5: 1, d5: 2, c5: 1, eb5: 6, r: 9],
    [r: 2, eb4: 1, e4: 2, g4: 1, a4: 2, g4: 1, c5: 6, r: 6, g4: 2, a4: 1],
    [b4: 3, d5: 3, f5: 2, d5: 1, b4: 3],
    [a4: 3, c5: 3, eb5: 2, c5: 1, a4: 3],
    [g4: 2, e4: 1, c4: 2, a3: 1, c4: 6]
  ]
  @lead_in [r: 6, g3: 2, b3: 1, d4: 2, f4: 1]

  # The chromatic harmonica's chorus, on the notes of each chord.
  @chromatic_chorus [
    [g5: 3, e5: 2, c5: 1, e5: 3, g5: 3],
    [a5: 3, f5: 2, c5: 1, f5: 6],
    [g5: 2, e5: 1, g5: 2, c6: 1, bb5: 3, g5: 3],
    [e5: 2, eb5: 1, c5: 9],
    [f5: 3, a5: 2, c6: 1, a5: 3, f5: 3],
    [eb5: 2, f5: 1, a5: 3, c6: 6],
    [c6: 2, bb5: 1, g5: 2, e5: 1, g5: 6],
    [e5: 2, c5: 1, e5: 2, g5: 1, e5: 6],
    [d5: 3, g5: 2, b5: 1, d6: 6],
    [c6: 3, a5: 2, f5: 1, a5: 6],
    [g5: 2, e5: 1, c5: 2, e5: 1, c5: 6],
    [r: 6, g5: 2, g5: 1, g5: 3]
  ]

  # The saxello's chorus.
  @saxello_chorus [
    [r: 2, g5: 1, bb5: 2, c6: 1, eb6: 2, e6: 1, c6: 3],
    [c6: 2, a5: 1, f5: 2, a5: 1, c6: 6],
    [bb5: 2, g5: 1, e5: 2, g5: 1, bb5: 3, c6: 3],
    [g5: 9, r: 3],
    [r: 2, a5: 1, c6: 2, a5: 1, f5: 2, eb5: 1, f5: 3],
    [a5: 2, c6: 1, eb6: 6, r: 3],
    [e6: 2, c6: 1, g5: 2, e5: 1, g5: 2, a5: 1, c6: 3],
    [bb5: 2, g5: 1, e5: 9],
    [d6: 3, b5: 2, g5: 1, f5: 3, d5: 3],
    [eb5: 2, f5: 1, a5: 2, c6: 1, a5: 6],
    [g5: 2, e5: 1, c5: 2, e5: 1, g5: 3, c6: 3],
    [c6: 6, r: 6]
  ]

  def song do
    seq([intro(), head(), chromatic_chorus(), saxello_chorus(), last_head(), ending()])
  end

  # The last four bars of the twelve on the piano alone, the kit coming in on the toms.
  defp intro do
    changes = ~w(g f c g)a

    play(
      piano:
        seq([
          triplets([:g, :f]),
          line(c5: 2, eb5: 1, e5: 2, g5: 1, c6: 3, a5: 2, g5: 1),
          bar(@chords.g.piano, [{0, 3, 1.0}])
        ]),
      bass: bass(changes),
      drums:
        seq([
          rest(8),
          kit(hat: "7.47.47.47.4"),
          kit(
            hat: "7.47.4......",
            snare: "......666...",
            high_tom: ".........77.",
            low_tom: "...........8"
          )
        ])
    )
  end

  defp head do
    play(
      [
        tenor: seq([riff(), line(@lead_in)]),
        piano: comping(),
        bass: bass(),
        drums: shuffle(:hat)
      ] ++ answers()
    )
  end

  defp chromatic_chorus do
    play(
      [
        chromatic: line(List.flatten(@chromatic_chorus)),
        piano: comping(),
        bass: bass(),
        drums: together([shuffle(:ride), sample(@kit.crash, 4, amp: 0.8)])
      ] ++ stabs()
    )
  end

  defp saxello_chorus do
    play(
      [
        saxello: line(List.flatten(@saxello_chorus)),
        piano: triplets(),
        bass: bass(),
        drums: shuffle(:ride)
      ] ++ train()
    )
  end

  # The riff again with the saxello an octave above, to its eleventh bar.
  defp last_head do
    eleven = Enum.take(@changes, 11)
    [harp_c, harp_f] = answers()

    play([
      {:tenor, riff()},
      {:saxello, transpose(riff(), 12)},
      {:piano, comping(eleven)},
      {:bass, bass(eleven)},
      {:drums,
       together([
         kit([ride: "7.47.47.47.4", kick: "8.....7....4", snare: "...7.....7.."], 11),
         sample(@kit.crash, 4, amp: 0.8)
       ])},
      harp_c,
      harp_f
    ])
  end

  # Everyone on one, the tenor alone down to the low G, and the last chord.
  defp ending do
    play(
      tenor: seq([line(c4: 2, r: 1, g4: 2, e4: 1, c4: 2, a3: 1, g3: 3), rest(8)]),
      tenor_vibrato: seq([rest(4), note(:c4, 8, sustain: 6)]),
      saxello: seq([line(c5: 2, r: 10), note(:bb4, 8, sustain: 6)]),
      harp_c: seq([bar(@chords.c.blown, [{0, 2, 1.0}]), note([:e5, :g5, :c6], 8, sustain: 6)]),
      piano:
        seq([
          bar(@chords.c.piano, [{0, 2, 1.0}]),
          note([:bb3, :e4, :g4, :d5], 8, strum: 0.03, release: 2)
        ]),
      bass: seq([line(c3: 2, r: 10), note([:c2, :c3], 8, release: 2)]),
      drums:
        seq([
          kit(kick: "6...........", snare: "6...........", hat: "6..........."),
          together([
            kit(kick: "6...........", low_tom: "6..........."),
            sample(@kit.crash, 8, amp: 1.0, sustain: 8, release: 3)
          ])
        ])
    )
  end

  defp play(voices) do
    together(for {name, music} <- voices, do: part(name, music))
  end

  # The right hand in triplets, the first of each three the strong one.
  defp triplets(changes \\ @changes) do
    seq(
      for chord <- changes do
        hits = for pulse <- 0..11, do: {pulse, 1, if(rem(pulse, 3) == 0, do: 0.75, else: 0.45)}
        bar(@chords[chord].piano, hits)
      end
    )
  end

  # A line as notes and their lengths in pulses, r a rest.
  defp line(steps, options \\ []) do
    seq(
      for {name, pulses} <- steps do
        if name == :r, do: rest(pulses * @pulse), else: note(name, pulses * @pulse, options)
      end
    )
  end

  # A bar of notes at the pulses given, each a pulse, a length in pulses and a level.
  defp bar(name, hits) do
    notes =
      for {pulse, pulses, amp} <- hits,
          do: {pulse * @pulse, note(name, pulses * @pulse, amp: amp)}

    at(notes, 4)
  end

  # The boogie bass: the chord's root, third, fifth, sixth and seventh, up and down the bar.
  defp bass(changes \\ @changes) do
    seq(
      for chord <- changes do
        root = pitch(@chords[chord].root)

        seq(
          for {step, index} <- Enum.with_index([0, 4, 7, 9, 10, 9, 7, 4]) do
            pulses = if rem(index, 2) == 0, do: 2, else: 1
            note(root + step, pulses * @pulse, amp: if(rem(index, 2) == 0, do: 1.0, else: 0.7))
          end
        )
      end
    )
  end

  # Bars of the kit in pulses, a row to each piece and a character to each pulse: a digit is a
  # stroke of that level, a dot is silence.
  defp kit(rows, bars \\ 1) do
    repeat(
      together(
        for {piece, pattern} <- rows do
          hits =
            for {cell, index} <- Enum.with_index(String.graphemes(pattern)), cell != "." do
              amp = String.to_integer(cell) / 9
              {index * @pulse, sample(@kit[piece], 0, amp: amp, sustain: 1.5, release: 0.5)}
            end

          at(hits, 4)
        end
      ),
      bars
    )
  end

  defp riff, do: line(List.flatten(@riff))

  # The piano's right hand: the chord on one, on the short note after two, and on four.
  defp comping(changes \\ @changes) do
    seq(
      for chord <- changes, do: bar(@chords[chord].piano, [{0, 2, 0.9}, {5, 2, 1.0}, {9, 2, 0.8}])
    )
  end

  # Eleven bars of the shuffle on the cymbal given, and a bar that ends on the toms.
  defp shuffle(cymbal) do
    seq([
      kit([{cymbal, "7.47.47.47.4"}, kick: "8.....7....4", snare: "...7.....7.."], 11),
      kit([
        {cymbal, "7.47.4......"},
        kick: "8.....7.....",
        snare: "...7..666...",
        high_tom: ".........77.",
        low_tom: "...........8"
      ])
    ])
  end

  # The harmonicas' answer in the second half of every other bar, and a long chord in the
  # eleventh.
  defp answers do
    harps(fn
      number when number in [2, 4, 6, 8] -> [{6, 2, 0.9}, {8, 1, 0.7}, {9, 3, 1.0}]
      11 -> [{6, 6, 0.8}]
      12 -> [{0, 5, 0.8}]
      _ -> []
    end)
  end

  # The saxophones' two short notes in each bar, the tenor on the chord's third and the saxello on
  # its seventh.
  defp stabs do
    for {voice, index} <- [tenor_short: 0, saxello: 1] do
      {voice,
       seq(
         for chord <- @changes,
             do: bar(elem(@chords[chord].stab, index), [{5, 1, 1.0}, {9, 1, 0.8}])
       )}
    end
  end

  # The train rhythm: the chord on every long and short note, the long one the stronger.
  defp train do
    harps(fn _ ->
      for pulse <- [0, 2, 3, 5, 6, 8, 9, 11],
          do: {pulse, 1, if(rem(pulse, 3) == 0, do: 0.8, else: 0.5)}
    end)
  end

  # One harmonica's bars through the chords, silent where the chord is the other harmonica's.
  defp harps(bars) do
    for harp <- [:harp_c, :harp_f] do
      {harp,
       seq(
         for {chord, number} <- Enum.with_index(@changes, 1) do
           hits = if @chords[chord].harp == harp, do: bars.(number), else: []
           bar(@chords[chord].blown, hits)
         end
       )}
    end
  end
end
