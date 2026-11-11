import Mx

# A beat is a quarter note of 4/4, so a pass is a bar of eighths, or of sixteenths in the fill.

defmodule Bongos do
  import Mx

  # The martillo is eight strokes in a bar, most of them on the small drum, the macho, and the seventh on the large one, the hembra, as https://www.x8drums.com/blog/martillo-bongo-rhythm describes.
  # Some bongoceros play the fourth and eighth as a heel-tip stroke, as the same page says.
  # The strokes are mx's own, a cell to each eighth: M is a muted stroke on the macho with the index finger, t a soft muted one with the thumb, o the macho's open tone, h a heel-tip stroke and H the hembra's open tone.
  def cells(:martillo), do: "M t o t M t H t"
  def cells(:heel_tip), do: "M t o h M t H h"

  # A fill across both drums written for mx, a cell to each sixteenth.
  def cells(:fill), do: "H M H M o M o M H H o o H o H H"

  def stroke("M"), do: {:high_bongo, 1, 0.8}
  def stroke("t"), do: {:high_bongo, 1, 0.4}
  def stroke("o"), do: {:high_bongo, 0, 0.7}
  def stroke("h"), do: {:high_bongo, 1, 0.25}
  def stroke("H"), do: {:low_bongo, 0, 0.8}

  # The strokes of a pass on one drum, as {beat, muted, vel}.
  def strokes(section, drum) do
    letters = String.split(cells(section))
    step = 4 / length(letters)

    for {letter, index} <- Enum.with_index(letters),
        {^drum, muted, vel} <- [stroke(letter)],
        do: {index * step, muted, vel}
  end

  # A pass of high_bongo, as 4 beats.
  def high_bongo(section, _pass) do
    hits =
      for {beat, muted, vel} <- strokes(section, :high_bongo),
          do: {beat, hit(muted: muted, vel: vel)}

    at(hits, 4)
  end

  # A pass of low_bongo, as 4 beats.
  def low_bongo(section, _pass) do
    hits =
      for {beat, muted, vel} <- strokes(section, :low_bongo),
          do: {beat, hit(muted: muted, vel: vel)}

    at(hits, 4)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [martillo: 4, heel_tip: 2, martillo: 2, fill: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:high_bongo, high_bongo(section, pass), synth: :high_bongo),
        part(:low_bongo, low_bongo(section, pass), synth: :low_bongo)
      ])
    end)
  end
end

song(tempo: 112, music: repeat(seq(Bongos.form())))
