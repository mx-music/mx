defmodule Mx.Paired.Clap do
  @moduledoc """
  mxs's clap written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [bpf: 3]

  @doc "A hand clap: band-passed noise in four quick bursts."
  attr :note, :note, default: 60, doc: "The clap's pitch."

  defsynth clap(o) do
    hands =
      envelope([
        {0.001, 1, -6},
        {0.008, 0.2, -6},
        {0.001, 1, -6},
        {0.009, 0.2, -6},
        {0.001, 0.9, -6},
        {0.011, 0.1, -6},
        {0.001, 0.8, -6},
        {0.32, 0, -6}
      ])

    rings(bpf(noise(:white), hz(o.note) * 4.2, 0.9) * hands * 1.8, seconds: 0.6)
  end
end
