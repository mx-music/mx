import Mx

defmodule Salsa do
  import Mx

  def chords, do: [chord(:a4, :minor7), chord(:d4, :dom7), chord(:f4, :major7), chord(:e4, :dom7)]

  def clave do
    entries = for beat <- [1, 2, 4, 5.5, 7, 9, 10, 12, 13.5, 15], do: {beat, hit(amp: 0.35)}
    at(entries, 16)
  end

  # The tumbao: the fifth on the and of two, and the next chord's root on four, held over the bar line.
  def bass(:intro), do: rest(16)

  def bass(_section) do
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

  # The same tumbao on the plucked double bass, as the baby bass under the band: its weight, where the pluck above is its attack.
  def baby_bass(:intro), do: rest(16)

  def baby_bass(_section) do
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

  def piano(:piano_solo, _pass) do
    chords = chords()

    # A solo: a right hand walking the scale in eighths, landing on a chord tone on each beat, over short chords in the left.
    notes = scale(:a4, :minor, octaves: 2)

    Enum.map_reduce(0..31, 7, fn step, index ->
      bar = div(step, 8)
      chord = Enum.at(chords, bar)
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

  def piano(_section, _pass) do
    chords = chords()

    # The montuno: chord tones in octaves on the off-beats, answering the clave, the last of each bar already in the next chord.
    two_side = [{0.5, 0}, {1, 2}, {1.5, 1}, {2.5, 2}, {3, 0}, {3.5, 2}]
    three_side = [{0, 1}, {0.5, 2}, {1.5, 3}, {2, 2}, {3, 1}, {3.5, 2}]

    hits =
      for bar <- 0..3, {beat, tone} <- if(rem(bar, 2) == 0, do: two_side, else: three_side) do
        chord = Enum.at(chords, if(beat == 3.5, do: rem(bar + 1, 4), else: bar))
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

  # Two voices under the lead, each on the nearest tone of the chord at least a minor third below the one above it, and a bass voice an octave under the lead.
  def voicing(note, chord) do
    second = below(note - 2, chord)
    [note, second, below(second - 2, chord), note - 12]
  end

  # Every hit starts dark and opens, like a wah pedal.
  def stab(notes, length, opts \\ []) do
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

  # The horns as a synth section: detuned saws through a resonant filter that opens on every hit, grit, a dotted echo and a slow stereo sweep.
  def horns(section, pass) do
    sweep = change({:horns, :pan}, pan: if(rem(pass, 2) == 0, do: 0.6, else: -0.6), pan_slide: 16)
    together([sweep, horn_part(section)])
  end

  def horn_part(section) when section in [:mambo, :mambo_again] do
    chords = chords()

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
        chord = Enum.at(chords, div(trunc(beat), 4))
        {beat, stab(voicing(pitch(name), chord), Float.round(length * 0.7, 2))}
      end

    at(hits, 16)
  end

  def horn_part(:horn_solo) do
    chords = chords()

    # A solo on one held voice that glides from note to note, a rhythm picked for each bar, the filter opening across the bar.
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
        Enum.at(if(bar == 3, do: fit(notes, Enum.at(chords, 3)), else: notes), index)
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

  def horn_part(section) when section in [:stabs, :stabs_again] do
    chords = chords()

    # Stabs, each pushing into the chord that follows, too short to start dark: louder and brighter than the mambo's hits.
    stabs = [{2.5, 0}, {3.5, 1}, {6.5, 1}, {7.5, 2}, {10.5, 2}, {11.5, 3}, {14, 3}, {15, 3}]

    entries =
      for {beat, bar} <- stabs,
          chord = Enum.at(chords, bar),
          do:
            {beat,
             stab(voicing(Enum.max(chord), chord), 0.2, cutoff: 110, amp: 0.3, release: 0.25)}

    at(entries, 16)
  end

  def horn_part(_section), do: rest(16)

  # The conga tumbao: soft tips, a slap on two, and two open tones on four, the second on the low drum every other bar.
  def high_conga(:intro), do: rest(16)

  def high_conga(_section) do
    strokes = [
      {0, :tip},
      {0.5, :tip},
      {1, :slap},
      {1.5, :tip},
      {2, :tip},
      {2.5, :tip},
      {3, :open},
      {3.5, :open}
    ]

    hits =
      for bar <- 0..3, {beat, stroke} <- strokes, not (beat == 3.5 and rem(bar, 2) == 1) do
        opts =
          case stroke do
            :tip -> [amp: 0.12, slap: 0.3]
            :slap -> [amp: 0.45, slap: 1]
            :open -> [amp: 0.45, slap: 0]
          end

        {bar * 4 + beat, hit(opts)}
      end

    at(hits, 16)
  end

  def low_conga(:intro), do: rest(16)
  def low_conga(_section), do: at([{7.5, hit(amp: 0.55)}, {15.5, hit(amp: 0.55)}], 16)

  # Cáscara on the timbale's shell, until the mambo and the brass solo, where the bell takes over.
  def cascara(section) when section in [:intro, :mambo, :horn_solo, :mambo_again], do: rest(16)

  def cascara(_section) do
    hits =
      for beat <- [0, 1, 2, 2.5, 3.5, 4, 5, 5.5, 6.5, 7.5], offset <- [0, 8], do: beat + offset

    entries = for beat <- hits, do: {beat, hit(amp: if(beat == trunc(beat), do: 0.3, else: 0.22))}
    at(entries, 16)
  end

  # The campana, the bongocero's bell, in its third gear over the clave's two bars, a cell to each eighth: O is an open stroke on the bell's mouth played hard, o an open stroke and c a closed one, muted by the hand.
  def cowbell(section) when section in [:mambo, :horn_solo, :mambo_again] do
    strokes = %{
      "O" => [amp: 0.3, vel: 1],
      "o" => [amp: 0.3, vel: 0.8],
      "c" => [amp: 0.3, vel: 0.6, muted: 1]
    }

    entries =
      for half <- [0, 8],
          {cell, index} <- Enum.with_index(String.graphemes("O.c.o.cco.cco.cc")),
          cell != ".",
          do: {half + index / 2, hit(strokes[cell])}

    at(entries, 16)
  end

  def cowbell(_section), do: rest(16)

  # Until the bell, the bongocero plays the martillo, a cell to each eighth: M is a muted stroke on the small drum with the index finger, t a soft one with the thumb, o its open tone and H the large drum's open tone.
  def bongo(section, _drum) when section in [:intro, :mambo, :horn_solo, :mambo_again],
    do: rest(16)

  def bongo(_section, drum) do
    strokes = %{
      "M" => {:high_bongo, [muted: 1, vel: 0.8]},
      "t" => {:high_bongo, [muted: 1, vel: 0.4]},
      "o" => {:high_bongo, [muted: 0, vel: 0.7]},
      "H" => {:low_bongo, [muted: 0, vel: 0.8]}
    }

    entries =
      for bar <- 0..3,
          {cell, index} <- Enum.with_index(String.split("M t o t M t H t")),
          {^drum, opts} <- [strokes[cell]],
          do: {bar * 4 + index / 2, hit(opts)}

    at(entries, 16)
  end

  # The maracas in eighths, the beat stronger than the stroke after it.
  def maracas(:intro), do: rest(16)

  def maracas(_section) do
    entries =
      for eighth <- 0..31,
          up = rem(eighth, 2),
          do: {eighth / 2, hit(vel: 0.5 - up * 0.15, up: up)}

    at(entries, 16)
  end

  # Whether a pass ends leading into the first stabs, mambo or horn solo, which a timbale fill marks.
  def fill?(section, coming), do: coming != section and coming in [:stabs, :mambo, :horn_solo]

  # A timbale fill in the last bar before the stabs, the mambo and the horn solo first come in.
  def fill_high(section, coming) do
    if fill?(section, coming) do
      {hits, _} =
        Enum.map_reduce(
          [{0.5, 0.35}, {0.5, 0.3}, {1, 0.4}, {0.25, 0.3}, {0.25, 0.3}, {1, 0.5}],
          12,
          fn {gap, amp}, beat ->
            {{beat, hit(amp: amp)}, beat + gap}
          end
        )

      at(hits, 16)
    else
      rest(16)
    end
  end

  def fill_low(section, coming) do
    if fill?(section, coming) do
      at(
        [
          {13.5, hit(amp: 0.4)},
          {14.5, hit(amp: 0.4)},
          {14.75, hit(amp: 0.4)},
          {15.5, hit(amp: 0.55)}
        ],
        16
      )
    else
      rest(16)
    end
  end

  # The güiro, long and two short, while the piano leads.
  def guiro(section) when section in [:band, :stabs, :piano_solo, :stabs_again] do
    scrapes =
      for bar <- 0..7,
          {beat, opts} <- [
            {0, [amp: 0.3, sustain: 0.6]},
            {1, [amp: 0.22, sustain: 0.18]},
            {1.5, [amp: 0.22, sustain: 0.18]}
          ],
          do: {bar * 2 + beat, hit(opts)}

    at(scrapes, 16)
  end

  def guiro(_section), do: rest(16)

  # Each pass is four bars of Am7, D7, Fmaj7 and E7, with the son clave running 2-3 across every two bars.
  def form do
    sections =
      for {section, count} <- [
            intro: 1,
            band: 1,
            stabs: 2,
            piano_solo: 2,
            mambo: 2,
            horn_solo: 2,
            mambo_again: 1,
            stabs_again: 1
          ],
          _ <- 1..count,
          do: section

    sections
    |> Enum.zip(tl(sections) ++ [hd(sections)])
    |> Enum.map(fn {section, coming} ->
      together([
        part(:clave, clave(), synth: :clave),
        part(:bass, bass(section), synth: :pluck),
        part(:baby_bass, baby_bass(section), synth: :double_bass, defaults: [pizz: 1, amp: 0.8]),
        part(:piano, loop(16, fn pass, _ -> piano(section, pass) end),
          synth: :piano,
          fx: [reverb: [room: 0.35, mix: 0.2]]
        ),
        part(:horns, loop(16, fn pass, _ -> horns(section, pass) end),
          synth: :supersaw,
          fx: [
            distortion: [distort: 0.35, mix: 0.3],
            echo: [phase: 0.75, decay: 3, mix: 0.3],
            pan: [],
            reverb: [room: 0.4, mix: 0.3],
            level: [amp: 0.55]
          ]
        ),
        part(:high_conga, high_conga(section), synth: :high_conga),
        part(:low_conga, low_conga(section), synth: :low_conga, fx: [level: [amp: 2.5]]),
        part(:cascara, cascara(section), synth: :timbale_shell, fx: [level: [amp: 0.5]]),
        part(:cowbell, cowbell(section), synth: :cowbell),
        part(:high_bongo, bongo(section, :high_bongo),
          synth: :high_bongo,
          defaults: [amp: 0.5, pan: 0.3]
        ),
        part(:low_bongo, bongo(section, :low_bongo),
          synth: :low_bongo,
          defaults: [amp: 0.5, pan: 0.3]
        ),
        part(:maracas, maracas(section), synth: :shaker, defaults: [amp: 0.5, pan: -0.3]),
        part(:fill_high, fill_high(section, coming), synth: :high_timbale),
        part(:fill_low, fill_low(section, coming), synth: :low_timbale),
        part(:guiro, guiro(section), synth: :guiro, fx: [level: [amp: 2]])
      ])
    end)
  end
end

song(tempo: 184, music: repeat(seq(Salsa.form())))
