# House Kit on mx's own synths: examples/sample_packs/virtuosity.exs stroke for stroke, to hear
# the synths beside the recordings of the Virtuosity kit.
# The kit plays a mambo, swings, trades fours with the band and comes back to the mambo, at 184
# bpm, over Dm7, G7, Cmaj7 and A7; the bass line is the floor tom, tuned to each note.
# In the mambo the right hand plays the cáscara on the floor tom's rim and then on the ride's
# bell, the left the son clave as cross-sticks, 2-3, and the feet the bombo and the hi-hat on two
# and four.
# In the swing the ride plays its beat with the hi-hat on two and four, the bass drum feathered
# under the walking bass and the snare comping in ghost notes.
# The first four is on the snare and toms in triplets, the second on the toms with the snares off,
# ending in a buzz roll.
# The drums are tuned to the recorded kit's: the kick to 83 Hz, the snare and the high tom to 181
# Hz and the floor tom to 113 Hz.
# The ride and its bell, the cross-sticks, the hi-hat's pedal, the rimshot, the buzz and the snare
# with its snares off are fitted to the kit's own recordings.
defmodule HouseKit do
  use Mx.Song, tempo: 184

  # Each voice of the kit and the percussion: the synths that sound it, each with the part it
  # plays on, its options, its level and how many beats after the stroke it sounds.
  # The floor tom's cross-stick is the snare's tuned down to it; a flam is the snare after a soft
  # stroke.
  @snare [note: 53.6]

  @kit [
    kick: [{:kick_0, :kick, [note: 40.4, beater: 0], 0.24, 0}],
    snare: [{:snare_0, :snare, @snare, 2.6, 0}],
    cross_stick: [{:cross_stick_0, :cross_stick, [], 0.8, 0}],
    rimshot: [{:rimshot_0, :snare, @snare ++ [rim: 1], 0.45, 0}],
    flam: [{:flam_0, :snare, @snare, 0.35, -0.06}, {:flam_1, :snare, @snare, 1.3, 0}],
    buzz: [{:buzz_0, :snare, @snare ++ [buzz: 1], 1.3, 0}],
    roll: [{:roll_0, :snare, @snare ++ [buzz: 1], 2.3, 0}],
    snares_off: [{:snares_off_0, :snare, @snare ++ [snares: 0], 3.2, 0}],
    high_tom: [{:high_tom_0, :high_tom, [note: 53.7], 3.2, 0}],
    low_tom: [{:low_tom_0, :low_tom, [note: 45.49], 2.2, 0}],
    rim: [{:rim_0, :cross_stick, [note: 46.3], 0.5, 0}],
    pedal: [{:pedal_0, :pedal_hihat, [], 0.8, 0}],
    ride: [{:ride_0, :ride, [sustain: 4, release: 3], 1.6, 0}],
    bell: [{:bell_0, :ride, [bell: 1, sustain: 2, release: 2], 1.0, 0}],
    crash: [{:crash_0, :crash, [sustain: 16, release: 6], 0.44, 0}],
    sizzle: [{:sizzle_0, :crash, [note: 57, sustain: 34, release: 6], 0.35, 0}],
    claves: [{:claves_0, :clave, [pan: 0.4], 0.1, 0}],
    cowbell: [{:cowbell_0, :cowbell, [note: 76.9, pan: -0.4], 0.14, 0}],
    conga: [{:conga_0, :mid_conga, [pan: -0.2], 0.95, 0}],
    conga_muted: [{:conga_muted_0, :mid_conga, [pan: -0.2], 0.21, 0}],
    tumba: [{:tumba_0, :low_conga, [pan: 0.1], 2.2, 0}],
    guiro_long: [{:guiro_long_0, :guiro, [sustain: 1.75, pan: 0.5], 0.008, 0}],
    guiro_short: [{:guiro_short_0, :guiro, [sustain: 0.55, pan: 0.5], 0.02, 0}]
  ]

  # The percussion was recorded close; the kit also sounds through its overhead and room
  # microphones, which a reverb stands for here.
  @close ~w(claves cowbell conga conga_muted tumba guiro_long guiro_short)a
  @room [reverb: [room: 0.5, mix: 0.3]]

  # Each layer of the kit is a part of its own.
  for {name, layers} <- @kit, {layer, synth, defaults, level, _late} <- layers do
    room = if name in @close, do: [], else: @room
    part layer, synth: synth, defaults: defaults, fx: [level: [amp: level]] ++ room
  end

  part :bass, synth: :low_tom, fx: [level: [amp: 2.0]] ++ @room

  def song do
    seq([
      intro(),
      mambo(),
      mambo_bell(setup()),
      swing(Enum.to_list(0..7), comping(), feathered(8, %{0 => "7..3..3..3.."})),
      swing(
        Enum.to_list(0..7),
        busier(),
        feathered(8, %{0 => "7..3..3..3..", 3 => "3..3....6..3", 5 => "3....6.3..3."})
      ),
      first_four(),
      swing(Enum.to_list(0..3), Enum.take(comping(), 4), feathered(4, %{0 => "8..3..3..3.."})),
      second_four(),
      swing(
        Enum.to_list(4..7),
        List.replace_at(Enum.take(busier(), 4), 3, "......6..7.8"),
        feathered(4, %{0 => "8..3..3..3.."})
      ),
      mambo_bell([]),
      ending()
    ])
  end

  # The kit alone, then the clave, the congas and the güiro, and the abanico, the timbalero's
  # rimshot and roll into the tune.
  defp intro do
    eighths(
      [
        rim: times(cascara(), 4),
        pedal: times("..5...5.", 8),
        cross_stick: after_bars(2, times(clave(), 3)),
        kick: after_bars(2, times("...5..3.", 6)),
        claves: after_bars(4, times(clave(), 2)),
        rimshot: after_bars(7, "....8..."),
        buzz: after_bars(7, ".....468")
      ] ++ later(4, tumbao(2)) ++ later(6, guiro(2))
    )
  end

  # The mambo: the cáscara on the floor tom's rim.
  defp mambo do
    eighths(
      [
        crash: "8.......",
        rim: times(cascara(), 4),
        cross_stick: times(clave(), 4),
        kick: ["8..6..4." | times("...6..4.", 7)],
        pedal: times("..5...5.", 8),
        claves: times(clave(), 4),
        bass: bass_tumbao(2)
      ] ++ tumbao(4) ++ guiro(8)
    )
  end

  # The mambo again with the cáscara on the ride's bell, the campana on the cowbell, and the left
  # hand between a cross-stick on two and the toms on four, as the congas go.
  defp mambo_bell(ending) do
    eighths(
      [
        crash: "8.......",
        bell: times("5.9.95.5 9.59.5.5", 4),
        cowbell: times("9.4.7.447.447.44", 4),
        cross_stick: times("..7.....", 8),
        high_tom: times("......6.", 7),
        low_tom: times(".......6", 7),
        kick: ["8..6..4." | times("...6..4.", 7)],
        pedal: times("..5...5.", 8),
        claves: times(clave(), 4),
        bass: bass_tumbao(2)
      ] ++ ending ++ tumbao(4) ++ guiro(8)
    )
  end

  # The fill out of the mambo, on the last bar's three and four.
  defp setup do
    [flam: after_bars(7, "....8..."), snare: after_bars(7, "......68")]
  end

  # The swing: the ride's beat, the hi-hat on two and four, the bass drum feathered, and the snare
  # comping.
  defp swing(walk_bars, comping, kicks) do
    bars = length(walk_bars)

    triplets(
      crash: "7...........",
      ride: times("5..8.45..8.4", bars),
      pedal: times(swing_pedal(), bars),
      kick: kicks,
      snare: comping,
      bass: walk(walk_bars)
    )
  end

  defp comping do
    [
      "........3...",
      ".....4......",
      "..3.........",
      "........5..3",
      "........3...",
      ".....4.....3",
      "..3.....4...",
      ".....5..3..."
    ]
  end

  defp busier do
    [
      "..3.....4..3",
      ".....5......",
      "..4..3.....4",
      "........6..3",
      "..3..4......",
      ".....3..5..3",
      "..4.....3..5",
      "...3.45.67.8"
    ]
  end

  # The bass drum feathered on every beat, with bombs in place of some bars.
  defp feathered(bars, bombs) do
    for bar <- 0..(bars - 1), do: Map.get(bombs, bar, "3..3..3..3..")
  end

  # The first four: accents on the snare over ghosted triplets, an answer on the toms, accents
  # every fourth triplet, and a run down the drums.
  defp first_four do
    triplets(
      pedal: times(swing_pedal(), 4),
      snare: ["833 833 833 8..", ".44 .44 8.. ...", "844 484 448 444", "678 ... ... ..."],
      high_tom: ["... ... ... ...", "8.. 8.. ... ...", "... ... ... ...", "... 678 ... ..."],
      low_tom: ["... ... ... ...", "... ... .88 8..", "... ... ... ...", "... ... 789 ..."],
      kick: ["... ... ... ..6", "... ... ... ...", "7.. ... ... ...", "... ... ... 9.."],
      flam: ["... ... ... ...", "... ... ... ...", "... ... ... ...", "... ... ... 9.."]
    )
  end

  # The second four, with the snares off: a tune on the floor tom, the snare drum and the high
  # tom, then a buzz roll that grows into the band.
  defp second_four do
    triplets(
      pedal: times(swing_pedal(), 3) ++ ["... ... ... ..."],
      low_tom: ["7.. ... ... ...", "7.. ... ... ...", "... 7.. ... 8..", "... ... ... ..."],
      snares_off: ["... ..6 ... 6..", "... ..6 ... 6.6", "..7 ... ..7 ...", "... ... ... ..."],
      high_tom: ["... ... 7.. ...", "... ... 7.7 ...", "8.. ... 8.. ...", "... ... ... ..."],
      kick: ["... ... ... ...", "... ... ... ...", "... 6.. ... .6.", "7.. ... ... ..."],
      buzz: ["... ... ... ...", "... ... ... ...", "... ... ... ...", "234 456 678 899"]
    )
  end

  # The mambo's last chord: a roll on the snare that grows over two bars, and one stroke on
  # everything.
  defp ending do
    last = after_bars(2, "8.......")

    together([
      triplets(roll: ["555 566 666 677", "777 788 889 999"]),
      eighths(
        kick: last,
        rimshot: last,
        low_tom: last,
        sizzle: last,
        crash: last,
        bass: seq([rest(8), note(:d2, 4, vel: 0.9), rest(20)])
      )
    ])
  end

  # The conga tumbao: soft tips, a slap on two and two open tones on four, the last of them on the
  # tumba every other bar.
  defp tumbao(cycles) do
    [
      conga_muted: times("338333.. 338333..", cycles),
      conga: times("......77 ......7.", cycles),
      tumba: times("........ .......8", cycles)
    ]
  end

  # The güiro: a long scrape on each beat and two short ones after it.
  defp guiro(bars) do
    [guiro_long: times("6...6...", bars), guiro_short: times("..44..44", bars)]
  end

  # The bass tumbao: the fifth on the and of two, and the next chord's root on four, held over the
  # bar line.
  defp bass_tumbao(cycles) do
    bars =
      for {fifth, next_root} <- [a2: :g2, d3: :c3, g2: :a2, e2: :d2] do
        seq([rest(1.5), note(fifth, 1.5, vel: 0.6), note(next_root, 1, vel: 0.6)])
      end

    repeat(seq(bars), cycles)
  end

  # The walking bass, a bar of quarters to each chord, twice round.
  defp walk(bars) do
    walk = [
      ~w(d2 f2 a2 ab2)a,
      ~w(g2 b2 d3 db3)a,
      ~w(c3 e3 g2 bb2)a,
      ~w(a2 cs3 e3 eb3)a,
      ~w(d3 c3 a2 f2)a,
      ~w(g2 a2 b2 db3)a,
      ~w(c3 b2 a2 g2)a,
      ~w(a2 g2 e2 cs2)a
    ]

    seq(for bar <- bars, pitch <- Enum.at(walk, bar), do: note(pitch, 1, vel: 0.6))
  end

  # The mambo is written in eighths, eight to a bar, and the swing in triplets, twelve to a bar.
  defp eighths(voices), do: play(voices, 2)
  defp triplets(voices), do: play(voices, 3)

  # The voices of a section, each given as its bars, on every synth that sounds it; the bass is
  # given as music.
  defp play(voices, per_beat) do
    together(
      for {name, bars} <- voices do
        if name == :bass, do: part(:bass, bars), else: on(name, bars, per_beat)
      end
    )
  end

  defp on(name, bars, per_beat) do
    together(
      for {layer, _synth, _defaults, _level, late} <- @kit[name] do
        part(layer, strokes(name, bars, per_beat, late))
      end
    )
  end

  # Bars of strokes for a voice, a character to each step: a digit is a stroke of that strength, a
  # dot is silence, and spaces are left out.
  # A layer that sounds before the stroke, as a flam's grace note does, is moved early.
  defp strokes(voice, bars, per_beat, late) do
    levels =
      for digit <- 1..9, do: {Integer.to_string(digit), stroke(voice, Float.round(digit / 9, 2))}

    music = steps(bars, 1 / per_beat, strokes: levels)
    if late == 0, do: music, else: Mx.swing(music, &(&1 + late))
  end

  # A stroke from 1, the softest, to 9: the strength is how hard the synth is struck, and the
  # softer strokes are turned up a little, as the recorded ones are.
  # The muted conga is struck with the hand left on the head, softly or hard.
  defp stroke(:conga_muted, vel) when vel < 0.6, do: [vel: 0.4, damp: 1]
  defp stroke(:conga_muted, _vel), do: [vel: 0.9, damp: 1]
  defp stroke(_voice, vel), do: [vel: vel, amp: Float.round(:math.pow(vel, -0.7), 2)]

  defp clave, do: "..7.7... 7..7..7."
  defp cascara, do: "5.8.85.5 8.58.5.5"
  defp swing_pedal, do: "...5.....5.."

  defp times(pattern, count), do: List.duplicate(pattern, count)
  defp after_bars(bars, patterns), do: times("........", bars) ++ List.wrap(patterns)

  defp later(bars, voices) do
    for {name, patterns} <- voices, do: {name, after_bars(bars, patterns)}
  end
end
