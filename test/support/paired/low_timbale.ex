defmodule Mx.Paired.LowTimbale do
  @moduledoc """
  mxs's low timbale written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @doc "The low timbale: a stick ringing the head and the shell."
  attr :note, :note, default: 62, doc: "The drum's pitch."

  defsynth low_timbale(o) do
    # mxs trims the low timbale 5.2 dB quieter.
    (timbale(hz(o.note)) * db(-5.2))
    |> rings(seconds: 1.2)
  end
end
