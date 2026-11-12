defmodule Mx.Instruments.Flute do
  @moduledoc """
  A flute, measured from the University of Iowa's flute, from B3 to Db7, played without vibrato, and its vibrato played with it.

  A note's fundamental is louder the higher it is, by more the harder it is played, up to F6; its second and third harmonics stand about as loud, and the rest fall away fast, far faster the softer the note.
  Breath hisses around 2 kHz under the tone, quieter the softer the note, which speaks over a quarter of a second; its vibrato grows as it holds, shallower the softer it is played.
  """

  use Mx.Instrument

  @doc "A flute note."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the note is blown."

  attr :vibrato, :float,
    default: 0.25,
    range: 0..1,
    doc: "The vibrato's depth in semitones, reached as the note holds."

  envelope_attrs sustain: 0.5, release: 0.2

  defsynth flute(played) do
    vel = played.vel
    soft = max((1 - vel) / 0.7, 0)
    depth = played.vibrato * vel ** 0.65 * envelope([{0.25, 0}, {1.2, 1, 2}])
    pitch = hz(played.note) * 2 ** (sine(hz: 5) * depth / 12)
    register = clamp(played.note - 59, 0, 30)
    fundamental = register * (0.25 + 0.75 * vel)

    tone =
      mix(
        for harmonic <- 1..16 do
          overtone =
            if harmonic == 1 do
              0
            else
              Enum.at([1, 0, -8], min(harmonic - 2, 2)) - 12 * max(log2(harmonic / 4), 0)
            end

          octave = log2(harmonic)
          level = fundamental + overtone + 0.05 * register * octave - soft ** 3.5 * 11 * octave

          sine(hz: pitch * harmonic, phase: :math.pi() * harmonic * (harmonic - 1) / 24)
          |> gain(select(hz(played.note) * harmonic < 16_000, db(level), 0))
        end
      )

    breath = noise(:white) |> bandpass(hz: 2000, q: 1) |> gain(db(-43.5) * vel ** 2)

    (gain(tone, 0.0106) + breath)
    |> envelope([{min(0.25, played.sustain * 0.4), 1, -2}])
    |> note_envelope(played)
  end
end
