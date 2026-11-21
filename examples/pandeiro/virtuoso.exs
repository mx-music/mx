defmodule Virtuoso do
  @moduledoc """
  A pandeiro solo in 2/4 at 104 bpm, on mx's four pandeiro strokes: the thumb's bass, the heel of
  the hand, the fingertips on the jingles, and the slap.
  It opens on a groove and a variation with ruffs, then the hand rocks in sixteenths with an
  accent every three strokes, then every five, then every fourth stroke of sextuplets, the accents
  crossing the bar line until the count meets the first beat again, and the groove comes back.
  """

  use Mx.Song, tempo: 104

  part :pandeiro_thumb, synth: :pandeiro_thumb
  part :pandeiro_heel, synth: :pandeiro_heel
  part :pandeiro_jingles, synth: :pandeiro_jingles
  part :pandeiro_slap, synth: :pandeiro_slap

  # o is an open bass with the thumb, ox a closed one, h the heel of the hand, f the fingertips
  # and s a slap.
  kit :pandeiro,
    o: [part: :pandeiro_thumb, vel: 0.75],
    ox: [part: :pandeiro_thumb, vel: 0.4],
    h: [part: :pandeiro_heel, vel: 0.5],
    f: [part: :pandeiro_jingles, vel: 0.4],
    s: [part: :pandeiro_slap, vel: 0.8]

  # The form, each of its passes a section; a beat is a quarter note of 2/4, so a pass is two
  # bars.
  def song do
    repeat(form([groove: 2, ruffs: 2, threes: 6, fives: 5, sextuplets: 4, groove: 2], &pass/2))
  end

  defp pass(section, _) when section in [:groove, :ruffs],
    do: kit(:pandeiro, cells(section), 0.25)

  defp pass(section, %{time: time}) do
    together(
      pandeiro_thumb: hits(section, time, ["o", "ox"]),
      pandeiro_heel: hits(section, time, ["h"]),
      pandeiro_jingles: hits(section, time, ["f"]),
      pandeiro_slap: hits(section, time, ["s"])
    )
  end

  # A pass of one hand's sound, as 4 beats.
  defp hits(section, time, letters) do
    entries =
      for {beat, stroke, vel} <- strokes(section, time),
          stroke in letters,
          do: {beat, hit(vel: vel)}

    at(entries, 4)
  end

  # Every stroke of a section's pass, as {beat, stroke, vel}, given how many of the section's
  # passes came before it.
  defp strokes(section, time) do
    hand = hand(section)
    size = length(hand)
    count = time * 4 * size

    for index <- 0..(4 * size - 1) do
      stroke = Enum.at(hand, rem(index, size))

      {stroke, vel} =
        if rem(count + index, group(section)) == 0 do
          accent(stroke)
        else
          {stroke, vel(stroke)}
        end

      {index / size, stroke, vel}
    end
  end

  # A stroke to each sixteenth; two in brackets split it in two.
  defp cells(:groove), do: ~MX"o f h o | f s h o | o f h s | h o o f"
  defp cells(:ruffs), do: ~MX"o f h [f h] | f o [f h] f | o o [f h] o | o o [f h] o"

  # mx's thumb has no closed bass, so ox is the thumb played softly.
  defp vel("o"), do: 0.75
  defp vel("ox"), do: 0.4
  defp vel("h"), do: 0.5
  defp vel("f"), do: 0.4
  defp vel("s"), do: 0.8

  # The hand never stops rocking: thumb, fingertips, heel, fingertips in sixteenths, or the thumb
  # and then heel and fingertips in turn in sextuplets.
  defp hand(:sextuplets), do: ["ox", "f", "h", "f", "h", "f"]
  defp hand(_), do: ["ox", "f", "h", "f"]

  # The strokes between accents; counted from the section's start, they cross the bar line and
  # meet the first beat again only when the count comes round.
  defp group(:threes), do: 3
  defp group(:fives), do: 5
  defp group(:sextuplets), do: 4

  # An accent opens the thumb's bass, turns the fingertips into a slap or digs the heel in,
  # wherever in the hand's rocking it falls.
  defp accent("ox"), do: {"o", 0.9}
  defp accent("f"), do: {"s", 0.85}
  defp accent("h"), do: {"h", 0.85}
end
