defmodule Mx.Paired.Flute do
  @moduledoc """
  mxs's flute written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @breath [0.38, 0.45, 0.56]
  @even [0.3, 1.0, 2.0]

  @doc """
  A flute note, an air jet swung across the edge by the bore's sound, with its vibrato in the
  breath.
  """
  attr :note, :note,
    default: 52,
    doc: "The pitch; a change while the note holds slurs to the new one."

  attr :vel, :float,
    default: 0.6,
    range: 0..1,
    doc: "How hard it is blown; a change while the note holds swells or fades it."

  attr :vibrato, :float,
    default: 0.17,
    range: 0..2,
    doc: "The vibrato's depth, reached as the note holds, in the breath."

  envelope_attrs sustain: 0.5, release: 0.2
  attr :breath, :float, range: 0..3, doc: "The breath's pressure, in place of the one fitted."

  attr :rise, :float,
    range: 0.001..2,
    doc: "The seconds the breath takes to reach its pressure, in place of the one fitted."

  attr :air, :float, range: -90..0, doc: "The breath's noise in dB, in place of the one fitted."
  attr :level, :float, range: -60..60, doc: "The sound's level in dB, in place of the one fitted."
  attr :lift, :float, default: 0.5, range: 0..1, doc: "How much louder a higher note sounds."
  attr :wander, :float, default: 0.2, range: 0..4, doc: "How much the breath drifts as it holds."

  attr :catch, :float,
    default: 0.15,
    range: 0..1,
    doc: "How far the breath falls while a slur moves the pitch."

  attr :corner, :float, range: 500..20_000, doc: "The bore's corner in Hz, in place of 3000."
  attr :shelf, :float, range: -30..30, doc: "The gain in dB above 4 kHz, in place of -8."
  attr :hiss, :float, range: -90..0, doc: "The breath's hiss above 3 kHz in dB, in place of -36."
  attr :tuned, :float, range: 0..3, doc: "The breath at which the jet is in tune."
  attr :pulse, :float, range: 0..1, doc: "How much the hiss follows the jet across the edge."
  attr :even, :float, range: 0..4, doc: "The part of the square of the jet's sound in the output."

  defsynth flute(blown) do
    by_vel = fn vel, [pp, mf, ff] ->
      pp + (mf - pp) * clamp((vel - 0.3) / 0.3, 0, 1) + (ff - mf) * clamp((vel - 0.6) / 0.4, 0, 1)
    end

    vel = clamp(blown.vel, 0, 1)
    played = clamp(follow(blown.vel), 0, 1)
    note = follow(blown.note)

    # The player takes back the cents the model plays sharp, fewer up the range.
    pitch = hz(note) * 2 ** (-(4.6 - 0.093 * (note - 69)) / 1200)
    rise = max(blown.rise || by_vel.(vel, [0.05, 0.05, 0.05]), 1.0e-3)
    breath = (blown.breath || by_vel.(played, @breath)) * (1 - (1 - min(time() / rise, 1)) ** 2)
    throb = 1 + vibrato(depth: 0.6 * blown.vibrato * vel ** 0.65, hz: 5.3)
    pulse = blown.pulse || 1
    air = blown.air || -90
    level = blown.level || -12

    air_jet(
      hz: pitch,
      breath: breath * throb,
      even: blown.even || by_vel.(vel, @even),
      wander: blown.wander,
      catch: blown.catch,
      corner: blown.corner || 3000,
      tuned: blown.tuned || Enum.at(@breath, 1),
      lift: blown.lift,
      side: fn side ->
        hiss = noise(:white) |> highpass(hz: 3000, q: 0.707) |> lowpass(hz: 10_000, q: 0.707)
        (1 - pulse + 2 * pulse * side) * hiss * breath * db(blown.hiss || -36)
      end,
      sound: fn sound ->
        (sound + bandpass(noise(:white), hz: 2000, q: 1) * db(by_vel.(played, [air, air, air])))
        |> wind_bands(
          vel: follow(blown.vel),
          gains: List.duplicate(0, 24),
          levels: [level, level, level]
        )
        |> highshelf(hz: 4000, q: 0.707, db: blown.shelf || -8)
      end
    )
    |> gain(clamp(follow(blown.vel) / 0.3, 0, 1) ** 1.5)
    |> note_envelope(blown)
  end
end
