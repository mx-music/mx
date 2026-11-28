defmodule Mx.Paired.Reeds do
  @moduledoc """
  mxs's reed and brass winds written with defsynth node for node: `use Mx.Paired.Reeds` with a
  synth's name, its vibrato's rate, its bore and its fit.
  """

  use Mx.Instrument
  import Mx.Paired.Sounds, only: [tilted: 2]

  @eq for band <- 0..10, do: :"eq#{band}"

  defmacro __using__(opts) do
    {name, rate, bore, fit} = {opts[:name], opts[:rate], opts[:bore], opts[:fit]}

    quote do
      use Mx.Instrument

      import Mx.Paired.Reeds, only: [reed_wind: 4]

      @rate unquote(rate)
      @bore unquote(bore)
      @fit unquote(fit)

      @doc "A reed or brass wind: a reed or the lips on a bore, sounding through its bell."
      attr :note, :note,
        default: 52,
        doc: "The pitch; a change while the note holds slurs to the new one."

      attr :vel, :float,
        default: 0.6,
        range: 0..1,
        doc: "How hard it is blown; a change while the note holds swells or fades it."

      attr :vibrato, :float,
        default: 0,
        range: 0..2,
        doc: "The vibrato's depth in semitones, reached as the note holds."

      envelope_attrs sustain: 0.5, release: 0.2
      attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

      attr :brightness, :float,
        default: 0.5,
        range: 0..1,
        doc: "Tilts the sound 3 dB an octave either way of 0.5."

      attr :pressure, :float, default: 0, range: 0..1, doc: "Raises vel towards 1."
      attr :breath, :float, range: 0..3, doc: "The breath's pressure, in place of the one fitted."

      attr :rise, :float,
        range: 0.001..2,
        doc: "The seconds the breath takes to reach its pressure, in place of the one fitted."

      attr :air, :float,
        range: -90..0,
        doc: "The breath's noise in dB, in place of the one fitted."

      attr :level, :float,
        range: -60..60,
        doc: "The sound's level in dB, in place of the one fitted."

      for band <- 0..10 do
        attr :"eq#{band}", :float,
          range: -60..60,
          doc: "The gain in dB of band #{band}, in place of the one fitted."
      end

      attr :kick, :float, range: 0..3, doc: "The breath a soft note starts at."
      attr :catch, :float, range: 0..1, doc: "How far the sound falls at a slur."

      attr :mend, :float,
        range: 0..1,
        doc: "The seconds a slur's dip takes to come back to a third."

      attr :gasp, :float, range: 0..1, doc: "How far the breath falls at a slur."
      attr :corner, :float, range: 0..100, doc: "The bore's corner as a multiple of the pitch."
      attr :least_corner, :float, range: 0..20_000, doc: "The least the bore's corner is, in Hz."
      attr :keep, :float, range: 0..1, doc: "What the bore keeps at each round trip."
      attr :zeta, :float, range: 0..1, doc: "How freely the reed lets the air through."
      attr :apex, :float, range: 0..0.5, doc: "A cone's missing apex, as part of its length."

      attr :bell, :float,
        range: 0..20_000,
        doc: "The corner in Hz the bore's end lets sound out above."

      attr :tongue, :float,
        range: 0..2,
        doc: "The part of the pressure the tongue's release sends in."

      attr :steep, :float,
        range: 0..50,
        doc: "How much earlier a unit of pressure reaches the bell."

      attr :jitter, :float, range: 0..50, doc: "The cents the pitch drifts while a note holds."
      attr :shimmer, :float, range: 0..6, doc: "The dB the level drifts while a note holds."
      attr :wander, :float, range: 0..4, doc: "The part of itself the steepening drifts."
      attr :lift, :float, range: -24..24, doc: "The dB louder the sound is an octave up."
      attr :sharp, :float, range: -100..100, doc: "The cents the model plays sharp."

      defsynth unquote(name)(blown) do
        reed_wind(blown, @rate, @bore, @fit)
      end
    end
  end

  @doc """
  A reed wind's sound for the note `o`, its vibrato at `rate`, with `bore` and `fit` as mxs's
  tables give them.
  """
  defsound reed_wind(o, rate, bore, fit) do
    vel = clamp(o.vel, 0, 1)
    effort = clamp(vel + (1 - vel) * o.pressure, 0, 1)
    played = clamp(follow(o.vel) + (1 - follow(o.vel)) * follow(o.pressure), 0, 1)

    # The player takes back the cents the model plays sharp; a sharp given holds at every note.
    fitted = select((o.sharp || 1000) == 1000, 1, 0)
    note = fingers(follow(o.note)) + follow(o.bend)
    from = note - 60

    sharps =
      for [at, slope, curve] <- fit.sharp,
          do: (o.sharp || at) + fitted * (slope * from + curve * from * from)

    grown = clamp((time() - 0.25) / 1.2, 0, 1)
    swing = sin(2 * :math.pi() * rate * time()) * grown * grown * follow(o.vibrato)
    cents = (o.jitter || bore.jitter) * sway() - by_vel(played, sharps)
    pitch = hz(note + swing + cents / 100)

    steep = by_vel(played, Enum.map(fit.steep, &(o.steep || &1)))
    eased = 1 - clamp((o.wander || bore.wander) * (1 + sway()), 0, 1)

    rise = max(o.rise || by_vel(effort, fit.rise), 1.0e-3)
    kick = max((o.kick || bore.kick) - by_vel(effort, fit.breath), 0)
    kicked = kick * exp(-time() / 0.05) * risen(time(), 0.01)
    pressure = o.breath || by_vel(played, fit.breath)
    breath = pressure * risen(time(), min(rise, 0.01)) + kicked

    blown =
      reed(
        hz: pitch,
        breath: breath,
        conical: bore.conical,
        least_corner: o.least_corner || bore.cutoff,
        corner: o.corner || bore.corner,
        keep: o.keep || bore.keep,
        zeta: o.zeta || bore.zeta,
        apex: o.apex || 0.3,
        relative: bore.relative,
        tongue: o.tongue || bore.tongue,
        gasp: o.gasp || bore.gasp,
        mend: o.mend || bore.mend,
        steep: steep,
        through: risen(time(), rise),
        eased: eased,
        bell: o.bell || bore.bell,
        bell_corner: bore.bell_corner,
        smooth: bore.smooth,
        lift: o.lift || fit.lift,
        catch: o.catch || bore.catch
      )

    # The level's drift takes its seed after the reed's noise and before the breath's.
    voiced =
      share(blown, fn model ->
        shimmer = db((o.shimmer || bore.shimmer) * sway())
        air = db(by_vel(played, Enum.map(fit.air, &(o.air || &1))))
        noise = bandpass(noise(:white), hz: bore.air, q: 1) * air

        gains =
          for gains <- fit.gains,
              {at, band} <- Enum.zip(gains, @eq),
              do: Map.fetch!(o, band) || at

        shimmer *
          wind_bands(model + noise,
            vel: played,
            gains: gains,
            levels: Enum.map(fit.levels, &(o.level || &1))
          )
      end)

    note_envelope(tilted(o, voiced), o)
  end

  defsoundp by_vel(vel, [pp, mf, ff]) do
    pp + (mf - pp) * clamp((vel - 0.3) / 0.3, 0, 1) + (ff - mf) * clamp((vel - 0.6) / 0.4, 0, 1)
  end

  defsoundp risen(t, rise), do: 1 - (1 - min(t / rise, 1)) ** 2
end
