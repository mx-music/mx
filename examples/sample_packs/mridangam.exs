defmodule Tani do
  @moduledoc """
  Tani, a mridangam solo in adi tala, the cycle of eight beats, at 76 bpm, for the mridangam
  strokes Arthur Carabott recorded from Harishankar V Menon, shared under Creative Commons
  Attribution-ShareAlike.
  It follows the order of a solo in a Carnatic concert: the first lesson, tha dhi thom nam, slowly
  and then at speed, a flowing pattern that keeps the cycle, the same with the sharp chaapu
  stroke, fast rolls at eight strokes to the beat, and a korvai, a composed ending whose last
  stroke is the first beat of the next cycle.
  The korvai takes two cycles: three phrases that shrink, 16, 12 and 8 strokes long, then tha dhin
  gi na thom spread over seven strokes, three times with a gap of four.
  Each row below is spoken as a drummer speaks a rhythm, a syllable to a stroke and a dot for a
  silent one, and each syllable plays the recordings of one or two strokes.
  The recordings of each stroke are sorted here into three strengths by their level, and the first
  stroke of each beat is the strong one.
  Download them with mx samples download
  "mridangam:sounds/tha", and the same for the other
  folders named below.
  """

  use Mx.Song, tempo: 76

  # Each stroke's folder and its recordings, the softest first.
  @recordings [
    tha: {"tha", [~w(tha2-1), ~w(tha-1 tha2-2), ~w(tha2-3 tha-2 tha-3 tha2-4)]},
    thom: {"thom", [~w(thom2-1 thom-1), ~w(thom-2 thom2-2), ~w(thom2-3 thom-3 thom2-4)]},
    gumki:
      {"gumki",
       [
         ~w(gumki2-1 gumki2-2 gumki2-5 gumki-5 gumki-1 gumki2-7),
         ~w(gumki2-3 gumki2-4 gumki2-8 gumki2-6 gumki-2 gumki-6),
         ~w(gumki-4 gumki-3)
       ]},
    ta: {"ta", [~w(ta2-1), ~w(ta-1 ta2-2 ta-2), ~w(ta2-3 ta2-4 ta2-6 ta-3 ta2-5)]},
    ki: {"ki", [~w(ki2-1 ki2-2), ~w(ki2-4 ki-1 ki-2 ki-3 ki2-3)]},
    dhi: {"dhi", [~w(dhi2-1), ~w(dhi-1 dhi2-2), ~w(dhi-2 dhi-3 dhi2-3 dhi2-4)]},
    nam: {"nam", [~w(nam2-1 nam-1), ~w(nam2-2 nam2-3 nam-2), ~w(nam2-4 nam-3 nam2-5)]},
    dhin: {"dhin", [~w(dhin2-1 dhin-1 dhin2-2), ~w(dhin2-3 dhin2-4 dhin2-5 dhin-3 dhin-2)]},
    na: {"na", [~w(na2-1 na-6), ~w(na2-5 na-2 na-3 na-4 na2-4), ~w(na-7 na2-2 na-5 na-1 na2-3)]},
    dhum: {"dhum", [~w(dhum2-1 dhum-1), ~w(dhum2-2 dhum-2 dhum2-4), ~w(dhum2-3 dhum-3)]},
    chaapu:
      {"c",
       [
         ~w(chaapu2-7 chaapu2-6 chaapu2-1),
         ~w(chaapu2-2 chaapu2-3 chaapu-1 chaapu-2),
         ~w(chaapu2-4 chaapu-3 chaapu2-9 chaapu2-5 chaapu-4 chaapu2-8)
       ]}
  ]

  # The left head's strokes sit to the left, the right head's to the right.
  @left [:tha, :thom, :gumki]

  @strokes (for {stroke, {folder, strengths}} <- @recordings do
              files =
                for {names, strength} <- Enum.with_index(strengths, 1),
                    {name, take} <- Enum.with_index(names, 1) do
                  {{:mridangam, "sounds/#{folder}/#{name}.wav"}, strength: strength, take: take}
                end

              pan = if stroke in @left, do: -0.3, else: 0.25
              level = if stroke == :gumki, do: 3.0, else: 0.9

              {stroke,
               [
                 synth: sampled(files),
                 defaults: [sustain: 4, release: 2],
                 fx: [
                   level: [amp: level],
                   reverb: [decay_seconds: 1.2, mix: 0.12],
                   pan: [pan: pan]
                 ]
               ]}
            end)

  # The strokes each spoken syllable plays.
  @syllables %{
    "tha" => [:tha],
    "thom" => [:thom],
    "tham" => [:nam, :thom],
    "dheem" => [:dhin, :thom],
    "jha" => [:chaapu, :thom],
    "gu" => [:gumki],
    "ka" => [:ki],
    "ki" => [:ki],
    "gi" => [:ki],
    "ta" => [:ta],
    "mi" => [:ta],
    "dhi" => [:dhi],
    "nam" => [:nam],
    "na" => [:nam],
    "dhin" => [:dhin],
    "nu" => [:na],
    "jo" => [:dhum],
    "cha" => [:chaapu]
  }

  @flow "tham dhin dhin nam tha dhin dhin nam tham dhin dhin nam tha dhin dhin nam"
  @bent "gu dhin dhin nam tha dhin dhin nam gu dhin gu nam tha dhin dhin nam"
  @turn "tham dhin dhin nam tha dhin dhin nam tha ka dhi mi tha ka jo nu"

  @sharp "jha . nam cha . nam cha . jha . nam cha tha ka jo nu"

  @roll "nam . ki ta tha ka dhin . ki ta tha ka jo nu tha ka"
  @stop "ki ta tha ka ki ta tha ka dhin . dhin . jha . . ."

  part :tha, @strokes[:tha]
  part :thom, @strokes[:thom]
  part :gumki, @strokes[:gumki]
  part :ta, @strokes[:ta]
  part :ki, @strokes[:ki]
  part :dhi, @strokes[:dhi]
  part :nam, @strokes[:nam]
  part :dhin, @strokes[:dhin]
  part :na, @strokes[:na]
  part :dhum, @strokes[:dhum]
  part :chaapu, @strokes[:chaapu]

  def song do
    seq([lesson(), flow(), chaapu(), rolls(), korvai()])
  end

  # The first lesson, a stroke to every half beat and softly, then at speed.
  defp lesson do
    slow = List.duplicate("tha . dhi . thom . nam .", 4)
    fast = List.duplicate("tha dhi thom nam", 8)
    seq([say(slow, 4, 0.25, 0.5), say(fast)])
  end

  # Four cycles of the pattern that keeps the tala, the second pair with the left hand bending the
  # bass.
  defp flow do
    say([@flow, @flow, @flow, @turn, @bent, @bent, @bent, @turn])
  end

  # Two cycles on the chaapu in threes and twos, ending in tha dhin gi na thom three times, the
  # last thom the first stroke of the rolls.
  defp chaapu do
    say([@sharp, @sharp, @sharp, "tha dhin gi na thom . tha dhin gi na thom . tha dhin gi na"])
  end

  # Two cycles of rolls, eight strokes to the beat.
  defp rolls do
    first = String.replace_prefix(@roll, "nam", "tham")
    say([first, @roll, @roll, @stop, @roll, @roll, @roll, @stop], 8)
  end

  # The korvai, and the stroke it lands on left to ring.
  defp korvai do
    seq([
      say([
        "tha ka dhi mi tha ka jo nu tha dhin gi na thom . . .",
        "tha ka jo nu tha dhin gi na thom . . .",
        "tha dhin gi na thom . . .",
        "tha . dhin . gi na thom . . . .",
        "tha . dhin . gi na thom . . . .",
        "tha . dhin . gi na"
      ]),
      say("jha . . . . . . . . . . . . . . .", 4, 0.9)
    ])
  end

  # Rows spoken at so many syllables to the beat: the first of each beat strong, the rest at
  # `vel`.
  defp say(rows, per_beat \\ 4, vel \\ 0.5, strong \\ 0.9) do
    words = rows |> List.wrap() |> Enum.join(" ") |> String.split()
    beats = length(words) / per_beat

    @strokes
    |> Keyword.keys()
    |> together(fn stroke ->
      hits =
        for {word, index} <- Enum.with_index(words),
            word != ".",
            stroke in Map.fetch!(@syllables, word) do
          strength = if rem(index, per_beat) == 0, do: strong, else: vel
          {index / per_beat, hit(dyn(strength))}
        end

      part(stroke, if(hits == [], do: rest(beats), else: at(hits, beats)))
    end)
  end

  # A stroke at a strength from 0 to 1: the strength picks the recording, and the level is left
  # nearly as recorded.
  defp dyn(vel), do: [vel: vel, amp: :math.pow(vel, -0.7)]
end
