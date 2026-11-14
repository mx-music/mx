# Trading Fours, a feature for the drum kit on mx's own synths, after
# examples/sample_packs/virtuosity.exs, which plays the same form on recordings of a jazz kit.
# The kit plays a mambo, swings, trades fours with the piano and comes back to the mambo, at 184
# bpm, over Dm7, G7, Cmaj7 and A7, with the congas, the claves, the güiro, a cowbell, a plucked
# double bass and a piano.
# In the mambo the right hand plays the cáscara on the timbale's shell and then the contracampana,
# the timbalero's bell, a cowbell tuned a fourth up; the left plays the son clave as cross-sticks,
# 2-3, and the feet the bombo and the hi-hat on two and four.
# The bongocero's campana joins the contracampana in its third gear, both as timba.com's "Finding
# the clave" writes them, https://www.timba.com/artist_pages/finding-the-clave, and the piano
# plays a montuno.
# In the swing the ride plays its beat with the hi-hat on two and four, the bass drum feathered
# under the walking bass and the snare comping in ghost notes, while the piano comps and then
# plays a riff.
# mx has no ride cymbal, so the ride is the crash struck softly and damped after two beats, and
# the hi-hat's pedal is the closed hi-hat struck softly.
# The first four is on the snare and toms in triplets, the second a tune on the three toms that
# ends in a buzz roll, and the piano answers each with four bars of its own.
defmodule TradingFours do
  use Mx.Song, tempo: 184

  # Each voice of the kit and the percussion: its synth and the options every stroke takes.
  part :kick, synth: :kick
  part :snare, synth: :snare
  part :flam, synth: :snare
  part :buzz, synth: :snare
  part :rimshot, synth: :snare
  part :rimshot_rim, synth: :rimshot, defaults: [amp: 0.5]
  part :cross_stick, synth: :rimshot, defaults: [pan: 0.1]
  part :high_tom, synth: :high_tom, defaults: [amp: 0.6, pan: -0.25]
  part :mid_tom, synth: :mid_tom, defaults: [amp: 1.0]
  part :low_tom, synth: :low_tom, defaults: [amp: 0.6, pan: 0.3]
  part :shell, synth: :timbale_shell, defaults: [pan: 0.3]
  part :bell, synth: :cowbell, defaults: [note: 75.07, amp: 0.22, pan: 0.3]
  part :pedal, synth: :closed_hihat, defaults: [amp: 14, pan: -0.3]
  part :ride, synth: :crash, defaults: [note: 62, amp: 1.4, pan: 0.35, sustain: 2, release: 3]
  part :crash, synth: :crash, defaults: [amp: 0.5, pan: -0.2]
  part :cowbell, synth: :cowbell, defaults: [amp: 0.22, pan: -0.4]
  part :claves, synth: :clave, defaults: [amp: 0.4, pan: 0.4]
  part :conga, synth: :mid_conga, defaults: [amp: 0.25, pan: -0.2]
  part :tumba, synth: :low_conga, defaults: [amp: 1.4, pan: 0.1]
  part :guiro, synth: :guiro, defaults: [amp: 0.6, pan: 0.5]

  part :bass, synth: :double_bass, defaults: [pizz: 1, amp: 1.2]
  part :piano, synth: :piano, fx: [reverb: [room: 0.4, mix: 0.2]]

  def song do
    seq([
      intro(),
      mambo(),
      mambo_bell(setup()),
      swing(
        Enum.to_list(0..7),
        ghosts(),
        feathered(8, %{0 => "7..3..3..3.."}),
        comp(Enum.to_list(0..7), comping())
      ),
      swing(
        Enum.to_list(0..7),
        busier(),
        feathered(8, %{0 => "7..3..3..3..", 3 => "3..3....6..3", 5 => "3....6.3..3."}),
        together([riff(), comp(Enum.to_list(0..7), comping())])
      ),
      first_four(),
      swing(
        Enum.to_list(0..3),
        Enum.take(ghosts(), 4),
        feathered(4, %{0 => "8..3..3..3.."}),
        answer(Enum.to_list(0..3), first_answer())
      ),
      second_four(),
      swing(
        Enum.to_list(4..7),
        List.replace_at(Enum.take(busier(), 4), 3, "......6..7.8"),
        feathered(4, %{0 => "8..3..3..3.."}),
        answer(Enum.to_list(4..7), second_answer())
      ),
      mambo_bell([]),
      ending()
    ])
  end

  # The kit alone, then the clave, the congas and the güiro, and the abanico, the timbalero's
  # rimshot and roll into the tune.
  defp intro do
    congas = for {drum, bars} <- tumbao(), do: {drum, after_bars(4, times(bars, 2))}

    mambo_voices(
      [
        shell: times(cascara(), 4),
        pedal: times("..5...5.", 8),
        cross_stick: after_bars(2, times(clave(), 3)),
        kick: after_bars(2, times("...5..3.", 6)),
        claves: after_bars(4, times(clave(), 2)),
        guiro: after_bars(6, times(guiro(), 2)),
        rimshot: after_bars(7, "....8..."),
        buzz: after_bars(7, ".....468")
      ] ++ congas
    )
  end

  # The mambo: the cáscara on the timbale's shell.
  defp mambo do
    together([
      mambo_voices(
        [
          crash: "8.......",
          shell: times(cascara(), 4),
          cross_stick: times(clave(), 4),
          kick: ["8..6..4." | times("...6..4.", 7)],
          pedal: times("..5...5.", 8)
        ] ++ percussion()
      ),
      part(:bass, bass_tumbao(2)),
      part(:piano, montuno(2))
    ])
  end

  # The mambo again with the right hand on the contracampana, the campana on the cowbell, and the
  # left hand between a cross-stick on two and the toms on four, as the congas go.
  defp mambo_bell(ending) do
    together([
      mambo_voices(
        [
          crash: "8.......",
          bell: times(contracampana(), 4),
          cowbell: times(campana(), 4),
          cross_stick: times("..7.....", 8),
          high_tom: times("......6.", 7),
          low_tom: times(".......6", 7),
          kick: ["8..6..4." | times("...6..4.", 7)],
          pedal: times("..5...5.", 8)
        ] ++ ending ++ percussion()
      ),
      part(:bass, bass_tumbao(2)),
      part(:piano, montuno(2))
    ])
  end

  # The fill out of the mambo, on the last bar's three and four.
  defp setup do
    [flam: after_bars(7, "....8..."), snare: after_bars(7, "......68")]
  end

  # The swing: the ride's beat, the hi-hat on two and four, the bass drum feathered, and the snare
  # comping.
  defp swing(walk_bars, snare, kicks, piano) do
    bars = length(walk_bars)

    together([
      swing_voices(
        crash: "7...........",
        ride: times("5..8.45..8.4", bars),
        pedal: times(swing_pedal(), bars),
        kick: kicks,
        snare: snare
      ),
      part(:bass, walk(walk_bars)),
      part(:piano, piano)
    ])
  end

  # The first four: accents on the snare over ghosted triplets, an answer on the toms, accents
  # every fourth triplet, and a run down the drums.
  defp first_four do
    swing_voices(
      pedal: times(swing_pedal(), 4),
      snare: ["844 844 844 8..", ".44 .44 8.. ...", "844 484 448 444", "678 ... ... ..."],
      high_tom: ["... ... ... ...", "8.. 8.. ... ...", "... ... ... ...", "... 678 ... ..."],
      mid_tom: ["... ... ... ...", "... ... ... ...", "... ... ... ...", "... ... 78. ..."],
      low_tom: ["... ... ... ...", "... ... .88 8..", "... ... ... ...", "... ... ..9 ..."],
      kick: ["... ... ... ..6", "... ... ... ...", "7.. ... ... ...", "... ... ... 9.."],
      flam: ["... ... ... ...", "... ... ... ...", "... ... ... ...", "... ... ... 9.."]
    )
  end

  # The second four: a tune on the three toms, low, middle and high, then a buzz roll that grows
  # into the band.
  defp second_four do
    swing_voices(
      pedal: times(swing_pedal(), 3),
      low_tom: ["7.. ... ... ...", "7.. ... ... ...", "... 7.. ... 8..", "... ... ... ..."],
      mid_tom: ["... ..6 ... 6..", "... ..6 ... 6.6", "..7 ... ..7 ...", "... ... ... ..."],
      high_tom: ["... ... 7.. ...", "... ... 7.7 ...", "8.. ... 8.. ...", "... ... ... ..."],
      kick: ["... ... ... ...", "... ... ... ...", "... 6.. ... .6.", "7.. ... ... ..."],
      buzz: ["... ... ... ...", "... ... ... ...", "... ... ... ...", "234 456 678 899"]
    )
  end

  # The mambo's last chord: a buzz roll on the snare that grows over two bars under the piano's
  # A7, and one stroke on everything.
  defp ending do
    last = fn voice -> part(voice, seq([rest(8), eighths(voice, "7.......")])) end

    piano =
      seq([
        note(pitch([:a2, :g3, :cs4, :f4]), 8, vel: 0.6, sustain: 7.5, release: 0.4),
        note(pitch([:d2, :d3, :a3, :f4, :b4, :e5]), 4,
          vel: 0.9,
          amp: 0.4,
          sustain: 14,
          release: 4,
          pedal: 1
        ),
        rest(20)
      ])

    bass =
      seq([
        note(:a1, 8, vel: 0.8, sustain: 6, release: 1),
        note(:d2, 4, vel: 0.95, sustain: 12, release: 4),
        rest(20)
      ])

    together([
      part(:buzz, triplets(:buzz, ["222 333 334 444", "445 555 666 778"])),
      last.(:kick),
      last.(:rimshot),
      last.(:rimshot_rim),
      last.(:low_tom),
      part(:crash, seq([rest(8), at([{0, hit(vel: 0.8, sustain: 22, release: 8)}], 32)])),
      part(:bass, bass),
      part(:piano, piano)
    ])
  end

  defp cascara, do: "5.8.85.5 8.58.5.5"
  defp clave, do: "..7.7... 7..7..7."

  # The güiro: a long scrape on each half bar and two short ones after it.
  defp guiro, do: "L.ssL.ss"

  # The conga tumbao for two drums: heel, tip, slap, tip, heel, tip and two open tones, with the
  # tumba's open tones on the clave's three side.
  defp tumbao, do: [conga: "HTSTHTOO HTS..TOO", tumba: "........ ...OO..."]

  defp percussion do
    [claves: times(clave(), 4), guiro: times(guiro(), 8)] ++
      for {drum, bars} <- tumbao(), do: {drum, times(bars, 4)}
  end

  # The bass tumbao: the fifth on the and of two, and the next chord's root on four, held over the
  # bar line.
  defp bass_tumbao(cycles) do
    bars =
      for {fifth, next_root} <- [a2: :g2, d2: :c2, g2: :a2, e2: :d2] do
        seq([
          rest(1.5),
          note(fifth, 1.5, vel: 0.8, sustain: 1.3, release: 0.2),
          note(next_root, 1, vel: 0.9, sustain: 2.2, release: 0.2)
        ])
      end

    repeat(seq(bars), cycles)
  end

  # The montuno: for each chord an octave and the two notes inside it, in turn, on the clave's two
  # side from the first beat and on its three side off the beat, the last of each bar already in
  # the next chord.
  defp montuno(cycles) do
    voicings = [
      dm7: {[:a4, :a5], [:c5, :f5]},
      g7: {[:g4, :g5], [:b4, :f5]},
      cmaj7: {[:g4, :g5], [:b4, :e5]},
      a7: {[:a4, :a5], [:cs5, :g5]}
    ]

    two_side = [{0, :octave}, {1, :inside}, {1.5, :octave}, {2.5, :inside}, {3.5, :next}]
    three_side = [{0.5, :inside}, {1.5, :octave}, {2.5, :inside}, {3.5, :next}]

    hits =
      for bar <- 0..3, {beat, hand} <- if(rem(bar, 2) == 0, do: two_side, else: three_side) do
        {octave, inside} = voicings[Enum.at(chords(), bar)]
        {next, _inside} = voicings[Enum.at(chords(), rem(bar + 1, 4))]

        {notes, vel} =
          case hand do
            :octave -> {octave, 0.6}
            :inside -> {inside, 0.5}
            :next -> {next, 0.65}
          end

        {bar * 4 + beat,
         note(pitch(notes), 0.4, vel: vel, amp: 1.6, sustain: 0.35, release: 0.25)}
      end

    repeat(at(hits, 16), cycles)
  end

  # The contracampana, and the campana in its third gear, over the clave's two bars.
  defp contracampana, do: "O.o.Oooo .oooO.oo"
  defp campana, do: "O.c.o.cc o.cco.cc"

  defp swing_pedal, do: "...5.....5.."

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

    seq(
      for bar <- bars,
          {pitch, beat} <- Enum.with_index(Enum.at(walk, bar)) do
        vel = if beat in [1, 3], do: 0.85, else: 0.7
        note(pitch, 1, vel: vel, sustain: 0.9, release: 0.1)
      end
    )
  end

  defp ghosts do
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

  # The bass drum feathered on every beat, with bombs in place of some bars.
  defp feathered(bars, bombs) do
    for bar <- 0..(bars - 1), do: Map.get(bombs, bar, "3..3..3..3..")
  end

  # A bar of comping for each bar of the walk, in triplets as the kit's bars are; a chord on the
  # bar's last triplet is already the next bar's.
  # The left hand's chords in the swing are without their roots: the third and seventh with a
  # ninth or a thirteenth.
  defp comp(walk_bars, patterns) do
    shells = [
      dm7: [:f3, :c4, :e4],
      g7: [:f3, :b3, :e4],
      cmaj7: [:e3, :b3, :d4],
      a7: [:g3, :cs4, :f4]
    ]

    seq(
      for {bar, pattern} <- Enum.zip(walk_bars, patterns) do
        cells = pattern |> String.replace(" ", "") |> String.graphemes()

        hits =
          for {cell, index} <- Enum.with_index(cells), cell != "." do
            chord = Enum.at(chords(), rem(if(index == 11, do: bar + 1, else: bar), 4))
            vel = Float.round(String.to_integer(cell) / 9 * 0.7, 2)
            {index / 3, note(pitch(shells[chord]), 0.5, vel: vel, sustain: 0.5, release: 0.3)}
          end

        if hits == [], do: rest(4), else: at(hits, 4)
      end
    )
  end

  defp comping do
    [
      "7.......5...",
      ".....6......",
      "7.......5...",
      ".....6.....6",
      "........6...",
      "7....5......",
      ".....6..5...",
      "7.......6..."
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

  # The riff of the second chorus, four bars played twice, the second time an octave higher at its
  # end.
  defp riff do
    four = fn top ->
      [
        {1.5, :d5, 0.4},
        {2, :f5, 0.4},
        {2.5, :a5, 1.2},
        {5, :g5, 0.4},
        {5.5, :f5, 0.4},
        {6, :d5, 1},
        {9.5, :e5, 0.4},
        {10, :g5, 0.4},
        {10.5, :b5, 1.2},
        {13, :a5, 0.4},
        {13.5, :g5, 0.4},
        {14, :e5, 0.6},
        {15, top, 0.8}
      ]
    end

    seq([line(four.(:cs5), 16), line(four.(:cs6), 16)])
  end

  # A line for the right hand: each note is the beat it starts on, counted from the line's first
  # bar, its pitch and how long it is held.
  # The eighths are swung, so the one off the beat falls on its last triplet, two thirds of the
  # way through.
  defp line(notes, beats) do
    hits =
      for {beat, name, held} <- notes do
        off = beat != trunc(beat)
        beat = if off, do: Float.round(trunc(beat) + 2 / 3, 3), else: beat
        accent = if off, do: 0.08, else: 0

        {beat,
         note(name, held,
           vel: 0.62 + accent,
           amp: 1.3,
           sustain: Float.round(held * 0.9, 2),
           release: 0.2
         )}
      end

    at(hits, beats)
  end

  # The piano's four bars: the line over the left hand's chords.
  defp answer(walk_bars, notes) do
    together([line(notes, 16), comp(walk_bars, times("7.......5...", 4))])
  end

  # The piano's first four: up the D minor chord, down G7's scale, a held E and A7 with its flat
  # ninth.
  defp first_answer do
    [
      {0.5, :a4, 0.4},
      {1, :d5, 0.4},
      {1.5, :f5, 0.4},
      {2, :a5, 0.4},
      {2.5, :c6, 0.4},
      {3, :e6, 0.4},
      {3.5, :d6, 0.4},
      {4, :b5, 0.4},
      {4.5, :a5, 0.4},
      {5, :g5, 0.4},
      {5.5, :f5, 0.4},
      {6, :e5, 0.4},
      {6.5, :d5, 0.4},
      {7, :b4, 0.4},
      {7.5, :d5, 0.4},
      {8, :e5, 1.6},
      {10, :g5, 0.4},
      {10.5, :e5, 0.4},
      {11, :c5, 0.4},
      {11.5, :b4, 0.4},
      {12, :cs5, 0.4},
      {12.5, :e5, 0.4},
      {13, :g5, 0.4},
      {13.5, :bb5, 0.4},
      {14, :a5, 0.4},
      {14.5, :g5, 0.4},
      {15, :e5, 0.4},
      {15.5, :cs5, 0.5}
    ]
  end

  # Its second four: down the D minor scale and back, a held E over G7, up the C major seventh
  # chord to its ninth, and down A7 to its root.
  defp second_answer do
    [
      {0, :f5, 0.4},
      {0.5, :e5, 0.4},
      {1, :d5, 0.4},
      {1.5, :c5, 0.4},
      {2, :a4, 0.4},
      {2.5, :c5, 0.4},
      {3, :d5, 0.4},
      {3.5, :f5, 0.4},
      {4, :e5, 1.6},
      {5.5, :d5, 0.4},
      {6, :b4, 0.4},
      {6.5, :g4, 0.4},
      {7, :a4, 0.4},
      {7.5, :b4, 0.4},
      {8, :c5, 0.4},
      {8.5, :e5, 0.4},
      {9, :g5, 0.4},
      {9.5, :b5, 0.4},
      {10, :d6, 1.6},
      {11.5, :c6, 0.4},
      {12, :bb5, 0.4},
      {12.5, :a5, 0.4},
      {13, :g5, 0.4},
      {13.5, :e5, 0.4},
      {14, :cs5, 0.4},
      {14.5, :bb4, 0.4},
      {15, :a4, 1}
    ]
  end

  # The voices of a section, each given as bars of eighths; a snare's rimshot sounds on the head
  # and on the rim.
  defp mambo_voices(voices) do
    together(
      for {voice, bars} <- voices do
        if voice == :rimshot do
          together([
            part(voice, eighths(voice, bars)),
            part(:rimshot_rim, eighths(:rimshot_rim, bars))
          ])
        else
          part(voice, eighths(voice, bars))
        end
      end
    )
  end

  defp swing_voices(voices) do
    together(for {voice, bars} <- voices, do: part(voice, triplets(voice, bars)))
  end

  # The mambo is written in eighths, eight to a bar, and the swing in triplets, twelve to a bar.
  defp eighths(voice, patterns), do: strokes(voice, patterns, 2)
  defp triplets(voice, patterns), do: strokes(voice, patterns, 3)

  # Bars of one voice's strokes, a character to each step: a dot is silence, and spaces are left
  # out.
  defp strokes(voice, patterns, per_beat) do
    seq(
      for pattern <- List.wrap(patterns) do
        cells = pattern |> String.replace(" ", "") |> String.graphemes()

        hits =
          for {cell, index} <- Enum.with_index(cells),
              cell != ".",
              {offset, opts} <- stroke(voice, cell) do
            beat = Float.round(max(index / per_beat + offset, 0), 3)
            {beat, hit(opts)}
          end

        if hits == [] do
          rest(length(cells) / per_beat)
        else
          at(hits, length(cells) / per_beat)
        end
      end
    )
  end

  # A stroke, as the beats it sounds after its step and its options.
  # A digit is a stroke from 1, the softest, to 9; each voice turns it into its synth's options.
  # The kick, the cross-stick and the shell take no vel, so the digit sets their amp.
  # The cross-stick is the rim's click tuned to 1.2 kHz, where the stick's sounds on the
  # Virtuosity kit's recordings, over a softer one a tenth below it.
  # A flam's soft stroke falls 0.06 beats before its hard one, and a buzz's bounce comes 0.167
  # beats after its stroke.
  # The bells and the hand drums are written in letters: O is a hard open stroke, o an open one
  # and c one the hand mutes; H is the conga's heel, T its tip and S a slap; L is a long scrape of
  # the güiro and s a short one.
  defp stroke(:kick, digit), do: [{0, [amp: Float.round(:math.pow(vel(digit), 1.5) * 0.5, 3)]}]

  defp stroke(:cross_stick, digit) do
    amp = vel(digit) * 0.3
    [{0, [note: 86.4, amp: amp]}, {0, [note: 76.4, amp: amp / 2]}]
  end

  defp stroke(:rimshot_rim, _digit), do: [{0, []}]
  defp stroke(:rimshot, _digit), do: [{0, snare(1)}]
  defp stroke(:shell, digit), do: [{0, [amp: vel(digit) * 0.2]}]
  defp stroke(:flam, digit), do: [{-0.06, snare(0.35)}, {0, snare(vel(digit))}]
  defp stroke(:buzz, digit), do: [{0, snare(vel(digit))}, {0.167, snare(vel(digit) * 0.85)}]
  defp stroke(:snare, digit), do: [{0, snare(vel(digit))}]

  # The hi-hat's softest strokes are its darkest, as the pedal's chick is, and the crash's soft
  # strokes fade as a ride's do.
  defp stroke(:pedal, digit), do: [{0, [vel: Float.round(0.1 + vel(digit) * 0.18, 2)]}]
  defp stroke(:ride, digit), do: [{0, [vel: Float.round(0.2 + vel(digit) * 0.225, 2)]}]

  defp stroke(bell, "O") when bell in [:bell, :cowbell], do: [{0, [vel: 1]}]
  defp stroke(bell, "o") when bell in [:bell, :cowbell], do: [{0, [vel: 0.8]}]
  defp stroke(bell, "c") when bell in [:bell, :cowbell], do: [{0, [vel: 0.6, muted: 1]}]

  # mx's conga has no stroke of the heel, so the heel is a soft tone; the tip is a muted stroke,
  # far quieter than a tone, so it plays at twice the conga's level.
  defp stroke(:conga, "H"), do: [{0, [vel: 0.35]}]
  defp stroke(:conga, "T"), do: [{0, [vel: 0.4, mute: 1, amp: 0.7]}]
  defp stroke(:conga, "S"), do: [{0, [vel: 0.9, slap: 1]}]
  defp stroke(drum, "O") when drum in [:conga, :tumba], do: [{0, [vel: 0.9]}]

  defp stroke(:guiro, "L"), do: [{0, [vel: 0.6, sustain: 0.6]}]
  defp stroke(:guiro, "s"), do: [{0, [vel: 0.5, sustain: 0.18]}]

  defp stroke(_voice, digit), do: [{0, [vel: vel(digit)]}]

  defp vel(digit), do: Float.round(String.to_integer(digit) / 9, 2)

  # The snare's soft strokes are far quieter than its hard ones, so the softer a stroke the more
  # it is turned up, and a ghost note is heard under the band.
  defp snare(vel) do
    vel = Float.round(vel / 1, 2)
    [vel: vel, amp: Float.round(0.6 * :math.pow(vel / 0.89, -1.6), 2)]
  end

  defp times(pattern, count), do: List.duplicate(pattern, count)
  defp after_bars(bars, patterns), do: times("........", bars) ++ List.wrap(patterns)

  defp chords, do: ~w(dm7 g7 cmaj7 a7)a
end
