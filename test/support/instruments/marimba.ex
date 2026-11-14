defmodule Mx.Instruments.Marimba do
  @moduledoc """
  A marimba, measured from the University of Iowa's marimba struck with yarn mallets.

  Each partial is a resonator struck once: the bar's note, its overtones two octaves, a little over three octaves and higher above it, and the odd harmonics of the tube under it.
  The harder the bar is struck, the louder and higher its overtones sound, and a short tap of the mallet sounds above them.
  """

  use Mx.Instrument

  @doc "A marimba note, which rings until it fades by itself unless `sustain` and `release` damp it."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0.05..1, doc: "How hard the bar is struck."
  envelope_attrs sustain: 1000, release: 0.3

  defsynth marimba(hit) do
    freq = hz(hit.note)
    vel = hit.vel

    # The seconds a note fades 60 dB in: 4.6 at C2, halving every 17 semitones, and every 16 more
    # above F#5.
    ring = 4.6 * 2 ** ((hit.note - 36) / -17) * 2 ** (max(hit.note - 78, 0) / -16)
    # The tube takes a moment to answer the bar, so the note starts at a quarter of its level.
    swell = 0.45 * 2 ** ((hit.note - 36) / -18)

    fourth =
      -12 - mallet(freq * 4, 600, 57 * (1 - vel)) - 10 * max(log2(freq * 4 / 900), 0) -
        20 * max(log2(370 / (freq * 4)), 0)

    overtone = fn n -> 10 + 14.5 * log2(vel) - mallet(freq * n, 1100, 33.4 - 11.4 * vel) end

    bar = [
      {4, fourth, 0.3},
      {10, overtone.(10), 0.1},
      {19, overtone.(19) - 8, 0.08},
      {30, overtone.(30) - 12, 0.06}
    ]

    twelfth = select(hit.note < 46, -82, select(hit.note > 62, -82, -22))

    tube =
      for {n, level} <- [{3, twelfth}, {5, -26}, {7, -26}, {9, -26}],
          do: {n, level - mallet(freq * n, 600, 12 + 45 * (1 - vel)), 0.35}

    strike = impulse()

    struck =
      mix(
        [
          strike |> mode(hz: freq, level: 1.25, fade: ring),
          strike |> mode(hz: freq, level: -1, fade: swell)
        ] ++
          for {n, level, fade} <- bar ++ tube do
            # Overtones above 1.5 kHz die sooner the higher they are.
            strike
            |> mode(
              hz: freq * n,
              level: select(freq * n < 15_000, db(level), 0),
              fade: ring * fade * min(1500 / (freq * n), 1) ** 0.8
            )
          end
      )

    tap =
      (noise(:white)
       |> lowpass(hz: 2200, poles: 6)
       |> highpass(hz: 1000)
       |> perc(attack: 0.0005, release: 0.12)
       |> gain(0.55)) +
        (noise(:white)
         |> lowpass(hz: 4000, poles: 4)
         |> highpass(hz: 2500)
         |> perc(attack: 0.0005, release: 0.05)
         |> gain(0.3))

    (struck + tap * (vel / 0.6) ** 0.5)
    |> gain(0.1 * (vel / 0.6) ** 1.9)
    |> note_envelope(hit)
    |> rings(seconds: ring * 4 / 3)
  end

  defsoundp mallet(hz, corner, slope),
    do: slope * max(log2(hz / corner), 0) + 24 * max(log2(hz / 3000), 0)
end
