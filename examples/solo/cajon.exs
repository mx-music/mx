defmodule Cajon do
  @moduledoc """
  A solo for the cajón written for mx, from Peru, where the cajón comes from, to flamenco, which
  took it up in 1977, and to the grooves it plays in place of a drum kit.
  The festejo is in 12/8, felt as a dotted quarter to the beat, as
  http://hugoalcazar.blogspot.com/2008/04/j.html explains; its strokes are written for mx.
  The rumba flamenca groups its eight eighths as 3+3+2 and accents the second and fourth beats, by
  Wikipedia's article on it: the bass tone on the first beat and the eighth after the second, and
  the slap on two and four.
  The bulerías is a cycle of twelve counts that starts on 12 and accents 12, 3, 6, 8 and 10, or
  12, 3, 7, 8 and 10, by Wikipedia's article on it; here a count is an eighth, 208 to the minute,
  and the last cycle closes on 10.
  The last groove is a rock beat moved from the kit in the three steps of
  https://www.thomann.co.uk/onlineexpert_page_cajon_traditional_and_modern_grooves.html: the bass
  tone for the kick and the slap for the snare, then soft slaps so every eighth is played, then
  every sixteenth.
  It ends on a roll of slaps that grows into the bass tone.
  """

  use Mx.Song, tempo: 104

  # Each pass is written as its beats and its cells: B is the bass tone, S the slap, s a softer
  # slap, g a ghost stroke, a slap at its softest, X the bass tone at its hardest and . a rest;
  # spaces are left out.
  @festejo [{4, ~MX"B.g S.g Bg. S.g"s}, {4, ~MX"Bgg Sgg Bgg SgS"s}]
  @rumba [{4, ~MX"B.SB ..S."s}, {4, ~MX"B.gg S.B. g.gg S.gg"s}]

  # Which accents of the bulerías are bass tones and which are slaps, and the cycle that closes on
  # 10, are written for mx.
  @bulerias [
    {6, ~MX"Bgg Bgg Bg Bg Bg"s},
    {6, ~MX"Bgg Bgg Sg Sg Sg"s},
    {6, ~MX"Bgg Bgg gS Sg Sg"s},
    {6, ~MX"B.g.g. B.gggg sgsg SgSS X..."s}
  ]

  @rock [
    {4, ~MX"B... S... B.B. S..."s},
    {4, ~MX"B.g. S.g. B.B. S.g."s},
    {4, ~MX"Bggg Sggg BgBg Sggg"s},
    {4, ~MX"Bggg Sggg BgBg SsSS"s}
  ]

  @ending [{4, ~MX"gggggggg ggggssss ssssSSSS X......."s}, {4, ~MX"X"s}]

  part :cajon, synth: :cajon

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a bar or, in the bulerías, a cycle of twelve counts.
  defp form do
    for pass <- passes(), do: part(:cajon, cajon(pass))
  end

  defp passes do
    twice = fn passes -> Enum.flat_map(passes, &[&1, &1]) end
    twice.(@festejo) ++ twice.(@rumba) ++ @bulerias ++ @rock ++ @ending
  end

  # A pass of cajon.
  defp cajon({beats, pattern}) do
    steps(pattern, beats / length(pattern),
      strokes: [
        B: [slap: 0, vel: 0.8],
        X: [slap: 0, vel: 0.95],
        S: [slap: 1, vel: 0.9],
        s: [slap: 1, vel: 0.6],
        g: [slap: 1, vel: 0.35]
      ]
    )
  end
end
