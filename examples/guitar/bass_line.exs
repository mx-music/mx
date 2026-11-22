defmodule BassLine do
  @moduledoc """
  A walking bass on the guitar at 96 bpm, round Dm7, G7, C6 and A7, four quarter notes to a bar
  with the root louder.
  Each walk steps through the chord and into the next root from a semitone away, and every eighth
  bar the A7 walks down to the low B instead.
  """

  use Mx.Song, tempo: 96

  part :bass, synth: :guitar, fx: [reverb: [decay_seconds: 1, mix: 0.12]]

  def song do
    part(:bass, loop(4, fn pass, _ -> walk(pass) end))
  end

  # A bar's walk as four quarter notes, the root louder.
  defp walk(pass) do
    # The steps of each walk from its root: down through the seventh and the fifth to a semitone
    # above the next root.
    down = [-2, -3, -1]

    walks = [
      # Dm7: D F A, then G# into G.
      melody(:d2, [3, 4, -1]),
      # G7: G F D, then C# into C.
      melody(:g2, down),
      # C6: C E G, then G# into A.
      melody(:c2, [4, 3, 1]),
      # A7: A G E, then D# into D.
      melody(:a2, down)
    ]

    # Every eighth bar the A7 walks down to the low B instead.
    walk = if rem(pass, 8) == 7, do: melody(:a2, [-2, -3, -5]), else: Enum.at(walks, rem(pass, 4))

    notes =
      for {step, beat} <- Enum.with_index(walk),
          do:
            note(step, 1,
              vel: if(beat == 0, do: 0.75, else: 0.55),
              sustain: 0.85,
              release: 0.1,
              amp: 0.7
            )

    seq(notes)
  end
end
