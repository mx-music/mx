defmodule Mx.Paired.Crash do
  @moduledoc """
  mxs's crash written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3, bpf: 3, band_noise: 4, between: 3]

  @bands [300, 500, 800, 1300, 2000, 3200, 5000, 8000, 12_500]
  @levels [-19.4, -46.4, -46.5, -32, -32.8, -36.5, -27.1, -31.8, -19.3]
  @rings [9.6, 9.6, 5.2, 5.28, 4.36, 3.38, 2.83, 1.93, 0.8]
  @shorter [0.75, 0.75, 0.68, 0.51, 0.4, 0.31, 0.18, 0, 0]
  # The fitted dBs after the bands' levels: the noise, the plate, the crack, the bank and the
  # early rings' longest.
  @noise_db 50
  @plate_db 6
  @crack_db -20
  @bank_db -14
  @early_ring 2
  @plate Mx.Paired.Draws.plate(160, 300, 15_000)

  @doc "A crash cymbal: a stick ringing 160 modes of the plate, noise in each band, a crack and a thud, choked after it rings."
  attr :note, :note, default: 60, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :sustain, :beats, default: 9, doc: "How long it rings before it is choked."
  attr :release, :beats, default: 1, doc: "How long the choke takes."

  defsynth crash(o) do
    vel = clamp(o.vel, 0, 1)
    scale = 2 ** ((o.note - 60) / 12)
    tilt = (vel - 0.6) * 4

    stick_noise = noise(:white) |> highpass(hz: 1000) |> highshelf(hz: 3000, q: 0.707, db: tilt)
    stick = stick_noise * hit(0.0005, 0.01, -4)

    groups =
      for some <- @plate do
        mean = Enum.sum(some) / length(some)
        longer = (vel / 0.55) ** -between(mean, @bands, @shorter)

        levels =
          Enum.map(some, fn f ->
            db(between(f, @bands, @levels) - @plate_db + if(f < 1000, do: 12, else: 0))
          end)

        {Enum.map(some, &(&1 * scale)), levels,
         Enum.map(some, &(between(&1, @bands, @rings) * longer))}
      end

    bank =
      mode(stick,
        hz: Enum.flat_map(groups, &elem(&1, 0)),
        level: Enum.flat_map(groups, &elem(&1, 1)),
        fade: Enum.flat_map(groups, &elem(&1, 2))
      )

    noise_rings = Enum.zip_with(@rings, @shorter, fn r, s -> r * (vel / 0.55) ** -s end)

    early_rings =
      Enum.take(noise_rings, 3) ++ Enum.map(Enum.drop(noise_rings, 3), &min(&1, @early_ring))

    noises =
      band_noise(@levels, noise_rings, 1, scale) * db(@bank_db) +
        band_noise(@levels, early_rings, 1, scale) +
        band_noise([-33], noise_rings, 0, scale * 0.7)

    plate =
      bank * db(@bank_db + 7) + highshelf(noises, hz: 3000, q: 0.707, db: tilt) * db(@noise_db)

    crack = highpass(noise(:white), hz: 6000 * scale) * hit(0.001, 0.06, -4) * (2 * db(@crack_db))

    thud_noise =
      noise(:white)
      |> bpf(330 * scale, 1)
      |> highpass(hz: 110 * scale)
      |> lowpass(hz: 400 * scale)
      |> lowpass(hz: 400 * scale)

    thud = thud_noise * hit(0.001, 0.035, -4) * (31.6 * db(@crack_db))

    held = o.sustain
    release = o.release
    # The choke falls from 1, so it is 1 less an envelope rising from the graph's 0.
    choke = 1 - envelope([{held, 0}, {release, 1, -4}])

    # mxs trims the crash 4.9 dB quieter.
    rings(
      (plate * 0.1 + crack + thud) * 0.9 * choke * (vel / 0.6) ** 1.7 * db(-4.9),
      seconds: held + release
    )
  end
end
