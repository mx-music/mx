import Mx

# A solo for the güiro written for mx from its standard patterns: the cha-cha-chá as the Jazz Education Network gives it, a long scrape on the quarter note and two short ones on the eighths after it, "down, down up"; son's long-short-short-long and Puerto Rican bomba's three short scrapes before a long one, as Michel Conci's notes on the güiro give them.
defmodule Guiro do
  import Mx

  # It opens on long, slow scrapes, plays the cha-cha-chá, son and bomba, the cha-cha-chá again, and ends on one long scrape.

  # A pass is a bar of four beats, as {beat, letter}: L is a long scrape, S a short one, and W a whole slow scrape.
  def scrapes(:slow), do: [{0, "W"}, {2, "W"}]
  def scrapes(:chacha), do: [{0, "L"}, {1, "S"}, {1.5, "S"}, {2, "L"}, {3, "S"}, {3.5, "S"}]
  def scrapes(:son), do: [{0, "L"}, {1, "S"}, {2, "S"}, {3, "L"}]
  def scrapes(:bomba), do: [{0, "S"}, {1, "S"}, {2, "S"}, {3, "L"}]
  def scrapes(:again), do: scrapes(:chacha)
  def scrapes(:ending), do: [{0, "W"}]

  def scrape("W"), do: [vel: 0.6, sustain: 1.6]
  def scrape("L"), do: [vel: 0.7, sustain: 0.6]
  def scrape("S"), do: [vel: 0.55, sustain: 0.18]

  # A pass of guiro, as 4 beats.
  def guiro(section, _pass) do
    hits = for {beat, letter} <- scrapes(section), do: {beat, hit(scrape(letter))}
    at(hits, 4)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [slow: 1, chacha: 4, son: 2, bomba: 2, again: 2, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:guiro, guiro(section, pass), synth: :guiro, defaults: [amp: 0.6])
    end)
  end
end

song(tempo: 120, music: repeat(seq(Guiro.form())))
