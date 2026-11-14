# A solo for the harmonium written for mx in raga Bhairav, on Sa G: Sa, the flat Re, Ga, Ma, Pa,
# the flat Dha and Ni.
defmodule Harmonium do
  use Mx.Song, tempo: 72

  # Wikipedia gives its ascent as Sa Re Ga Ma Pa Dha Ni Sa', its descent as Sa' Ni Dha Pa Ma Ga Re
  # Sa and its pakad as Ga Ma Dha Dha Pa, Ga Ma Re Re Sa.
  # The left hand holds Sa an octave down while the right plays the ascent and descent, the pakad,
  # a phrase that dips below Sa, one high in the upper octave, and an ending on Sa.

  part :melody, synth: :harmonium
  part :sa, synth: :harmonium, defaults: [amp: 0.6]

  def song do
    repeat(seq(form()))
  end

  # The form, each section with the time it plays in a row: the ascent and descent, the melody
  # twice, the high phrase and the ending.
  defp form do
    for {section, time} <- [ascent: 0, melody: 0, melody: 1, high: 0, ending: 0] do
      together([
        part(:melody, right_hand(section, time)),
        part(:sa, left_hand())
      ])
    end
  end

  # The right hand's line, each token a note held a little short of its length.
  defp right_hand(section, time) do
    notes =
      for token <- String.split(line(section, time)) do
        [name, beats] = String.split(token, ":")
        {beats, _} = Float.parse(beats)

        note(swara(name), beats,
          vel: if(beats < 1, do: 0.5, else: 0.6),
          sustain: beats * 0.9,
          release: 0.15
        )
      end

    seq(notes)
  end

  # The left hand's Sa an octave down, held through the 16 beats.
  defp left_hand, do: note(sa() - 12, 16, vel: 0.5, sustain: 15.5, release: 0.5)

  # Each token is a note and its length in beats.
  defp line(:ascent, _), do: "S:1 r:1 G:1 M:1 P:1 d:1 N:1 S':2 N:1 d:1 P:1 M:1 G:1 r:1 S:1"
  defp line(:melody, 0), do: "G:1 M:1 d:1 d:1 P:2 G:1 M:1 r:1 r:1 S:2 .N:0.5 S:0.5 r:1 S:2"

  defp line(:melody, 1) do
    "S:0.5 r:0.5 G:0.5 M:0.5 P:2 d:0.5 P:0.5 M:0.5 G:0.5 M:2 G:0.5 M:0.5 r:1 S:1 .d:1 .N:1 S:3"
  end

  defp line(:high, _) do
    "P:1 d:1 N:1 S':1 r':1 G':1 M':2 G':0.5 r':0.5 S':1 N:1 d:1 P:1 d:0.5 N:0.5 S':2"
  end

  defp line(:ending, _), do: "G:1 M:1 d:2 P:2 G:1 M:1 r:2 S:6"

  # Each note's cents above Sa, as just intervals; r and d are the flat Re and Dha, a dot before a
  # note is the octave below and a quote after it the octave above.
  defp swara(token) do
    octave =
      cond do
        String.starts_with?(token, ".") -> -12
        String.ends_with?(token, "'") -> 12
        true -> 0
      end

    name = token |> String.trim_leading(".") |> String.trim_trailing("'")
    steps = %{"S" => 0, "r" => 112, "G" => 386, "M" => 498, "P" => 702, "d" => 814, "N" => 1088}
    Float.round(sa() + octave + cents(steps[name]), 2)
  end

  defp sa, do: 55
end
