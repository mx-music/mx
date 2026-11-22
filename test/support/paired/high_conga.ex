defmodule Mx.Paired.HighConga do
  @moduledoc """
  mxs's high_conga written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [conga: 6]

  @conga %{
    ratios: [0.372, 0.856, 0.943, 1, 1.12, 1.618, 1.664, 2.247, 2.415],
    levels: [-12, -33, -26.5, 0, -33.6, -14.5, -17.5, -25, -39.5],
    rings: [0.9, 0.72, 0.71, 0.7, 0.7, 0.8, 0.8, 0.47, 0.47],
    skin: [17.8, -3.4, -0.6, -8.7, -6.5, -6.1, -7.7],
    skin_rings: [0.47, 0.83, 0.4, 0.95, 0.6, 0.6, 0.6],
    tap: [8.5, 16.9, 25.5, 14, 9, 38.6, 24.7],
    tap_rings: [1.49, 1.26, 0.97, 1.11, 1.25, 0.2, 0.95],
    head_tap: [-14, -21, -21, -21, -21, -40, -40, -30, -30],
    tap_gain: -32.4,
    curve: 1.42,
    bright: [-1.5, 3],
    soft: 0,
    gain: -22.8
  }

  @doc "The quinto, the high conga, with open, muted and slapped strokes."
  attr :note, :note, default: 56.62, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :mute, :float, default: 0, range: 0..1, doc: "1 taps the head with the fingers."
  attr :slap, :float, default: 0, range: 0..1, doc: "1 slaps the head."

  attr :damp, :float,
    default: 0,
    range: 0..1,
    doc: "1 leaves the hand on the head, which stops the tone."

  defsynth high_conga(o) do
    rings(
      conga(
        hz(o.note),
        clamp(o.vel, 0, 1),
        clamp(o.mute, 0, 1),
        clamp(o.slap, 0, 1),
        clamp(o.damp, 0, 1),
        @conga
      ), seconds: 1.31)
  end
end
