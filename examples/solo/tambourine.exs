defmodule Tambourine do
  @moduledoc """
  A solo for the tambourine written for mx from its standard ways of playing, none of them
  transcribed.
  """

  use Mx.Song, tempo: 112

  # It opens on a shake roll that starts and ends on a stroke, as orchestral players begin and end
  # a roll; then the pop and soul backbeat, shaken in eighths and struck on the second and fourth
  # beats; then a tarantella, the traditional dance of southern Italy, in continuous 6/8 triplets,
  # the palm on each beat and the fingers or the knee between; then soft strokes of the fingertips
  # by the rim; and a roll that grows into a last stroke of the flat hand.

  part :tambourine, synth: :tambourine, defaults: [amp: 0.5]
  part :tambourine_shake, synth: :tambourine_shake, defaults: [amp: 0.5]

  def song do
    repeat(
      form([roll: 1, backbeat: 2, tarantella: 3, soft: 1, ending: 1], fn section, %{pass: pass} ->
        together([
          part(:tambourine, tambourine(section, pass)),
          part(:tambourine_shake, tambourine_shake(section, pass))
        ])
      end)
    )
  end

  # A pass of tambourine, as 4 beats.
  defp tambourine(section, pass) do
    {per_beat, drums} = cells(section, pass)

    steps(drums[:hit], 1 / per_beat,
      strokes: [g: [vel: 0.3], o: [vel: 0.45], x: [vel: 0.6], X: [vel: 1]]
    )
  end

  # A pass of tambourine_shake, as 4 beats; the ending's shakes grow from soft to loud.
  defp tambourine_shake(section, pass) do
    {per_beat, drums} = cells(section, pass)
    vel = fn step -> if section == :ending, do: 0.3 + step / 4 * 0.2, else: 0.45 end

    case drums[:shake] do
      nil -> rest(4)
      shakes -> steps(shakes, 1 / per_beat, strokes: [s: []], each: &[vel: vel.(&1)])
    end
  end

  # A pass is four beats, written as cells: sixteenths for most sections, and for the tarantella
  # triplet eighths, so a beat is a dotted quarter of 6/8.
  # A letter is a stroke, and s a shake as long as its length in cells.
  defp cells(:roll, _pass), do: {4, [hit: ~MX"x.............x."s, shake: ~MX"s:14 _:2"]}

  defp cells(:backbeat, _pass) do
    {4, [hit: ~MX"....X.......X..."s, shake: ~MX"s _ s _ s _ s _ s _ s _ s _ s _"]}
  end

  # DA-da-da on every beat, then DA-da DA-da-da, the tarantella's two figures, and the first
  # again, closing on two strokes of the palm.
  defp cells(:tarantella, pass) do
    figures = [~MX"XooXooXooXoo"s, ~MX"Xo.XooXo.Xoo"s, ~MX"XooXooXooX.X"s]
    {3, [hit: Enum.at(figures, rem(pass, 3))]}
  end

  defp cells(:soft, _pass), do: {4, [hit: ~MX"g...g...g.g.g..."s]}

  # A roll in three shakes, each harder than the last, into the flat hand.
  defp cells(:ending, _pass), do: {4, [hit: ~MX"............X..."s, shake: ~MX"s:4 s:4 s:4 _:4"]}
end
