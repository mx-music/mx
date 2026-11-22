defmodule Mx.Paired.PedalHihat do
  @moduledoc """
  mxs's pedal hi-hat written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [fitted: 3]

  @stroke %{
    note: 60,
    partials: [],
    levels: [-4.9, 0, -17.8, -7.3, -8.2, -11.7, -10.6, -1, -0.7, -0.1],
    rings: [0.6, 0.97, 0.5, 0.39, 0.41, 0.45, 0.5, 0.5, 0.43, 0.3],
    partial_db: 0,
    early_db: -40,
    early_ring: 0.2,
    dense_db: 30,
    gain: -30
  }

  @doc "A pedal hi-hat: the two cymbals closed by the foot, as fitted to recordings."
  attr :note, :note, default: 60, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth pedal_hihat(o) do
    rings(fitted(2 ** ((o.note - @stroke.note) / 12), clamp(o.vel, 0, 1), @stroke), seconds: 0.97)
  end
end
