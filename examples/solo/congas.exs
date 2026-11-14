# A solo for the three congas written for mx from their standard patterns, as Wikipedia's articles
# on the tumbao and on the quinto give them.
# The conga plays the tumbao, or marcha, of son montuno alone: heel, tip, slap, tip, heel, tip and
# two open tones, twice to a clave.
# The tumba joins it in the two tumbaos for two drums that the article takes from Rebeca Mauleón's
# Salsa Guidebook, each with the tumba's open tones on the clave's three side.
# Over the tumbao the quinto plays as it does in rumba: the lock, whose strokes are the son clave
# a sixteenth late, tone, slap, tone in one clave and slap, tone, slap in the next, and then with
# strokes doubled or left out; the cross, a slap on every third sixteenth, which takes three
# claves to come round; and a phrase that ends on the sixteenth after the third beat.
# The conga rolls heel and tip, the manoteo, into a run down the three drums; the tumbao comes
# back, and the solo ends on a slap and an open tone together.
defmodule Congas do
  use Mx.Song, tempo: 100

  # A beat is a quarter note of 4/4, so a pass is a bar, the length of a clave, written as sixteen
  # cells to a drum; the roll is written as thirty-two.
  # The letters are the articles': H is the heel of the hand, T its tip, S a slap and O an open
  # tone; h and t are the heel and tip played softly.
  @one_drum [mid_conga: "HTSTHTOO HTSTHTOO"]
  @two_drums [mid_conga: "HTS..TOO HTSTHTOO", low_conga: "...OO... ........"]
  @two_drums_again [mid_conga: "HTS.HTOO HTS.HTOO", low_conga: "...O.... ...O...."]

  # The lock is the quinto's own; which strokes are tones and which are slaps, and the strokes
  # doubled and left out, are written for mx.
  @lock [".O..S..S ...O.O..", ".S..O..O ...S.S.."]
  @varied [".OO.S..S S..O.O..", ".S..O..O ...SS..."]
  @cross [".S..S..S ..S..S..", "S..S..S. .S..S..S", "..S..S.. S..S..S."]

  # The phrase that ends on the sixteenth after the third beat is written for mx.
  @resolution "..O.OO.S .O......"

  # The tumba is the quietest of the three drums and the conga the loudest, so each plays at the
  # level that brings their open tones together.
  part :low_conga, synth: :low_conga, defaults: [amp: 1.4]
  part :mid_conga, synth: :mid_conga, defaults: [amp: 0.35]
  part :high_conga, synth: :high_conga, defaults: [amp: 0.55]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a bar.
  defp form do
    for cells <- bars() do
      together(
        for drum <- [:low_conga, :mid_conga, :high_conga] do
          part(drum, bar(Keyword.get(cells, drum, "")))
        end
      )
    end
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
          mid_conga: "hthththt hthtHTHT HTHTHTHT ....O...",
          high_conga: "........ ....OO..",
          low_conga: "........ .......O"
        ],
        @two_drums,
        @two_drums,
        [
          mid_conga: "HTSTHTOO HTS.....",
          high_conga: "........ ...OO.O.",
          low_conga: "........ .....O.O"
        ],
        [high_conga: "S", low_conga: "O"]
      ]
  end

  # A bar of one drum, as 4 beats.
  defp bar(cells) do
    letters = cells |> String.replace(" ", "") |> String.graphemes()
    per_beat = length(letters) / 4

    hits =
      for {letter, index} <- Enum.with_index(letters), letter != "." do
        beat = index / per_beat
        {beat, hit(stroke(letter))}
      end

    if hits == [], do: rest(4), else: at(hits, 4)
  end

  # mx's conga has no stroke of the heel, so the heel is a soft tone, low as the palm's stroke is.
  # The tip is a muted stroke, far quieter than a tone, as on the recordings, so it plays at twice
  # the conga's level.
  defp stroke("H"), do: [vel: 0.35]
  defp stroke("T"), do: [vel: 0.4, mute: 1, amp: 0.7]
  defp stroke("h"), do: [vel: 0.2]
  defp stroke("t"), do: [vel: 0.25, mute: 1, amp: 0.7]
  defp stroke("S"), do: [vel: 0.9, slap: 1]
  defp stroke("O"), do: [vel: 0.9]
end
