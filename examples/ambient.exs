import Mx

# Every part's pass is one bar of 8 beats, so they all change chord together.
defmodule Ambient do
  import Mx

  def pad(pass) do
    chord =
      ring(
        [chord(:d3, :minor7), chord(:bb2, :major7), chord(:f3, :major7), chord(:c3, :sus4)],
        pass
      )

    note(chord, 8,
      attack: 3,
      sustain: 3,
      release: 5,
      cutoff: 60,
      res: 0.2,
      amp: 0.09,
      changes: [{1, cutoff: 85, cutoff_slide: 5}]
    )
  end

  def sub(pass) do
    note(ring([:d2, :bb1, :f2, :c2], pass), 8, attack: 2, sustain: 4, release: 3, amp: 0.18)
  end

  def keys(pass) do
    chord =
      ring(
        [chord(:d4, :minor7), chord(:bb3, :major7), chord(:f4, :major7), chord(:c4, :sus4)],
        pass
      )

    notes =
      for note <- Enum.take_random(chord, 3),
          do: seq([note(note, 0, decay: 3, amp: 0.13, pan: pick([-0.4, 0.4])), rest(2)])

    seq(notes ++ [rest(2)])
  end

  def bells do
    notes = scale(:d5, :minor_pentatonic)

    bells =
      for _ <- 1..4 do
        bell =
          if chance(0.45) do
            [note(pick(notes), 0, amp: 0.15, pan: pick([-0.6, -0.2, 0.2, 0.6]))]
          else
            []
          end

        seq(bell ++ [rest(2)])
      end

    seq(bells)
  end

  def air(pass) do
    case rem(pass, 4) do
      0 -> sample(:ambi_drone, 8, rate: 0.5, amp: 0.2, attack: 2, release: 4)
      2 -> sample(:ambi_glass_hum, 8, amp: 0.13, pan: -0.5, attack: 1)
      3 -> sample(:ambi_lunar_land, 8, rate: 0.75, amp: 0.1, pan: 0.5)
      _ -> rest(8)
    end
  end
end

song(
  tempo: 64,
  music:
    together([
      part(:pad, loop(8, fn pass, _ -> Ambient.pad(pass) end),
        synth: :supersaw,
        fx: [lpf: [cutoff: 84], reverb: [room: 0.95, damp: 0.6, mix: 0.7]]
      ),
      part(:sub, loop(8, fn pass, _ -> Ambient.sub(pass) end)),
      part(:keys, loop(8, fn pass, _ -> Ambient.keys(pass) end),
        synth: :piano,
        fx: [echo: [phase: 1.5, decay: 8, mix: 0.4], reverb: [room: 0.8, mix: 0.5]]
      ),
      part(:bells, loop(8, fn _, _ -> Ambient.bells() end),
        synth: :vibraphone,
        fx: [echo: [phase: 0.75, decay: 6, mix: 0.5], reverb: [room: 0.9, mix: 0.6]]
      ),
      part(:air, loop(8, fn pass, _ -> Ambient.air(pass) end), fx: [reverb: [room: 1, mix: 0.8]]),
      part(:dust, loop(8, fn _, _ -> sample(:vinyl_hiss, 8, amp: 0.04, rate: 0.8) end))
    ])
)
