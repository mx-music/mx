defmodule Mx.Paired.Violin do
  @moduledoc """
  mxs's violin written with defsynth, node for node, so the two can be compared and timed; it was modelled here first, fitted to the University of Iowa's arco violin, then ported.
  """

  use Mx.Instrument

  @bands [113, 200, 316, 502, 794, 1265, 2000, 3162]
  @gains [
    [0.0, 0.0, 12.2, -0.8, 8.0, -1.0, 4.5, 5.0],
    [0.0, 0.0, 7.2, 1.5, 1.4, -1.5, 8.0, 6.1],
    [0.0, 0.0, 3.8, -3.4, 3.4, -3.2, 3.5, 11.5]
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

  attr :cutoff_hz, :float,
    range: 1000..20_000,
    doc: "The lowpass after the body, in place of the fitted one; for fitting."

  attr :swell, :float,
    range: 0.01..4,
    doc: "The seconds a note rises from silence, in place of the fitted one; for fitting."

  attr :shelf_hz, :float,
    range: 1000..16_000,
    doc: "The air shelf's corner, in place of the fitted one; for fitting."

  attr :shelf_db, :float,
    range: -24..24,
    doc: "The air shelf's gain, in place of the fitted one; for fitting."

  attr :scratch_db, :float,
    range: -80..20,
    doc:
      "The level of the bow's scratch as it starts the string, in place of the fitted one; for fitting."

  attr :scratch_s, :float,
    range: 0.001..0.5,
    doc:
      "The seconds the scratch takes to fall by a factor of e, in place of the fitted one; for fitting."

  attr :wander_cents, :float,
    range: 0..50,
    doc:
      "How far the pitch drifts while a note holds, in cents, in place of the fitted one; for fitting."

  attr :wander_db, :float,
    range: 0..12,
    doc:
      "How far each band of the body drifts while a note holds, in dB, in place of the fitted one; for fitting."

  attr :hiss_hz, :float,
    range: 200..12_000,
    doc: "The centre of the bow's hiss, in place of the fitted one; for fitting."

  attr :hiss_db, :float,
    range: -80..0,
    doc: "The bow's hiss level, in place of the fitted one; for fitting."

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
        note: follow(bowed.note) + wander(bowed, 0) * (bowed.wander_cents || 2) / 100,
        speed: speed,
        force: 1.8 * low * speed * bowed.bow_force,
        position: bowed.bow_position,
        takes: 0.03 - 0.01 * legato,
        rosin: bowed.rosin || by_vel.(0.15, 0.23, 0.35)
      )

    body = bowed.body_hz || 384.3
    shaped = string |> highpass(hz: body, q: 0.541) |> highpass(hz: body, q: 1.307)

    shaped =
      Enum.reduce(Enum.with_index(@bands), shaped, fn {centre, band}, sound ->
        [pp, mf, ff] = Enum.map(@gains, &Enum.at(&1, band))
        gain = Map.fetch!(bowed, :"eq#{band}") || by_vel.(pp, mf, ff)

        peak(sound,
          hz: centre,
          q: 1.4,
          db: gain + wander(bowed, band + 1) * (bowed.wander_db || 4.5)
        )
      end)

    # A delay that swings after the string gives the vibrato, which grows in after 0.3 seconds.
    depth = bowed.vibrato * :math.log(2) / 12 / (2 * :math.pi() * 5.4)
    grown = clamp(time() - 0.3, 0, 1) ** 2
    swing = 0.002 + sin(2 * :math.pi() * 5.4 * time() + :math.pi() / 2) * depth * grown
    cutoff = bowed.cutoff_hz || 16_000

    sound =
      shaped
      |> highshelf(hz: bowed.shelf_hz || 6000, db: bowed.shelf_db || by_vel.(6, 17, 16), q: 0.707)
      |> delay(seconds: swing, max: 0.01)
      |> lowpass(hz: cutoff, q: 0.541)
      |> lowpass(hz: cutoff, q: 1.307)

    hiss =
      noise(:pink)
      |> bandpass(hz: bowed.hiss_hz || 3000, q: 0.7)
      |> gain(db(bowed.hiss_db || by_vel.(0, -35.5, -30.5)))

    from_silence = min(bowed.swell || by_vel.(1.3, 1.0, 0.45), bowed.sustain * 0.4)
    swell = max(from_silence + (min(0.06, from_silence) - from_silence) * legato, 1.0e-3)
    rising = 1 - (1 - min(time() / swell, 1)) ** 2

    # The bow catching the string scratches before the string speaks, unless it changes bow from a
    # sounding note.
    scratch =
      noise(:white)
      |> highpass(hz: 400, q: 0.707)
      |> gain(
        db(bowed.scratch_db || -8) * (1 - exp(-time() / 0.004)) *
          exp(-time() / (bowed.scratch_s || 0.03)) * (1 - legato)
      )

    (dc_block(sound + hiss) * rising + scratch) *
      (vel ** 0.6 * db(by_vel.(-25.05, -28.90, -30.45)))
  end

  # A slow drift of a standard deviation near 1: three sines at unrelated rates, their phases set
  # by `which` and the note.
  # mxs's filters stop at 20 Hz, so noise cannot be slowed this far.
  defsoundp wander(bowed, which) do
    mix(
      for {rate, index} <- Enum.with_index([0.23, 0.41, 0.67]) do
        phase = bowed.note * (1.7 + index) + which * (2.3 + 0.9 * index)
        sin(2 * :math.pi() * rate * (1 + 0.05 * which) * time() + phase) * 0.816
      end
    )
  end

  defsoundp plucked(bowed, pizz) do
    vel = bowed.vel
    freq = hz(bowed.note)
    soft = max((1 - vel) / 0.7, 0)

    modes =
      for harmonic <- 1..32 do
        octave = log2(freq * harmonic / 333)
        level = min(octave, 0) * (18 + 6 * soft ** 3) - max(octave, 0) * (12 + 3 * soft)
        {harmonic, select(freq * harmonic < 16_000, db(level), 0), 2.1 * 2 ** (octave * -0.55)}
      end

    strike = impulse()

    bank =
      mix(for {n, level, fade} <- modes, do: mode(strike, hz: freq * n, level: level, fade: fade))

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
