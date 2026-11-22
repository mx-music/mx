defmodule Mx.Paired.Drums do
  @moduledoc """
  The helpers mxs's drums share, written with defsound so the twins can share them as the drums do.
  """

  use Mx.Instrument

  @ride_bands [200, 300, 500, 800, 1300, 2000, 3200, 5000, 8000, 12_500]

  @doc "A rise over `attack` seconds and a fall over `decay`, both bent by `curve`."
  defsound hit(attack, decay, curve) do
    envelope([{attack, 1, curve}, {decay, 0, curve}])
  end

  @doc "A rise from 0.001 to 1 over `attack` seconds and a fall back to 0.001 over `decay`, both exponential; a first point of no length starts it at 0.001, as the graph's envelopes start at 0."
  defsound exp_hit(attack, decay) do
    envelope([{0, 0.001}, {attack, 1, :exp}, {decay, 0.001, :exp}])
  end

  @doc "A band-pass with a peak of 1, whose width is `rq` times its centre."
  defsound bpf(sound, f, rq) do
    bandpass(sound, hz: f, q: 1 / rq)
  end

  @doc "Bands of noise at the ride's bands from `first`, scaled by `scale`, each struck and fading over its ring."
  defsound band_noise(levels, rings, first, scale) do
    Enum.zip([Enum.drop(@ride_bands, first), levels, rings])
    |> Enum.reduce(0, fn {f, l, r}, sound ->
      f = f * scale
      level = exp_hit(0.0005, r)

      band =
        (noise(:white) * level)
        |> bpf(f, 0.5)
        |> highpass(hz: f * 0.6)
        |> lowpass(hz: f * 1.7)
        |> lowpass(hz: f * 1.7)

      sound + band * (db(l) * (200 / f) ** 0.5)
    end)
  end
end
