defmodule Mx.Paired.Triangle do
  @moduledoc """
  mxs's triangle written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3, between: 3]
  alias Mx.Instrument.Vocabulary, as: V

  @bands [1300, 2000, 3200, 5000, 8000, 12_500]
  @levels [-40, -40, -17.5, -15, -2, -0.5]
  @rings [10, 10, 9, 5, 3, 1.5]
  @plate Mx.Paired.Draws.plate(120, 1000, 18_000)

  @doc "A triangle: a beater ringing 120 modes of the bar, each group damped by the hand as the note ends, higher ones sooner."
  attr :note, :note, default: 69, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :sustain, :beats, default: 30, doc: "How long the bar rings before the hand damps it."
  attr :release, :beats, default: 1, doc: "How long the hand takes to damp it."

  defsynth triangle(o) do
    vel = clamp(o.vel, 0.05, 1)
    scale = 2 ** ((o.note - 69) / 12)
    held = o.sustain
    release = o.release
    mean = fn some -> Enum.sum(some) / length(some) end
    lowest = mean.(hd(@plate))

    beater =
      impulse() +
        highpass(noise(:white), hz: clamp(3000 + vel * 5000, 20, 20_000)) * hit(0.0002, 0.002, -4) *
          vel

    # The beater rings every group, each damped by its own hand, so it is shared, its noise drawn
    # once.
    bar =
      share(beater, fn beater ->
        Enum.reduce(@plate, 0, fn some, bar ->
          damp = release * (mean.(some) / lowest) ** -0.35
          hand = envelope([{0, 1}, {held, 1}, {damp, 0.001, :exp}])

          group =
            mode(beater,
              hz: Enum.map(some, &(&1 * scale)),
              level: Enum.map(some, &db(between(&1, @bands, @levels))),
              fade: Enum.map(some, &between(&1, @bands, @rings))
            )

          bar + group * hand
        end)
      end)

    hard = max(vel - 0.6, 0) / 0.4

    sound =
      bar
      |> V.peak(hz: 1300, q: 1 / 0.8, db: hard * 12)
      |> V.peak(hz: 3200, q: 1 / 0.5, db: hard * 6)
      |> lowshelf(hz: 3500, q: 0.707, db: hard * 5)

    # mxs trims the triangle 3.5 dB quieter.
    rings(
      sound * (db(-46) * (vel / 0.6) ** 2.6) * db(-3.5),
      seconds: min(held + release, held + 12)
    )
  end
end
