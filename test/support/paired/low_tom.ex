defmodule Mx.Paired.LowTom do
  @moduledoc """
  mxs's low tom written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [tom: 4]

  @note 41.85
  @tom %{
    ratios: [1, 1.18, 1.39, 1.59, 1.78, 2.88, 3, 3.21, 3.73, 4.1, 4.22],
    levels: [0, -9.4, -12.1, -12.9, -15.2, -9.3, -9.8, -14.7, -14.6, -6.9, -13.2],
    rings: [1.6, 1.6, 1.56, 1.5, 1.4, 1.5, 1.5, 1.5, 0.95, 0.93, 1.06],
    skin: [35, 35.5, 19.4, 26, 20, 9.7, 6.5, -58.9],
    skin_rings: [0.9, 0.73, 0.33, 0.5, 0.6, 0.62, 0.55, 0.06],
    gain: -32,
    curve: 0.79,
    bright: [250, 24, 20, 10]
  }

  @doc "The low tom: a stick ringing the head's modes, over the skin's noise."
  attr :note, :note, default: 41.85, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth low_tom(o) do
    rings(tom(o.note, @note, clamp(o.vel, 0, 1), @tom), seconds: 2.5)
  end
end
