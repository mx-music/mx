defmodule Mx.Paired.FluteFigured do
  @moduledoc """
  mxs's flute played from its table, written with defsynth, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A flute played from its table, a change of note a slur to the new note's figures."
  attr :note, :note,
    default: 72,
    doc: "The pitch; a change while the note holds slurs to the new one."

  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the flute is blown."

  attr :vibrato, :float,
    range: 0..2,
    doc: "The vibrato's depth in semitones, in place of the recordings'."

  attr :inhale, :float, default: 0, range: 0..1, doc: "1 takes a breath once the note is let go."
  envelope_attrs sustain: 0.5, release: 0.2
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  attr :pressure, :float, default: 0, range: 0..1, doc: "Raises vel towards 1."

  defsynth flute_figured(o) do
    # A negative vibrato keeps the recordings'.
    figures(:flute,
      play: :blown,
      level: 3.4,
      vibrato: o.vibrato || -1,
      wander: 0.5,
      wander_above: 1.5,
      catch: 1,
      vary: 0.6,
      inhale: o.inhale,
      even: 1
    )
  end
end
