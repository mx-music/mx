defmodule Mx.Paired.ClosedHihat do
  @moduledoc """
  mxs's closed_hihat written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3, exp_hit: 2, bpf: 3, band_noise: 4]

  @levels [-30.0, -6.4, -9.2, -10.6, -4.7, -1.4, -5.2, 10.4, 10.7, 14.7]
  @rings [0.79, 0.55, 0.58, 0.74, 0.55, 0.43, 0.71, 0.5, 0.31, 0.22]

  @doc "A closed hi-hat."
  attr :note, :note, default: 92, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :release, :beats, default: 0.05, doc: "How long the hat takes to close."

  defsynth closed_hihat(o) do
    vel = clamp(o.vel, 0, 1)
    scale = 2 ** ((o.note - 92) / 12)
    held = 0.8
    release = o.release
    soft = (1 - vel) / 0.7
    dark = highshelf(band_noise(@levels, @rings, 0, scale), hz: 4000, db: (0.333 - soft) * 10)
    sizzle = highpass(noise(:white), hz: 7000 * scale) * hit(0.001, 0.05, -4) * 0.035
    # The choke falls from 1, so it is 1 less an envelope rising from the graph's 0.
    choke = 1 - envelope([{held, 0}, {release, 1, -4}])

    thud =
      (noise(:white) * exp_hit(0.0005, Enum.at(@rings, 1)))
      |> bpf(320 * scale, 0.2)
      |> highpass(hz: 285 * scale)
      |> highpass(hz: 285 * scale)
      |> lowpass(hz: 400 * scale)
      |> gain(max(soft, 0) ** 0.5 * 0.25)

    # mxs turns the hat down by the dB its default stroke measured louder than scsynth's.
    rings(
      (dark * 0.1 + sizzle + thud) * 2.2 * choke * ((vel / 0.6) ** 2.8 * db(-3.2)),
      seconds: held + release
    )
  end
end
