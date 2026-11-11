defmodule Mx.Paired.Flute do
  @moduledoc """
  mxs's flute written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A flute note, swelling in as the air starts and holding while it sustains."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is blown."

  attr :vibrato, :float,
    default: 0.25,
    range: 0..2,
    doc: "The vibrato's depth in semitones, reached as the note holds."

  envelope_attrs sustain: 0.5, release: 0.2

  defsynth flute(blown) do
    vel = blown.vel
    freq = hz(blown.note)
    soft = max((1 - vel) / 0.7, 0)
    register = clamp(blown.note - 59, 0, 30)
    fundamental = register * (0.25 + 0.75 * vel)

    levels =
      for n <- 1..16 do
        overtone =
          if n == 1,
            do: 0,
            else: Enum.at([1, 0, -8], min(n - 2, 2)) - 12 * max(:math.log2(n / 4), 0)

        octave = :math.log2(n)
        level = fundamental + overtone + 0.05 * register * octave - soft ** 3.5 * 11 * octave
        select(freq * n < 16000, db(level), 0)
      end

    # The vibrato waits a quarter second, then grows in over 1.2.
    grows = envelope([[0.25, 0, 2], [1.2, 1, 2]])
    swing = sine(hz: 5) * grows * (blown.vibrato * vel ** 0.65)
    pitch = hz(follow(blown.note)) * 2 ** (swing / 12)

    tone =
      partials(pitch,
        ratios: Enum.to_list(1..16),
        levels: levels,
        phases: for(n <- 1..16, do: :math.pi() * n * (n - 1) / 24)
      )

    breath = noise(:white) |> bandpass(hz: 2000, q: 1) |> gain(db(-43.5) * vel * vel)
    swell = envelope([[max(min(0.25, blown.sustain * 0.4), 1.0e-4), 1, -2]])

    ((tone * 0.0106 + breath) * swell)
    |> note_envelope(blown)
  end
end
