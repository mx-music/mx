defmodule SquidPolka do
  @moduledoc """
  Squid Polka, a polka in A minor at 144 bpm for the odd instruments of Karoryfer Samples, six
  libraries each under Creative Commons 0: Squidpipes, War Tuba, Horse Pulse, Unruly Drums,
  Gogodze Phu and 272 Merry Orks.
  The bagpipes play the tune over their drone, with a short high note before the first note of
  each bar, which is how a piper separates notes on an instrument that never stops sounding.
  The tuba plays the beats and the tagelharpa, a bowed lyre played here plucked, answers off them.
  Every drum of the kit has snare wires on it, the kick too, and the hand drums and the woodblocks
  open the piece and take the middle with the tuba.
  The orks count the band in and shout at the ends of the phrases.
  Download them with mx samples download
  "sfzinstruments/karoryfer.squidpipes@b258528c8f49d6389ec2b4ec04a8b10013169dd9:Samples/long_clean",
  and the same for the other folders named below.
  """

  use Mx.Song, tempo: 144

  @pipes {"sfzinstruments/karoryfer.squidpipes", "b258528c8f49d6389ec2b4ec04a8b10013169dd9"}
  @tuba {"sfzinstruments/karoryfer.war-tuba", "5b62dd6ef6b00281bb734769e44a63f5e013018a"}
  @horse {"sfzinstruments/Karoryfer.HorsePulse", "6f4749d54512d762098ca726a3cbd13444562904"}
  @drums {"sfzinstruments/karoryfer.unruly-drums", "9bf75c2a1392f190cd1c264645653629f0b3a097"}
  @hand_drums {"sfzinstruments/karoryfer.gogodze-phu-vol-i",
               "7452f62060cd3a468c78bc361d96a4dfb30879c9"}
  @orks {"sfzinstruments/karoryfer.272-merry-orks", "a437e2c02014e02710a104a6692193eab8672d0a"}

  file = fn {repo, commit}, path -> {:github, repo, commit, path} end

  # The libraries name their notes in different octaves: the pipes and the tagelharpa an octave
  # above the pitch mx names, the tuba an octave below.
  key = fn name, octaves -> Mx.Notes.parse(name) + 12 * octaves end

  @pipe_notes ~w(g4 ab4 a4 bb4 b4 c5 db5 d5 eb5 e5 f5 gb5 g5 ab5 a5 bb5 b5 c6 db6 d6 eb6 e6 f6 gb6 g6 ab6 a6 bb6 b6 c7 db7 d7 eb7 e7 f7 gb7 g7 ab7 a7 bb7 b7 c8)

  @chanter for name <- @pipe_notes,
               do:
                 {file.(@pipes, "Samples/long_clean/#{name}_long_clean.wav"),
                  note: key.(name, -1)}

  @short for name <- @pipe_notes,
             take <- 1..4,
             do:
               {file.(@pipes, "Samples/short_clean/#{name}_short_clean_rr#{take}.wav"),
                note: key.(name, -1), take: take}

  @tuba_notes ~w(f0 gb0 g0 ab0 a0 bb0 b0 c1 db1 d1 eb1 e1 f1 gb1 g1 ab1 a1 bb1 b1 c2 db2 d2 eb2 e2 f2 gb2 g2)

  # The tuba's short notes through its condenser microphone: four strengths, three takes of each.
  @tongued for name <- @tuba_notes,
               strength <- 1..4,
               take <- 1..3,
               do:
                 {file.(@tuba, "Samples/#{name}_s_vl#{strength}_rr#{take}_cnd.wav"),
                  note: key.(name, 1), strength: strength, take: take}

  @held for name <- @tuba_notes,
            do: {file.(@tuba, "Samples/#{name}_sus_cnd.wav"), note: key.(name, 1)}

  # The tagelharpa plucked hard, six takes of each note.
  @plucked for name <-
                 ~w(d3 eb3 e3 f3 gb3 g3 ab3 a3 bb3 b3 c4 db4 d4 eb4 e4 f4 gb4 g4 ab4 a4 bb4 b4 c5 db5 d5 eb5 e5 f5),
               take <- 1..6,
               do:
                 {file.(@horse, "Samples/f/#{name}_f_rr#{take}.wav"),
                  note: key.(name, -1), take: take}

  # A drum of the kit from one microphone: its strengths, four takes of each, each take in a
  # folder of its own.
  kit = fn folder, stroke, strengths ->
    sampled(
      for strength <- 1..strengths, take <- 1..4 do
        {file.(@drums, "Samples/#{folder}/rr#{take}/#{stroke}_vl#{strength}_rr#{take}.flac"),
         strength: strength, take: take}
      end
    )
  end

  hand_drum = fn name ->
    sampled(
      for strength <- 1..4, take <- 1..4 do
        {file.(@hand_drums, "Samples/bobobo/bobobo_#{name}_vl#{strength}_rr#{take}.wav"),
         strength: strength, take: take}
      end
    )
  end

  @shouts for word <-
                ~w(numbers_one numbers_two numbers_three numbers_four hey_rr1 hey_rr2 oi_rr2),
              into: %{},
              do: {word, file.(@orks, "samples/misc/#{word}.wav")}

  part :chanter,
    synth: sampled(@chanter),
    defaults: [attack: 0.02, release: 0.1],
    fx: [level: [amp: 2.6], reverb: [room: 0.6, mix: 0.2], pan: [pan: 0.15]]

  part :cut,
    synth: sampled(@short),
    defaults: [release: 0.05],
    fx: [level: [amp: 1.8], reverb: [room: 0.6, mix: 0.2], pan: [pan: 0.15]]

  part :drone,
    synth: sampled(@chanter),
    defaults: [attack: 0.5, release: 0.8],
    fx: [level: [amp: 0.7], reverb: [room: 0.6, mix: 0.2], pan: [pan: 0.15]]

  part :tuba,
    synth: sampled(@tongued),
    defaults: [release: 0.2],
    fx: [level: [amp: 0.8], pan: [pan: -0.15]]

  part :held_tuba,
    synth: sampled(@held),
    defaults: [attack: 0.05, release: 1],
    fx: [level: [amp: 1.5], pan: [pan: -0.15]]

  part :tagelharpa,
    synth: sampled(@plucked),
    defaults: [release: 0.3],
    fx: [level: [amp: 0.3], pan: [pan: -0.45]]

  part :kick,
    synth: kit.("k20/oh", "kick_dirty", 8),
    defaults: [sustain: 1.5, release: 0.5],
    fx: [level: [amp: 0.5]]

  part :snare,
    synth: kit.("s14/top", "s14_center", 8),
    defaults: [sustain: 1.5, release: 0.5],
    fx: [level: [amp: 0.7]]

  part :snare_overhead,
    synth: kit.("s14/ohl", "s14_center", 8),
    defaults: [sustain: 1.5, release: 0.5],
    fx: [level: [amp: 0.7]]

  part :big_snare,
    synth: kit.("s22/top", "s22_center", 8),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 0.5]]

  part :big_snare_overhead,
    synth: kit.("s22/ohl", "s22_center", 8),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 0.5]]

  part :high_block,
    synth: kit.("wb/oh", "woodblock_hi", 6),
    defaults: [sustain: 1, release: 0.3],
    fx: [level: [amp: 0.6], pan: [pan: 0.5]]

  part :low_block,
    synth: kit.("wb/oh", "woodblock_lo", 6),
    defaults: [sustain: 1, release: 0.3],
    fx: [level: [amp: 0.6], pan: [pan: 0.5]]

  part :bass_drum,
    synth: hand_drum.("bass"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 1.2], pan: [pan: -0.3]]

  part :tenor_drum,
    synth: hand_drum.("tenor_l"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 1.2], pan: [pan: -0.5]]

  part :treble_drum,
    synth: hand_drum.("treble_s"),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 1.2], pan: [pan: 0.4]]

  part :orks, fx: [level: [amp: 1.4], reverb: [room: 0.7, mix: 0.25]]

  @both [snare: :snare_overhead, big_snare: :big_snare_overhead]

  # The two strains of the tune, a bar of two beats to each row: a name alone is half a beat.
  @first [
    ~w(a4 c5 e5 c5)a,
    ~w(d5 e5 d5 b4)a,
    ~w(c5 a4 c5 e5)a,
    [d5: 1, b4: 1],
    ~w(a4 c5 e5 c5)a,
    ~w(d5 e5 fs5 d5)a,
    ~w(e5 d5 c5 b4)a,
    [a4: 1, a4: 1]
  ]

  @second [
    ~w(e5 g5 e5 c5)a,
    ~w(d5 g5 d5 b4)a,
    ~w(c5 e5 a5 e5)a,
    [g5: 1, e5: 1],
    ~w(e5 g5 e5 c5)a,
    ~w(d5 g5 b5 g5)a,
    ~w(g5 e5 d5 b4)a,
    [a4: 1, a4: 1]
  ]

  @first_chords ~w(am g am g am d em am)a
  @second_chords ~w(c g am em c g em am)a

  # Each chord: the tuba's two beats, and the two notes the tagelharpa plucks.
  @chords %{
    am: {:a2, :e2, [:e3, :a3]},
    g: {:g2, :d2, [:d3, :g3]},
    d: {:d2, :a2, [:fs3, :a3]},
    em: {:e2, :b2, [:e3, :b3]},
    c: {:c2, :g2, [:e3, :g3]}
  }

  @cut_length 0.08

  def song do
    seq([
      intro(),
      strain(@first, @first_chords, march(16)),
      strain(@second, @second_chords, march(16) ++ hey(16)),
      middle(),
      strain(@first, @first_chords, full(16)),
      strain(@second, @second_chords, full(16) ++ hey(16)),
      ending()
    ])
  end

  # The hand drums and the woodblocks, then the tuba, the tagelharpa and the kick while the orks
  # count four bars.
  defp intro do
    play(
      bass_drum: drum("7.....6.", 8),
      tenor_drum: drum("..5.5...", 8),
      treble_drum: drum(["4.44..4.", "4.44.444"], 4),
      low_block: drum("6...6...", 8),
      high_block: drum("..5...55", 8),
      drone: drone(8),
      tuba: seq([rest(8), oom(~w(am g am em)a)]),
      tagelharpa: seq([rest(8), pah(~w(am g am em)a)]),
      kick: seq([rest(8), drum("7...7...", 4)]),
      orks:
        seq([
          rest(8),
          shout("numbers_one", 2),
          shout("numbers_two", 2),
          shout("numbers_three", 2),
          shout("numbers_four", 2)
        ])
    )
  end

  # A strain twice over its chords, with the drums given.
  defp strain(tune, chords, drums) do
    twice = fn music -> repeat(music, 2) end

    play(
      [
        chanter: twice.(chanter(tune)),
        cut: twice.(cuts(tune)),
        drone: drone(16),
        tuba: twice.(oom(chords)),
        tagelharpa: twice.(pah(chords))
      ] ++ drums
    )
  end

  defp march(bars), do: [kick: drum("8...8...", bars), snare: drum("..6...66", bars)]

  defp hey(bars) do
    [orks: seq([rest(bars * 2 - 1.5), shout("hey_rr1", 1.5)])]
  end

  # The first strain on the tuba, two octaves down, over the hand drums and the woodblocks.
  defp middle do
    low =
      seq(
        for bar <- @first, {name, beats} <- lengths(bar) do
          note(pitch(name) - 24, beats, dyn(0.7))
        end
      )

    play(
      [
        tuba: low,
        tagelharpa: pah(@first_chords),
        drone: drone(8),
        bass_drum: drum("7.....6.", 8),
        tenor_drum: drum("..5.5...", 8),
        treble_drum: drum(["4.44..4.", "4.44.444"], 4),
        low_block: drum("6...6...", 8),
        high_block: drum("..5...55", 8)
      ] ++ hey(8)
    )
  end

  defp full(bars) do
    [
      kick: drum("9...9...", bars),
      snare: drum(["..7.7.77", "..7.7777"], div(bars, 2)),
      big_snare: drum(["9.......", "........"], div(bars, 2)),
      high_block: drum("..5...5.", bars)
    ]
  end

  # A roll, a last A from everyone and a last shout.
  defp ending do
    play(
      snare: seq([drum("56667788"), drum("9......."), rest(4)]),
      big_snare: seq([rest(2), drum("9......."), rest(4)]),
      kick: seq([drum("8...8..."), drum("9......."), rest(4)]),
      chanter: seq([rest(2), note([:a4, :e5, :a5], 6, sustain: 5, release: 1)]),
      drone: seq([rest(2), note([:a2, :a3], 6, sustain: 5, release: 1)]),
      held_tuba: seq([rest(2), note([:a1, :a2], 6, sustain: 5, release: 1)]),
      tagelharpa: seq([rest(2), note([:a2, :e3, :a3], 6, strum: 0.05)]) |> Mx.swing(&(&1 - 0.23)),
      orks: seq([rest(2), shout("oi_rr2", 6)])
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

  # Bars of a drum in sixteenths, a character to each: a digit is a stroke of that strength, a dot
  # is silence.
  defp drum(patterns, bars \\ 1) do
    bar = fn pattern ->
      hits =
        for {cell, index} <- Enum.with_index(String.graphemes(pattern)),
            cell != ".",
            do: {index / 4, hit(dyn(String.to_integer(cell) / 9))}

      if hits == [], do: rest(2), else: at(hits, 2)
    end

    repeat(seq(Enum.map(List.wrap(patterns), bar)), bars)
  end

  # The drone, two octaves of A: a recording of four seconds started again every four bars, each
  # fading in under the end of the one before.
  defp drone(bars) do
    seq(for _ <- 1..div(bars, 4), do: note([:a2, :a3], 8, sustain: 8.6))
  end

  # The tuba on the beats: the chord's root, then its other note.
  defp oom(chords, vel \\ 0.8) do
    seq(
      for chord <- chords do
        {root, other, _} = @chords[chord]
        seq([note(root, 1, dyn(vel)), note(other, 1, dyn(vel - 0.2))])
      end
    )
  end

  # The tagelharpa off the beats.
  # Its plucks start about 95 ms into their files, so the part plays that much early.
  defp pah(chords) do
    seq(
      for chord <- chords do
        {_, _, notes} = @chords[chord]
        seq([rest(0.5), note(notes, 0.5), rest(0.5), note(notes, 0.5)])
      end
    )
    |> Mx.swing(&(&1 - 0.23))
  end

  defp shout(word, beats), do: sample(@shouts[word], beats)

  # A strain on the chanter, the first note of each bar starting late to leave room for its cut.
  defp chanter(strain) do
    seq(
      for bar <- strain do
        [{name, beats} | others] = lengths(bar)
        others = for {name, beats} <- others, do: note(name, beats)
        seq([rest(@cut_length), note(name, beats - @cut_length)] ++ others)
      end
    )
  end

  # The cuts: before the first note of each bar, a short high G, or the note above when the tune
  # is that high.
  defp cuts(strain) do
    seq(
      for bar <- strain do
        [{name, _} | _] = lengths(bar)
        cut = if pitch(name) < pitch(:g5), do: pitch(:g5), else: pitch(name) + 2
        seq([note(cut, @cut_length), rest(2 - @cut_length)])
      end
    )
  end

  defp lengths(bar) do
    for item <- bar, do: if(is_atom(item), do: {item, 0.5}, else: item)
  end

  # A note at a strength from 0 to 1: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]
end
