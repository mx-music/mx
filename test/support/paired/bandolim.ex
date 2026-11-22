defmodule Mx.Paired.Bandolim do
  @moduledoc """
  mxs's bandolim written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Plucked, only: [plucked: 2]

  @string %{pick: 0.12, ring: 1.6, bright: 1.1, body: [380, 900], courses: [1, 1.0025]}

  @doc "A bandolim, the Brazilian mandolin, with steel strings and a tremolo."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the string is plucked."

  attr :tremolo, :float,
    default: 0,
    doc: "How many times a second a held note is picked; 0 picks it once."

  envelope_attrs sustain: 0, release: 0.8

  defsynth bandolim(o) do
    plucked(o, @string)
  end
end
