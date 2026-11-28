defmodule Mx.Paired.TambourineShake do
  @moduledoc """
  mxs's tambourine_shake written with defsynth, node for node, so the two can be compared and
  timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [tambourine: 4]

  @doc "A tambourine shaken for as long as its sustain."
  attr :note, :note, default: 69, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :sustain, :beats, default: 0.25, doc: "How long it is shaken."

  defsynth tambourine_shake(o) do
    vel = clamp(o.vel, 0.05, 1)
    scale = 2 ** ((o.note - 69) / 12)
    # mxs trims the tambourine shake 6.6 dB quieter.
    rings(tambourine(scale, vel, max(o.sustain, 0.02), true) * db(-6.6),
      seconds: 0.005 + max(o.sustain, 0.02) + 0.15 + vel * 0.6 + 0.7
    )
  end
end
