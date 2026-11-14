# Kaida, a tabla solo in teentaal, the cycle of sixteen beats, at 84 bpm, made only of the tabla
# strokes Sonic Pi ships, which are under Creative Commons 0.
# It opens with teentaal's theka, the pattern that names the cycle, then plays the kaida every
# student of the Delhi school learns first: dha dha te te dha dha tin na, answered without the
# bass drum as ta ta te te dha dha dhin na.
# A kaida is a theme and its variations, each made only of the theme's strokes: here the theme at
# half speed, at speed, three variations, and a tihai, a phrase played three times so that its
# last dha is the first beat of the next cycle.
# Each row is spoken as a tabla player speaks it, a syllable to a stroke and a dot for a silent
# one, and each syllable plays a stroke of the small drum, of the bass drum, or of both.
defmodule Kaida do
  use Mx.Song, tempo: 84

  # Each syllable as the small drum's stroke and the bass drum's, nil where that hand rests: dha
  # is na over ghe.
  @bols %{
    "dha" => {:tabla_na, :tabla_ghe1},
    "dha~" => {:tabla_na, :tabla_ghe2},
    "dhin" => {:tabla_tun1, :tabla_ghe4},
    "tin" => {:tabla_tun2, nil},
    "ta" => {:tabla_na, nil},
    "na" => {:tabla_na_s, nil},
    "te" => {:tabla_te1, nil},
    "ge" => {nil, :tabla_ghe8}
  }

  part :dayan, fx: [level: [amp: 0.7], reverb: [room: 0.4, mix: 0.12], pan: [pan: 0.25]]
  part :bayan, fx: [level: [amp: 0.7], reverb: [room: 0.4, mix: 0.12], pan: [pan: -0.25]]

  @theka "dha dhin dhin dha dha dhin dhin dha dha tin tin ta ta dhin dhin dha"
  @filled "dha . dhin . dhin . dha~ . dha . dhin . dhin . dha te dha . tin . tin . ta . ta te dhin . dhin . dha~ ge"

  @theme [
    "dha dha te te dha dha tin na",
    "ta ta te te dha dha dhin na"
  ]

  @first [
    "dha dha te te dha dha te te dha dha te te dha dha tin na",
    "ta ta te te ta ta te te dha dha te te dha dha dhin na"
  ]

  @second [
    "dha dha te te te te dha dha dha dha te te dha dha tin na",
    "ta ta te te te te ta ta dha dha te te dha dha dhin na"
  ]

  @third [
    "te te dha dha te te dha dha dha dha te te dha dha tin na",
    "te te ta ta te te ta ta dha dha te te dha dha dhin na"
  ]

  # Nine strokes three times with gaps of three, 33 in all: the last is the first beat after its
  # eight.
  @tihai [
    "dha dha te te dha dha tin na dha . . .",
    "dha dha te te dha dha tin na dha . . .",
    "dha dha te te dha dha tin na"
  ]

  def song do
    seq([
      say(@theka, 1),
      say(@filled, 2),
      say([@theme, @theme], 2),
      say([@theme, @theme, @theme, @theme], 4),
      say([@first, @first], 4),
      say([@second, @second], 4),
      say([@third, @third], 4),
      say([@theme, @theme, @tihai], 4),
      say("dha~ . . . . . . .", 1)
    ])
  end

  # Rows spoken at so many syllables to the beat, the first of each beat the strong one.
  # Two te in a row are two strokes of different fingers, so every other one plays the second
  # recording.
  defp say(rows, per_beat) do
    words = rows |> List.wrap() |> List.flatten() |> Enum.join(" ") |> String.split()
    beats = length(words) / per_beat

    together(
      for {drum, hand} <- [dayan: 0, bayan: 1] do
        hits =
          for {word, index} <- Enum.with_index(words),
              word != ".",
              stroke = elem(Map.fetch!(@bols, word), hand),
              stroke != nil do
            stroke = if stroke == :tabla_te1 and rem(index, 2) == 1, do: :tabla_te2, else: stroke
            amp = if rem(index, per_beat) == 0, do: 1.0, else: 0.65
            {index / per_beat, sample(stroke, 0, amp: amp)}
          end

        part(drum, at(hits, beats))
      end
    )
  end
end
