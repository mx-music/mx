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
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [roll: 1, backbeat: 2, tarantella: 3, soft: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:tambourine, tambourine(section, pass)),
        part(:tambourine_shake, tambourine_shake(section, pass))
      ])
    end)
  end

  # A pass of tambourine, as 4 beats.
  defp tambourine(section, pass) do
    hits = for {beat, opts} <- strokes(section, pass), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of tambourine_shake, as 4 beats.
  defp tambourine_shake(section, pass) do
    hits = for {beat, opts} <- shakes(section, pass), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # The strokes of a pass, as {beat, options}.
  defp strokes(section, pass) do
    {per_beat, drums} = cells(section, pass)
    letters = drums |> Keyword.get(:hit, "") |> String.graphemes()

    for {letter, index} <- Enum.with_index(letters),
        letter != ".",
        do: {index / per_beat, [vel: vel(letter)]}
  end

  # The shakes of a pass, as {beat, options}; the ending's grow from soft to loud.
  defp shakes(section, pass) do
    {per_beat, drums} = cells(section, pass)
    found = Regex.scan(~r/s-*/, Keyword.get(drums, :shake, ""), return: :index) |> List.flatten()

    for {{start, length}, index} <- Enum.with_index(found) do
      vel = if section == :ending, do: 0.3 + index * 0.2, else: 0.45
      {start / per_beat, [vel: vel, sustain: length / per_beat]}
    end
  end

  # A pass is four beats, written as cells: sixteenths for most sections, and for the tarantella
  # triplet eighths, so a beat is a dotted quarter of 6/8.
  # A letter is a stroke, s starts a shake, and each - after it holds the shake a cell longer.
  defp cells(:roll, _pass), do: {4, [hit: "x.............x.", shake: "s-------------.."]}

  defp cells(:backbeat, _pass) do
    {4, [hit: "....X.......X...", shake: "s.s.s.s.s.s.s.s."]}
  end

  # DA-da-da on every beat, then DA-da DA-da-da, the tarantella's two figures, and the first
  # again, closing on two strokes of the palm.
  defp cells(:tarantella, pass) do
    figures = ["XooXooXooXoo", "Xo.XooXo.Xoo", "XooXooXooX.X"]
    {3, [hit: Enum.at(figures, rem(pass, 3))]}
  end

  defp cells(:soft, _pass), do: {4, [hit: "g...g...g.g.g..."]}

  # A roll in three shakes, each harder than the last, into the flat hand.
  defp cells(:ending, _pass), do: {4, [hit: "............X...", shake: "s---s---s---...."]}

  defp vel("g"), do: 0.3
  defp vel("o"), do: 0.45
  defp vel("x"), do: 0.6
  defp vel(_), do: 1
end
