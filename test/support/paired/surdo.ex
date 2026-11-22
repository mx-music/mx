defmodule Mx.Paired.Surdo do
  @moduledoc """
  mxs's surdo written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @open [
    [1, 1.69, 2, 2.38, 2.61, 3, 3.32, 4.12],
    [0, -26, -15.5, -16, -12.5, -18.5, -21.5, -24.5],
    [1.45, 1.25, 1.25, 1.1, 1.1, 1, 1, 1.2]
  ]
  @muted [
    [1.82, 2.03, 2.36, 2.57, 2.76, 3.11, 5.01, 5.71],
    [0, -6.6, -7.2, -8.3, -0.4, -3.7, 0, -6.5],
    [0.52, 0.68, 0.64, 0.64, 0.67, 0.69, 0.44, 0.48]
  ]
  @high [
    [4.9, 7.6, 12, 19, 30, 47.5],
    [-24, -12.3, -5.5, -23, -37, -34],
    [0.5, 0.25, 0.25, 0.2, 0.2, 0.2],
    [1.2, 2.4, 2.4, 2.4, 2.5, 3.4]
  ]

  @doc "A surdo: a mallet ringing the head's modes, open or muted, and its higher modes with their tails."
  attr :note, :note, default: 36.31, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :muted, :float,
    default: 0,
    range: 0..1,
    doc: "1 mutes the head with the hand, so it rings higher and shorter."

  defsynth surdo(o) do
    vel = clamp(o.vel, 0, 1)
    mute = clamp(o.muted, 0, 1)
    f = hz(o.note)

    mallet =
      impulse() +
        lowpass(noise(:white), hz: clamp(1500 + vel * 3000, 20, 20_000)) * hit(0.001, 0.006, -4) *
          0.2

    [open_ratios, open_levels, open_rings] = @open
    [muted_ratios, muted_levels, muted_rings] = @muted
    [high_ratios, high_levels, high_rings, tail_rings] = @high
    freqs = &Enum.map(&1, fn r -> f * r end)

    head =
      mode(mallet,
        hz:
          freqs.(open_ratios) ++
            freqs.(muted_ratios) ++ freqs.(high_ratios) ++ freqs.(high_ratios),
        level:
          Enum.map(open_levels, &(db(&1) * (1 - mute))) ++
            Enum.map(muted_levels, &(db(&1) * (mute * db(-6)))) ++
            Enum.map(high_levels, &db(&1)) ++ Enum.map(high_levels, &db(&1 - 20)),
        fade:
          open_rings ++
            muted_rings ++ high_rings ++ Enum.map(tail_rings, &(&1 * (1 - 0.6 * mute)))
      )

    (highshelf(head, hz: 800, q: 0.707, db: (vel - 0.6) * 6) * (0.05 * (vel / 0.6) ** 1.6))
    |> rings(seconds: 2 - 0.8 * mute)
  end
end
