defmodule Congas do
  @moduledoc """
  A solo for the three congas written for mx from their standard patterns, as Wikipedia's articles
  on the tumbao and on the quinto give them.
  The conga plays the tumbao, or marcha, of son montuno alone: heel, tip, slap, tip, heel, tip and
  two open tones, twice to a clave.
  The tumba joins it in the two tumbaos for two drums that the article takes from Rebeca Mauleón's
  Salsa Guidebook, each with the tumba's open tones on the clave's three side.
  Over the tumbao the quinto plays as it does in rumba: the lock, whose strokes are the son clave
  a sixteenth late, tone, slap, tone in one clave and slap, tone, slap in the next, and then with
  strokes doubled or left out; the cross, a slap on every third sixteenth, which takes three
  claves to come round; and a phrase that ends on the sixteenth after the third beat.
  The conga rolls heel and tip, the manoteo, into a run down the three drums; the tumbao comes
  back, and the solo ends on a slap and an open tone together.
  """

  use Mx.Song, tempo: 100

  # A beat is a quarter note of 4/4, so a pass is a bar, the length of a clave, written as sixteen
  # cells to a drum; the roll is written as thirty-two.
  # The letters are the articles': H is the heel of the hand, T its tip, S a slap and O an open
  # tone; h and t are the heel and tip played softly.
  @one_drum [mid_conga: ~MX"HTSTHTOO HTSTHTOO"s]
  @two_drums [mid_conga: ~MX"HTS..TOO HTSTHTOO"s, low_conga: ~MX"...OO... ........"s]
  @two_drums_again [mid_conga: ~MX"HTS.HTOO HTS.HTOO"s, low_conga: ~MX"...O.... ...O...."s]

  # The lock is the quinto's own; which strokes are tones and which are slaps, and the strokes
  # doubled and left out, are written for mx.
  @lock [~MX".O..S..S ...O.O.."s, ~MX".S..O..O ...S.S.."s]
  @varied [~MX".OO.S..S S..O.O.."s, ~MX".S..O..O ...SS..."s]
  @cross [~MX".S..S..S ..S..S.."s, ~MX"S..S..S. .S..S..S"s, ~MX"..S..S.. S..S..S."s]

  # The phrase that ends on the sixteenth after the third beat is written for mx.
  @resolution ~MX"..O.OO.S .O......"s

  # The tumba is the quietest of the three drums and the conga the loudest, so each plays at the
  # level that brings their open tones together.
  part :low_conga, synth: :low_conga, defaults: [amp: 1.4]
  part :mid_conga, synth: :mid_conga, defaults: [amp: 0.35]
  part :high_conga, synth: :high_conga, defaults: [amp: 0.55]

  # The form, each of its passes a bar.
  def song, do: repeat(seq(bars(), &drums/1))

  # A bar of the three drums, each silent where the bar gives it no cells.
  defp drums(cells) do
    together([:low_conga, :mid_conga, :high_conga], fn drum ->
      cell = Keyword.get(cells, drum, ~MX"."s)
      part(drum, bar(cell))
    end)
  end

  defp bars do
    quinto = @lock ++ @varied ++ @cross ++ [@resolution]
    answers = for cells <- quinto, do: [high_conga: cells] ++ @two_drums

    List.duplicate(@one_drum, 2) ++
      List.duplicate(@two_drums, 2) ++
      List.duplicate(@two_drums_again, 2) ++
      answers ++
      [
        [
          mid_conga: ~MX"hthththt hthtHTHT HTHTHTHT ....O..."s,
          high_conga: ~MX"........ ....OO.."s,
          low_conga: ~MX"........ .......O"s
        ],
        @two_drums,
        @two_drums,
        [
          mid_conga: ~MX"HTSTHTOO HTS....."s,
          high_conga: ~MX"........ ...OO.O."s,
          low_conga: ~MX"........ .....O.O"s
        ],
        [high_conga: ~MX"S"s, low_conga: ~MX"O"s]
      ]
  end

  # A bar of one drum, as 4 beats.
  defp bar(pattern), do: steps(pattern, 4 / length(pattern), strokes: strokes())

  # mx's conga has no stroke of the heel, so the heel is a soft tone, low as the palm's stroke is.
  # The tip is a muted stroke, far quieter than a tone, as on the recordings, so it plays at twice
  # the conga's level.
  defp strokes do
    [
      H: [vel: 0.35],
      T: [vel: 0.4, mute: 1, amp: 0.7],
      h: [vel: 0.2],
      t: [vel: 0.25, mute: 1, amp: 0.7],
      S: [vel: 0.9, slap: 1],
      O: [vel: 0.9]
    ]
  end
end
