import Mx

# The caboclinho of caboclinho.exs made a bit more modern, as Recife's mangue beat set its folk rhythms under a drum kit and a bass, and as DJ Dolores set a caboclinho gaita over bass on "Wakaru" (1 Real, 2007).
# The terno and the gaita's melodies are copied from it, so each file plays alone; a drum kit leads under them, a saw bass holds G, and the new effects colour each part.
# The gaita plays through a chorus and a ping-pong echo, the preacas through a bitcrusher, a ganzá through a band-pass and the shaker through a flanger; the bass wobbles through macumba do índio, where the kit drops out and the atabaque bounces between the sides.
defmodule CaboclinhoModern do
  import Mx

  # Beats of the song to one beat of the toque: guerra is the fastest.
  def unit(:guerra), do: 1
  def unit(:baiao), do: 1.25
  def unit(:macumba), do: 1.25
  def unit(:perre), do: 1.5

  # The gaita's notes as steps from its tonic, G5: a neutral third, 3.5 semitones up, in place of the minor or the major third.
  def gaita(step) do
    degrees = [0, 2, 3.5, 5, 7, 9, 10]
    79 + 12 * Integer.floor_div(step, 7) + Enum.at(degrees, Integer.mod(step, 7))
  end

  # Each toque's melody, four phrases of two bars, as {step, beats of the toque} or {step, beats, appoggiaturas}.
  def melody(:guerra) do
    [
      [
        {4, 0.5},
        {2, 0.5},
        {1, 0.25},
        {2, 0.25},
        {0, 0.5},
        {2, 0.5},
        {4, 0.5},
        {5, 0.5},
        {4, 0.5}
      ],
      [{4, 0.5, [5]}, {2, 0.5}, {1, 0.25}, {2, 0.25}, {0, 0.5}, {2, 0.5}, {4, 0.5}, {2, 1}],
      [{7, 0.5}, {5, 0.5}, {4, 0.5}, {5, 0.5}, {4, 0.25}, {2, 0.25}, {1, 0.5}, {0, 1, [1, 2]}],
      [{2, 0.5}, {1, 0.5}, {0, 0.5}, {-1, 0.5}, {0, 2, [-1]}]
    ]
  end

  def melody(:perre) do
    [
      [{0, 1, [1]}, {2, 0.5}, {1, 0.5}, {0, 1.5}, {-1, 0.5}],
      [{0, 1, [2, 1]}, {2, 0.5}, {4, 0.5}, {2, 1.5}, {1, 0.5}],
      [{4, 1, [5]}, {5, 0.5}, {4, 0.5}, {2, 1}, {1, 1}],
      [{2, 1}, {1, 0.5}, {-1, 0.5}, {0, 2, [1]}]
    ]
  end

  def melody(:baiao) do
    [
      [{0, 0.75}, {2, 0.25}, {4, 1}, {5, 0.75}, {4, 0.25}, {2, 1}],
      [{0, 0.75}, {2, 0.25}, {4, 1, [5]}, {7, 0.75}, {5, 0.25}, {4, 1}],
      [{5, 0.5}, {4, 0.5}, {2, 0.75}, {1, 0.25}, {2, 0.5}, {1, 0.5}, {0, 1}],
      [{-1, 0.75}, {0, 0.25}, {2, 0.5}, {1, 0.5}, {0, 2, [2, 1]}]
    ]
  end

  def melody(:macumba) do
    [
      [{0, 0.5}, {0, 0.5}, {2, 0.5}, {0, 0.5}, {-1, 1}, {-3, 1}],
      [{0, 0.5}, {0, 0.5}, {2, 0.5}, {3, 0.5}, {2, 1, [3]}, {0, 1}],
      [{2, 0.5}, {2, 0.5}, {3, 0.5}, {2, 0.5}, {0, 1}, {-1, 1}],
      [{-1, 0.5}, {0, 0.5}, {-1, 0.5}, {-3, 0.5}, {0, 2, [-1]}]
    ]
  end

  # A pass's strokes in beats of the song, from each bar's strokes, given by the bar's number, as {beat of the toque, options}.
  def bars(unit, strokes) do
    for bar <- 0..7, {beat, options} <- strokes.(bar), do: {(bar * 2 + beat) * unit, options}
  end

  # The sixteenths of a pass, each as {beat of the song, its place in the beat}.
  def sixteenths(unit), do: Enum.map(0..63, &{&1 * 0.25 * unit, rem(&1, 4)})

  # The tarol in guerra: a dotted eighth and a sixteenth, a rest on the second beat, and the bacalhau, struck muted, on every fourth bar.
  # Its perré and baião are mx's own; it rests while the atabaque plays.
  def tarol(:guerra, bar) when rem(bar, 4) == 3 do
    [
      {0, [vel: 0.8]},
      {0.75, [vel: 0.7]},
      {1, [muted: 1, vel: 0.5]},
      {1.25, [muted: 1, vel: 0.4]},
      {1.5, [muted: 1, vel: 0.55]},
      {1.75, [muted: 1, vel: 0.4]}
    ]
  end

  def tarol(:guerra, _bar), do: [{0, [vel: 0.8]}, {0.75, [vel: 0.7]}]

  def tarol(:baiao, bar) do
    [{0, [vel: 0.8]}, {0.75, [vel: 0.6]}, {1, [vel: 0.7]}] ++
      if(rem(bar, 4) == 3, do: [{1.5, [muted: 1, vel: 0.45]}], else: [])
  end

  def tarol(:perre, bar) do
    [{0, [vel: 0.8]}, {1, [vel: 0.6]}] ++
      if(rem(bar, 4) == 3, do: [{1.5, [muted: 1, vel: 0.45]}], else: [])
  end

  def tarol(:macumba, _bar), do: []

  # The preacas: three strikes a beat in guerra, two a bar in baião, one a bar in perré and macumba do índio.
  def preacas(:guerra), do: [0, 1 / 3, 2 / 3, 1, 4 / 3, 5 / 3]
  def preacas(:baiao), do: [0, 1]
  def preacas(_toque), do: [0]

  def flute(toque) do
    unit = unit(toque)

    notes =
      for phrase <- melody(toque), note <- phrase do
        {step, beats, graces} =
          case note do
            {step, beats} -> {step, beats, []}
            note -> note
          end

        # An appoggiatura takes a thirty-second note from the start of the note it leads to.
        graces =
          for grace <- graces,
              do:
                note(gaita(grace), 0.125 * unit,
                  vel: 0.5,
                  sustain: 0.08 * unit,
                  release: 0.03 * unit
                )

        length = (beats - 0.125 * length(graces)) * unit
        vel = if beats >= 1, do: 0.75, else: 0.6

        seq(
          graces ++
            [
              note(gaita(step), length,
                vel: vel,
                sustain: Float.round(length * 0.75, 4),
                release: Float.round(length * 0.15, 4)
              )
            ]
        )
      end

    seq(notes)
  end

  # The caracaxás shake sixteenths, the third of each beat accented, down on the beat and up off it; they rest while the atabaque plays.
  def caracaxa(:macumba, _accent, _soft, _up), do: rest(16 * unit(:macumba))

  def caracaxa(toque, accent, soft, up) do
    unit = unit(toque)

    hits =
      for {beat, place} <- sixteenths(unit),
          do: {beat, hit(vel: if(place == 2, do: accent, else: soft), up: up.(place))}

    at(hits, 16 * unit)
  end

  def low_bongo(toque) do
    unit = unit(toque)
    entries = for {beat, options} <- bars(unit, &tarol(toque, &1)), do: {beat, hit(options)}
    at(entries, 16 * unit)
  end

  def high_bongo(toque) do
    unit = unit(toque)
    strokes = bars(unit, fn _bar -> Enum.map(preacas(toque), &{&1, []}) end)
    entries = for {beat, _} <- strokes, do: {beat, hit(vel: 0.7)}
    at(entries, 16 * unit)
  end

  # The atabaque of macumba do índio, written for mx: the bass tone on the beats and slaps between them.
  def cajon(:macumba) do
    unit = unit(:macumba)

    bar = [
      {0, [vel: 0.8]},
      {0.5, [slap: 1, vel: 0.5]},
      {0.75, [vel: 0.6]},
      {1, [vel: 0.7]},
      {1.5, [slap: 1, vel: 0.6]}
    ]

    entries = for {beat, options} <- bars(unit, fn _bar -> bar end), do: {beat, hit(options)}

    at(entries, 16 * unit)
  end

  def cajon(toque), do: rest(16 * unit(toque))

  # G, two octaves and a fourth below the gaita's tonic.
  @root 43

  # Each bar's strokes for the kit, as {beat of the toque, options}: the kick and snare on the beats, the hi-hat off them.
  def kick(:guerra, bar) when rem(bar, 4) == 3, do: [{0, []}, {1, []}, {1.75, [amp: 0.5]}]
  def kick(:guerra, _bar), do: [{0, []}, {1, []}]
  def kick(:perre, _bar), do: [{0, []}, {1.5, []}]
  def kick(:baiao, _bar), do: [{0, []}, {0.75, []}]
  def kick(:macumba, bar) when rem(bar, 2) == 0, do: [{0, []}]
  def kick(:macumba, _bar), do: []

  def snare(:macumba, _bar), do: []
  def snare(:guerra, bar) when rem(bar, 2) == 1, do: [{1, []}, {1.75, [vel: 0.2]}]
  def snare(_toque, _bar), do: [{1, []}]

  def hihat(:macumba, _bar), do: []
  def hihat(_toque, _bar), do: [{0.5, []}, {1.5, [vel: 0.35]}]

  # The bass's notes as {beat of the toque, semitones above G, beats of the toque}.
  def bass_bar(:guerra, bar) when rem(bar, 4) == 3,
    do: [{0, 0, 0.5}, {0.75, 0, 0.25}, {1, 12, 0.25}, {1.25, 10, 0.25}, {1.5, 7, 0.5}]

  def bass_bar(:guerra, _bar), do: [{0, 0, 0.5}, {0.75, 0, 0.25}, {1, 7, 0.5}, {1.5, 10, 0.5}]
  def bass_bar(:perre, _bar), do: [{0, 0, 1}, {1, 7, 0.5}, {1.5, 5, 0.5}]
  def bass_bar(:baiao, _bar), do: [{0, 0, 0.75}, {0.75, 7, 0.25}, {1, 12, 0.5}, {1.5, 7, 0.5}]
  def bass_bar(:macumba, bar), do: [{0, Enum.at([0, 0, -2, -5], rem(bar, 4)), 2}]

  def drum(toque, strokes) do
    unit = unit(toque)

    entries =
      for {beat, options} <- bars(unit, &strokes.(toque, &1)), do: {beat, hit(options)}

    at(entries, 16 * unit)
  end

  # The wobble is wet only in macumba do índio, so the bass's sweep marks the breakdown.
  def bass(toque) do
    unit = unit(toque)
    wobble = if toque == :macumba, do: 1, else: 0

    notes =
      for bar <- 0..7, {beat, step, beats} <- bass_bar(toque, bar) do
        length = beats * unit

        {(bar * 2 + beat) * unit,
         note(@root + step, length,
           sustain: Float.round(length * 0.7, 4),
           release: Float.round(length * 0.2, 4)
         )}
      end

    seq([change({:bass, :wobble}, mix: wobble), at(notes, 16 * unit)])
  end

  # A root and fifth held through the pass, pulsed by a tremolo, under every toque but guerra.
  def pad(:guerra), do: rest(16 * unit(:guerra))

  def pad(toque) do
    beats = 16 * unit(toque)
    note([@root + 12, @root + 19], beats, sustain: beats - 1, release: 1)
  end

  def form do
    for {toque, count} <- [guerra: 2, perre: 2, baiao: 2, macumba: 2], _ <- 1..count do
      together([
        part(:flute, flute(toque),
          synth: :flute,
          defaults: [vibrato: 0.1],
          fx: [
            chorus: [mix: 0.4],
            ping_pong: [phase: 0.75, feedback: 0.35, mix: 0.25],
            reverb: [room: 0.4, mix: 0.2]
          ]
        ),
        part(:ganza, caracaxa(toque, 0.7, 0.35, &rem(&1, 2)),
          synth: :ganza,
          defaults: [amp: 0.4, pan: -0.2],
          fx: [bpf: [centre: 100, res: 0.3]]
        ),
        part(:shaker, caracaxa(toque, 0.65, 0.3, &(1 - rem(&1, 2))),
          synth: :shaker,
          defaults: [amp: 0.25, pan: 0.35],
          fx: [flanger: [phase: 8, feedback: 0.5, mix: 0.5]]
        ),
        part(:low_bongo, low_bongo(toque),
          synth: :low_bongo,
          defaults: [amp: 0.7, pan: 0.15],
          fx: [compressor: [threshold: 0.3]]
        ),
        part(:high_bongo, high_bongo(toque),
          synth: :high_bongo,
          defaults: [muted: 1, amp: 0.5, pan: -0.35],
          fx: [bitcrusher: [bits: 6, sample_rate: 8000, mix: 0.6]]
        ),
        part(:cajon, cajon(toque),
          synth: :cajon,
          defaults: [amp: 0.8],
          fx: [ping_pong: [phase: 0.5, feedback: 0.4, mix: 0.3]]
        ),
        part(:kick, drum(toque, &kick/2), synth: :kick, defaults: [amp: 0.45]),
        part(:snare, drum(toque, &snare/2),
          synth: :snare,
          defaults: [vel: 0.6, amp: 0.6],
          fx: [reverb: [room: 0.5, mix: 0.2]]
        ),
        part(:hihat, drum(toque, &hihat/2),
          synth: :closed_hihat,
          defaults: [vel: 0.5, amp: 0.4, pan: 0.25]
        ),
        part(:bass, bass(toque),
          synth: :saw,
          defaults: [amp: 0.8, cutoff: 95, attack: 0.01],
          fx: [
            rlpf: [cutoff: 86, res: 0.4],
            wobble: [phase: 1, cutoff_min: 50, cutoff_max: 90, res: 0.6, wave: 3, mix: 0],
            compressor: [threshold: 0.3, slope_above: 0.4]
          ]
        ),
        part(:pad, pad(toque),
          synth: :supersaw,
          defaults: [amp: 0.08, cutoff: 85, attack: 1, pan: -0.1],
          fx: [tremolo: [phase: 0.5, depth: 0.6], reverb: [room: 0.7, mix: 0.4]]
        )
      ])
    end
  end
end

song(tempo: 132, music: repeat(seq(CaboclinhoModern.form())))
