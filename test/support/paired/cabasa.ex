defmodule Mx.Paired.Cabasa do
  @moduledoc """
  mxs's cabasa written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [bpf: 3]

  @doc "A cabasa: beads struck against the cylinder, or turned against it for the sustain with rub."
  attr :note, :note, default: 96, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :rub, :float,
    default: 0,
    range: 0..1,
    doc: "1 turns the beads against the cylinder for the sustain."

  attr :sustain, :beats, default: 0.1, doc: "How long a rub lasts."

  defsynth cabasa(o) do
    freq = hz(o.note)
    vel = clamp(o.vel, 0, 1)
    rub = clamp(o.rub, 0, 1)
    hold = max(o.sustain, 0.01) * rub
    rising = envelope([{0.002, 1}, {hold, 1}])
    burst = rising * envelope([{0, 1}, {0.002, 1, :exp}, {hold, 1, :exp}, {0.22, 0.001, :exp}])
    tail = rising * envelope([{0, 1}, {0.002, 1, :exp}, {hold, 1, :exp}, {0.9, 0.001, :exp}])

    beads =
      struck(clicks(rate: 6000), attack: 0.0001, fall: 0.0008) * noise(:white) +
        noise(:white) * 0.2

    bottom = clamp(freq * (0.6 + rub * 0.4), 20, 20_000)

    colour =
      beads
      |> highpass(hz: bottom, q: 1 / 1.41)
      |> highpass(hz: bottom, q: 1 / 1.41)

    shell = bpf(noise(:white), freq * 0.25, 1) * (0.15 * (1 - rub))

    shaped =
      colour
      |> highshelf(hz: clamp(freq * 3, 20, 20_000), q: 0.707, db: 4)
      |> peak(hz: clamp(freq * 2.4, 20, 20_000), q: 1, db: -3)

    bright =
      highshelf(shaped + shell, hz: clamp(freq * 2, 20, 20_000), q: 0.707, db: (vel - 0.6) * 6)

    # The bright sound plays through the burst and, lowpassed, through the tail: built once.
    sound =
      share(bright, fn both ->
        both * burst * 0.9 + lowpass(both, hz: clamp(freq * 3.5, 20, 20_000), q: 1) * tail * 0.1
      end)

    rings(sound * (0.5 * (1 - rub * 0.52) * (vel / 0.6) ** 1.1), seconds: 0.002 + hold + 0.9)
  end
end
