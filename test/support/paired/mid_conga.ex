defmodule Mx.Paired.MidConga do
  @moduledoc """
  mxs's mid_conga written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [conga: 6]

  @conga %{
    ratios: [0.487, 0.6, 0.66, 0.785, 0.944, 1, 1.13, 1.19, 1.627, 2.126, 2.226, 2.437, 3.5],
    levels: [-5.5, -29, -30, -26, -19, 0, -24, -30, -20, -32, -22, -23, -30],
    rings: [0.78, 0.9, 0.9, 1.05, 1.05, 1.05, 1.05, 1.05, 0.85, 0.62, 0.62, 0.62, 0.7],
    skin: [1.3, 1.7, -9.8, -31, -12.2, -14.1, -19.1],
    skin_rings: [0.32, 0.47, 0.9, 0.8, 0.6, 0.6, 0.6],
    tap: [26.6, 32.5, 29, -5.5, 16, 40.2, 25.9],
    tap_rings: [0.79, 0.61, 0.63, 1.43, 0.99, 0.47, 0.75],
    head_tap: [-5, -18, -18, -18, -18, -28, -28, -28, -30, -30, -30, -30, -28],
    tap_gain: -30.1,
    curve: 1.17,
    bright: [-5.5, 3],
    soft: 0.5,
    gain: -23.3
  }

  @doc "The conga, the middle drum of the three, with open, muted and slapped strokes."
  attr :note, :note, default: 51.88, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :mute, :float, default: 0, range: 0..1, doc: "1 taps the head with the fingers."
  attr :slap, :float, default: 0, range: 0..1, doc: "1 slaps the head."

  attr :damp, :float,
    default: 0,
    range: 0..1,
    doc: "1 leaves the hand on the head, which stops the tone."

  defsynth mid_conga(o) do
    # mxs trims the mid conga 3.2 dB louder.
    rings(
      conga(
        hz(o.note),
        clamp(o.vel, 0, 1),
        clamp(o.mute, 0, 1),
        clamp(o.slap, 0, 1),
        clamp(o.damp, 0, 1),
        @conga
      ) * db(3.2), seconds: 1.31)
  end
end
