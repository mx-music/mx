defmodule Mx.Paired.LowBongo do
  @moduledoc """
  mxs's low bongo written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [bongo: 4]

  @bongo %{
    ratios: [0.46, 0.906, 1.005, 1.05, 1.548, 1.976, 2.9, 4.8, 7.6, 12.4, 19.5, 30],
    open: [-31.8, -12, 0, -7, -11.5, -15.5, -21, -33.7, -34, -44, -45, -50],
    open_rings: [1.97, 0.88, 0.91, 0.91, 0.79, 0.79, 0.68, 0.65, 0.62, 1.15, 1.26, 2.05],
    muted: [-16.3, -7, 0, -7, -5.2, -9.2, -14.3, -35.4, -34, -38, -40, -45],
    muted_rings: [0.79, 0.76, 0.79, 0.79, 0.75, 0.75, 0.7, 0.65, 0.69, 0.69, 0.63, 1.54],
    fast: [0.25, 0.25, 0.18, 0.18, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25],
    tail: List.duplicate(0.2, 12),
    curve0: 1.95,
    curve1: 2.45,
    gain: 0.02
  }

  @doc "The low bongo: a hand ringing the head's modes."
  attr :note, :note, default: 60, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :muted, :float, default: 0, range: 0..1, doc: "1 mutes the head with the hand."

  defsynth low_bongo(o) do
    # mxs trims the low bongo 5.2 dB louder.
    rings(
      bongo(hz(o.note), clamp(o.vel, 0, 1), clamp(o.muted, 0, 1), @bongo) * db(5.2),
      seconds: 1.18
    )
  end
end
