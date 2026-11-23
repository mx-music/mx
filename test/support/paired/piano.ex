defmodule Mx.Paired.Piano do
  @moduledoc """
  mxs's piano written with defsynth, playing its two tables as mxs does, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "The piano, played from its tables with the pedal and without."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0.05..1, doc: "How hard the key is struck."
  attr :pedal, :float, default: 0, range: 0..1, doc: "How far the sustain pedal is down."

  attr :aftersound, :float,
    default: 0.5,
    range: 0..1,
    doc: "How far each partial fades in two stages."

  attr :uneven, :float,
    default: 1,
    range: 0..1,
    doc: "How far each key not recorded differs from those either side."

  attr :instrument, :integer, default: 0, doc: "Which piano's keys uneven draws."
  attr :knock, :float, default: 1, range: 0..1, doc: "How loud the hammer's knock is."
  envelope_attrs sustain: 1, release: 1
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  defsynth piano(_o), do: figures(:piano, play: :piano)
end
