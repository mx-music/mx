defmodule Pandeiro do
  @moduledoc """
  A beat is a quarter note of 2/4, so a pass is two bars of sixteenths.
  """

  use Mx.Song, tempo: 100

  part :pandeiro_thumb, synth: :pandeiro_thumb
  part :pandeiro_heel, synth: :pandeiro_heel
  part :pandeiro_jingles, synth: :pandeiro_jingles
  part :pandeiro_slap, synth: :pandeiro_slap

  # o is an open bass with the thumb, ox a closed one, h the heel of the hand, f the fingertips and
  # s a slap; mx's thumb has no closed bass, so ox is the thumb played softly.
  kit :pandeiro,
    o: [part: :pandeiro_thumb, vel: 0.75],
    ox: [part: :pandeiro_thumb, vel: 0.4],
    h: [part: :pandeiro_heel, vel: 0.55],
    f: [part: :pandeiro_jingles, vel: 0.5],
    s: [part: :pandeiro_slap, vel: 0.8]

  def song do
    repeat(
      form([choro: 4, samba_de_roda: 2, baiao: 2, forro: 2, coco: 4], fn section ->
        kit(:pandeiro, pattern(section), 0.25, accent: [vel: 0.9])
      end)
    )
  end

  # Each pass is two bars, a sixteenth to each stroke, and _ a rest; > accents a stroke.
  defp pattern(:choro), do: ~MX"ox f h f  o f h f  ox f h f  o f h f"
  defp pattern(:samba_de_roda), do: ~MX"o s _ s  o f h f  o s _ s  o f h f"
  defp pattern(:baiao), do: ~MX"o f h o  o f >h f  o f h o  o s h f"
  defp pattern(:forro), do: ~MX"o f h o  s h f o  o f h >f  h o f o"
  defp pattern(:coco), do: ~MX"o f h o  f s h o  o f h s  h o o f"
end
