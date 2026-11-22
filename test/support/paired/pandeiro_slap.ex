defmodule Mx.Paired.PandeiroSlap do
  @moduledoc """
  mxs's pandeiro_slap written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [pandeiro: 4]

  @stroke Mx.Paired.Pandeiro.strokes().slap

  @doc "The pandeiro's slap stroke."
  attr :note, :note, default: 49, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :muted, :float,
    default: 0,
    range: 0..1,
    doc:
      "1 presses a finger of the holding hand on the head from behind, so it rings higher and shorter."

  defsynth pandeiro_slap(o) do
    rings(
      pandeiro(hz(o.note), clamp(o.vel, 0, 1), clamp(o.muted, 0, 1), @stroke),
      seconds: @stroke.length
    )
  end
end
