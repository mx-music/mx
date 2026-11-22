defmodule Mx.Paired.LowConga do
  @moduledoc """
  mxs's low_conga written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [conga: 6]

  @conga %{
    ratios: [0.558, 0.78, 0.85, 1, 1.12, 1.525, 2.14, 2.24, 2.32, 2.42],
    levels: [-7, -21, -23, 0, -27, -12, -20, -13, -14, -12],
    rings: [0.5, 1.05, 1.05, 1.08, 1.08, 1.05, 0.8, 0.8, 0.8, 0.75],
    skin: [15.5, 6.2, 7.9, -1, 1.3, -0.5, -5.8],
    skin_rings: [0.6, 0.23, 0.61, 0.72, 0.6, 0.6, 0.6],
    tap: [31, 37.6, 30.1, 24.4, 2, 19.8, 14.6],
    tap_rings: [0.46, 0.59, 0.81, 0.78, 1.87, 1.01, 1.37],
    head_tap: [-35, -25, -25, -44, -44, -39, -26, -26, -26, -26],
    tap_gain: -17,
    curve: 0.79,
    bright: [-6, 5],
    soft: 0,
    gain: -33.8
  }

  @doc "The tumba, the low conga, with open, muted and slapped strokes."
  attr :note, :note, default: 48.93, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :mute, :float, default: 0, range: 0..1, doc: "1 taps the head with the fingers."
  attr :slap, :float, default: 0, range: 0..1, doc: "1 slaps the head."

  attr :damp, :float,
    default: 0,
    range: 0..1,
    doc: "1 leaves the hand on the head, which stops the tone."

  defsynth low_conga(o) do
    # mxs trims the low conga 3.4 dB quieter.
    rings(
      conga(
        hz(o.note),
        clamp(o.vel, 0, 1),
        clamp(o.mute, 0, 1),
        clamp(o.slap, 0, 1),
        clamp(o.damp, 0, 1),
        @conga
      ) * db(-3.4), seconds: 1.31)
  end
end
