import Mx

# A solo for the tanpura written for mx from how a tanpura is played: Pa, Sa, Sa and the low Sa plucked in turn, the first and the last given two beats and the middle two one beat each, as players on Rasikas.org give the Hindustani pattern, so the low Sa rings on before the cycle starts again.
defmodule Tanpura do
  import Mx

  # It holds a slow drone on C sharp, plucks it quicker, moves to a low E for two short drones, and ends on a long, slow drone on C sharp.

  # Each drone as its Sa, the beats between plucks, and the beats it holds.
  def drone(:slow), do: {49, 1, 36}
  def drone(:quick), do: {49, 0.6, 24}
  def drone(:low), do: {40, 0.8, 12}
  def drone(:long), do: {49, 1, 60}

  # A pass of the drone: Sa plucked and held, then 4 beats of its ring.
  def tanpura(section, _pass) do
    {sa, gap, held} = drone(section)
    seq([note(sa, held, vel: 0.6, gap: gap), rest(4)])
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [slow: 1, quick: 1, low: 2, long: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:tanpura, tanpura(section, pass), synth: :tanpura, defaults: [amp: 0.5])
    end)
  end
end

song(tempo: 60, music: repeat(seq(Tanpura.form())))
