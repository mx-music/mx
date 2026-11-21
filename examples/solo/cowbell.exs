defmodule Cowbell do
  @moduledoc """
  A solo for two cowbells written for mx from salsa's bell patterns, as timba.com's "Finding the
  clave" writes them, https://www.timba.com/artist_pages/finding-the-clave, all in 2:3 clave.
  The campana is the bongocero's bell, large and held in the hand: its "second gear", then the
  standard "third gear".
  The contracampana is the timbalero's bell, smaller and higher, here the same cowbell tuned a
  fourth up: its pattern alone, then with the campana, the two bells against each other as in a
  montuno, and then the pattern the page names for Changuito over the second gear.
  The campana plays the standard pattern of the 12/8 rhythms, which Wikipedia's article on bell
  patterns gives as X . X . X X . X . X . X, the two bells come back together, and both end on one
  open stroke.
  """

  use Mx.Song, tempo: 190

  # A pass is the two bars of the clave, written as sixteen cells of eighth notes, or for the 12/8
  # bell as twenty-four of triplet eighths.
  # O is an open stroke on the bell's mouth, played hard, o an open stroke, and c a closed stroke,
  # muted by the hand.
  # The second gear: closed strokes on the 2 side, and the 3 side's first two strokes strongly
  # open.
  @second_gear ~MX"c... ...c O..O ...c"s

  # The third gear: open on each half bar, closed between, with a rest on the 2 side's second
  # beat.
  @third_gear ~MX"O.c. o.cc o.cc o.cc"s

  # The page writes the contracampana's strokes alike; the harder ones on the four beats are mx's
  # own.
  @contracampana ~MX"O.o. Oooo .ooo O.oo"s
  @changuito ~MX".oo. .ooo .ooo .ooo"s

  @standard ~MX"O.o.oo.o.o.o O.o.oo.o.o.o"s

  # The contracampana sounds a fourth above the campana, and a little under it.
  part :campana, synth: :cowbell, defaults: [amp: 0.4]
  part :contracampana, synth: :cowbell, defaults: [amp: 0.3, note: 75]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a clave.
  defp form do
    for cells <- passes() do
      together(
        for name <- [:campana, :contracampana] do
          part(name, bell(Keyword.get(cells, name, ~MX"."s)))
        end
      )
    end
  end

  defp passes do
    [
      [campana: @second_gear],
      [campana: @second_gear],
      [campana: @third_gear],
      [campana: @third_gear],
      [contracampana: @contracampana],
      [contracampana: @contracampana],
      [campana: @third_gear, contracampana: @contracampana],
      [campana: @third_gear, contracampana: @contracampana],
      [campana: @third_gear, contracampana: @contracampana],
      [campana: @third_gear, contracampana: @contracampana],
      [campana: @second_gear, contracampana: @changuito],
      [campana: @second_gear, contracampana: @changuito],
      [campana: @standard],
      [campana: @standard],
      [campana: @third_gear, contracampana: @contracampana],
      [campana: @third_gear, contracampana: @contracampana],
      [campana: ~MX"O"s, contracampana: ~MX"O"s]
    ]
  end

  # A pass of one bell, as 8 beats.
  defp bell(pattern) do
    steps(pattern, 8 / length(pattern),
      strokes: [O: [vel: 1], o: [vel: 0.8], c: [vel: 0.6, muted: 1]]
    )
  end
end
