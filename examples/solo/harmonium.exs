defmodule Harmonium do
  @moduledoc """
  A solo for the harmonium written for mx in raga Bhairav, on Sa G: Sa, the flat Re, Ga, Ma, Pa,
  the flat Dha and Ni.
  """

  use Mx.Song, tempo: 72

  # Wikipedia gives its ascent as Sa Re Ga Ma Pa Dha Ni Sa', its descent as Sa' Ni Dha Pa Ma Ga Re
  # Sa and its pakad as Ga Ma Dha Dha Pa, Ga Ma Re Re Sa.
  # The left hand holds Sa an octave down while the right plays the ascent and descent, the pakad,
  # a phrase that dips below Sa, one high in the upper octave, and an ending on Sa.

  part :melody, synth: :harmonium
  part :sa, synth: :harmonium, defaults: [amp: 0.6]

  # The form, each section with the time it plays in a row: the ascent and descent, the melody
  # twice, the high phrase and the ending.
  def song do
    repeat(
      form([ascent: 1, melody: 2, high: 1, ending: 1], fn section, %{time: time} ->
        together(melody: right_hand(section, time), sa: left_hand())
      end)
    )
  end

  # The right hand's line, each word a note held a little short of its length.
  defp right_hand(section, time) do
    words =
      for name <- ~w(.d .N S r G M P d N S' r' G' M')a, do: {name, swara(Atom.to_string(name))}

    steps(line(section, time), 1,
      words: words,
      each: fn _step, beats ->
        [vel: if(beats < 1, do: 0.5, else: 0.6), held: 0.9, release: 0.15]
      end
    )
  end

  # The left hand's Sa an octave down, held through the 16 beats.
  defp left_hand, do: note(sa() - 12, 16, vel: 0.5, sustain: 15.5, release: 0.5)

  # Each word is a note a beat long, or as many beats as its length.
  defp line(:ascent, _), do: ~MX"S r G M P d N S':2 N d P M G r S"
  defp line(:melody, 0), do: ~MX"G M d d P:2 G M r r S:2 .N:0.5 S:0.5 r S:2"

  defp line(:melody, 1) do
    ~MX"S:0.5 r:0.5 G:0.5 M:0.5 P:2 d:0.5 P:0.5 M:0.5 G:0.5 M:2 G:0.5 M:0.5 r S .d .N S:3"
  end

  defp line(:high, _) do
    ~MX"P d N S' r' G' M':2 G':0.5 r':0.5 S' N d P d:0.5 N:0.5 S':2"
  end

  defp line(:ending, _), do: ~MX"G M d:2 P:2 G M r:2 S:6"

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
