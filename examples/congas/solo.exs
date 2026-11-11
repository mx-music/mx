import Mx

# A solo for the congas written for mx: a tumbao on the conga and the tumba, the same with a slap answered on the quinto, a solo on the quinto over muted strokes, the tumbao at its softest, and a run down the three drums to a last slap.
defmodule Congas do
  import Mx

  # A beat is a quarter note of 4/4, so a pass is a bar, written as sixteen cells to a drum.

  # The tumbao: muted strokes on each beat and between, a slap on the second beat, and open tones on the fourth, the second on the tumba.
  def tumbao, do: [mid_conga: "m.m.S.m.m.m.O...", low_conga: "..............O."]

  def cells(:tumbao), do: tumbao()
  def cells(:answer), do: tumbao() ++ [high_conga: "......S.....S.S."]

  # The quinto plays open tones and slaps against muted strokes on the conga.
  def cells(:solo) do
    [
      high_conga: "O.SSO..SO.S.OOS.",
      mid_conga: "m...m...m...m...",
      low_conga: "..............O."
    ]
  end

  def cells(:soft), do: [mid_conga: "g.g.g.g.g.g.g...", low_conga: "..............g."]

  # Down the three drums in sixteenths, then a slap on the quinto and an open tone on the tumba together.
  def cells(:ending) do
    [
      high_conga: "OOOO........S...",
      mid_conga: "....OOOO........",
      low_conga: "........OOOOO..."
    ]
  end

  def stroke("m"), do: [vel: 0.6, mute: 1]
  def stroke("S"), do: [vel: 0.9, slap: 1]
  def stroke("O"), do: [vel: 0.8]
  def stroke("g"), do: [vel: 0.3]

  # The strokes of a pass on one drum, as {beat, options}.
  def strokes(section, drum) do
    letters = section |> cells() |> Keyword.get(drum, "") |> String.graphemes()

    for {letter, index} <- Enum.with_index(letters),
        letter != ".",
        do: {index / 4, stroke(letter)}
  end

  # A pass of low_conga, as 4 beats.
  def low_conga(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :low_conga), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of mid_conga, as 4 beats.
  def mid_conga(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :mid_conga), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of high_conga, as 4 beats.
  def high_conga(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :high_conga), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [tumbao: 2, answer: 2, solo: 2, soft: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:low_conga, low_conga(section, pass), synth: :low_conga, defaults: [amp: 0.5]),
        part(:mid_conga, mid_conga(section, pass), synth: :mid_conga, defaults: [amp: 0.5]),
        part(:high_conga, high_conga(section, pass), synth: :high_conga, defaults: [amp: 0.5])
      ])
    end)
  end
end

song(tempo: 104, music: repeat(seq(Congas.form())))
