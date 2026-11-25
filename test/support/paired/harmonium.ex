defmodule Mx.Paired.Harmonium do
  @moduledoc """
  mxs's harmonium written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Sounds, only: [pitch: 1, tilted: 2, swell: 2, along: 3]

  @centres [
    65.4,
    113.0,
    200.0,
    316.0,
    502.0,
    794.0,
    1265.0,
    2000.0,
    3162.0,
    5019.0,
    7937.0,
    12_649.0
  ]
  @table [0.0, 6.85, 3.1, 3.8, -6.5, 3.9, 4.7, -1.0, -10.4, -27.1, -45.7, -55.6]
  @noise [2.4, 0.9, -8.8, -5.7, -5.6, -6.5, -7.0, -10.5, -17.5, -27.5, -40.5]

  @doc "A harmonium: a reed's harmonics and bands of noise from the bellows."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the bellows are pumped."
  envelope_attrs sustain: 0.5, release: 0.2
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  defsynth harmonium(o) do
    vel = clamp(o.vel, 0, 1)
    freq = hz(o.note)

    levels =
      for harmonic <- 1..48 do
        select(
          freq * harmonic < 16_000,
          db(along(@centres, @table, freq * harmonic) + (vel - 0.6) * 3 * :math.log2(harmonic)),
          0
        )
      end

    phases = for harmonic <- 1..48, do: :math.pi() * harmonic * (harmonic - 1) / 24
    tone = partials(pitch(o), ratios: Enum.to_list(1..48), levels: levels, phases: phases)

    noise =
      @centres
      |> tl()
      |> Enum.zip(@noise)
      |> Enum.reduce(0, fn {centre, level}, sum ->
        sum +
          (noise(:white) |> bandpass(hz: centre, q: 1 / 0.3) |> bandpass(hz: centre, q: 1 / 0.3)) *
            db(level)
      end)

    note_envelope(tilted(o, (tone + noise) * swell(o, 0.3) * (0.006 * (vel / 0.6) ** 1.2)), o)
  end
end
