defmodule Mx.Paired.HighTimbale do
  @moduledoc """
  mxs's high timbale written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [timbale: 1]

  @doc "The high timbale: a stick ringing the head and the shell."
  attr :note, :note, default: 67, doc: "The drum's pitch."

  defsynth high_timbale(o) do
    # mxs trims the high timbale 2.5 dB quieter.
    rings(timbale(hz(o.note)) * db(-2.5), seconds: 1.2)
  end
end
