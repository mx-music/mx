# A solo for the tanpura written for mx from how a tanpura is played: Pa, Sa, Sa and the low Sa
# plucked in turn, the first and the last given two beats and the middle two one beat each, as
# players on Rasikas.org give the Hindustani pattern, so the low Sa rings on before the cycle
# starts again.
defmodule Tanpura do
  use Mx.Song, tempo: 60

  # It holds a slow drone on C sharp, plucks it quicker, moves to a low E for two short drones,
  # and ends on a long, slow drone on C sharp.

  part :tanpura, synth: :tanpura, defaults: [amp: 0.5]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [slow: 1, quick: 1, low: 2, long: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:tanpura, tanpura(section, pass))
    end)
  end

  # A pass of the drone: Sa plucked and held, then 4 beats of its ring.
  defp tanpura(section, _pass) do
    {sa, gap, held} = drone(section)
    seq([note(sa, held, vel: 0.6, gap: gap), rest(4)])
  end

  # Each drone as its Sa, the beats between plucks, and the beats it holds.
  defp drone(:slow), do: {49, 1, 36}
  defp drone(:quick), do: {49, 0.6, 24}
  defp drone(:low), do: {40, 0.8, 12}
  defp drone(:long), do: {49, 1, 60}
end
