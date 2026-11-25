defmodule LowB do
  @moduledoc """
  Low B, a piece for the mbira of VCSL, Versilian Studios' Versilian Community Sample Library,
  under Creative Commons 0, with its marimba, shaker, claps and frame drum.
  It is built as Shona mbira music is: a cycle of 48 pulses in four phrases, each three pairs of
  notes a fifth apart, four pulses to a pair against the shaker's three.
  One mbira plays the leading part, the kushaura, and a second plays the same part a pulse later,
  the kutsinhira, so the two interlock.
  The shaker plays the hosho's three strokes to the beat and the claps a pattern of five strokes
  to the phrase, then the marimba takes the bass and the top line, as Zimbabwe's marimba bands
  play mbira pieces.
  The mbira keeps the tuning it was recorded in, a scale of B with a flat seventh that sits some
  15 cents above concert pitch, and the marimba is raised to meet it.
  Its plucks start a tenth of a second into their files, so the mbiras play that much early, after
  a beat of silence.
  Download them with mx samples download
  "vcsl:Idiophones", and the same for
  Membranophones.
  """

  use Mx.Song, tempo: 130

  @plucked "Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B"
  @struck "Idiophones/Struck Idiophones"
  @drums "Membranophones/Struck Membranophones"

  vcsl = fn path -> {:vcsl, path} end

  # VCSL names each key an octave below the pitch mx names it by.
  key = fn name ->
    name = name |> String.downcase() |> String.replace("#", "s") |> pitch()
    pitch(name) + 12
  end

  # The mbira's keys, one recording of each; the lowest, named A#1, sounds nearer B and is played
  # as B.
  @keys [
    {"A#1_14_50_100_rr1", :b2},
    {"D#2_12_50_100_rr2", :ds3},
    {"E2_10_50_100_rr3", :e3},
    {"F#2_8_50_100_rr2", :fs3},
    {"G#2_6_50_100_rr1", :gs3},
    {"A2_4_50_100_rr2", :a3},
    {"B2_13_50_100_rr3", :b3},
    {"C#3_2_50_100_rr5", :cs4},
    {"D#3_15_50_100_rr1", :ds4},
    {"E3_9_50_100_rr4", :e4},
    {"F#3_11_50_100_rr2", :fs4},
    {"G#3_7_50_100_rr2", :gs4},
    {"A3_5_50_100_rr1", :a4},
    {"B3_16_50_100_rr2", :b4},
    {"C#4_17_50_100_rr1", :cs5},
    {"D#4_18_50_100_rr5", :ds5},
    {"E4_19_50_100_rr2", :e5},
    {"F#4_20_50_100_rr3", :fs5},
    {"G#4_21_50_100_rr3", :gs5},
    {"A4_22_50_100_rr3", :a5},
    {"B4_23_50_100_rr3", :b5},
    {"C#5_24_50_100_rr5", :cs6}
  ]

  @mbira for {name, note} <- @keys,
             do: {vcsl.("#{@plucked}/MBira4_pluck_Main_#{name}.wav"), note: pitch(note)}

  # The marimba's bars at three strengths, listed 15 cents under their pitch so they sound that
  # much above it, with the mbira.
  @marimba for name <- ~w(F1 C2 G2 B2 F3 C4 G4 B4 F5 C6),
               {touch, strength} <- [{"soft", 1}, {"med", 2}, {"loud", 3}],
               do:
                 {vcsl.("#{@struck}/Marimba/Marimba_hit_Outrigger_#{name}_#{touch}_01.wav"),
                  note: key.(name) - 0.15, strength: strength}

  shaker = fn stroke ->
    for take <- 1..2,
        do:
          {vcsl.("#{@struck}/Shaker, Small/Mid_ShakerLowFaster_#{stroke}_rr#{take}.wav"),
           take: take}
  end

  frame = fn stroke ->
    for strength <- 2..3,
        take <- 1..2,
        do:
          {vcsl.("#{@drums}/Frame Drum/HDrumL_#{stroke}_v#{strength}_rr#{take}_Sum.wav"),
           strength: strength - 1, take: take}
  end

  @claps for take <- 1..6, do: {vcsl.("#{@struck}/Claps/Clap_rr#{take}.wav"), take: take}

  @plucks [defaults: [sustain: 1.5, release: 1.5]]

  part :kushaura,
       [
         synth: sampled(@mbira),
         fx: [level: [amp: 7.0], reverb: [decay_seconds: 1.5, mix: 0.15], pan: [pan: -0.4]]
       ] ++ @plucks

  part :kutsinhira,
       [
         synth: sampled(@mbira),
         fx: [level: [amp: 5.5], reverb: [decay_seconds: 1.5, mix: 0.15], pan: [pan: 0.4]]
       ] ++ @plucks

  part :bass,
    synth: sampled(@marimba),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 2.5], reverb: [decay_seconds: 1.5, mix: 0.15]]

  part :soprano,
    synth: sampled(@marimba),
    defaults: [sustain: 1, release: 1],
    fx: [level: [amp: 3.0], reverb: [decay_seconds: 1.5, mix: 0.2], pan: [pan: 0.15]]

  part :hosho_down,
    synth: sampled(shaker.("Down")),
    defaults: [sustain: 0.5, release: 0.2],
    fx: [level: [amp: 8.0], pan: [pan: 0.2]]

  part :hosho_up,
    synth: sampled(shaker.("Up")),
    defaults: [sustain: 0.5, release: 0.2],
    fx: [level: [amp: 8.0], pan: [pan: 0.2]]

  part :claps,
    synth: sampled(@claps),
    defaults: [sustain: 0.5, release: 0.3],
    fx: [level: [amp: 0.5], reverb: [decay_seconds: 1.8, mix: 0.25], pan: [pan: -0.2]]

  part :drum,
    synth: sampled(frame.("Hit")),
    defaults: [sustain: 1, release: 1],
    fx: [level: [amp: 1.2]]

  part :muted_drum,
    synth: sampled(frame.("HitMuted")),
    defaults: [sustain: 0.5, release: 0.5],
    fx: [level: [amp: 1.2]]

  # The cycle: four phrases of three pairs, each pair as its bass key, then the high, middle, high
  # and middle keys of its four pulses.
  @cycle [
    [{:b3, :b5, :fs4, :fs5, :b4}, {:ds3, :fs5, :fs4, :ds5, :a4}, {:fs3, :cs6, :fs4, :a5, :cs5}],
    [{:b3, :b5, :fs4, :fs5, :b4}, {:ds3, :fs5, :fs4, :ds5, :a4}, {:gs3, :b5, :ds4, :gs5, :gs4}],
    [{:b3, :fs5, :fs4, :ds5, :b4}, {:e3, :e5, :e4, :gs5, :gs4}, {:gs3, :gs5, :ds4, :ds5, :gs4}],
    [{:cs4, :e5, :e4, :cs6, :gs4}, {:e3, :b5, :e4, :gs5, :b4}, {:gs3, :ds5, :ds4, :gs5, :gs4}]
  ]

  @pulse 1 / 3

  def song do
    together([
      part(:kushaura, kushaura()),
      part(:kutsinhira, kutsinhira()),
      seq([
        rest(1 + 16),
        together(hosho(1)),
        together(hosho(2)),
        together(hosho(2) ++ claps(2) ++ drum(2)),
        together([bass: bass(2)] ++ hosho(2) ++ claps(2) ++ drum(2)),
        together([bass: bass(2), soprano: soprano(2)] ++ hosho(2) ++ claps(2) ++ drum(2)),
        together(hosho(1))
      ])
    ])
  end

  # The leading mbira, the whole piece: soft in its first and last cycles, and a last chord of B.
  defp kushaura do
    early(
      seq(
        [rest(1)] ++
          plucks(1, 0.6) ++
          plucks(10, 0.8) ++
          plucks(1, 0.6) ++
          [note([:b3, :fs4, :b4, :fs5, :b5], 8, strum: 0.08, sustain: 6, release: 2)]
      )
    )
  end

  # The second mbira, from the third cycle to the eleventh: the same part a pulse later, without
  # its last pluck.
  defp kutsinhira do
    early(seq([rest(1 + 2 * 16 + @pulse)] ++ Enum.drop(plucks(9, 0.8), -1) ++ [rest(16 + 8)]))
  end

  defp hosho(cycles) do
    down = for beat <- 0..3, {pulse, vel} <- [{0, 0.9}, {2, 0.45}], do: {beat * 3 + pulse, vel}
    up = for beat <- 0..3, do: {beat * 3 + 1, 0.5}
    [hosho_down: strokes(down, cycles), hosho_up: strokes(up, cycles)]
  end

  defp claps(cycles) do
    claps = for pulse <- [0, 2, 4, 7, 9], do: {pulse, 0.8}
    [claps: strokes(claps, cycles)]
  end

  defp drum(cycles) do
    [
      drum: strokes([{0, 0.9}, {6, 0.6}], cycles),
      muted_drum: strokes([{3, 0.4}, {5, 0.6}, {9, 0.4}, {11, 0.6}], cycles)
    ]
  end

  # The marimba's bass: each pair's low key an octave down, struck again softly on its third
  # pulse.
  defp bass(cycles) do
    pairs = List.flatten(@cycle)

    repeat(
      seq(pairs, fn {low, _, _, _, _} ->
        seq([
          note(pitch(low) - 12, 2 * @pulse, vel: 0.9, amp: 1.1),
          note(pitch(low) - 12, 2 * @pulse, vel: 0.4, amp: 1.6)
        ])
      end),
      cycles
    )
  end

  # The marimba's top line: the mbira's two high keys of each pair, an octave down.
  defp soprano(cycles) do
    pairs = List.flatten(@cycle)

    repeat(
      seq(pairs, fn {_, high, _, second_high, _} ->
        seq([
          note(pitch(high) - 12, 2 * @pulse, vel: 0.9, amp: 1.1),
          note(pitch(second_high) - 12, 2 * @pulse, vel: 0.6, amp: 1.4)
        ])
      end),
      cycles
    )
  end

  # The plucks start 0.1 seconds into their files, 0.22 beats at this tempo, so they play that
  # much early.
  defp early(music), do: Mx.swing(music, &(&1 - 0.22))

  # The mbira's part, a note to each pulse: the bass and a high key together, then middle, high
  # and middle.
  defp plucks(cycles, vel) do
    for _ <- 1..cycles,
        {bass, high, middle, second_high, second_middle} <- List.flatten(@cycle) do
      [
        note([bass, high], @pulse, amp: vel),
        note(middle, @pulse, amp: vel * 0.7),
        note(second_high, @pulse, amp: vel * 0.85),
        note(second_middle, @pulse, amp: vel * 0.7)
      ]
    end
    |> List.flatten()
  end

  # Strokes at pulses of a phrase of twelve, each with its strength.
  defp strokes(pulses, cycles) do
    hits = for {pulse, vel} <- pulses, do: {pulse * @pulse, hit(vel: vel, amp: 1)}
    phrase = at(hits, 4)
    repeat(phrase, cycles * 4)
  end
end
