defmodule Mx.Paired.MidTom do
  @moduledoc """
  mxs's mid tom written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [tom: 4]

  @note 43.4
  @tom %{
    ratios: [1, 1.16, 1.32, 1.95, 2.55, 2.71, 2.99, 3.08, 3.59, 6.78],
    levels: [0, -8, -11, -10, -7.7, -11, -4.6, -7.8, -10.7, -19.8],
    rings: [1.47, 1.47, 1.5, 2.1, 1, 0.79, 0.79, 0.78, 0.92, 0.62],
    skin: [34, -51.6, 28.7, -2.7, 16, 8.1, -3.4, -32.5],
    skin_rings: [0.75, 0.47, 0.54, 0.38, 0.65, 0.47, 0.6, 0.1],
    gain: -35.1,
    curve: 1.32,
    bright: [1500, 0, 12, 16]
  }

  @doc "The mid tom: a stick ringing the head's modes, over the skin's noise."
  attr :note, :note, default: 43.4, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth mid_tom(o) do
    # mxs trims the mid tom 5 dB quieter.
    rings(tom(o.note, @note, clamp(o.vel, 0, 1), @tom) * db(-5), seconds: 2.5)
  end
end
