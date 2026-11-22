defmodule Mx.Paired.Pulse do
  @moduledoc """
  mxs's pulse written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  # The synth is named after the pulse node, so the node is called by its module.
  import Mx.Instrument.Vocabulary, except: [pulse: 1]
  alias Mx.Instrument.Vocabulary, as: V

  @doc "A pulse wave under a resonant low-pass."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :cutoff, :note, default: 100, doc: "The MIDI note above which the low-pass cuts."
  attr :res, :float, default: 0.2, range: 0..1, doc: "How much the low-pass rings at its cutoff."

  attr :pulse_width, :float,
    default: 0.3,
    range: 0.01..0.99,
    doc: "The part of each cycle that is up."

  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Moves the cutoff two octaves either way of 0.5."

  envelope_attrs sustain: 0, release: 1

  defsynth pulse(o) do
    V.pulse(
      hz: hz(follow(o.note) + follow(o.bend)),
      width: clamp(follow(o.pulse_width), 0.01, 0.99)
    )
    |> gain(db(-4.5))
    |> lowpass(
      hz: clamp(hz(follow(o.cutoff) + (follow(o.brightness) - 0.5) * 48), 20, 18_000),
      q: 1 / (1 - clamp(follow(o.res), 0, 1) * 0.93)
    )
    |> gain(0.5)
    |> note_envelope(o)
  end
end
