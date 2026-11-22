defmodule Mx.Paired.Brass do
  @moduledoc """
  mxs's brass written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A saw and a pulse under a low-pass that opens with the breath, with breath noise and a late vibrato."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is blown."
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  envelope_attrs sustain: 0, release: 0.25

  defsynth brass(o) do
    vel = o.vel
    breath = envelope([{0.05, 1, 2}, {0.25, 0.8, -2}])
    scoop = -0.35 + envelope([{0.06, 0.35, 3}])
    vibrato = sine(hz: 5.3) * 0.12 * envelope([{0.3, 0}, {0.5, 1}])
    note = follow(o.note) + follow(o.bend)
    freq = hz(note + scoop + vibrato)
    reed = saw(hz: freq) * db(-4.5) + pulse(hz: freq, width: 0.38) * db(-4.5) * 0.5
    horn = lowpass(reed, hz: clamp(freq * (1.5 + breath * (2 + vel * 9)), 20, 18_000), q: 1 / 0.7)
    air = bandpass(noise(:white), hz: min(freq * 4, 20_000), q: 2) * 0.04 * breath
    sound = (horn * 0.4 + air) * (0.4 + vel * 0.6)

    pitch = hz(note)
    gain = (follow(o.brightness) - 0.5) * 12

    # An expression used twice is built twice, so a select between the dry and shelved sound would play a second noise; at brightness 0.5 the shelves' 0 dB leaves the sound as it is.
    tilted =
      Enum.reduce(0..3, sound, fn k, shelved ->
        highshelf(shelved, hz: min(pitch * (2 * 4 ** k), 18_000), q: 0.707, db: gain)
      end)

    tilted
    |> note_envelope(o)
  end
end
