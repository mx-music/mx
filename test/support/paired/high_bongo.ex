defmodule Mx.Paired.HighBongo do
  @moduledoc """
  mxs's high bongo written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @bongo %{
    ratios: [0.26, 0.45, 0.63, 0.665, 0.97, 0.987, 1.7, 2.7, 4.3, 7, 11, 17, 27],
    open: [-35.2, -16, -0.9, -0.9, -6, 0, -18.2, -20.6, -17.8, -31.8, -36.6, -40.6, -50.6],
    open_rings: [6.5, 0.95, 0.98, 0.98, 0.64, 0.64, 0.59, 0.64, 0.65, 1.22, 1.8, 2.61, 3.53],
    muted: [-29, -14.5, -1, -1, -6, 0, -15.2, -22.2, -19.3, -30.6, -30.9, -32.1, -45.7],
    muted_rings: [1.59, 0.79, 0.9, 0.9, 0.68, 0.68, 0.52, 0.65, 0.71, 0.69, 0.63, 0.85, 2.49],
    fast: [0.25, 0.25, 0.12, 0.12, 0.7, 0.7, 1, 0.25, 0.15, 0.25, 0.25, 0.25, 0.25],
    tail: [0.2, 0.2, 0.14, 0.14, 0, 0, 0, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
    curve0: 1.95,
    curve1: 1,
    gain: 0.017
  }

  @doc "The high bongo: a hand ringing the head's modes."
  attr :note, :note, default: 70, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :muted, :float, default: 0, range: 0..1, doc: "1 mutes the head with the hand."

  defsynth high_bongo(o) do
    bongo(hz(o.note), clamp(o.vel, 0, 1), clamp(o.muted, 0, 1), @bongo)
    |> rings(seconds: 1.18)
  end
end
