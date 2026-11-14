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
  @second_gear "c... ...c O..O ...c"

  # The third gear: open on each half bar, closed between, with a rest on the 2 side's second
  # beat.
  @third_gear "O.c. o.cc o.cc o.cc"

  # The page writes the contracampana's strokes alike; the harder ones on the four beats are mx's
  # own.
  @contracampana "O.o. Oooo .ooo O.oo"
  @changuito ".oo. .ooo .ooo .ooo"

  @standard "O.o.oo.o.o.o O.o.oo.o.o.o"

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
          part(name, bell(Keyword.get(cells, name, "")))
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
      [campana: "O", contracampana: "O"]
    ]
  end

  # A pass of one bell, as 8 beats.
  defp bell(cells) do
    letters = cells |> String.replace(" ", "") |> String.graphemes()
    per_beat = length(letters) / 8

    hits =
      for {letter, index} <- Enum.with_index(letters), letter != "." do
        beat = Float.round(index / per_beat, 3)
        {beat, hit(stroke(letter))}
      end

    if hits == [], do: rest(8), else: at(hits, 8)
  end

  defp stroke("O"), do: [vel: 1]
  defp stroke("o"), do: [vel: 0.8]
  defp stroke("c"), do: [vel: 0.6, muted: 1]
end
