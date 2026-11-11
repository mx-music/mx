defmodule Mx.Paired.Marimba do
  @moduledoc """
  mxs's marimba written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A marimba note, which rings until it fades by itself unless `sustain` and `release` damp it."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0.05..1, doc: "How hard the bar is struck."
  envelope_attrs sustain: 1000, release: 0.3

  defsynth marimba(hit) do
    freq = hz(hit.note)
    vel = hit.vel
    ring = 4.6 * 2 ** ((hit.note - 36) / -17) * 2 ** (max(hit.note - 78, 0) / -16)
    swell = 0.45 * 2 ** ((hit.note - 36) / -18)

    fourth =
      -12 - mallet(freq * 4, 600, 57 * (1 - vel)) - 10 * above(freq * 4, 900) -
        20 * max(log2(370 / (freq * 4)), 0)

    overtone = fn n -> 10 + 14.5 * log2(vel) - mallet(freq * n, 1100, 33.4 - 11.4 * vel) end
    low_tube = select(hit.note < 46, -82, select(hit.note > 62, -82, -22))

    tube =
      for {n, level} <- [{3, low_tube}, {5, -26}, {7, -26}, {9, -26}],
          do: {n, db(level - mallet(freq * n, 600, 12 + 45 * (1 - vel))), 0.35}

    modes =
      [{1, 1.25, nil}, {1, -1, nil}] ++
        [
          {4, db(fourth), 0.3},
          {10, db(overtone.(10)), 0.1},
          {19, db(overtone.(19) - 8), 0.08},
          {30, db(overtone.(30) - 12), 0.06}
        ] ++ tube

    modes =
      for {{n, level, fade}, index} <- Enum.with_index(modes) do
        fade =
          case index do
            0 -> ring
            1 -> swell
            _ -> ring * fade * min(1500 / (freq * n), 1) ** 0.8
          end

        {n, select(freq * n < 15000, level, 0), fade}
      end

    strike = impulse()

    bar =
      mix(
        for {n, level, fade} <- modes, do: strike |> mode(hz: freq * n, level: level, fade: fade)
      )

    low_tap =
      noise(:white)
      |> lowpass(hz: 2200, poles: 6)
      |> highpass(hz: 1000)
      |> envelope([[0.0005, 1, -4], [0.12, 0, -4]])
      |> gain(0.55)

    high_tap =
      noise(:white)
      |> lowpass(hz: 4000, poles: 4)
      |> highpass(hz: 2500)
      |> envelope([[0.0005, 1, -4], [0.05, 0, -4]])
      |> gain(0.3)

    level = 0.1 * (vel / 0.6) ** 1.9

    # The seconds until the loudest mode has faded below 1e-4.
    silent =
      Enum.reduce(modes, 0.1, fn {_n, level_n, fade}, longest ->
        loud = abs(level_n) * level
        max(longest, select(loud > 1.0e-4, fade * 20 * log2(loud / 1.0e-4) / log2(10) / 60, 0))
      end)

    (bar + (low_tap + high_tap) * (vel / 0.6) ** 0.5)
    |> gain(level)
    |> note_envelope(hit)
    |> rings(seconds: silent)
  end

  defsoundp mallet(hz, corner, slope), do: slope * above(hz, corner) + 24 * above(hz, 3000)
  defsoundp above(hz, corner), do: max(log2(hz / corner), 0)
end
