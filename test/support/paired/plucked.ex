defmodule Mx.Paired.Plucked do
  @moduledoc """
  mxs's plucked strings, the cavaquinho and the bandolim, written with defsound so their twins can
  share them as the Rust voices do.
  """

  use Mx.Instrument

  @doc """
  A plucked string at the note `o`: harmonics shaped by where `p` plucks it, the higher ones dying
  sooner, through the body's resonances; tremolo picks it again that many times a second.
  """
  defsound plucked(o, p) do
    vel = clamp(o.vel, 0, 1)
    freq = hz(o.note)

    # mxs picks again every 1 / tremolo seconds, and once when tremolo is 0.
    every = select(o.tremolo > 0, 1 / max(o.tremolo, 0.01), 0)
    length = p.ring * 2 ** ((60 - o.note) / 24)
    courses = length(p.courses)

    strings =
      mix(
        for harmonic <- 1..16 do
          level =
            (abs(:math.sin(harmonic * :math.pi() * p.pick)) + 0.02) *
              harmonic ** -(p.bright + (1 - vel) * 0.8) / courses

          fall = length / (1 + (harmonic - 1) * 0.35)
          # mxs leaves out a harmonic at 14 kHz or above.
          heard = select(freq * harmonic < 14_000, level, 0)
          tones = mix(for detune <- p.courses, do: sine(hz: freq * harmonic * detune))
          tones * envelope([{0.001, 1, -4}, {fall, 0, -4}], every: every) * heard
        end
      )

    damp = 1 - envelope([{0.004, 0.85}, {0.012, 0}], every: every)
    attack_level = envelope([{0.0005, 1, -4}, {0.008, 0, -4}], every: every)
    attack = bpf(noise(:white), freq * 6, 1) * attack_level * (vel * 0.3)

    bodied =
      share(strings * damp + attack, fn sound ->
        Enum.reduce(p.body, sound, fn centre, bodies -> bodies + bpf(sound, centre, 0.4) * 0.5 end)
      end)

    note_envelope(bodied * ((0.3 + vel * 0.7) * 0.3), o)
  end

  defsoundp bpf(sound, centre, rq),
    do: bandpass(sound, hz: clamp(centre, 20, 20_000), q: 1 / rq)
end
