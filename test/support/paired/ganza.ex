defmodule Mx.Paired.Ganza do
  @moduledoc """
  mxs's ganza written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [shake: 4]

  @shake %{
    gain: 0.33,
    down: [0.045, 0.72, 2.6, 1.45, -8.0, 0.21, 0.72, 1.0, 1.0, -4.0, 5.0],
    upward: [0.025, 0.2, 2.4, 1.4, -9.0, 0.13, 0.2, 1.0, 1.0, -6.0, 5.0],
    stages: 1,
    dip: 0.75,
    up_notch: [1.05, 0.4, -18.0],
    darken: 1.0
  }

  @doc """
  A ganzá, a small shaker, with a down and an up stroke, fitted to the small shaker of the
  Versilian Community Sample Library.
  """
  attr :note, :note, default: 111, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :up, :float, default: 0, range: 0..1, doc: "1 shakes upward instead of down."

  defsynth ganza(o) do
    # mxs trims the ganza 2.3 dB quieter.
    rings(shake(hz(o.note), clamp(o.vel, 0, 1), clamp(o.up, 0, 1), @shake) * db(-2.3),
      seconds: 0.26
    )
  end
end
