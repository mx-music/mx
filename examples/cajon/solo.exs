import Mx

# Festejo is written in 12/8 and felt as a dotted quarter to the beat, as http://hugoalcazar.blogspot.com/2008/04/j.html explains, so a beat is three eighths and a pass is a bar.

defmodule Cajon do
  import Mx

  # Festejo patterns written for mx, an eighth to each cell: B is the bass tone, S the slap, g a ghost stroke and . a rest.
  def cells(:groove), do: "B . g  S . g  B g .  S . g"
  def cells(:ghosts), do: "B g g  S g g  B g g  S g S"
  def cells(:accents), do: "B . B  S . S  B . B  S . ."
  def cells(:break), do: "S S S  S S S  B . .  B . ."

  # The beats a stroke falls on in a pass, as {beat, slap, vel}; a stroke on the beat is accented, and a ghost stroke is a soft slap.
  def strokes(section) do
    letters = section |> cells() |> String.replace(" ", "") |> String.graphemes()

    for {cell, index} <- Enum.with_index(letters), cell != "." do
      {slap, vel, accented} =
        %{"B" => {0, 0.7, 0.85}, "S" => {1, 0.8, 0.95}, "g" => {1, 0.3, 0.3}}[cell]

      {index / 3, slap, if(rem(index, 3) == 0, do: accented, else: vel)}
    end
  end

  # A pass of cajon, as 4 beats.
  def cajon(section, _pass) do
    hits = for {beat, slap, vel} <- strokes(section), do: {beat, hit(slap: slap, vel: vel)}
    at(hits, 4)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [groove: 4, ghosts: 4, accents: 2, break: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:cajon, cajon(section, pass), synth: :cajon)
    end)
  end
end

song(tempo: 104, music: repeat(seq(Cajon.form())))
