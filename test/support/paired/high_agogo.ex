defmodule Mx.Paired.HighAgogo do
  @moduledoc """
  mxs's high agogo written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [agogo: 9]

  @doc "The high agogo bell: a stick's click ringing its modes, a hiss and a thump."
  attr :note, :note, default: 90.07, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth high_agogo(o) do
    rings(
      agogo(
        hz(o.note),
        clamp(o.vel, 0, 1),
        [0.671, 0.704, 1, 1.47, 2.206, 3.226, 3.572, 4.013, 4.598, 5.24, 5.9, 6.6],
        [0.04, 0.04, 1, 0.1, 0.25, 0.4, 0.1, 0.35, 0.8, 0.6, 0.5, 0.45],
        [0.75, 1.6, 0.56, 0.75, 1.05, 0.85, 0.65, 0.62, 0.42, 0.5, 0.38, 0.34],
        4,
        20_000,
        6,
        0.035
      ),
      seconds: 1.5
    )
  end
end
