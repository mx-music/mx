defmodule Mx.Paired.Tanpura do
  @moduledoc """
  mxs's tanpura written with defsynth, node for node, so the two can be compared and timed.

  Each string's high partials go up to the 500th, where mxs's go as far as 16 kHz, so the two agree from note 36 up.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [bpf: 3]

  @body [-7, 10, 1, 13, 12, 9]
  @strings [{0.75, 0, -11}, {1, 2, 0}, {1.0017, 3, 0}, {0.4994, 4, -3}]
  @highest 500
  @buzz Enum.zip(
          [200, 320, 500, 800, 1260, 2000, 3200, 5000, 8000, 12_500],
          [-12, 9, 26, -7, 16, 4, -4, 0, -6, -11]
        )

  @doc "A tanpura: four strings plucked in turn, each blooming with its own harmonics, over the bridge's buzz."
  attr :note, :note, default: 52, doc: "Sa, the note the drone is tuned to."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the strings are plucked."

  attr :gap, :beats,
    default: 0.8,
    doc: "The time between plucks; a cycle of the four strings takes six gaps."

  envelope_attrs sustain: 16, release: 4

  defsynth tanpura(o) do
    vel = clamp(o.vel, 0, 1)
    freq = hz(o.note)
    gap = max(o.gap, 0.05)
    plucks = fn beat -> impulse(at: beat * gap, period: 6 * gap, until: o.sustain) end

    sound =
      mix(
        for {ratio, beat, offset} <- @strings do
          string_hz = freq * ratio

          harmonics =
            for harmonic <- 1..24 do
              level =
                select(
                  string_hz * harmonic < 12_000,
                  db(curve(138.6 * ratio * harmonic) + offset),
                  0
                )

              bloom = 0.005 + 1.722 * (harmonic - 1) / 47
              fade = 25.872 * harmonic ** -0.35

              sine(hz: string_hz * harmonic, phase: harmonic * 2.4 + beat) *
                struck(plucks.(beat), attack: bloom, fall: fade) * level
            end

          high =
            high_train(string_hz) * struck(plucks.(beat), attack: 1.7, fall: 7) * db(45 + offset)

          mix(harmonics) + high
        end
      )

    all_plucks = plucks.(0) + plucks.(2) + plucks.(3) + plucks.(4)

    buzz =
      mix(
        for {centre, level} <- @buzz do
          at = freq / 138.6 * centre
          noise(:white) |> bpf(at, 0.3) |> bpf(at, 0.3) |> gain(db(level))
        end
      )

    buzzing = buzz * struck(all_plucks, attack: 0.05, fall: 6)
    note_envelope((sound + buzzing * 18.75) * (0.004 * (0.3 + vel * 0.7)), o)
  end

  # The string's partials from the 25th up to 16 kHz, each at one over their count.
  defsoundp high_train(string_hz) do
    within = 16_000 / string_hz
    count = within - mod(within, 1)
    ratios = Enum.to_list(25..@highest)
    levels = Enum.map(ratios, &select(&1 <= within, 1 / count, 0))

    string_hz
    |> partials(ratios: ratios, levels: levels, phases: List.duplicate(0, length(ratios)))
    |> highpass(hz: string_hz * 24.5)
    |> highpass(hz: string_hz * 24.5)
    |> lowpass(hz: 7000)
  end

  # The body's level in dB at `freq` Hz: straight lines in octaves from 100 Hz, and falling 40 dB
  # a decade below it.
  defp curve(freq) do
    slopes = Enum.zip_with(@body, tl(@body), &(&2 - &1)) ++ [7]
    octaves = min(max(:math.log2(freq / 100), 0), 6)

    bends =
      slopes
      |> Enum.zip(tl(slopes))
      |> Enum.with_index(1)
      |> Enum.map(fn {{from, to}, index} -> (to - from) * max(octaves - index, 0) end)
      |> Enum.sum()

    hd(@body) + octaves * hd(slopes) + bends + 40 * :math.log10(min(freq / 100, 1))
  end
end
