import Mx

# A solo for the cabasa written for mx from the ways it is played.
# The player holds the handle and twists it back and forth with the other hand pressed on the beads, as Wikipedia's article on the cabasa describes, and that hand can strike the cabasa for an accent, as https://www.carvedculture.com/blogs/articles/how-to-play-cabasa-tutorial describes; with less pressure the beads spin on after a turn.
# In bossa nova the cabasa plays a steady, unending sixteenth-note pulse, as https://www.masterclass.com/articles/guide-to-brazilian-bossa-nova-music describes.
# It opens on two long turns, settles into the pulse, strikes the two-bar bossa nova figure from https://tunableapp.com/rhythm/bossa-nova-rhythm/ over it, plays the figure alone with the beads left to spin after each stroke, takes up the pulse again, and ends on a turn that grows into a stroke.
defmodule Cabasa do
  import Mx

  # A beat is a quarter note of 4/4, so a pass is two bars of sixteenths.
  # The bossa nova figure, as the sixteenths it falls on.
  def figure, do: [0, 6, 12, 18, 24, 28]

  # A twist is a short turn of the beads, harder forward, on the eighths, than back.
  def twist(sixteenth) do
    vel = if rem(sixteenth, 2) == 0, do: 0.55, else: 0.35
    {sixteenth * 0.25, [vel: vel, rub: 1, sustain: 0.1]}
  end

  def strike(sixteenth, vel \\ 0.8), do: {sixteenth * 0.25, [vel: vel]}

  # A turn that lets the beads spin for its beats.
  def spin(sixteenth, beats, vel), do: {sixteenth * 0.25, [vel: vel, rub: 1, sustain: beats]}

  def strokes(:turns), do: [spin(0, 3, 0.4), spin(16, 3, 0.6)]
  def strokes(:pulse), do: for(sixteenth <- 0..31, do: twist(sixteenth))

  # Where the figure falls, the stroke takes the twist's place.
  def strokes(:bossa) do
    for sixteenth <- 0..31 do
      if sixteenth in figure(), do: strike(sixteenth), else: twist(sixteenth)
    end
  end

  def strokes(:spinning) do
    Enum.flat_map(figure(), &[strike(&1), spin(&1, 0.5, 0.45)])
  end

  def strokes(:ending), do: [spin(0, 2, 0.4), spin(8, 1.75, 0.7), strike(16, 0.9)]

  # A pass of cabasa, as 8 beats.
  def cabasa(section) do
    hits = for {beat, opts} <- strokes(section), do: {beat, hit(opts)}
    at(hits, 8)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [turns: 1, pulse: 2, bossa: 4, spinning: 2, bossa: 2, ending: 1],
          _ <- 1..count,
          do: section

    for section <- sections do
      part(:cabasa, cabasa(section), synth: :cabasa, defaults: [amp: 0.6])
    end
  end
end

song(tempo: 120, music: repeat(seq(Cabasa.form())))
