defmodule Mx.Paired.Vibraphone do
  @moduledoc """
  mxs's vibraphone written with defsynth, playing its table as mxs does, so the two can be compared and timed.
  """

  use Mx.Instrument

  @level 14.7

  @doc "The vibraphone, played from its table, its motor pulsing the note."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  envelope_attrs sustain: 1000, release: 0.3
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  attr :motor, :float,
    default: 0,
    range: 0..1_000_000,
    doc: "How many times a second the discs pulse the note; 0 leaves the motor off."

  defsynth vibraphone(%{motor: 0}), do: figures(:vibraphone, play: :kept, level: @level)

  defsynth vibraphone(o) do
    pulse = 1 - 0.25 * (1 - cos(2 * :math.pi() * o.motor * time()))
    figures(:vibraphone, play: :following, level: @level, times: pulse)
  end
end
