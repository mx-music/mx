defmodule Mx.Paired.Tambourine do
  @moduledoc """
  mxs's tambourine written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [tambourine: 4]

  @doc "A tambourine struck, fitted to the University of Iowa's three tambourines."
  attr :note, :note, default: 69, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth tambourine(o) do
    vel = clamp(o.vel, 0.05, 1)
    scale = 2 ** ((o.note - 69) / 12)
    # mxs trims the tambourine 7.2 dB quieter.
    rings(tambourine(scale, vel, 0, false) * db(-7.2),
      seconds: 0.005 + 0 + 0.15 + vel * 0.6 + 0.7
    )
  end
end
