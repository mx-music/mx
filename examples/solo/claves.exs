defmodule Claves do
  @moduledoc """
  A solo for the claves written for mx from the standard clave patterns, as Wikipedia's article on
  the clave rhythm gives them: son clave 3-2 and then 2-3, rumba clave, the bossa nova clave, the
  6/8 standard bell of bembé, and son clave again to close.
  """

  use Mx.Song, tempo: 104

  # A pass is two bars of 4/4, written as sixteen cells of eighth notes, or for the 6/8 bell as
  # twenty-four cells of triplet eighths.

  part :clave, synth: :clave, defaults: [amp: 0.5]

  def song do
    repeat(form())
  end

  # The form, each of its passes a section.
  defp form do
    form([son: 2, son_2_3: 1, rumba: 2, bossa: 2, bembe: 2, ending: 1], fn section,
                                                                           %{pass: pass} ->
      part(:clave, clave(section, pass))
    end)
  end

  # A pass of clave, as 8 beats.
  defp clave(section, _pass) do
    pattern = cells(section)
    steps(pattern, 8 / length(pattern), strokes: [x: [vel: 0.75], X: [vel: 1]])
  end

  # The son clave: three strokes in the first bar and two in the second.
  defp cells(:son), do: ~MX"x..x..x...x.x..."s
  defp cells(:son_2_3), do: ~MX"..x.x...x..x..x."s

  # The rumba clave delays the third stroke by an eighth.
  defp cells(:rumba), do: ~MX"x..x...x..x.x..."s

  # The bossa nova clave delays the son clave's last stroke by an eighth.
  defp cells(:bossa), do: ~MX"x..x..x...x..x.."s

  # The 6/8 standard bell, twice to a pass.
  defp cells(:bembe), do: ~MX"x.x.xx.x.x.x x.x.xx.x.x.x"s

  # Son clave 3-2, its last stroke the hardest.
  defp cells(:ending), do: ~MX"x..x..x...x.X..."s
end
