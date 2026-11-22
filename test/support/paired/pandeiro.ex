defmodule Mx.Paired.Pandeiro do
  @moduledoc """
  mxs's pandeiro written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @strokes %{
    thumb: %{
      gain: 0.0507,
      head: [1, 0.5, 0.18, 0.1, 0.05],
      rings: [0.55, 0.8, 0.6, 0.3, 0.2],
      crack: [3, 0.15, 8],
      jingle: [1, 0.5],
      length: 1.6
    },
    heel: %{
      gain: 0.074,
      head: [0.25, 1, 0.45, 0.2, 0.12],
      rings: [0.12, 0.5, 0.3, 0.2, 0.15],
      crack: [10, 0.15, 8],
      jingle: [3.5, 0.4],
      length: 1
    },
    slap: %{
      gain: 0.221,
      head: [0.01, 0.015, 0.015, 0.01, 0.01],
      rings: [0.6, 0.6, 0.5, 0.4, 0.3],
      crack: [6, 0.13, 5],
      jingle: [1.5, 0.3],
      length: 0.8
    },
    jingles: %{
      gain: 0.582,
      head: [0.035, 0.025, 0.012, 0.006, 0.003],
      rings: [0.4, 0.4, 0.3, 0.2, 0.1],
      crack: [1, 0.08, 10],
      jingle: [1, 0.35],
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
    pandeiro(hz(o.note), clamp(o.vel, 0, 1), clamp(o.muted, 0, 1), s)
    |> rings(seconds: s.length)
  end
end
