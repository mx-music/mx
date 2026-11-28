defmodule Mx.Paired.Shaker do
  @moduledoc """
  mxs's shaker written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [shake: 4]

  @shake %{
    gain: 0.3,
    down: [0.02, 0.85, 2.6, 0.8, -3.0, 1.1, 0.2, 0.35, 0.65, 3.0, 5.0],
    upward: [0.15, 0.85, 1.6, 0.6, -11.0, 1.1, 0.85, 1.0, 0.9, -6.0, 5.0],
    stages: 3,
    dip: 0.6,
    up_notch: [1.0, 1.0, 0.0],
    darken: 0.45
  }

  @doc """
  A large shaker, with a down and an up stroke, fitted to the large shaker of the Versilian
  Community Sample Library.
  """
  attr :note, :note, default: 103, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :up, :float, default: 0, range: 0..1, doc: "1 shakes upward instead of down."

  defsynth shaker(o) do
    rings(shake(hz(o.note), clamp(o.vel, 0, 1), clamp(o.up, 0, 1), @shake), seconds: 1.2)
  end
end
