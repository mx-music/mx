import Mx

# A solo for the timpani written for mx: a roll on A2 that swells from soft to loud, the tonic and dominant pounded in turn, a melody on five drums tuned to D major, the same melody at its softest, and a roll on D3 that ends on a loud stroke left to ring.
defmodule Timpani do
  import Mx

  # The drums are tuned to A2, B2, D3, E3 and F#3, all within the recordings' range.

  # A roll as quick repeated strokes, six to a beat, from one strength to another.
  def roll(from, beats, note, soft, loud) do
    count = beats * 6

    for index <- 0..(count - 1),
        do: {from + index / 6, note, Float.round(soft + (loud - soft) * index / (count - 1), 2)}
  end

  # A melody as beat and note, on the five drums.
  def melody do
    [
      {0, 45},
      {1, 50},
      {2, 50},
      {3, 52},
      {4, 54},
      {6, 52},
      {7, 50},
      {8, 47},
      {9, 50},
      {10, 52},
      {11, 47},
      {12, 45},
      {14, 50}
    ]
  end

  # A roll on A2 that swells over eight beats from soft to loud, and fades over the next six.
  def strokes(:swell), do: roll(0, 8, 45, 0.3, 1) ++ roll(8, 6, 45, 1, 0.3)

  # D3 and A2 in turn, loud, in quarters and then eighths, as a tonic and dominant are pounded.
  def strokes(:pounding) do
    quarters = for beat <- 0..7, do: {beat, Enum.at([50, 45], rem(beat, 2)), 0.9}
    eighths = for index <- 0..15, do: {8 + index / 2, Enum.at([50, 45], rem(index, 2)), 0.8}
    quarters ++ eighths
  end

  def strokes(:melody) do
    for {beat, note} <- melody(), do: {beat, note, 0.65}
  end

  def strokes(:soft) do
    for {beat, note} <- melody(), do: {beat, note, 0.3}
  end

  # A roll on D3 that swells over six beats, then A2 and a last D3 struck hard and left to ring.
  def strokes(:ending), do: roll(0, 6, 50, 0.4, 0.9) ++ [{6, 45, 1}, {8, 50, 1}]

  # A pass of timpani, as 16 beats.
  def timpani(section, _pass) do
    hits = for {beat, note, vel} <- strokes(section), do: {beat, note(note, 0, vel: vel)}
    at(hits, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [swell: 1, pounding: 1, melody: 1, soft: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:timpani, timpani(section, pass), synth: :timpani, defaults: [amp: 0.5])
    end)
  end
end

song(tempo: 80, music: repeat(seq(Timpani.form())))
