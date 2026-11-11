import Mx

defmodule Virtuoso do
  import Mx

  # o is an open bass with the thumb, ox a closed one, h the heel of the hand, f the fingertips and s a slap; a cell of two splits its sixteenth in two.
  def cells(:groove), do: "o f h o  f s h o  o f h s  h o o f"
  def cells(:ruffs), do: "o f h fh  f o fh f  o o fh o  o o fh o"

  # mx's thumb has no closed bass, so ox is the thumb played softly.
  def vel("o"), do: 0.75
  def vel("ox"), do: 0.4
  def vel("h"), do: 0.5
  def vel("f"), do: 0.4
  def vel("s"), do: 0.8

  # The hand never stops rocking: thumb, fingertips, heel, fingertips in sixteenths, or the thumb and then heel and fingertips in turn in sextuplets.
  def hand(:sextuplets), do: ["ox", "f", "h", "f", "h", "f"]
  def hand(_), do: ["ox", "f", "h", "f"]

  # An accent opens the thumb's bass, turns the fingertips into a slap or digs the heel in, wherever in the hand's rocking it falls.
  def accent("ox"), do: {"o", 0.9}
  def accent("f"), do: {"s", 0.85}
  def accent("h"), do: {"h", 0.85}

  # The strokes between accents; counted from the section's start, they cross the bar line and meet the first beat again only when the count comes round.
  def group(:threes), do: 3
  def group(:fives), do: 5
  def group(:sextuplets), do: 4

  # Every stroke of a section's pass, as {beat, stroke, vel}, given how many of the section's passes came before it.
  def strokes(section, _time) when section in [:groove, :ruffs] do
    for {cell, index} <- section |> cells() |> String.split() |> Enum.with_index(),
        strokes = List.flatten(Regex.scan(~r/ox|[ofhs]/, cell)),
        {stroke, half} <- Enum.with_index(strokes) do
      {index * 0.25 + half * 0.25 / length(strokes), stroke, vel(stroke)}
    end
  end

  def strokes(section, time) do
    hand = hand(section)
    size = length(hand)
    count = time * 4 * size

    for index <- 0..(4 * size - 1) do
      stroke = Enum.at(hand, rem(index, size))

      {stroke, vel} =
        if rem(count + index, group(section)) == 0 do
          accent(stroke)
        else
          {stroke, vel(stroke)}
        end

      {index / size, stroke, vel}
    end
  end

  # A pass of one hand's sound, as 4 beats.
  def hits(section, time, letters) do
    entries =
      for {beat, stroke, vel} <- strokes(section, time),
          stroke in letters,
          do: {beat, hit(vel: vel)}

    at(entries, 4)
  end

  # The form, each of its passes a section; a beat is a quarter note of 2/4, so a pass is two bars.
  def form do
    for {section, count} <- [groove: 2, ruffs: 2, threes: 6, fives: 5, sextuplets: 4, groove: 2],
        time <- 0..(count - 1) do
      together([
        part(:pandeiro_thumb, hits(section, time, ["o", "ox"]), synth: :pandeiro_thumb),
        part(:pandeiro_heel, hits(section, time, ["h"]), synth: :pandeiro_heel),
        part(:pandeiro_jingles, hits(section, time, ["f"]), synth: :pandeiro_jingles),
        part(:pandeiro_slap, hits(section, time, ["s"]), synth: :pandeiro_slap)
      ])
    end
  end
end

song(tempo: 104, music: repeat(seq(Virtuoso.form())))
