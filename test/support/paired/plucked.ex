defmodule Mx.Paired.Plucked do
  @moduledoc """
  mxs's plucked strings, the cavaquinho and the bandolim, written with defsound so their twins can share them as the Rust voices do.
  """

  use Mx.Instrument

  @doc "A plucked string at the note `o`: harmonics shaped by where `p` plucks it, the higher ones dying sooner, through the body's resonances; tremolo picks it again that many times a second."
  defsound plucked(o, p) do
    vel = clamp(o.vel, 0, 1)
    freq = hz(o.note)

    # time's every starts over on the sample the Rust voice does, where mod of time can be one
    # sample early.
    since = time(every: 1 / max(o.tremolo, 0.01))
    length = p.ring * 2 ** ((60 - o.note) / 24)
    courses = length(p.courses)

    strings =
      mix(
        for harmonic <- 1..16, detune <- p.courses do
          level =
            (abs(:math.sin(harmonic * :math.pi() * p.pick)) + 0.02) *
              harmonic ** -(p.bright + (1 - vel) * 0.8) / courses

          fall = length / (1 + (harmonic - 1) * 0.35)
          fade = segments([0, 1, 0], [0.001, fall], [-4, -4], since)
          # mxs leaves out a harmonic at 14 kHz or above.
          heard = select(freq * harmonic < 14_000, level, 0)
          sine(hz: freq * harmonic * detune) * fade * heard
        end
      )

    damp = segments([1, 0.15, 1], [0.004, 0.012], [0, 0], since)
    attack_level = segments([0, 1, 0], [0.0005, 0.008], [-4, -4], since)
    attack = bpf(noise(:white), freq * 6, 1) * attack_level * (vel * 0.3)

    bodied =
      share(strings * damp + attack, fn sound ->
        Enum.reduce(p.body, sound, fn centre, bodies -> bodies + bpf(sound, centre, 0.4) * 0.5 end)
      end)

    note_envelope(bodied * ((0.3 + vel * 0.7) * 0.3), o)
  end

  # mxs's segment_at: from each of `levels` to the next over each of `times`, bent by each of
  # `curves`, read at the time `at`, holding the last.
  defsoundp segments(levels, times, curves, at) do
    starts = Enum.scan([0 | Enum.drop(times, -1)], &(&1 + &2))

    pieces =
      for {{from, to}, start, time, curve} <-
            Enum.zip([Enum.zip(levels, tl(levels)), starts, times, curves]) do
        place = (at - start) / time

        {start + time, from + (to - from) * bent(place, curve)}
      end

    List.foldr(pieces, List.last(levels), fn {ends, value}, rest ->
      select(at < ends, value, rest)
    end)
  end

  defsoundp bent(place, curve) do
    if abs(curve) < 1.0e-3 do
      place
    else
      (1 - exp(curve * place)) / (1 - :math.exp(curve))
    end
  end

  defsoundp bpf(sound, centre, rq),
    do: bandpass(sound, hz: clamp(centre, 20, 20_000), q: 1 / rq)
end
