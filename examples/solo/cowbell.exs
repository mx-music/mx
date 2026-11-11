import Mx

# A solo for the cowbell written for mx from the campana, the bongocero's bell in salsa, as timba.com's "Finding the clave" gives its two 2:3 patterns: the "second gear", then the standard "third gear", the second gear again, and a last open stroke.
defmodule Cowbell do
  import Mx

  # A pass is the two bars of the clave, written as sixteen cells of eighth notes.

  # O is an open stroke on the bell's mouth, played hard, o an open stroke, and c a closed stroke, muted by the hand.
  # The second gear: closed strokes on the 2 side, and the 3 side's first two strokes strongly open.
  def cells(:second_gear), do: "c......cO..O...c"

  # The third gear: open on each half bar, closed between, with a rest on the 2 side's second beat.
  def cells(:third_gear), do: "O.c.o.cco.cco.cc"
  def cells(:again), do: cells(:second_gear)
  def cells(:ending), do: "O..............."

  def stroke("O"), do: [vel: 1]
  def stroke("o"), do: [vel: 0.8]
  def stroke("c"), do: [vel: 0.6, muted: 1]

  # The strokes of a pass, as {beat, options}.
  def strokes(section) do
    for {letter, index} <- Enum.with_index(String.graphemes(cells(section))),
        letter != ".",
        do: {index / 2, stroke(letter)}
  end

  # A pass of cowbell, as 8 beats.
  def cowbell(section, _pass) do
    hits = for {beat, opts} <- strokes(section), do: {beat, hit(opts)}
    at(hits, 8)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [second_gear: 2, third_gear: 4, again: 2, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:cowbell, cowbell(section, pass), synth: :cowbell, defaults: [amp: 0.5])
    end)
  end
end

song(tempo: 190, music: repeat(seq(Cowbell.form())))
