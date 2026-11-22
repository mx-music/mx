defmodule Mx.Paired.Caxixi do
  @moduledoc """
  mxs's caxixi written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @lows [400, 630, 1000, 1600, 2500, 4000, 6300, 10_000]
  @levels [-36, -28, -14.5, -5.8, -5.4, -3.6, 1.5, -4]
  @fast [0.027, 0.027, 0.027, 0.026, 0.036, 0.034, 0.022, 0.019]
  @tails [-15, -15, -15, -16.7, -23.5, -28, -26.2, -28.5]
  @slow [0.9, 0.9, 0.9, 0.42, 0.44, 0.41, 0.21, 0.33]
  # How mxs moves the caxixi's seed with each shake.
  @mix 0x9E37_79B9_7F4A_7C15

  @doc "The woven basket shaker a berimbau player shakes, fitted to \"Caxixi.ogg\" by Freddythehat on Wikimedia Commons."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is shaken."

  defsynth caxixi(o) do
    vel = clamp(o.vel, 0, 1)
    # Each shake throws the seeds differently, so its strongest peak moves.
    top = 1734 * (9556 / 1734) ** (draw(0, mix: @mix) ** 1.6)
    bands = Enum.zip([@lows, tl(@lows) ++ [16_000], @levels, @fast, @tails, @slow])

    seeds =
      mix(
        for {{low, high, level, fast, tail, slow}, band} <- Enum.with_index(bands) do
          centre = :math.sqrt(low * high)
          rising = min(time() / 0.002, 1)
          falling = exp(-time() / fast) + db(tail) * exp(-time() / slow)

          bandpass(noise(:white, drawn: band, mix: @mix), hz: centre, q: centre / (high - low)) *
            rising * falling * db(level)
        end
      )

    shaken =
      seeds
      |> highpass(hz: 700)
      |> highpass(hz: 700)
      |> peak(hz: top, q: 4, db: 8)

    rings(shaken * (0.3 * (vel / 0.6) ** 1.2), seconds: 3)
  end
end
