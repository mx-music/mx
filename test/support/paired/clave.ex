defmodule Mx.Paired.Clave do
  @moduledoc """
  mxs's clave written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @ratios [0.65, 1, 1.08, 1.5, 2.72, 3.6, 6.2]
  @levels [-24, 0, -6, -6, -9.5, -20, -22]
  @bright [0, 0, 0, 0.6, 0.6, 1.3, 1]
  @rings [0.75, 0.75, 0.75, 0.72, 0.65, 0.5, 0.4]

  @doc "A clave: two sticks' click ringing their modes twice, briefly and long."
  attr :note, :note, default: 95.2, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth clave(o) do
    vel = clamp(o.vel, 0.05, 1)
    f = hz(o.note)
    bright = (vel - 0.6) * 30
    strike = impulse() + highpass(noise(:white), hz: 1000) * hit(0.0002, 0.002, -4) * 0.3
    levels = Enum.zip_with(@levels, @bright, fn l, b -> db(l + b * bright) end)
    freqs = Enum.map(@ratios, &(f * &1))

    stick =
      mode(strike,
        hz: freqs ++ freqs,
        level: levels ++ Enum.map(levels, &(&1 * 0.1)),
        fade: Enum.map(@rings, &(&1 * 0.08)) ++ @rings
      )

    # mxs trims the clave 4.4 dB quieter.
    (stick * (db(-21.8) * (vel / 0.6) ** 1.72) * db(-4.4))
    |> rings(seconds: 1)
  end
end
