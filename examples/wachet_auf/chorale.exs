import Mx

# A score, imported from bwv140.7.mxl by mix mx.import.
# Each part's bars are written one to a line where they fit, as the bar's number and its music; a bar of several voices plays them together.
# A note's length is in beats, a quarter note being a beat; a note tied over a bar line sounds for the whole tie, given as its sustain, and the note it ties into is a rest.
# Notes play at vel 0.6, and a dynamic marked in the score gives the notes after it another vel.
# The whole score plays once, 99 beats.

defmodule Chorale.Soprano do
  import Mx

  def bar(1), do: seq(eb4: 1, g4: 1, bb4: 1.5, bb4: 0.5)
  def bar(2), do: seq(bb4: 1, bb4: 1, c5: 2)
  def bar(3), do: seq(bb4: 2, r: 1, bb4: 1)
  def bar(4), do: seq(eb5: 1, bb4: 1, eb5: 0.5, f5: 0.5, g5: 1)
  def bar(5), do: seq(f5: 1, eb5: 1, d5: 1, c5: 1)
  def bar(6), do: seq(bb4: 2, r: 1, bb4: 1)
  def bar(7), do: seq(eb5: 1, bb4: 1, c5: 1, g4: 1)
  def bar(8), do: seq(ab4: 0.5, g4: 0.5, f4: 1, eb4: 1)
  def bar(9), do: seq(bb4: 1)
  def bar(10), do: seq(bb4: 1.5, ab4: 0.5, g4: 1, f4: 1)
  def bar(11), do: seq(eb4: 2, r: 1, bb4: 1)
  def bar(12), do: seq(bb4: 1.5, ab4: 0.5, g4: 1, f4: 1)
  def bar(13), do: seq(eb4: 2, r: 1, f4: 1)
  def bar(14), do: seq(g4: 1, ab4: 1, g4: 1, bb4: 1)
  def bar(15), do: seq(c5: 1, d5: 1, eb5: 1, eb5: 0.5, f5: 0.5)
  def bar(16), do: seq(g5: 1, f5: 1, eb5: 1, bb4: 1)
  def bar(17), do: seq(eb5: 1, bb4: 1, c5: 1, g4: 1)
  def bar(18), do: seq(ab4: 0.5, g4: 0.5, f4: 1, eb4: 2)
end

defmodule Chorale.Alto do
  import Mx

  def bar(1), do: seq(bb3: 1, eb4: 1, g4: 1, f4: 1)
  def bar(2), do: seq(g4: 1, f4: 1, g4: 1, f4: 1)
  def bar(3), do: seq(f4: 2, r: 1, f4: 1)
  def bar(4), do: seq(bb4: 1.5, ab4: 0.5, g4: 0.5, ab4: 0.5, bb4: 1)
  def bar(5), do: seq(bb4: 1, c5: 1.5, bb4: 1, a4: 0.5)
  def bar(6), do: seq(f4: 2, r: 1, g4: 1)
  def bar(7), do: seq(ab4: 1, g4: 1, eb4: 1, eb4: 1)
  def bar(8), do: seq(eb4: 1, d4: 1, bb3: 1)
  def bar(9), do: seq(f4: 1)
  def bar(10), do: seq(g4: 1.5, f4: 0.5, bb3: 0.5, c4: 0.5, d4: 1)
  def bar(11), do: seq(c4: 2, r: 1, d4: 0.5, eb4: 0.5)
  def bar(12), do: seq(f4: 1, f4: 1.5, eb4: 1, d4: 0.5)
  def bar(13), do: seq(bb3: 2, r: 1, d4: 1)

  def bar(14) do
    seq([note(:eb4, 1.5), note(:d4, 0.5), note(:eb4, 1), note(:g4, 1, sustain: 1.5)])
  end

  def bar(15), do: seq(r: 0.5, f4: 1, g4: 0.5, g4: 1, g4: 0.5, ab4: 0.5)
  def bar(16), do: seq(bb4: 1.5, ab4: 0.5, g4: 1, g4: 0.5, ab4: 0.5)
  def bar(17), do: seq(bb4: 0.5, ab4: 0.5, bb4: 0.5, g4: 0.5, ab4: 1, eb4: 1)
  def bar(18), do: seq(eb4: 1, d4: 1, bb3: 2)
end

