defmodule Triangle do
  @moduledoc """
  A solo for the triangle written for mx from its standard ways of playing, none of them
  transcribed.
  """

  use Mx.Song, tempo: 96

  # It opens on single strokes left to ring, as in the orchestra, from soft to loud; then short
  # strokes the hand damps at once; then a roll, strokes as fast as a beater moves inside one
  # corner, growing into a stroke left to ring; then the forró triangle of the baião, four
  # sixteenths to a beat with the hand open on the third and closed on the others; and a last
  # stroke left to ring.

  part :triangle, synth: :triangle, defaults: [amp: 0.5]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [ringing: 2, damped: 1, roll: 1, baiao: 3, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:triangle, triangle(section, pass))
    end)
  end

  # A pass of triangle, as 4 beats.
  defp triangle(section, pass) do
    hits = for {beat, opts} <- strokes(section, pass), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # The strokes of a pass, as {beat, options}; the roll plays two strokes to each of its
  # sixteenths.
  defp strokes(section, pass) do
    letters = section |> cells(pass) |> String.graphemes()

    for {letter, index} <- Enum.with_index(letters),
        letter != ".",
        {offset, step} <- if(letter == "r", do: [{0, 0}, {0.125, 1}], else: [{0, 0}]) do
      {index / 4 + offset, stroke(letter, pass, index * 2 + step)}
    end
  end

  # A pass is four beats of sixteenths.
  # O rings until it fades, o rings until the hand closes on the next stroke, c is a stroke the
  # hand keeps closed, d a stroke damped at once, and r a stroke of the roll.
  defp cells(:ringing, pass) do
    if(rem(pass, 2) == 0, do: "O.......O.......", else: "O...............")
  end

  defp cells(:damped, _pass), do: "d.d.d...d.d.dd.."
  defp cells(:roll, _pass), do: "rrrrrrrrrrrrO..."

  # The baião's sixteenths, then the same with the open stroke pushed to the last sixteenth of the
  # fourth beat.
  defp cells(:baiao, pass) do
    if(rem(pass, 3) == 0, do: "ccocccocccocccco", else: "ccocccocccocccoc")
  end

  defp cells(:ending, _pass), do: "O..............."

  # The ringing strokes grow from soft to loud over the first passes, and the roll from soft to
  # loud over its strokes.
  defp stroke("O", pass, _index), do: [vel: Enum.at([0.4, 0.7, 1, 1, 1, 1, 1, 1], pass)]
  defp stroke("o", _pass, _index), do: [vel: 0.75, sustain: 0.2, release: 0.1]
  defp stroke("c", _pass, _index), do: [vel: 0.5, sustain: 0.02, release: 0.15]
  defp stroke("d", _pass, _index), do: [vel: 0.7, sustain: 0.1, release: 0.05]
  defp stroke("r", _pass, index), do: [vel: Float.round(0.3 + index * 0.03, 2)]
end
