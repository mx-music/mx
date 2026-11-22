defmodule Mx.Paired.Noise do
  @moduledoc """
  mxs's noise written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  # The synth is named after the noise node, so the node is called by its module.
  alias Mx.Instrument.Vocabulary, as: V

  @doc "White noise under a resonant low-pass."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :cutoff, :note, default: 110, doc: "The MIDI note above which the low-pass cuts."
  attr :res, :float, default: 0.2, range: 0..1, doc: "How much the low-pass rings at its cutoff."
  envelope_attrs sustain: 0, release: 1

  defsynth noise(o) do
    V.noise(:white)
    |> lowpass(
      hz: clamp(hz(follow(o.cutoff)), 20, 18_000),
      q: 1 / (1 - clamp(follow(o.res), 0, 1) * 0.93)
    )
    |> gain(0.4)
    |> note_envelope(o)
  end
end
