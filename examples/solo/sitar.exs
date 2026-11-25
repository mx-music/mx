defmodule Sitar do
  @moduledoc """
  A solo for the sitar written for mx in raga Yaman, on Sa C sharp: Sa, Re, Ga, the sharp Ma, Pa,
  Dha and Ni.
  """

  use Mx.Song, tempo: 60

  # Wikipedia gives its ascent as N R G m P D N S', its descent as S' N D P m G R S and its pakad
  # as .N R G R S P m G R S, with Ga its most important note and Ni the next, and Sa and Pa weak
  # on the way up.
  # A slow alap with meend, glides from one note to the next on one pluck, then a gat in
  # teentaal's 16 beats, low and high on the string, with short and long notes.

  part :sitar, synth: :sitar, defaults: [sa: 49]

  # The alap's three lines, then the gat's five parts.
  def song do
    repeat(
      form([alap: 3, gat: 5], fn
        :alap, %{time: time} -> part(:sitar, alap(time))
        :gat, %{time: time} -> part(:sitar, gat(time))
      end)
    )
  end

  # An alap line as its plucks: one pluck lasts through every note glided into after it, and moves
  # to each of them as the finger slides along the fret.
  defp alap(time) do
    tokens =
      for token <- String.split(line(time)) do
        [name, beats] = String.split(token, ":")
        {beats, _} = Float.parse(beats)
        {name, beats}
      end

    {plucks, length} =
      Enum.reduce(tokens, {[], 0}, fn {token, beats}, {plucks, beat} ->
        plucks =
          cond do
            token == "-" ->
              plucks

            String.starts_with?(token, "~") ->
              [{start, pitch, held, glides} | rest] = plucks
              glide = {beat - start, note: token |> String.trim_leading("~") |> swara()}
              [{start, pitch, held + beats, glides ++ [glide]} | rest]

            true ->
              [{beat, swara(token), beats, []} | plucks]
          end

        {plucks, beat + beats}
      end)

    notes =
      for {start, pitch, held, glides} <- plucks do
        opts = [vel: 0.7, sustain: held - 0.3, release: 0.6, note_slide: 0.6]
        {start, note(pitch, held, if(glides == [], do: opts, else: opts ++ [changes: glides]))}
      end

    at(notes, length)
  end

  # A gat part's notes over teentaal's 16 beats, the short ones softer.
  defp gat(time) do
    words =
      for name <- ~w(.N D G G' M N P R R' S S')a, do: {name, name |> Atom.to_string() |> swara()}

    steps(cells(time), 1,
      words: words,
      each: fn _step, length ->
        [vel: if(length < 0.5, do: 0.5, else: 0.65), held: 0.9, release: 0.25]
      end
    )
  end

  # The alap's unmetered lines: each token is a note and its length in beats, ~ glides into it
  # from the note before on the same pluck, and - rests.
  defp line(0), do: "-:1 .N:1.5 R:1 ~G:4 R:1.5 ~S:4 -:3"
  defp line(1), do: ".N:1 R:1 G:1.5 M:1 ~P:3 M:1 ~G:2 R:1 ~S:3.5 -:1"
  defp line(2), do: "G:1 M:1 D:1.5 N:1 ~S':4 N:1 ~D:1.5 P:1.5 M:1 ~G:2.5"

  # Each note's cents above Sa, as just intervals; M is the sharp Ma, a dot before a note is the
  # octave below and a quote after it the octave above.
  defp swara(token) do
    octave =
      cond do
        String.starts_with?(token, ".") -> -12
        String.ends_with?(token, "'") -> 12
        true -> 0
      end

    name = token |> String.trim_leading(".") |> String.trim_trailing("'")
    steps = %{"S" => 0, "R" => 204, "G" => 386, "M" => 590, "P" => 702, "D" => 884, "N" => 1088}
    Float.round(sa() + octave + cents(steps[name]), 2)
  end

  defp sa, do: 49

  # The gat, a word to each beat: the words in brackets divide their beat evenly, and - holds
  # the note before.
  defp cells(0), do: ~MX"G R G M P - [M G] [R S] .N R G - [M D] [N S'] [N D] P"

  defp cells(1), do: ~MX"P [M G] M D N S' - S' [N R'] G' R' S' [N D] P [M G] [R S]"

  defp cells(2) do
    ~MX"[N R G M] [D N S' N] [D P M G] [R S .N R] [G M P M] [G R S .N] [R G M D] [N S' N D] [P M G R] [S .N R G] [M G R S] - [.N R G R] S [P M] [G R]"
  end

  defp cells(3), do: ~MX"G R G M P - [M G] [R S] .N R G - [M D] [N S'] [N D] P"

  defp cells(4), do: ~MX"G R G M P - [M G] [R S] .N R G R S - - -"
end
