import Mx

# A beat is a quarter note of 2/4, so a pass is two bars of sixteenths.

defmodule Pandeiro do
  import Mx

  # Each pass is two bars, a sixteenth to each cell: o is an open bass with the thumb, ox a closed one, h the heel of the hand, f the fingertips, s a slap and . a rest; > accents a stroke.
  def cells(:choro), do: "ox f h f  o f h f  ox f h f  o f h f"
  def cells(:samba_de_roda), do: "o s . s  o f h f  o s . s  o f h f"
  def cells(:baiao), do: "o f h o  o f h> f  o f h o  o s h f"
  def cells(:forro), do: "o f h o  s h f o  o f h f>  h o f o"
  def cells(:coco), do: "o f h o  f s h o  o f h s  h o o f"

  # mx's thumb has no closed bass, so ox is the thumb played softly.
  def vel("o"), do: 0.75
  def vel("ox"), do: 0.4
  def vel("h"), do: 0.55
  def vel("f"), do: 0.5
  def vel("s"), do: 0.8

  # The beats the given strokes fall on in a pass, as {beat, vel}.
  def strokes(section, letters) do
    for {cell, index} <- section |> cells() |> String.split() |> Enum.with_index(),
        stroke = String.trim_trailing(cell, ">"),
        stroke in letters do
      vel = if stroke == cell, do: vel(stroke), else: 0.9
      {index * 0.25, vel}
    end
  end

  # A pass of pandeiro_thumb, as 4 beats.
  def pandeiro_thumb(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["o", "ox"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # A pass of pandeiro_heel, as 4 beats.
  def pandeiro_heel(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["h"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # A pass of pandeiro_jingles, as 4 beats.
  def pandeiro_jingles(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["f"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # A pass of pandeiro_slap, as 4 beats.
  def pandeiro_slap(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["s"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [choro: 4, samba_de_roda: 2, baiao: 2, forro: 2, coco: 4],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:pandeiro_thumb, pandeiro_thumb(section, pass), synth: :pandeiro_thumb),
        part(:pandeiro_heel, pandeiro_heel(section, pass), synth: :pandeiro_heel),
        part(:pandeiro_jingles, pandeiro_jingles(section, pass), synth: :pandeiro_jingles),
        part(:pandeiro_slap, pandeiro_slap(section, pass), synth: :pandeiro_slap)
      ])
    end)
  end
end

song(tempo: 100, music: repeat(seq(Pandeiro.form())))
