defmodule Mx.Paired.Bowed do
  @moduledoc """
  mxs's bowed strings without a violin's air, the viola and the double bass, written with defsynth node for node: `use Mx.Paired.Bowed` with a synth's name, its pluck and its fit.
  """

  use Mx.Instrument

  @bands [113, 200, 316, 502, 794, 1265, 2000, 3162]

  defmacro __using__(opts) do
    {name, pluck, fit} = {opts[:name], opts[:pluck], opts[:fit]}

    quote do
      use Mx.Instrument

      import Mx.Paired.Bowed, only: [held: 2, plucked: 3]

      @pluck unquote(pluck)
      @fit unquote(fit)

      @doc "A bowed string, which pizz: 1 plucks instead."
      attr :note, :note, default: 52, doc: "The pitch."

      attr :vel, :float,
        default: 0.6,
        range: 0..1,
        doc: "How hard the string is bowed or plucked."

      attr :pizz, :float,
        default: 0,
        range: 0..1,
        doc: "1 plucks the string instead of bowing it."

      attr :vibrato, :float, default: 0.25, range: 0..2, doc: "The vibrato's depth in semitones."
      envelope_attrs sustain: 1, release: 0.3
      attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

      attr :brightness, :float,
        default: 0.5,
        range: 0..1,
        doc: "Tilts the sound 3 dB an octave either way of 0.5."

      attr :bow_speed, :float, default: 1, range: 0.1..4, doc: "How fast the bow moves."
      attr :bow_force, :float, default: 1, range: 0.1..4, doc: "How hard the bow presses."

      attr :legato, :float,
        default: 0,
        range: 0..1,
        doc: "1 changes bow from a note still sounding."

      attr :body_hz, :float,
        range: 20..2000,
        doc: "The body's corner, in place of the one fitted."

      attr :rosin, :float, range: 0..2, doc: "How much the rosin's noise sways the bow's speed."
      attr :hiss, :float, range: -90..0, doc: "The bow's hiss in dB, in place of the one fitted."

      attr :bow_position, :float,
        default: 0.12,
        range: 0.05..0.5,
        doc: "Where the bow meets the string."

      for band <- 0..7 do
        attr :"eq#{band}", :float,
          range: -60..60,
          doc: "The gain in dB of band #{band}, in place of the one fitted."
      end

      defsynth unquote(name)(bowed) do
        pizz = clamp(bowed.pizz, 0, 1)
        {pluck, ends} = plucked(bowed, pizz, @pluck)

        (held(bowed, @fit) * (1 - pizz) + pluck)
        |> note_envelope(bowed)
        |> rings(seconds: ends)
      end
    end
  end

  @doc "The bowed string's held sound, as `fit` sets it for the note `bowed`."
  defsound held(bowed, fit) do
    vel = clamp(bowed.vel, 0, 1)

    by_vel = fn [pp, mf, ff] ->
      pp + (mf - pp) * clamp((vel - 0.3) / 0.3, 0, 1) +
        (ff - mf) * clamp((vel - 0.6) / 0.4, 0, 1)
    end

    speed = (0.2 + vel * 0.6) * bowed.bow_speed
    low = clamp(110 / hz(bowed.note), 1, 2)
    legato = clamp(bowed.legato, 0, 1)
    note = follow(bowed.note) + follow(bowed.bend)

    string =
      bowed_string(
        note: note,
        speed: speed,
        force: 1.8 * low * speed * bowed.bow_force,
        position: bowed.bow_position,
        takes: 0.03 - 0.01 * legato,
        rosin: bowed.rosin || by_vel.(fit.rosin)
      )

    body = bowed.body_hz || fit.body
    shaped = string |> highpass(hz: body, q: 0.541) |> highpass(hz: body, q: 1.307)

    shaped =
      Enum.reduce(Enum.with_index(@bands), shaped, fn {centre, band}, sound ->
        gain =
          Map.fetch!(bowed, :"eq#{band}") || by_vel.(Enum.map(fit.gains, &Enum.at(&1, band)))

        peak(sound, hz: centre, q: 1.4, db: gain)
      end)

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
      |> gain(db(bowed.hiss || by_vel.(fit.hiss)))

    from_silence = min(by_vel.(fit.swell), bowed.sustain * 0.4)
    swell = max(from_silence + (min(0.06, from_silence) - from_silence) * legato, 1.0e-3)
    rising = 1 - (1 - min(time() / swell, 1)) ** 2

    # mxs passes the sound untilted at brightness 0.5, where the shelves' 0 dB leaves it as it
    # is.
    pitch = hz(note)
    tilt = (follow(bowed.brightness) - 0.5) * 12

    tilted =
      Enum.reduce(0..3, dc_block(sound + hiss), fn k, shelved ->
        highshelf(shelved, hz: min(pitch * (2 * 4 ** k), 18_000), q: 0.707, db: tilt)
      end)

    tilted * rising * (vel ** 0.6 * db(by_vel.(fit.levels)))
  end

  @doc "The string plucked by `pizz`, as `pluck` sets it for the note `bowed`, and the seconds it rings."
  defsound plucked(bowed, pizz, pluck) do
    vel = clamp(bowed.vel, 0, 1)
    freq = hz(bowed.note)
    soft = max((1 - vel) / 0.7, 0)

    modes =
      for harmonic <- 1..pluck.count do
        octave = log2(freq * harmonic / pluck.peak)

        level =
          min(octave, 0) * (pluck.rise + pluck.soft_rise * soft ** 3) -
            max(octave, 0) * (pluck.fall + pluck.soft_fall * soft)

        {harmonic, select(freq * harmonic < 16_000, db(level), 0),
         pluck.fade * 2 ** (octave * pluck.fade_slope)}
      end

    strike = impulse()

    bank =
      mix(
        for {n, level, fade} <- modes,
            do: mode(strike, hz: freq * n, level: level, fade: fade)
      )

    gain = vel ** pluck.gain * db(pluck.level)

    # A plucked note falls silent once its loudest harmonic is 80 dB down.
    silent =
      Enum.reduce(modes, 0.1, fn {_n, level, fade}, longest ->
        loud = abs(level) * pluck.pluck

        max(
          longest,
          select(loud > 1.0e-4, fade * 20 * log2(loud / 1.0e-4) / log2(10) / 60, 0)
        )
      end)

    {bank * (pluck.pluck * pizz * gain), select(pizz >= 1, silent, 1.0e9)}
  end
end
