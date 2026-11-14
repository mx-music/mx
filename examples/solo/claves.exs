# A solo for the claves written for mx from the standard clave patterns, as Wikipedia's article on
# the clave rhythm gives them: son clave 3-2 and then 2-3, rumba clave, the bossa nova clave, the
# 6/8 standard bell of bembé, and son clave again to close.
defmodule Claves do
  use Mx.Song, tempo: 104

  # A pass is two bars of 4/4, written as sixteen cells of eighth notes, or for the 6/8 bell as
  # twenty-four cells of triplet eighths.

  part :clave, synth: :clave, defaults: [amp: 0.5]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [son: 2, son_2_3: 1, rumba: 2, bossa: 2, bembe: 2, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:clave, clave(section, pass))
    end)
  end

  # A pass of clave, as 8 beats.
  defp clave(section, _pass) do
    hits = for {beat, opts} <- strokes(section), do: {beat, hit(opts)}
    at(hits, 8)
  end

  # The strokes of a pass, as {beat, options}.
  defp strokes(section) do
    {per_beat, cells} = cells(section)

    for {letter, index} <- Enum.with_index(String.graphemes(cells)),
        letter != ".",
        do: {index / per_beat, [vel: vel(letter)]}
  end

  # The son clave: three strokes in the first bar and two in the second.
  defp cells(:son), do: {2, "x..x..x...x.x..."}
  defp cells(:son_2_3), do: {2, "..x.x...x..x..x."}

  # The rumba clave delays the third stroke by an eighth.
  defp cells(:rumba), do: {2, "x..x...x..x.x..."}

  # The bossa nova clave delays the son clave's last stroke by an eighth.
  defp cells(:bossa), do: {2, "x..x..x...x..x.."}

  # The 6/8 standard bell, twice to a pass.
  defp cells(:bembe), do: {3, String.duplicate("x.x.xx.x.x.x", 2)}

  # Son clave 3-2, its last stroke the hardest.
  defp cells(:ending), do: {2, "x..x..x...x.X..."}

  defp vel("x"), do: 0.75
  defp vel("X"), do: 1
end
