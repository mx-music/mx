defmodule Mx.Paired.Cello do
  @moduledoc """
  mxs's cello written with defsynth, playing its table as mxs does, so the two can be compared and timed.

  It is bowed only: mxs mixes a pluck into a note given pizz, built in a context of its own, which a defsynth cannot build.
  """

  use Mx.Instrument

  @doc "The cello, bowed, played from its table."
  attr :note, :note,
    default: 52,
    doc: "The pitch; a change while the note holds slides to the new one."

  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the string is bowed."
  attr :pizz, :float, default: 0, range: 0..1, doc: "1 plucks the string; not twinned."

  attr :vibrato, :float,
    default: 0.25,
    range: 0..2,
    doc: "The vibrato's depth in semitones, reached as the note holds."

  attr :legato, :float,
    default: 0,
    range: 0..1,
    doc: "1 changes bow from a note still sounding: the string speaks at once."

  envelope_attrs sustain: 1, release: 0.3
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  attr :pressure, :float, default: 0, range: 0..1, doc: "Raises vel towards 1."

  defsynth cello(o) do
    figures(:cello, play: :held, level: 1, vibrato: o.vibrato, legato: o.legato)
  end
end
