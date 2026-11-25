defmodule Mx.Paired.Tamborim do
  @moduledoc """
  mxs's tamborim written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3]

  @ratios [0.38, 0.55, 1, 1.8, 2.5, 3.2, 4, 5, 6.3, 8, 10, 13, 17]
  @levels [-26, -17, 0, -2, -3.5, -8, -9, -10, -11, -15, -18, -18, -22]
  @rings [0.68, 0.58, 0.45, 0.85, 0.9, 0.85, 0.75, 0.7, 0.7, 0.6, 0.5, 0.45, 0.4]

  @doc "A tamborim: a stick ringing the head's modes, and the crack of the stick on the skin."
  attr :note, :note, default: 72.03, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth tamborim(o) do
    vel = clamp(o.vel, 0, 1)
    pitch = hz(o.note)
    stick = impulse() + highpass(noise(:white), hz: 2000) * hit(0.0003, 0.004, -4) * 0.3

    head =
      mode(stick,
        hz: Enum.map(@ratios, &(pitch * &1)),
        level: Enum.map(@levels, fn level -> db(level) end),
        fade: @rings
      )

    crack_noise = noise(:white) |> highpass(hz: 3000) |> lowpass(hz: 12_000)
    crack = crack_noise * hit(0.0005, 0.03, -4) * db(-12)

    rings(
      highshelf(head + crack, hz: 2000, q: 0.707, db: (vel - 0.6) * 6) *
        (0.02 * (vel / 0.6) ** 1.4),
      seconds: 1.4
    )
  end
end
