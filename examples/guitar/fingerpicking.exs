import Mx

defmodule Fingerpicking do
  import Mx

  # A bar of 3/4 as six eighths, a chord of the progression to each bar.
  def bar(pass) do
    {bass, i, m, a} =
      ring(
        [
          {:a2, :a3, :c4, :e4},
          {:e2, :gs3, :b3, :d4},
          {:a2, :a3, :c4, :e4},
          {:d3, :a3, :d4, :f4},
          {:g2, :b3, :d4, :f4},
          {:c3, :g3, :c4, :e4},
          {:f2, :a3, :c4, :f4},
          {:e2, :gs3, :b3, :e4}
        ],
        pass
      )

    # The string, how hard it is plucked, and how long it rings before the next pluck on it, in eighths.
    picks = [{bass, 0.7, 6}, {i, 0.5, 4}, {m, 0.55, 2}, {a, 0.6, 6}, {m, 0.45, 4}, {i, 0.4, 2}]

    seq(
      for {note, vel, eighths} <- picks,
          do: note(note, 0.5, vel: vel, sustain: eighths * 0.5, release: 0.15, amp: 0.5)
    )
  end
end

song(
  tempo: 84,
  music:
    part(:guitar, loop(3, fn pass, _ -> Fingerpicking.bar(pass) end),
      synth: :guitar,
      fx: [reverb: [room: 0.35, mix: 0.18]]
    )
)
