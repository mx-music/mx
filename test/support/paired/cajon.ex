defmodule Mx.Paired.Cajon do
  @moduledoc """
  mxs's cajon written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @doc "A cajon: a hand ringing the box and the front plate, and a click ringing its shimmer."
  attr :note, :note, default: 40, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :slap, :float,
    default: 0,
    range: 0..1,
    doc: "1 slaps the front plate instead of the bass tone."

  defsynth cajon(o) do
    vel = clamp(o.vel, 0, 1)
    slap = clamp(o.slap, 0, 1)
    f = hz(o.note)
    mix = fn bass, slapped -> bass + (slapped - bass) * slap end

    hand =
      lowpass(noise(:white), hz: clamp(2000 + slap * 8000 + vel * 4000, 20, 20_000)) *
        hit(0.0005, 0.004 + slap * 0.004, -4)

    click = highpass(noise(:white), hz: 1000) * hit(0.0003, 0.003, -4)

    box =
      ringing(
        f,
        [0.983, 1.61, 2.2, 3.7],
        [1, 0.45, mix.(0.05, 1.1), mix.(0.033, 0.23)],
        [mix.(0.46, 0.9), 0.3, mix.(0.33, 0.44), mix.(0.7, 0.46)],
        [0.3, 0.3, mix.(0.3, 0.15), 0.3]
      )

    plate =
      ringing(
        f,
        [6.3, 6.5, 6.7, 6.9, 9.8],
        [1, 1, 1, 1, mix.(0.4, 0.55)],
        List.duplicate(mix.(0.45, 0.26), 4) ++ [mix.(0.6, 0.32)],
        List.duplicate(0.15, 5)
      )

    # The box is struck by the impulse and by the hand at 0.3, the plate by the hand; one bank over the hand holds both, so its noise is drawn once.
    by_hand = scaled(box, 0.05 * 0.3) ++ scaled(plate, mix.(0.0014, 0.0225))

    levels =
      Enum.zip_with(
        [0.3, 0.4, 0.5, 0.6, 0.25, 0.29, 0.49, 0.47, 0.47],
        [2.3, 1.55, 1.6, 1.9, 0.7, 0.8, 1.16, 1.19, 1.19],
        mix
      )

    rings =
      Enum.zip_with(
        [1, 0.97, 0.94, 0.9, 0.85, 0.8, 0.72, 0.66, 0.6],
        [0.255, 0.25, 0.28, 0.27, 0.255, 0.24, 0.216, 0.198, 0.18],
        &mix.(0.5 * &1, &2)
      )

    shimmer_hz = Enum.map([16, 23, 31, 44, 58, 75, 97, 128, 160], &(f * &1))

    sound =
      bank(hand, by_hand) + bank(impulse(), scaled(box, 0.05)) +
        mode(click, hz: shimmer_hz, level: levels, fade: rings) * mix.(0.00175, 0.0078)

    # mxs trims the cajon 3.5 dB louder.
    (highshelf(sound, hz: 1500, q: 0.707, db: (vel - 0.6) * 5) *
       (mix.(1, 0.106) * (vel / 0.6) ** 1.6) * db(3.5))
    |> rings(seconds: 1.72)
  end

  # A part of the cajon as its modes struck briefly and in a tail: {hz, levels, fades}.
  defsoundp ringing(f, ratios, levels, rings, tail) do
    freqs = Enum.map(ratios, &(f * &1))
    tails = Enum.zip_with(levels, tail, &(&1 * &2))
    {freqs ++ freqs, levels ++ tails, Enum.map(rings, &(&1 * 0.25)) ++ rings}
  end

  defsoundp scaled({freqs, levels, fades}, by) do
    [{freqs, Enum.map(levels, &(&1 * by)), fades}]
  end

  defsoundp bank(sound, parts) do
    {freqs, levels, fades} =
      Enum.reduce(parts, {[], [], []}, fn {f, l, r}, {fs, ls, rs} ->
        {fs ++ f, ls ++ l, rs ++ r}
      end)

    mode(sound, hz: freqs, level: levels, fade: fades)
  end
end
