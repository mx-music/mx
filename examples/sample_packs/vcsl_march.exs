defmodule Parade do
  @moduledoc """
  Parade, a march for the orchestral percussion of VCSL, Versilian Studios' Versilian Community
  Sample Library, under Creative Commons 0: the rope-tension field drum, bass drum, clash cymbals,
  timpani, tubular glockenspiel, triangle, tambourine, sleigh bells, anvil, ratchet, slapstick and
  flexatone.
  It has a march's form: the field drum calls the band in, the first strain is played twice, the
  trio is quieter, with triangle, tambourine and sleigh bells, and the first strain returns at
  full strength, with the anvil.
  Between the trio and the return the ratchet, the slapstick, the flexatone and the anvil have
  four bars to themselves.
  The tune is the tubular glockenspiel's, in G, and the timpani play G and D under it; the pack's
  five timpani are fixed at the notes they were recorded at, and the two used sit some 40 cents
  under G and D, so the glockenspiel is listed half a semitone above its pitch and sounds that
  much lower, with them.
  Each row of the drums is a bar of eight sixteenths, a character to each: a digit is a stroke of
  that level and a dot is silence.
  The bass drum's stroke starts 28 thousandths of a second into its file, so it plays that much
  early.
  The files are fetched as the song loads, about 25 MB.
  """

  use Mx.Song, tempo: 112

  vcsl = fn path -> {:vcsl, path} end
  drum = fn path -> vcsl.("Membranophones/Struck Membranophones/#{path}") end
  struck = fn path -> vcsl.("Idiophones/Struck Idiophones/#{path}") end

  # Each sound's file and the gain that brings it level with the others.
  @sounds %{
    accent: {drum.("Snare Drum, Rope Tension/Hi/RopeSnare_hi_sn_Main_vl4_rr1.wav"), 0.9},
    tap: {drum.("Snare Drum, Rope Tension/Hi/RopeSnare_hi_sn_Main_vl2_rr1.wav"), 4.0},
    click: {drum.("Legacy Snares/drum3_marching/snare3_click_rr1.wav"), 1.0},
    bass_drum: {drum.("Bass Drum 2/bassdrum_hit_f.wav"), 0.7},
    timpani_g: {drum.("Timpani 1/Hit/Timpani5_Hit_v4_rr1_Sum.wav"), 1.1},
    timpani_d: {drum.("Timpani 1/Hit/Timpani3_Hit_v4_rr1_Sum.wav"), 0.8},
    cymbals: {struck.("Clash Cymbals 1/cymbal_crash1_short1.wav"), 0.3},
    triangle: {struck.("Triangles/Triangle1_Hit_v2_rr1_Mid.wav"), 4.0},
    tambourine: {struck.("Tambourine 1/Tamb1_Hit_v2_rr1_Mid.wav"), 1.3},
    shake: {struck.("Tambourine 1/Tamb1_Shake_rr1_Mid.wav"), 3.0},
    sleigh_bells: {struck.("Sleigh Bells/Sleighbells_Hit_rr1_Mid.wav"), 2.5},
    anvil: {struck.("Anvil/Anvil_Hit1_v3_rr1_Mid.wav"), 0.8},
    high_anvil: {struck.("Anvil/Anvil_Hit2_v3_rr1_Mid.wav"), 0.5},
    ratchet: {struck.("Ratchet/Ratchet1_Crank_rr1_Mid.wav"), 2.5},
    slapstick: {struck.("Slapstick/slapstick_rr1.wav"), 0.35}
  }

  @flexatone struck.("Flexatone/flexatone1.wav")
  @long_crash struck.("Clash Cymbals 1/cymbal_crash1_ff2.wav")
  @timpani_roll drum.("Timpani 1/Roll/Timpani5_Roll_v4_rr1_Sum.wav")
  @bass_drum_roll drum.("Bass Drum 2/bassdrum_roll_mf.wav")

  # The glockenspiel's tubes, half a semitone above the notes they sound.
  @glockenspiel (for {name, note} <- [
                       {"G0", :g6},
                       {"A0", :a6},
                       {"B0", :b6},
                       {"C1", :c7},
                       {"D1", :d7},
                       {"E1", :e7},
                       {"F#1", :fs7},
                       {"G1", :g7},
                       {"A1", :a7}
                     ] do
                   {struck.("Tubular Glockenspiel/#{name}_loud1.wav"), note: pitch(note) + 0.5}
                 end)

  @room [room: 0.7, mix: 0.2]

  part :field_drum, fx: [level: [amp: 2.5], reverb: @room, pan: [pan: -0.2]]
  part :bass_drum, fx: [level: [amp: 1.5], reverb: @room]
  part :timpani, fx: [level: [amp: 2.0], reverb: @room, pan: [pan: 0.25]]
  part :metal, fx: [level: [amp: 1.8], reverb: @room, pan: [pan: 0.35]]
  part :toys, fx: [level: [amp: 2.0], reverb: @room, pan: [pan: -0.35]]

  part :glockenspiel,
    synth: sampled(@glockenspiel),
    defaults: [sustain: 2, release: 1.5],
    fx: [level: [amp: 0.6], reverb: @room]

  # The tunes as notes and their lengths in beats, eight bars each.
  @first [
    [g6: 0.75, g6: 0.25, b6: 0.5, d7: 0.5],
    [g7: 1, d7: 1],
    [e7: 0.5, d7: 0.5, c7: 0.5, a6: 0.5],
    [b6: 1, g6: 1],
    [g6: 0.75, g6: 0.25, b6: 0.5, d7: 0.5],
    [g7: 0.75, fs7: 0.25, e7: 0.5, d7: 0.5],
    [c7: 0.5, e7: 0.5, d7: 0.5, a6: 0.5],
    [g6: 2]
  ]
  @trio [
    [c7: 1, e7: 1],
    [d7: 1.5, b6: 0.5],
    [a6: 0.5, b6: 0.5, c7: 0.5, a6: 0.5],
    [b6: 1, g6: 1],
    [c7: 1, e7: 1],
    [d7: 1, g7: 1],
    [fs7: 0.5, d7: 0.5, c7: 0.5, a6: 0.5],
    [g6: 2]
  ]

  def song do
    together([
      seq([call(), first_strain(), first_strain(), trio(), novelties(), last_strain(), ending()]),
      part(:bass_drum, bass_drum())
    ])
  end

  # A bar of sticks, two of the field drum alone and two with the cymbals and the bass drum.
  defp call do
    together(
      field_drum: seq([rows(click: ~MX"8...8..."s), street_beat(2)]),
      metal: seq([rest(6), rows(cymbals: [~MX"8......."s, ~MX"8...8..."s])])
    )
  end

  defp first_strain do
    together(
      field_drum: street_beat(8),
      timpani: timpani(:first, 2),
      metal: rows([cymbals: [~MX"8......."s, ~MX"........"s, ~MX"........"s, ~MX"........"s]], 4),
      glockenspiel: tune(@first, 2)
    )
  end

  defp trio do
    together(
      field_drum: rows([tap: [~MX"6.446.44"s, ~MX"6.446464"s]], 8),
      timpani: timpani(:trio, 2),
      metal: rows([triangle: ~MX"..7...7."s, sleigh_bells: ~MX"6.6.6.6."s], 16),
      toys: rows([tambourine: ~MX"....7..."s, shake: ~MX"3.3...3."s], 16),
      glockenspiel: tune(@trio, 2)
    )
  end

  # Four bars for the ratchet, the slapstick, the flexatone and the anvils.
  defp novelties do
    together(
      toys:
        seq([
          rows(ratchet: ~MX"8...8.8."s),
          rows(slapstick: ~MX"....9..."s),
          sample(@flexatone, 2, amp: 3.0),
          rows(slapstick: ~MX"9......."s)
        ]),
      metal: seq([rest(6), rows(anvil: ~MX"..7.7.77"s, high_anvil: ~MX"....7..."s)]),
      field_drum: seq([rest(6), rows(accent: ~MX"....6789"s, tap: ~MX"9999...."s)])
    )
  end

  defp last_strain do
    together(
      field_drum: street_beat(8),
      timpani: timpani(:first, 2),
      metal:
        rows(
          [cymbals: [~MX"8......."s, ~MX"8......."s], anvil: [~MX"..6...6."s, ~MX"..6...66"s]],
          8
        ),
      toys: rows([tambourine: ~MX"....7..."s, sleigh_bells: ~MX"5.5.5.5."s], 16),
      glockenspiel: tune(@first, 2)
    )
  end

  # Two bars of rolls, and the last stroke.
  defp ending do
    together(
      timpani:
        seq([
          sample(@timpani_roll, 4, amp: 1.5, sustain: 4, release: 0.2),
          rows(timpani_g: ~MX"9......."s, timpani_d: ~MX"9......."s),
          rest(2)
        ]),
      field_drum: seq([rows([tap: ~MX"99999999"s], 2), rows(accent: ~MX"9......."s), rest(2)]),
      metal: seq([rest(4), sample(@long_crash, 4, amp: 0.5, sustain: 4, release: 3)]),
      toys:
        seq([
          sample(@bass_drum_roll, 4, amp: 0.9, sustain: 4, release: 0.2),
          rows(anvil: ~MX"9......."s),
          rest(2)
        ]),
      glockenspiel: seq([rest(4), note([:g6, :d7, :g7], 4)])
    )
  end

  # The bass drum from first bar to last: silent through the sticks and the field drum's call, on
  # both beats of the strains, on the first of the trio's bars, and under the last stroke.
  defp bass_drum do
    early = fn music -> Mx.swing(music, &(&1 - 0.05)) end

    early.(
      seq([
        rest(6),
        rows([bass_drum: ~MX"8...8..."s], 2),
        rows([bass_drum: ~MX"8...8..."s], 32),
        rows([bass_drum: ~MX"5......."s], 16),
        rest(6),
        rows(bass_drum: ~MX"....8.8."s),
        rows([bass_drum: ~MX"9...9..."s], 16),
        rest(4),
        rows(bass_drum: ~MX"9......."s),
        rest(2)
      ])
    )
  end

  # Rows of sounds played together, each row one bar or several in turn, the whole played so many
  # times.
  defp rows(rows, times \\ 1) do
    together(
      for {sound, patterns} <- rows do
        {file, gain} = @sounds[sound]

        strokes =
          for strength <- 1..9,
              do: {:"#{strength}", [amp: gain * strength / 9, sustain: 3, release: 1]}

        bars =
          for pattern <- if(match?([%{} | _], patterns), do: [patterns], else: patterns),
              do: steps(pattern, 2 / length(pattern), sample: file, strokes: strokes)

        repeat(seq(bars), times)
      end
    )
  end

  # The street beat, two bars of it.
  defp street_beat(times, level \\ 1.0) do
    accents =
      if level < 1, do: [~MX"6...6..."s, ~MX"6...6.6."s], else: [~MX"9...9..."s, ~MX"9...9.9."s]

    rows([accent: accents, tap: [~MX"..66..66"s, ~MX"..66.6.6"s]], times)
  end

  # The timpani under the first strain, G and D, and under the trio.
  defp timpani(:first, times) do
    rows(
      [
        timpani_g: [
          ~MX"8......."s,
          ~MX"8......."s,
          ~MX"........"s,
          ~MX"8...8..."s,
          ~MX"8......."s,
          ~MX"8......."s,
          ~MX"........"s,
          ~MX"8...6.8."s
        ],
        timpani_d: [
          ~MX"....6..."s,
          ~MX"....6..."s,
          ~MX"8...6.6."s,
          ~MX"........"s,
          ~MX"....6..."s,
          ~MX"....6..."s,
          ~MX"8...8..."s,
          ~MX"........"s
        ]
      ],
      times
    )
  end

  defp timpani(:trio, times) do
    rows(
      [
        timpani_g: [
          ~MX"5......."s,
          ~MX"5......."s,
          ~MX"........"s,
          ~MX"5......."s,
          ~MX"5......."s,
          ~MX"5......."s,
          ~MX"........"s,
          ~MX"5......."s
        ],
        timpani_d: [
          ~MX"........"s,
          ~MX"........"s,
          ~MX"5......."s,
          ~MX"........"s,
          ~MX"........"s,
          ~MX"........"s,
          ~MX"5...5..."s,
          ~MX"........"s
        ]
      ],
      times
    )
  end

  defp tune(bars, times) do
    repeat(seq(for {name, beats} <- List.flatten(bars), do: note(name, beats)), times)
  end
end
