defmodule Mx.Paired.Supersaw do
  @moduledoc """
  mxs's supersaw written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "Seven saws spread around the note under a resonant low-pass."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :cutoff, :note, default: 110, doc: "The MIDI note above which the low-pass cuts."
  attr :res, :float, default: 0.2, range: 0..1, doc: "How much the low-pass rings at its cutoff."
  attr :detune, :float, default: 0.2, doc: "How far in semitones the saws spread around the note."
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Moves the cutoff two octaves either way of 0.5."

  envelope_attrs sustain: 0, release: 1

  defsynth supersaw(o) do
    note = follow(o.note) + follow(o.bend)

    saws =
      Enum.reduce([-1.0, -0.62, -0.3, 0.0, 0.3, 0.62, 1.0], 0, fn offset, sum ->
        sum + saw(hz: hz(note + offset * follow(o.detune))) * db(-4.5)
      end)

    saws
    |> lowpass(
      hz: clamp(hz(follow(o.cutoff) + (follow(o.brightness) - 0.5) * 48), 20, 18_000),
      q: 1 / (1 - clamp(follow(o.res), 0, 1) * 0.93)
    )
    |> gain(0.18)
    |> note_envelope(o)
  end
end
