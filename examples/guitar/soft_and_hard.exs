import Mx

defmodule SoftAndHard do
  import Mx

  # The phrase at the pass's strength, softly, then harder, then as hard as the guitar goes.
  def phrase(pass) do
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

song(
  tempo: 72,
  music:
    part(:guitar, loop(16, fn pass, _ -> SoftAndHard.phrase(pass) end),
      synth: :guitar,
      defaults: [amp: 0.5],
      fx: [reverb: [room: 0.4, mix: 0.2]]
    )
)
