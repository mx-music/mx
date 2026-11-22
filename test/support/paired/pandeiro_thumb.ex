defmodule Mx.Paired.PandeiroThumb do
  @moduledoc """
  mxs's pandeiro_thumb written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @stroke Mx.Paired.Pandeiro.strokes().thumb

  @doc "The pandeiro's thumb stroke."
  attr :note, :note, default: 49, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :muted, :float,
    default: 0,
    range: 0..1,
    doc:
      "1 presses a finger of the holding hand on the head from behind, so it rings higher and shorter."

  defsynth pandeiro_thumb(o) do
    pandeiro(hz(o.note), clamp(o.vel, 0, 1), clamp(o.muted, 0, 1), @stroke)
    |> rings(seconds: @stroke.length)
  end
end
