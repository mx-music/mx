defmodule Salsa do
  @moduledoc """
  A salsa in A minor at 184 bpm, round four bars of Am7, D7, Fmaj7 and E7, with the son clave
  running 2-3 across every two bars.
  The bass and the baby bass play the tumbao, the piano the montuno, the congas their tumbao, the
  bongocero the martillo and then the bell, the timbales the cáscara, and the maracas and the
  güiro fill in the eighths.
  It goes from an intro through the band, horn stabs, a piano solo, the mambo and a horn solo,
  back to the mambo and the stabs, with a timbale fill before the stabs, the mambo and the horn
  solo first come in.
  """

  use Mx.Song, tempo: 184

  part :clave, synth: :clave
  part :bass, synth: :pluck
  part :baby_bass, synth: :double_bass, defaults: [pizz: 1, amp: 0.8]
  part :piano, synth: :piano, fx: [reverb: [room: 0.35, mix: 0.2]]

  part :horns,
    synth: :supersaw,
    fx: [
      distortion: [distort: 0.35, mix: 0.3],
      echo: [phase: 0.75, decay: 3, mix: 0.3],
      pan: [],
      reverb: [room: 0.4, mix: 0.3],
      level: [amp: 0.55]
    ]

  part :high_conga, synth: :high_conga
  part :low_conga, synth: :low_conga, fx: [level: [amp: 2.5]]
  part :cascara, synth: :timbale_shell, fx: [level: [amp: 0.5]]
  part :cowbell, synth: :cowbell
  part :high_bongo, synth: :high_bongo, defaults: [amp: 0.5, pan: 0.3]
  part :low_bongo, synth: :low_bongo, defaults: [amp: 0.5, pan: 0.3]
  part :maracas, synth: :shaker, defaults: [amp: 0.5, pan: -0.3]
  part :fill_high, synth: :high_timbale
  part :fill_low, synth: :low_timbale
  part :guiro, synth: :guiro, fx: [level: [amp: 2]]

  # Each pass is four bars of Am7, D7, Fmaj7 and E7, with the son clave running 2-3 across every
  # two bars.
  def song do
    repeat(
      form(
        [
          intro: 1,
          band: 1,
          stabs: 2,
          piano_solo: 2,
          mambo: 2,
          horn_solo: 2,
          mambo_again: 1,
          stabs_again: 1
        ],
        fn section, %{coming: coming} -> section(section, coming) end,
        round: true
      )
    )
  end

  # The parts silent in each section: the rhythm section comes in after the intro, the bell takes
  # over from the cáscara and the bongos in the mambo and the horn solo, and the güiro plays while
  # the piano leads.
  @silent [
    intro: [
      :bass,
      :baby_bass,
      :high_conga,
      :low_conga,
      :cascara,
      :cowbell,
      :high_bongo,
      :low_bongo,
      :maracas,
      :guiro
    ],
    band: [:cowbell],
    stabs: [:cowbell],
    piano_solo: [:cowbell],
    mambo: [:cascara, :high_bongo, :low_bongo, :guiro],
    horn_solo: [:cascara, :high_bongo, :low_bongo, :guiro],
    mambo_again: [:cascara, :high_bongo, :low_bongo, :guiro],
    stabs_again: [:cowbell]
  ]

  # A section, with a timbale fill at its end when the stabs, the mambo or the horn solo first
  # come next.
  defp section(section, coming) do
    together([
      part(:clave, clave()),
      part(:bass, bass()),
      part(:baby_bass, baby_bass()),
      part(:piano, loop(16, fn pass, _ -> piano(section, pass) end)),
      part(:horns, loop(16, fn pass, _ -> horns(section, pass) end)),
      part(:high_conga, high_conga()),
      part(:low_conga, low_conga()),
      part(:cascara, cascara()),
      part(:cowbell, cowbell()),
      part(:high_bongo, high_bongo()),
      part(:low_bongo, low_bongo()),
      part(:maracas, maracas()),
      part(:fill_high, fill_high(section, coming)),
      part(:fill_low, fill_low(section, coming)),
      part(:guiro, guiro())
    ])
    |> without(@silent[section])
  end

  # The son clave, 2-3, in eighths.
  defp clave, do: steps(~MX"..x.x... x..x..x. ..x.x... x..x..x."s, 0.5, amp: 0.35)

  # The tumbao: the fifth on the and of two, and the next chord's root on four, held over the bar
  # line.
  defp bass do
    bars =
      for {fifth, next_root} <- [{40, 38}, {45, 41}, {36, 40}, {35, 33}] do
        seq([
          rest(1.5),
          note(fifth, 0, amp: 0.9, release: 1.4, ring: 1.2, coef: 0.55),
          rest(1.5),
          note(next_root, 0, amp: 1, release: 2.4, ring: 1.6, coef: 0.55),
          rest(1)
        ])
      end

    seq(bars)
  end

  # The same tumbao on the plucked double bass, as the baby bass under the band: its weight, where
  # the pluck above is its attack.
  defp baby_bass do
    bars =
      for {fifth, next_root} <- [{40, 38}, {45, 41}, {36, 40}, {35, 33}] do
        seq([
          rest(1.5),
          note(fifth, 1.5, vel: 0.8, sustain: 1.3, release: 0.2),
          note(next_root, 1, vel: 0.9, sustain: 2.2, release: 0.2)
        ])
      end

    seq(bars)
  end

  defp piano(:piano_solo, _pass) do
    # A solo: a right hand walking the scale in eighths, landing on a chord tone on each beat,
    # over short chords in the left.
    notes = scale(:a4, :minor, octaves: 2)

    Enum.map_reduce(0..31, 7, fn step, index ->
      bar = div(step, 8)
      chord = chord_on(bar * 4)
      classes = Enum.map(chord, &rem(&1, 12))

      left =
        if rem(step, 8) in [0, 5] do
          [
            note(Enum.map(chord, &(&1 - 12)), 0, vel: 0.4, amp: 0.6, sustain: 0.3, release: 0.2)
          ]
        else
          []
        end

      index = clamp(index + pick([-2, -1, -1, 1, 1, 2, 3]), 0, 14)

      index =
        if rem(step, 2) == 0 do
          Enum.min_by(0..14, &{rem(Enum.at(notes, &1), 12) not in classes, abs(&1 - index)})
        else
          index
        end

      note = Enum.at(if(bar == 3, do: fit(notes, chord), else: notes), index)

      right =
        if chance(0.85) do
          [note(note, 0, vel: between(0.6, 0.9), amp: 1.4, sustain: 0.3, release: 0.3)]
        else
          []
        end

      {seq(left ++ right ++ [rest(0.5)]), index}
    end)
    |> elem(0)
    |> seq()
  end

  defp piano(_section, _pass) do
    # The montuno: chord tones in octaves on the off-beats, answering the clave, the last of each
    # bar already in the next chord.
    two_side = [{0.5, 0}, {1, 2}, {1.5, 1}, {2.5, 2}, {3, 0}, {3.5, 2}]
    three_side = [{0, 1}, {0.5, 2}, {1.5, 3}, {2, 2}, {3, 1}, {3.5, 2}]

    hits =
      for bar <- 0..3, {beat, tone} <- if(rem(bar, 2) == 0, do: two_side, else: three_side) do
        chord = chord_on(if(beat == 3.5, do: bar + 1, else: bar) * 4)
        note = Enum.at(chord, tone)
        {bar * 4 + beat, [note - 12, note]}
      end

    hits =
      for {beat, notes} <- hits do
        accent = if beat == trunc(beat), do: 0.1, else: 0
        {beat, note(notes, 0.35, vel: 0.5 + accent, amp: 1.2, sustain: 0.35, release: 0.25)}
      end

    at(hits, 16)
  end

  # Two voices under the lead, each on the nearest tone of the chord at least a minor third below
  # the one above it, and a bass voice an octave under the lead.
  defp voicing(note, chord) do
    second = below(note - 2, chord)
    [note, second, below(second - 2, chord), note - 12]
  end

  # Every hit starts dark and opens, like a wah pedal.
  defp stab(notes, length, opts \\ []) do
    opts =
      Keyword.merge(
        [
          cutoff: 90,
          res: 0.55,
          detune: 0.25,
          amp: 0.14,
          sustain: length,
          release: 0.15,
          changes: [{0, cutoff: 126, cutoff_slide: min(length, 0.2)}]
        ],
        opts
      )

    note(notes, length, opts)
  end

  # The horns as a synth section: detuned saws through a resonant filter that opens on every hit,
  # grit, a dotted echo and a slow stereo sweep.
  defp horns(section, pass) do
    sweep = change({:horns, :pan}, pan: if(rem(pass, 2) == 0, do: 0.6, else: -0.6), pan_slide: 16)
    together([sweep, horn_part(section)])
  end

  defp horn_part(section) when section in [:mambo, :mambo_again] do
    # The mambo, a written line for the section, from E5 up to D6.
    line = [
      {0.5, :e5, 0.5},
      {1, :g5, 0.5},
      {1.5, :a5, 1.2},
      {3, :g5, 0.4},
      {3.5, :e5, 0.5},
      {4.5, :fs5, 0.5},
      {5, :a5, 0.5},
      {5.5, :c6, 1.2},
      {7, :a5, 0.4},
      {7.5, :fs5, 0.5},
      {8.5, :e5, 0.5},
      {9, :f5, 0.5},
      {9.5, :a5, 1.2},
      {11, :c6, 0.4},
      {11.5, :b5, 0.5},
      {12, :gs5, 0.5},
      {12.5, :b5, 0.5},
      {13, :d6, 1.2},
      {14.5, :b5, 0.4},
      {15, :gs5, 0.4},
      {15.5, :e5, 0.5}
    ]

    hits =
      for {beat, name, length} <- line do
        chord = chord_on(beat)
        {beat, stab(voicing(pitch(name), chord), Float.round(length * 0.7, 2))}
      end

    at(hits, 16)
  end

  defp horn_part(:horn_solo) do
    # A solo on one held voice that glides from note to note, a rhythm picked for each bar, the
    # filter opening across the bar.
    notes = scale(:a4, :minor, octaves: 2)

    cells = [
      [0, 1, 1.5, 2.5],
      [0.5, 1, 1.5, 3, 3.5],
      [0, 2.5, 3],
      [0.5, 2, 2.5, 3, 3.5],
      [1]
    ]

    step = fn index -> clamp(index + pick([-2, -1, 1, 1, 2]), 2, 11) end

    Enum.map_reduce(0..3, 6, fn bar, index ->
      [first | rest] = pick(cells)
      index = step.(index)
      glides = Enum.scan(rest, index, fn _, index -> step.(index) end)

      lead_note = fn index ->
        Enum.at(if(bar == 3, do: fit(notes, chord_on(12)), else: notes), index)
      end

      # The glides count from the note they bend.
      bends =
        for {at, index} <- Enum.zip(Enum.map(rest, &(&1 - first)), glides),
            do: {at, note: lead_note.(index), note_slide: 0.12}

      lead =
        note(lead_note.(index), 4 - first,
          cutoff: 98,
          res: 0.6,
          detune: 0.12,
          amp: 0.3,
          sustain: 3.6 - first,
          release: 0.3,
          changes: [{0, cutoff: 126, cutoff_slide: 0.5} | bends]
        )

      {at([{first, lead}], 4), List.last([index | glides])}
    end)
    |> elem(0)
    |> seq()
  end

  defp horn_part(section) when section in [:stabs, :stabs_again] do
    # Stabs, each pushing into the chord that follows, too short to start dark: louder and
    # brighter than the mambo's hits.
    stabs = [{2.5, 0}, {3.5, 1}, {6.5, 1}, {7.5, 2}, {10.5, 2}, {11.5, 3}, {14, 3}, {15, 3}]

    entries =
      for {beat, bar} <- stabs,
          chord = chord_on(bar * 4),
          do:
            {beat,
             stab(voicing(Enum.max(chord), chord), 0.2, cutoff: 110, amp: 0.3, release: 0.25)}

    at(entries, 16)
  end

  defp horn_part(_section), do: rest(16)

  # The conga tumbao in eighths: t a soft tip, S a slap on two, and o two open tones on four, the
  # second on the low drum every other bar.
  defp high_conga do
    strokes = [t: [amp: 0.12, slap: 0.3], S: [amp: 0.45, slap: 1], o: [amp: 0.45, slap: 0]]
    steps(List.duplicate([~MX"ttSt ttoo"s, ~MX"ttSt tto."s], 2), 0.5, strokes: strokes)
  end

  defp low_conga, do: steps(~MX"........ .......x ........ .......x"s, 0.5, amp: 0.55)

  # Cáscara on the timbale's shell in eighths, louder on the beat, until the mambo and the brass
  # solo, where the bell takes over.
  defp cascara do
    strokes = [X: [amp: 0.3], x: [amp: 0.22]]
    steps(List.duplicate(~MX"X.X.Xx.x X.Xx.x.x"s, 2), 0.5, strokes: strokes)
  end

  # The campana, the bongocero's bell, in its third gear over the clave's two bars, a cell to each
  # eighth: O is an open stroke on the bell's mouth played hard, o an open stroke and c a closed
  # one, muted by the hand.
  defp cowbell do
    strokes = [
      O: [amp: 0.3, vel: 1],
      o: [amp: 0.3, vel: 0.8],
      c: [amp: 0.3, vel: 0.6, muted: 1]
    ]

    steps(List.duplicate(~MX"O.c.o.cc o.cco.cc"s, 2), 0.5, strokes: strokes)
  end

  # Until the bell, the bongocero plays the martillo in eighths, M t o t M t H t: M is a muted
  # stroke on the small drum with the index finger, t a soft one with the thumb, o its open tone
  # and H the large drum's open tone.
  defp high_bongo do
    strokes = [M: [muted: 1, vel: 0.8], t: [muted: 1, vel: 0.4], o: [muted: 0, vel: 0.7]]
    steps(List.duplicate(~MX"Mtot Mt.t"s, 4), 0.5, strokes: strokes)
  end

  defp low_bongo do
    steps(List.duplicate(~MX".... ..H."s, 4), 0.5, strokes: [H: [muted: 0, vel: 0.8]])
  end

  # The maracas in eighths, the beat stronger than the stroke after it.
  defp maracas do
    strokes = [d: [vel: 0.5, up: 0], u: [vel: 0.35, up: 1]]
    steps(List.duplicate(~MX"du"s, 16), 0.5, strokes: strokes)
  end

  # A timbale fill in the last bar before the stabs, the mambo and the horn solo first come in.
  defp fill_high(section, coming) do
    if fill?(section, coming) do
      at(
        [{12, 0.35}, {12.5, 0.3}, {13, 0.4}, {14, 0.3}, {14.25, 0.3}, {14.5, 0.5}],
        16,
        &hit(amp: &1)
      )
    else
      rest(16)
    end
  end

  defp fill_low(section, coming) do
    if fill?(section, coming) do
      at([{13.5, 0.4}, {14.5, 0.4}, {14.75, 0.4}, {15.5, 0.55}], 16, &hit(amp: &1))
    else
      rest(16)
    end
  end

  # The güiro, long and two short, while the piano leads.
  defp guiro do
    strokes = [L: [amp: 0.3, sustain: 0.6], s: [amp: 0.22, sustain: 0.18]]
    steps(List.duplicate(~MX"L.ss"s, 8), 0.5, strokes: strokes)
  end

  # Whether a pass ends leading into the first stabs, mambo or horn solo, which a timbale fill
  # marks.
  defp fill?(section, coming), do: coming != section and coming in [:stabs, :mambo, :horn_solo]

  # The chart every player reads, a chord to each bar of four beats, played round.
  defp chart, do: ~MX"Am7 D7 Fmaj7 E7"

  # The chord at a beat of the chart, its root from D4 up.
  defp chord_on(beat), do: named(chord_at(chart(), 4, beat), :d4)

  # The chord written at a beat of a chart read a word to every step beats, going round past its
  # end.
  defp chord_at(chart, step, beat) do
    length = Enum.sum(Enum.map(chart, & &1.steps)) * step
    beat = beat - length * Float.floor(beat / length)

    Enum.reduce_while(chart, 0, fn %{tokens: [name], steps: steps}, start ->
      if beat < start + steps * step, do: {:halt, name}, else: {:cont, start + steps * step}
    end)
  end

  # A chord's pitches from its name as a chart writes it, such as C#dim7, its root the lowest of
  # its letter at or above from.
  defp named(name, from) do
    [_, letter, accidental, kind] = Regex.run(~r/^([A-G])([#b]?)(.*)$/, name)
    letters = %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}
    class = letters[letter] + %{"" => 0, "#" => 1, "b" => -1}[accidental]
    from = pitch(from)
    root = from + Integer.mod(class - from, 12)
    chord(root, kind(kind))
  end

  defp kind(""), do: :major
  defp kind("m"), do: :minor
  defp kind("7"), do: :dom7
  defp kind("m7"), do: :minor7
  defp kind("maj7"), do: :major7
  defp kind("dim7"), do: :dim7
end
