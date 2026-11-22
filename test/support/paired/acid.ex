defmodule Mx.Paired.Acid do
  @moduledoc """
  mxs's acid written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A saw and a pulse an octave down, under a resonant low-pass that springs shut, driven."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :cutoff, :note, default: 70, doc: "The MIDI note the filter closes to."
  attr :res, :float, default: 0.7, range: 0..1, doc: "How much the filter rings at its cutoff."
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Moves the cutoff two octaves either way of 0.5."

  envelope_attrs sustain: 0, release: 0.5

  defsynth acid(o) do
    pitch = hz(follow(o.note) + follow(o.bend))

    # The graph's envelopes start at 0, so the spring from 30 semitones down to 0 is 30 less one
    # rising to 30.
    spring = 30 - envelope([{0.18, 30, -4}])
    sound = saw(hz: pitch) * db(-4.5) + pulse(hz: pitch * 0.5, width: 0.5) * db(-4.5) * 0.25

    filtered =
      lowpass(sound,
        hz: clamp(hz(follow(o.cutoff) + spring + (follow(o.brightness) - 0.5) * 48), 20, 18_000),
        q: 1 / (1 - clamp(follow(o.res), 0, 1) * 0.93)
      )

    rising = exp(2 * 1.6 * filtered)

    note_envelope((rising - 1) / (rising + 1) * 0.45, o)
  end
end
