defmodule Mx.Paired.Cowbell do
  @moduledoc """
  mxs's cowbell written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3]

  @ratios [
    0.925,
    0.955,
    1,
    1.034,
    1.07,
    1.093,
    2.09,
    2.115,
    3.016,
    3.63,
    3.88,
    4.04,
    5.43,
    7.41,
    9.4,
    10.5,
    12.6,
    14.7,
    17,
    21
  ]
  @levels [
    -26,
    -18,
    0,
    -1,
    -7,
    -12,
    -18,
    -13,
    -27,
    -22,
    -14,
    -18,
    -7,
    -15,
    -20,
    -21,
    -29,
    -31,
    -33,
    -38
  ]
  @tone [0, 0, 0, 0, 0, 0, 0, 0, 0, -11, -11, -11, -18, -18, 7, 7, 7, 7, 7, 7]
  @mute [-8, -8, -8, -8, -8, -8, -12, -12, 7, 7, 7, 7, 4, 4, 11, 11, 11, 19, 19, 19]
  @rings [
    0.8,
    0.8,
    0.8,
    0.8,
    0.8,
    0.8,
    0.65,
    0.65,
    1.35,
    1.05,
    1.05,
    1.05,
    0.9,
    0.9,
    0.9,
    0.9,
    0.9,
    0.75,
    0.75,
    0.6
  ]

  @doc "A cowbell: a stick's click ringing its modes twice, briefly and long."
  attr :note, :note, default: 70.07, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :muted, :float, default: 0, range: 0..1, doc: "1 damps the bell with the hand."

  defsynth cowbell(o) do
    vel = clamp(o.vel, 0.05, 1)
    muted = clamp(o.muted, 0, 1)
    pitch = hz(o.note)
    bright = vel - 0.6
    worn = 0.6 + 0.4 * vel
    strike = impulse() + highpass(noise(:white), hz: 3000) * hit(0.0002, 0.002, -4) * 0.3

    levels =
      Enum.zip_with([@levels, @tone, @mute], fn [l, t, m] -> db(l + t * bright + m * muted) end)

    worn_rings = @rings |> Enum.slice(12..13) |> Enum.map(&(&1 * worn))
    rings = Enum.take(@rings, 12) ++ worn_rings ++ Enum.drop(@rings, 14)

    freqs = Enum.map(@ratios, &(pitch * &1))

    bell =
      mode(strike,
        hz: freqs ++ freqs,
        level: levels ++ Enum.map(levels, &(&1 * 0.06)),
        fade: Enum.map(rings, &(&1 * 0.13)) ++ Enum.map(rings, &(&1 * (1 - muted * 0.1)))
      )

    rings(bell * (db(-27.5) * (vel / 0.6) ** 2.3), seconds: 1.5)
  end
end
