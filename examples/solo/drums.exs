defmodule Drums do
  @moduledoc """
  A solo for the drum kit written for mx from the kit's standard vocabulary.
  It builds the beat of James Brown's "Funky Drummer" in the steps of Ethan Hein's "Building the
  Funky Drummer beat", https://www.ethanhein.com/wp/2023/building-the-funky-drummer-beat/:
  sixteenths on the hi-hat, the kick and the backbeat, the snare's ghost notes, and the hi-hat
  opening for a sixteenth.
  Then come the rudiments, as the Percussive Arts Society's forty give them: the single paradiddle
  between the hi-hat and the snare, flams, a drag, and a single stroke roll from the snare's
  softest stroke to its hardest.
  The solo plays over the feet, the kick on one and three and the hi-hat closed on two and four:
  accents every third sixteenth for three bars, until the count meets the first beat again, on the
  snare, the high tom and down the toms; sextuplets down the drums; the toms answered by flams;
  and threes between the kick and the hands.
  The beat comes back, and the last crash rings and is choked.
  """

  use Mx.Song, tempo: 96

  @kit ~w(kick snare closed_hihat open_hihat high_tom mid_tom low_tom crash)a

  # A bar is four beats, a character to each step of a drum: a digit is a stroke from 1, the
  # softest, to 9, a dot is silence, and spaces are left out.
  # A drum's bar is written in sixteenths as 16 steps, in sextuplets as 24 and in thirty-seconds
  # as 32.
  # On the snare f is a flam, a soft stroke just before a hard one, and d a drag, two soft strokes
  # before a hard one; on the crash c is a stroke rung for three beats and then choked.
  # The open hi-hat rings for a sixteenth, until the next stroke closes it, and o is a stroke that
  # rings for an eighth.
  @hats "7353 7353 7353 7353"
  @kicks "7.7. .... ..7. .7.."
  @ghosts ".... 8..2 .2.2 8..2"

  # The whole beat: the hi-hat opens on the sixteenth before the third beat and the one after the
  # fourth.
  @beat [
    closed_hihat: "7353 735. 7353 7.53",
    open_hihat: ".... ...6 .... .6..",
    snare: @ghosts,
    kick: @kicks
  ]

  # A single paradiddle, right left right right, left right left left, with the right hand on the
  # hi-hat and the left on the snare, whose stroke on two and four is the backbeat.
  @paradiddle [closed_hihat: "5.33 .3.. 5.33 .3..", snare: ".2.. 8.22 .2.. 8.22"]

  @feet [closed_hihat: ".... 4... .... 4...", kick: "6... .... 6... ...."]

  # How long before its hard stroke a flam's soft one falls, in beats, and how far apart a drag's
  # two soft ones are.
  @grace 0.05

  part :kick, synth: :kick
  part :snare, synth: :snare, defaults: [amp: 0.5]
  part :closed_hihat, synth: :closed_hihat, defaults: [amp: 0.7]
  part :open_hihat, synth: :open_hihat, defaults: [amp: 0.5]
  part :high_tom, synth: :high_tom, defaults: [amp: 0.5]
  part :mid_tom, synth: :mid_tom, defaults: [amp: 0.5]
  part :low_tom, synth: :low_tom, defaults: [amp: 0.5]
  part :crash, synth: :crash, defaults: [amp: 0.5]

  # The form, each of its passes a bar.
  def song, do: repeat(seq(bars(), &kit_bar/1))

  # A bar of the whole kit, each drum silent where the bar gives it no pattern.
  defp kit_bar(patterns) do
    together(@kit, &part(&1, bar(&1, Keyword.get(patterns, &1, ""))))
  end

  defp bars do
    [
      [closed_hihat: @hats],
      [closed_hihat: @hats, kick: @kicks, snare: ".... 8... .... 8..."],
      [closed_hihat: @hats, kick: @kicks, snare: @ghosts],
      [crash: "8"] ++ @beat,
      @beat,
      [
        closed_hihat: "7353 735. .... ....",
        open_hihat: ".... ...6 .... ....",
        snare: ".... 8..2 46.6 ....",
        high_tom: ".... .... .... 77..",
        low_tom: ".... .... .... ..78",
        kick: "7.7. .... 7... ...."
      ],
      [crash: "8", kick: "7... .... ..7. ...."] ++ @paradiddle,
      [kick: "7..5 .... ..7. ..5."] ++ @paradiddle,
      [crash: "7", snare: "9229 2292 2922 9229"] ++ @feet,
      [snare: "22.2 2.22 .22. 22.2", high_tom: "..8. .8.. 8..8 ..8."] ++ @feet,
      [
        snare: "2.22 .22. 22.2 2.22",
        high_tom: ".8.. 8... .... ....",
        mid_tom: ".... ...8 ..8. ....",
        low_tom: ".... .... .... .9.."
      ] ++ @feet,
      [
        snare: "456456 ...... ...... ......",
        high_tom: "...... 567567 ...... ......",
        mid_tom: "...... ...... 678678 ......",
        low_tom: "...... ...... ...... 678899",
        kick: "7... 7... 7... 7..."
      ],
      [
        crash: "8",
        low_tom: "8..8 ..8. .... ....",
        high_tom: ".... .... 7.7. 8...",
        kick: "8... .... .... ..6.",
        closed_hihat: ".... 4... .... 4..."
      ],
      [low_tom: "8..8 ..8. .... ....", snare: ".... .... f..f ..f."] ++ @feet,
      [
        kick: "7..7 ..7. .7.. 7...",
        snare: ".66. .... .... ..d.",
        high_tom: ".... 77.. .... ....",
        mid_tom: ".... ...7 7... ....",
        low_tom: ".... .... ..88 ...."
      ],
      [snare: "1111 2222 2233 3344 4455 5566 6777 8899", kick: "5... 5... 5... 5..."],
      [crash: "9"] ++ @beat,
      @beat,
      @beat,
      [
        closed_hihat: "7353 735. .... ....",
        open_hihat: ".... ...6 .... ..o.",
        snare: ".... 8..2 .... f...",
        high_tom: ".... .... 77.. ....",
        low_tom: ".... .... ..77 ....",
        kick: "7.7. .... .... ...."
      ],
      [crash: "c", kick: "9", snare: "9"]
    ]
  end

  # A bar of one drum, as 4 beats.
  defp bar(drum, pattern) do
    steps = pattern |> String.replace(" ", "") |> String.graphemes()
    per_beat = length(steps) / 4

    hits =
      for {step, index} <- Enum.with_index(steps),
          step != ".",
          {offset, opts} <- strokes(drum, step) do
        beat = Float.round(index / per_beat + offset, 3)
        {beat, hit(opts)}
      end

    if hits == [], do: rest(4), else: at(hits, 4)
  end

  # The kick is mx's own, written by ear, and takes amp where the measured drums take vel; the
  # measured drums play at half their level, and the hi-hat a little above it, so strokes together
  # stay below full scale.
  defp strokes(:kick, digit), do: [{0, [amp: vel(digit) / 2]}]
  defp strokes(:snare, "f"), do: [{-@grace, [vel: 0.3]}, {0, [vel: 1]}]

  defp strokes(:snare, "d") do
    [{-2 * @grace, [vel: 0.25]}, {-@grace, [vel: 0.25]}, {0, [vel: 1]}]
  end

  defp strokes(:crash, "c"), do: [{0, [vel: 1, sustain: 3, release: 0.1]}]
  defp strokes(:open_hihat, "o"), do: [{0, [vel: 0.67, sustain: 0.5, release: 0.05]}]
  defp strokes(:open_hihat, digit), do: [{0, [vel: vel(digit), sustain: 0.25, release: 0.05]}]
  defp strokes(_drum, digit), do: [{0, [vel: vel(digit)]}]

  defp vel(digit) do
    level = String.to_integer(digit) / 9
    Float.round(level, 2)
  end
end
