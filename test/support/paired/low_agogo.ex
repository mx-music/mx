defmodule Mx.Paired.LowAgogo do
  @moduledoc """
  mxs's low agogo written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [agogo: 9]

  @doc "The low agogo bell: a stick's click ringing its modes, and a hiss."
  attr :note, :note, default: 84, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth low_agogo(o) do
    rings(
      agogo(
        hz(o.note),
        clamp(o.vel, 0, 1),
        [
          0.953,
          1,
          2.197,
          2.197,
          2.85,
          3.249,
          3.763,
          3.91,
          4.021,
          4.657,
          5.848,
          6.488,
          7.3,
          8.1,
          9.39
        ],
        [0.3, 1, 0.5, 0.2, 0.65, 0.8, 0.3, 0.25, 0.45, 0.4, 0.5, 0.5, 0.6, 0.45, 0.45],
        [2.6, 2, 0.25, 1, 0.7, 1, 0.62, 0.6, 0.72, 0.52, 0.57, 0.45, 0.4, 0.35, 0.29],
        7,
        7800,
        0,
        0.026
      ),
      seconds: 2.6
    )
  end
end
