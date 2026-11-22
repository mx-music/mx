defmodule Mx.Paired.Cavaquinho do
  @moduledoc """
  mxs's cavaquinho written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Plucked, only: [plucked: 2]

  @string %{pick: 0.1, ring: 1.2, bright: 1.05, body: [420, 1100], courses: [1]}

  @doc "A cavaquinho, with steel strings, brighter and shorter than the guitar."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the string is plucked."

  attr :tremolo, :float,
    default: 0,
    doc: "How many times a second a held note is picked; 0 picks it once."

  envelope_attrs sustain: 0, release: 0.8

  defsynth cavaquinho(o) do
    plucked(o, @string)
  end
end
