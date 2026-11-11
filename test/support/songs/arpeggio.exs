import Mx

song(
  tempo: 120,
  music: part(:melody, loop(3, fn _, _ -> seq(c4: 1, e4: 1, g4: 1) end), synth: :tri)
)
