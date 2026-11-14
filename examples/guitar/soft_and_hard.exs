defmodule SoftAndHard do
  use Mx.Song, tempo: 72

  part :guitar, synth: :guitar, defaults: [amp: 0.5], fx: [reverb: [room: 0.4, mix: 0.2]]

  def song do
    part(:guitar, loop(16, fn pass, _ -> phrase(pass) end))
  end

  # The phrase at the pass's strength, softly, then harder, then as hard as the guitar goes.
  defp phrase(pass) do
    vel = ring([0.3, 0.6, 1], pass)

    phrase = [
      {:e4, 0.5},
      {:c4, 0.5},
      {:a3, 1},
      {:b3, 0.5},
      {:c4, 0.5},
      {:d4, 1},
      {:e4, 0.5},
      {:f4, 0.5},
      {:e4, 0.5},
      {:d4, 0.5},
      {:c4, 1},
      {:b3, 1},
      {:a3, 0.5},
      {:c4, 0.5},
      {:e4, 1},
      {:a4, 2}
    ]

    notes = for {note, beats} <- phrase, do: note(note, beats, vel: vel, release: 0.2)

    # A low A rings on through a bar's rest before the next pass.
    seq(notes ++ [note(:a2, 0, vel: vel), rest(4)])
  end
end
