defmodule Mx.Paired.Organ do
  @moduledoc """
  mxs's organ written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Sounds, only: [pitch: 1, tilted: 2]

  @doc """
  A pipe organ: a quiet stopped flute, or a loud principal chorus with a bourdon an octave down.
  """
  attr :note, :note, default: 52, doc: "The pitch."

  attr :loud, :float,
    default: 0,
    range: 0..1,
    doc: "1 plays the loud set instead of the quiet flute."

  envelope_attrs sustain: 1, release: 0.15
  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  defsynth organ(o) do
    loud = clamp(o.loud, 0, 1)
    note = o.note
    freq = hz(note)
    key = max(note, 36)
    loud_level = -0.83 * max(60 - key, 0) - 0.25 * max(note - 60, 0) + 6

    levels =
      for harmonic <- 1..24 do
        octave = :math.log2(harmonic)
        flute = if(rem(harmonic, 2) == 1, do: (-8 - 0.25 * (key - 36)) * octave, else: -45)
        flute = if(harmonic == 3, do: flute + 10 * max((42 - key) / 6, 0), else: flute)
        chorus = (4 - 0.4 * (key - 36)) * octave
        slope = 18 - loud * 2

        top =
          slope * min(max(log2(freq * harmonic / max(freq, 740 + loud * 220)), 0), 27 / slope) +
            30 * max(log2(freq * harmonic / 5000), 0)

        quiet_level = min(1.5 * (key - 45), 0)
        level = db(flute + quiet_level - top) * (1 - loud) + db(chorus + loud_level - top) * loud
        select(freq * harmonic < 16_000, level, 0)
      end

    phases = for harmonic <- 1..24, do: :math.pi() * harmonic * (harmonic - 1) / 24
    pipes = partials(pitch(o), ratios: Enum.to_list(1..24), levels: levels, phases: phases)
    bourdon_level = select(note >= 60, loud * db(-13) * db(loud_level), 0)

    bourdon =
      partials(pitch(o),
        ratios: [0.5, 1.5, 2.5],
        levels: [bourdon_level, 0.2 * bourdon_level, 0.05 * bourdon_level],
        phases: [0, 0, 0]
      )

    speak = envelope([{0.12 + loud * 0.04, 1, 3}])
    wind = bandpass(noise(:pink), hz: freq * 2, q: 1) * speak * 0.005

    note_envelope(tilted(o, (pipes + bourdon) * speak * 0.03 + wind), o)
  end
end
