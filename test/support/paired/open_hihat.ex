defmodule Mx.Paired.OpenHihat do
  @moduledoc """
  mxs's open_hihat written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @levels [-21.0, -14.9, 7.9, -22.7, 5.6, -2.4, 8.4, 11.1, 11.0, 15.0]
  @rings [2.0, 3.5, 2.37, 2.49, 2.32, 2.96, 2.63, 2.49, 2.71, 2.6]

  @doc "An open hi-hat, which rings until it is closed."
  attr :note, :note, default: 92, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :release, :beats, default: 0.05, doc: "How long the hat takes to close."
  attr :sustain, :beats, default: 5, doc: "How long it rings open."

  defsynth open_hihat(o) do
    vel = clamp(o.vel, 0, 1)
    scale = 2 ** ((o.note - 92) / 12)
    held = o.sustain
    release = o.release
    soft = (1 - vel) / 0.7
    dark = band_noise(@levels, @rings, 0, scale) |> highshelf(hz: 4000, db: (0.333 - soft) * 10)
    sizzle = highpass(noise(:white), hz: 7000 * scale) * hit(0.001, 0.05, -4) * 0.035
    # The choke falls from 1, so it is 1 less an envelope rising from the graph's 0.
    choke = 1 - envelope([{held, 0}, {release, 1, -4}])

    thud =
      (noise(:white) * exp_hit(0.0005, Enum.at(@rings, 1)))
      |> bpf(320 * scale, 0.2)
      |> highpass(hz: 285 * scale)
      |> highpass(hz: 285 * scale)
      |> lowpass(hz: 400 * scale)
      |> gain(max(soft, 0) ** 0.5 * 0)

    # mxs turns the hat down by the dB its default stroke measured louder than scsynth's.
    ((dark * 0.1 + sizzle + thud) * 3.3 * choke * ((vel / 0.6) ** 2.8 * db(-5.4)))
    |> rings(seconds: held + release)
  end
end
