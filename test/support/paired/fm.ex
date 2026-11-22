defmodule Mx.Paired.Fm do
  @moduledoc """
  mxs's fm written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A sine whose frequency a second sine swings."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :divisor, :float, default: 2, doc: "The note's frequency over the modulator's."

  attr :depth, :float,
    default: 1,
    doc: "How far the modulator swings the frequency, in times the note's."

  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."
  envelope_attrs sustain: 0, release: 1

  defsynth fm(o) do
    pitch = hz(follow(o.note) + follow(o.bend))
    modulator = sine(hz: pitch / max(follow(o.divisor), 0.01))

    sine(hz: pitch + modulator * pitch * follow(o.depth))
    |> gain(0.6)
    |> note_envelope(o)
  end
end
