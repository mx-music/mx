defmodule Ganza do
  @moduledoc """
  A beat is a quarter note of samba's 2/4, so a pass is two bars of sixteenths.
  """

  use Mx.Song, tempo: 100

  part :ganza, synth: :ganza
  part :shaker, synth: :shaker

  def song do
    repeat(
      form([one: 4, two: 2, three: 2, four: 4], fn section, %{pass: pass} ->
        together(ganza: ganza(section, pass), shaker: shaker(section, pass))
      end)
    )
  end

  # A pass of ganza, as 4 beats; the accent on each beat's first sixteenth is mx's own, since the
  # patterns mark none.
  defp ganza(section, _pass) do
    steps(pattern(section), 0.25,
      strokes: [F: [up: 0], B: [up: 1]],
      each: fn step -> [vel: if(rem(step, 4) == 0, do: 0.85, else: 0.45)] end
    )
  end

  # A pass of the shaker, as 4 beats: silent in the first section, then down on the beats and up
  # between them.
  defp shaker(section, _pass) do
    if section == :one do
      rest(4)
    else
      downs = for beat <- [0, 1, 2, 3], do: {beat, hit(vel: 0.5)}
      ups = for beat <- [0.5, 1.5, 2.5, 3.5], do: {beat, hit(up: 1, vel: 0.35)}
      at(downs ++ ups, 4)
    end
  end

  # Four samba ganzá patterns from
  # https://kkfsamba2014.wordpress.com/2014/10/01/samba-patterns-for-ganza/, a sixteenth each:
  # F pushes the ganzá forward for a down stroke, B pulls it back for an up stroke, and O, written here as a dot, rests.
  defp pattern(:one), do: ~MX"FBFB FBFB FBFB FBFB"s
  defp pattern(:two), do: ~MX"F.B. F.B. F.B. F.B."s
  defp pattern(:three), do: ~MX"F..B F..B F..B F..B"s
  defp pattern(:four), do: ~MX"FB.F BF.B FB.F BF.B"s
end
