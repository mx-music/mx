defmodule Mx.Paired.Snare do
  @moduledoc """
  mxs's snare written with defsynth, node for node, at its plain stroke, so the two can be
  compared and timed.

  It takes only note and vel: mxs builds its bounces, its snares-off body and its rimshot only for
  the options that ask for them, and a defsynth's nodes cannot depend on the note's options.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3]

  @ratios [1, 1.2, 1.46, 1.66, 2.18, 2.8, 3.6, 4.4]
  @levels [-3, 0, -3, -3, -14, -14, -24, -24]
  @hard [0, 0, -11, -11, 4, 4, 0, 0]
  @rings [0.65, 0.65, 0.65, 0.6, 0.55, 0.55, 0.5, 0.5]
  # mxs draws the burst's noise for the snares-off and rimshot bodies even when it builds neither.
  @unused 0

  @doc """
  A snare drum at its plain stroke: the stick ringing the head's modes, and the wires' noise.
  """
  attr :note, :note, default: 55, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  defsynth snare(o) do
    vel = clamp(o.vel, 0, 1)
    pitch = hz(o.note)
    one = impulse() + lowpass(noise(:white), hz: 4000) * hit(0.0005, 0.004, -4) * 0.3
    burst = noise(:white) * hit(0.0005, 0.004, -4)
    hard = clamp((vel - 0.65) / 0.175, 0, 1)
    freqs = Enum.map(@ratios, &(pitch * &1))

    levels =
      [@levels, @hard, freqs]
      |> Enum.zip()
      |> Enum.map(fn {level, by_hard, freq} -> db(level + by_hard * hard) * freq / 20 end)

    stick = lowpass(one, hz: 20, poles: 1)

    head =
      mode(stick,
        hz: freqs ++ freqs,
        level: levels ++ Enum.map(levels, &(&1 * db(-11))),
        fade: Enum.map(@rings, &(&1 * 0.07)) ++ @rings
      )

    shake = envelope([{0, 0.0001}, {0.001, 1, :exp}, {0.5, 0.001, :exp}])
    soft = vel - 0.65

    wash =
      noise(:white)
      |> highpass(hz: 500)
      |> lowshelf(hz: 1500, q: 0.707, db: 6)
      |> highshelf(hz: 6000, q: 0.707, db: -6)

    dark = highshelf(wash, hz: 2000, q: 0.707, db: min(soft, 0) * 20)
    cutoff = max(7500 * max(shake, 0) ** 0.15, 2000)
    wires = lowpass(dark, hz: cutoff, q: 0.707) * shake * db(-30.5 - abs(soft) * 14)
    sound = (head * db(-32) + burst * @unused + wires) * (vel / 0.6) ** 3.8
    # mxs trims the snare 3.3 dB quieter.
    rings(sound * db(-3.3), seconds: 0.8)
  end
end
