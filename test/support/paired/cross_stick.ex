defmodule Mx.Paired.CrossStick do
  @moduledoc """
  mxs's cross stick written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @stroke %{
    note: 53.6,
    partials: [
      {181.2, 0, 0.65},
      {199.6, -12.1, 0.65},
      {289, -8.2, 1.71},
      {308.6, -10.7, 1.68},
      {1067.9, -19, 0.44},
      {1116.4, -14.4, 0.47},
      {1204.4, -16.1, 0.48},
      {1226.1, -17.4, 0.48},
      {1345.6, -18.8, 0.42},
      {1840, -17.6, 0.53},
      {1891.9, -19.3, 0.57},
      {1940.2, -19.4, 0.5}
    ],
    levels: [-19.1, -4.9, -13.9, -5.2, -2, -3.9, 0, -9.6, -15.6, -13.5],
    rings: [0.66, 1.2, 0.62, 0.53, 0.46, 0.52, 0.47, 0.51, 0.45, 0.33],
    partial_db: -6,
    early_db: 10,
    early_ring: 0.08,
    dense_db: 30,
    gain: -32
  }

  @doc "A cross stick: the stick laid across the snare's head and struck on its rim, as fitted to recordings."
  attr :note, :note, default: 53.6, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth cross_stick(o) do
    fitted(2 ** ((o.note - @stroke.note) / 12), clamp(o.vel, 0, 1), @stroke)
    |> rings(seconds: 1.2)
  end
end