defmodule Chorale.Tenor do
  import Mx

  def bar(1), do: seq(g3: 1, bb3: 1, eb4: 1, d4: 1)
  def bar(2), do: seq(eb4: 1, bb3: 1, bb3: 1, a3: 1)
  def bar(3), do: seq(d4: 2, r: 1, d4: 1)
  def bar(4), do: seq(eb4: 1, eb4: 1, bb3: 1, eb4: 1)
  def bar(5), do: seq(f4: 1, f4: 1, f4: 1.5, c4: 0.5)
  def bar(6), do: seq(d4: 2, r: 1, eb4: 1)
  def bar(7), do: seq(eb4: 1.5, db4: 0.5, c4: 1, c4: 1)
  def bar(8), do: seq(c4: 0.5, bb3: 0.5, ab3: 1, g3: 1)
  def bar(9), do: seq(bb3: 1)
  def bar(10), do: seq(eb4: 0.5, d4: 0.5, c4: 0.5, d4: 0.5, eb4: 1, bb3: 0.5, ab3: 0.5)
  def bar(11), do: seq(g3: 2, r: 1, bb3: 1)
  def bar(12), do: seq(bb3: 0.5, c4: 0.5, d4: 1, bb3: 0.5, c4: 1, bb3: 0.5)
  def bar(13), do: seq(g3: 2, r: 1, bb3: 1)
  def bar(14), do: seq(bb3: 1, c4: 0.5, ab3: 0.5, bb3: 1, eb4: 1)
  def bar(15), do: seq(eb4: 1, d4: 1, c4: 1, eb4: 1)
  def bar(16), do: seq(eb4: 1, d4: 1, eb4: 1, eb4: 1)
  def bar(17), do: seq(bb3: 1, eb4: 1, eb4: 1.5, c4: 0.5)
  def bar(18), do: seq(c4: 0.5, bb3: 0.5, ab3: 1, g3: 2)
end

defmodule Chorale.Bass do
  import Mx

  def bar(1) do
    seq([
      note(:eb3, 2, sustain: 2.5),
      rest(0.5),
      note(:g3, 0.5),
      note(:bb3, 0.5),
      note(:ab3, 0.5)
    ])
  end

  def bar(2), do: seq(g3: 0.5, f3: 0.5, eb3: 0.5, d3: 0.5, eb3: 0.5, c3: 0.5, f3: 1)
  def bar(3), do: seq(bb2: 2, r: 1, bb3: 0.5, ab3: 0.5)
  def bar(4), do: seq(g3: 0.5, ab3: 0.5, g3: 0.5, f3: 0.5, eb3: 1, eb4: 1)
  def bar(5), do: seq(d4: 0.5, c4: 0.5, bb3: 0.5, a3: 0.5, bb3: 1, f3: 1)
  def bar(6), do: seq(bb2: 2, r: 1, eb3: 0.5, db3: 0.5)
  def bar(7), do: seq(c3: 0.5, d3: 0.5, eb3: 1, ab2: 0.5, bb2: 0.5, c3: 1)
  def bar(8), do: seq(f2: 1, bb2: 1, eb2: 1)
  def bar(9), do: seq(d3: 1)
  def bar(10), do: seq(eb3: 1, f3: 1, g3: 0.5, ab3: 0.5, bb3: 0.5, bb2: 0.5)
  def bar(11), do: seq(c3: 2, r: 1, g3: 1)
  def bar(12), do: seq(d3: 0.5, c3: 0.5, bb2: 1, eb3: 0.5, c3: 0.5, ab2: 0.5, bb2: 0.5)
  def bar(13), do: seq(eb3: 2, r: 1, bb3: 0.5, ab3: 0.5)
  def bar(14), do: seq(g3: 1, f3: 1, eb3: 1, eb4: 1)
  def bar(15), do: seq(a3: 1, b3: 1, c4: 1, c4: 1)
  def bar(16), do: seq(g3: 0.5, ab3: 0.5, bb3: 1, c3: 1, eb3: 0.5, f3: 0.5)
  def bar(17), do: seq(g3: 0.5, f3: 0.5, g3: 0.5, eb3: 0.5, ab2: 0.5, bb2: 0.5, c3: 1)
  def bar(18), do: seq(f2: 1, bb2: 1, eb2: 2)
end

# The bars in the order the score plays them, its repeats taken.
order = Enum.concat([1..8, 1..8, 9..18])

song(
  tempo: 72,
  music:
    together([
      part(:soprano, seq(Enum.map(order, &Chorale.Soprano.bar/1)),
        synth: :oboe,
        defaults: [vel: 0.6]
      ),
      part(:alto, seq(Enum.map(order, &Chorale.Alto.bar/1)),
        synth: :clarinet,
        defaults: [vel: 0.6]
      ),
      part(:tenor, seq(Enum.map(order, &Chorale.Tenor.bar/1)),
        synth: :viola,
        defaults: [vel: 0.6]
      ),
      part(:bass, seq(Enum.map(order, &Chorale.Bass.bar/1)),
        synth: :bassoon,
        defaults: [vel: 0.6]
      )
    ])
)
