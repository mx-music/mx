defmodule Mx.Paired.Violin do
  @moduledoc """
  mxs's violin written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @bands [113, 200, 316, 502, 794, 1265, 2000, 3162]
  @gains [
    [0.0, 0.0, 12.2, -3.9, 5.1, -11.6, 4.5, 5.0],
    [0.0, 0.0, 7.2, 2.1, 1.4, -1.5, 8.0, 6.1],
    [0.0, 0.0, 3.8, 2.0, 3.4, -3.2, 3.5, 11.5]
  ]

  @doc "A violin note, bowed or plucked."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the string is bowed or plucked."
  attr :pizz, :float, default: 0, range: 0..1, doc: "1 plucks the string instead of bowing it."

  attr :vibrato, :float,
    default: 0.25,
    range: 0..2,
    doc: "The vibrato's depth in semitones, reached as the note holds."

  envelope_attrs sustain: 1, release: 0.3
  attr :bow_speed, :float, default: 1, range: 0.1..4, doc: "How fast the bow moves."
  attr :bow_force, :float, default: 1, range: 0.1..4, doc: "How hard the bow presses."

  attr :legato, :float,
    default: 0,
    range: 0..1,
    doc: "1 changes bow from a note still sounding: the string speaks at once."

  attr :body_hz, :float, range: 20..2000, doc: "The body's corner, in place of the one fitted."
  attr :rosin, :float, range: 0..2, doc: "How much the rosin's noise sways the bow's speed."

  attr :bow_position, :float,
    default: 0.12,
    range: 0.05..0.5,
    doc: "Where the bow meets the string, as a fraction of its length from the bridge."

  for band <- 0..7 do
    attr :"eq#{band}", :float,
      range: -60..60,
      doc: "A band's gain in dB, in place of the one fitted."
  end

  defsynth violin(bowed) do
    pizz = clamp(bowed.pizz, 0, 1)
    {pluck, ends} = plucked(bowed, pizz)

    (held(bowed) * (1 - pizz) + pluck)
    |> note_envelope(bowed)
    |> rings(seconds: ends)
  end

  defsoundp held(bowed) do
    vel = bowed.vel

    by_vel = fn pp, mf, ff ->
      pp + (mf - pp) * clamp((vel - 0.3) / 0.3, 0, 1) + (ff - mf) * clamp((vel - 0.6) / 0.4, 0, 1)
    end

    speed = (0.2 + vel * 0.6) * bowed.bow_speed
    low = clamp(110 / hz(bowed.note), 1, 2)
    legato = clamp(bowed.legato, 0, 1)

    string =
      bowed_string(
        note: follow(bowed.note),
        speed: speed,
        force: 1.8 * low * speed * bowed.bow_force,
        position: bowed.bow_position,
        takes: 0.03 - 0.01 * legato,
        rosin: bowed.rosin || by_vel.(0.6, 0.23, 0.35)
      )

    body = bowed.body_hz || 384.3
    shaped = string |> highpass(hz: body, q: 0.541) |> highpass(hz: body, q: 1.307)

    shaped =
      Enum.reduce(Enum.with_index(@bands), shaped, fn {centre, band}, sound ->
        [pp, mf, ff] = Enum.map(@gains, &Enum.at(&1, band))
        gain = Map.fetch!(bowed, :"eq#{band}") || by_vel.(pp, mf, ff)
        peak(sound, hz: centre, q: 1.4, db: gain)
      end)

    # A delay that swings after the string gives the vibrato, which grows in after 0.3 seconds.
    depth = bowed.vibrato * :math.log(2) / 12 / (2 * :math.pi() * 5.4)
    grown = clamp(time() - 0.3, 0, 1) ** 2
    swing = 0.002 + sin(2 * :math.pi() * 5.4 * time() + :math.pi() / 2) * depth * grown
    cutoff = 2000 + vel * vel * 7000

    sound =
      shaped
      |> delay(seconds: swing, max: 0.01)
      |> lowpass(hz: cutoff, q: 0.541)
      |> lowpass(hz: cutoff, q: 1.307)

    hiss =
      noise(:pink)
      |> highpass(hz: 1800 - vel * 400, q: 0.707)
      |> gain(db(by_vel.(-35.5, -35.5, -30.5)))

    from_silence = min(by_vel.(0.875, 0.65, 0.35), bowed.sustain * 0.4)
    swell = max(from_silence + (min(0.06, from_silence) - from_silence) * legato, 1.0e-3)
    rising = 1 - (1 - min(time() / swell, 1)) ** 2

    dc_block(sound + hiss) * rising * (vel ** 0.6 * db(by_vel.(-25.05, -28.90, -30.45)))
  end

  defsoundp plucked(bowed, pizz) do
    vel = bowed.vel
    freq = hz(bowed.note)
    soft = max((1 - vel) / 0.7, 0)

    modes =
      for n <- 1..32 do
        octave = log2(freq * n / 333)
        level = min(octave, 0) * (18 + 6 * soft ** 3) - max(octave, 0) * (12 + 3 * soft)
        {n, select(freq * n < 16000, db(level), 0), 2.1 * 2 ** (octave * -0.55)}
      end

    strike = impulse()

    bank =
      mix(
        for {n, level, fade} <- modes, do: strike |> mode(hz: freq * n, level: level, fade: fade)
      )

    gain = 0.13 * pizz * vel ** 0.6

    # A plucked note falls silent once its loudest harmonic is 80 dB down.
    silent =
      Enum.reduce(modes, 0.1, fn {_n, level, fade}, longest ->
        loud = abs(level) * 0.13
        max(longest, select(loud > 1.0e-4, fade * 20 * log2(loud / 1.0e-4) / log2(10) / 60, 0))
      end)

    {bank * gain, select(pizz >= 1, silent, 1.0e9)}
  end
end
