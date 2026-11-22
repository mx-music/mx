defmodule Mx.Paired.Accordion do
  @moduledoc """
  mxs's accordion written with defsynth, node for node, so the two can be compared and timed.
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
  @table [0.0, -1.3, 1.8, 9.2, 7.7, 2.4, 0.5, -1.5, -4.8, -8.3, -23.0, -41.5]
  @noise [-8.2, -8.2, -13.6, -16.3, -14.7, -9.9, -10.1, -8.4, -13.1, 1.4, -27.8]
  @second 0.5

  @doc "An accordion's right hand: two reeds a few Hz apart, beating."
  attr :note, :note, default: 60, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the bellows are pressed."

  attr :detune, :float,
    default: 4,
    range: 0..20,
    doc: "How many Hz the second reed sounds above the first."

  envelope_attrs sustain: 0.5, release: 0.15
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  defsynth accordion(o) do
    vel = clamp(o.vel, 0, 1)
    freq = hz(o.note)
    detune = o.detune

    levels =
      for harmonic <- 1..48 do
        select(
          freq * harmonic < 16_000,
          db(along(@centres, @table, freq * harmonic) + (vel - 0.6) * 3 * :math.log2(harmonic)),
          0
        )
      end

    phases = for harmonic <- 1..48, do: :math.pi() * harmonic * (harmonic - 1) / 24

    reed = fn pitch ->
      partials(pitch, ratios: Enum.to_list(1..48), levels: levels, phases: phases)
    end

    one = reed.(pitch(o))
    two = (reed.(pitch(o)) + reed.(pitch(o) + detune) * @second) * (1 / (1 + @second))
    tone = select(detune > 0, two, one)

    noise =
      Enum.reduce(Enum.zip(tl(@centres), @noise), 0, fn {centre, level}, sum ->
        sum +
          (noise(:white) |> bandpass(hz: centre, q: 1 / 0.3) |> bandpass(hz: centre, q: 1 / 0.3)) *
            db(level)
      end)

    note_envelope(tilted(o, (tone + noise) * swell(o, 0.065) * (0.036 * (vel / 0.6) ** 1.2)), o)
  end
end
