import Mx

# A beat is a quarter note of 4/4, so a pass is two bars of sixteenths.

defmodule Cabasa do
  import Mx

  # In bossa nova the cabasa plays a steady, unending sixteenth-note pulse, as https://www.masterclass.com/articles/guide-to-brazilian-bossa-nova-music describes.
  # The two-bar bossa nova figure from https://tunableapp.com/rhythm/bossa-nova-rhythm/, as the sixteenths it falls on.
  def figure, do: [0, 6, 12, 18, 24, 28]

  # The accents are mx's own: on each beat while the pulse settles, then on the bossa figure, which the turns play as a rub, the beads turned against the cylinder.
  def strokes(section) do
    for sixteenth <- 0..31 do
      accent? = if section == :steady, do: rem(sixteenth, 4) == 0, else: sixteenth in figure()
      rub = if section == :turns and accent?, do: 1, else: 0
      {sixteenth * 0.25, if(accent?, do: 0.8, else: 0.4), rub}
    end
  end

  # A pass of cabasa, as 8 beats.
  def cabasa(section, _pass) do
    hits =
      for {beat, vel, rub} <- strokes(section) do
        if rub == 1, do: {beat, hit(vel: vel, rub: 1, sustain: 0.25)}, else: {beat, hit(vel: vel)}
      end

    at(hits, 8)
  end

  # The form, each of its passes a section.
  def form do
    sections = for {section, count} <- [steady: 2, bossa: 4, turns: 2], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:cabasa, cabasa(section, pass), synth: :cabasa)
    end)
  end
end

song(tempo: 120, music: repeat(seq(Cabasa.form())))
