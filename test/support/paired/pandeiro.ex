defmodule Mx.Paired.Pandeiro do
  @moduledoc """
  mxs's pandeiro written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [pandeiro: 4]

  @free [0.974, 1.652, 2.475, 3.25, 4.13]

  @strokes %{
    thumb: %{
      gain: 0.0507,
      modes: @free,
      head: [2.8, 0.8, 0.812, 0.28, 0.308],
      rings: [0.85, 1.3, 0.69, 0.76, 0.48],
      crack: [3.4, 0.15, 7, 2],
      jingle: [0.75, 0.45, 1.5],
      shake: {[0.02, 0.2, 1, 0.5, 0.001], [0.008, 0.02, 0.05, 0.3]},
      pressed: 0.5,
      length: 1.6
    },
    heel: %{
      gain: 0.0115,
      modes: @free,
      head: [3, 0.93, 1.35, 0.75, 1.71],
      rings: [2.4, 1.5, 0.8, 0.7, 0.49],
      crack: [28, 0.15, 10, 2],
      jingle: [7.5, 0.38, 1.4],
      shake: {[0.5, 1, 0.45, 0.25, 0.001], [0.012, 0.028, 0.04, 0.2]},
      pressed: 1,
      length: 1
    },
    slap: %{
      gain: 0.19,
      modes: [0.974, 1.59, 2.17, 2.5, 2.93],
      head: [0.0369, 0.0309, 0.047, 0.034, 0.0276],
      rings: [0.83, 0.77, 0.57, 0.61, 0.52],
      crack: [16, 0.13, 3.3, 0.6],
      jingle: [1.5, 0.3, 0.6],
      shake: {[0.5, 1, 0.45, 0.13, 0.001], [0.008, 0.03, 0.04, 0.25]},
      pressed: 1,
      length: 0.8
    },
    jingles: %{
      gain: 0.0165,
      modes: @free,
      head: [0.9, 0.65, 0.95, 0.53, 1.2],
      rings: [0.6, 0.45, 0.3, 0.25, 0.2],
      crack: [14, 0.1, 10, 2],
      jingle: [7.5, 0.2, 1.4],
      shake: {[0.5, 1, 0.3, 0.06, 0.001], [0.012, 0.028, 0.04, 0.12]},
      pressed: 1,
      length: 1.2
    }
  }

  @doc false
  def strokes, do: @strokes

  @doc "A pandeiro stroke: the thumb, the heel of the hand, a slap or the fingertips on the jingles."
  attr :note, :note, default: 49, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :muted, :float,
    default: 0,
    range: 0..1,
    doc:
      "1 presses a finger of the holding hand on the head from behind, so it rings higher and shorter."

  attr :stroke, :atom,
    values: [:thumb, :heel, :slap, :jingles],
    default: :thumb,
    doc: "The stroke: the thumb, the heel of the hand, a slap or the fingertips on the jingles."

  defsynth pandeiro(%{stroke: :thumb} = o), do: played(o, @strokes.thumb)
  defsynth pandeiro(%{stroke: :heel} = o), do: played(o, @strokes.heel)
  defsynth pandeiro(%{stroke: :slap} = o), do: played(o, @strokes.slap)
  defsynth pandeiro(%{stroke: :jingles} = o), do: played(o, @strokes.jingles)

  defsoundp played(o, s) do
    rings(pandeiro(hz(o.note), clamp(o.vel, 0, 1), clamp(o.muted, 0, 1), s), seconds: s.length)
  end
end
