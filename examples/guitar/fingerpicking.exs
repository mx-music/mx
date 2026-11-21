defmodule Fingerpicking do
  @moduledoc """
  A fingerpicked guitar in 3/4 at 84 bpm, round eight chords in A minor, one to a bar.
  Each bar is six eighths, the bass and then the index, middle and ring fingers, each string
  plucked at its own strength and left to ring until it is plucked again.
  """

  use Mx.Song, tempo: 84

  part :guitar, synth: :guitar, fx: [reverb: [room: 0.35, mix: 0.18]]

  def song do
    part(:guitar, loop(3, fn pass, _ -> bar(pass) end))
  end

  # A bar of 3/4 as six eighths, a chord of the progression to each bar.
  defp bar(pass) do
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

    # The string, how hard it is plucked, and how long it rings before the next pluck on it, in
    # eighths.
    picks = [{bass, 0.7, 6}, {i, 0.5, 4}, {m, 0.55, 2}, {a, 0.6, 6}, {m, 0.45, 4}, {i, 0.4, 2}]

    seq(picks, fn {note, vel, eighths} ->
      note(note, 0.5, vel: vel, sustain: eighths * 0.5, release: 0.15, amp: 0.5)
    end)
  end
end
