defmodule Meditation do
  @moduledoc """
  A meditation in raga Bhupali, the five notes Sa, Re, Ga, Pa and Dha, on Sa D.
  A beat is a matra and a pass is one cycle of teentaal's 16, about 16 seconds at 60 bpm.
  """

  use Mx.Song, tempo: 60

  part :flute,
    synth: :flute,
    defaults: [vibrato: 0.1, pan: 0.1, amp: 2.2],
    fx: [reverb: [decay_seconds: 4, mix: 0.4, amp: 0.84]]

  part :tanpura,
    synth: :harp,
    defaults: [pan: -0.3],
    fx: [reverb: [decay_seconds: 5.1, mix: 0.45]]

  part :shruti, synth: :organ, fx: [reverb: [decay_seconds: 5.1, mix: 0.5]]

  part :bells,
    synth: :vibraphone,
    defaults: [pan: -0.2],
    fx: [reverb: [decay_seconds: 5.1, mix: 0.5]]

  part :chikari,
    synth: :harp,
    defaults: [pan: 0.35],
    fx: [reverb: [decay_seconds: 3.2, mix: 0.35]]

  part :dayan,
    synth: :high_bongo,
    defaults: [note: 62, pan: 0.25, amp: 2.7],
    fx: [reverb: [decay_seconds: 1.8, mix: 0.25]]

  part :bayan,
    synth: :low_bongo,
    defaults: [note: 50, pan: 0.15, amp: 4.4],
    fx: [reverb: [decay_seconds: 1.8, mix: 0.25]]

  part :ganza, synth: :ganza, defaults: [pan: 0.45]

  part :sam,
    synth: :glockenspiel,
    defaults: [pan: -0.1],
    fx: [reverb: [decay_seconds: 5.1, mix: 0.5]]

  # Alap opens over the drone alone, jor finds a pulse, gat brings in the tabla, and shanti
  # settles back on Sa.
  def song do
    cycles =
      for {section, count} <- [alap: 4, jor: 4, gat: 8, shanti: 2],
          time <- 0..(count - 1),
          do: cycle(section, time)

    repeat(seq(cycles))
  end

  # One cycle of a section, given how many of its cycles came before.
  defp cycle(section, time) do
    together([
      part(:flute, flute(section, time)),
      part(:tanpura, tanpura()),
      part(:shruti, shruti()),
      part(:bells, bells(section)),
      part(:chikari, chikari(section)),
      part(:dayan, dayan(section)),
      part(:bayan, bayan(section)),
      part(:ganza, ganza(section)),
      part(:sam, sam(section, time))
    ])
  end

  # The flute's unmetered lines: each token is a note and its length in beats, ~ glides into it
  # from the note before, and - rests.
  defp line(:alap, 0), do: "-:2 S:4 .D:1.5 ~S:4.5 -:4"
  defp line(:alap, 1), do: "-:1 S:1 R:1.5 ~G:4 R:1 ~S:3.5 -:4"
  defp line(:alap, 2), do: "-:1 G:1.5 P:2 ~D:1 ~P:3 G:1 R:1.5 ~G:2 -:3"
  defp line(:alap, 3), do: "-:1 P:1 D:1.5 S':5 D:1 ~P:1.5 G:1 ~R:1 ~S:3"
  defp line(:jor, 0), do: "S:1 R:1 G:2 R:1 G:1 P:2 G:1 R:1 S:2 .D:1 S:3"
  defp line(:jor, 1), do: "G:1 P:1 D:2 P:1 D:1 S':2 D:1 P:1 G:2 R:1 G:3"
  defp line(:jor, 2), do: "P:1 D:1 S':1 R':1 G':2 R':1 S':1 D:2 P:1 D:1 S':4"
  defp line(:jor, 3), do: "D:1 P:1 G:1 P:1 D:2 P:1 G:1 R:1 G:1 R:1 S:1 .D:1 S:3"
  defp line(:shanti, 0), do: "S:6 .D:1 ~S:5 -:4"
  defp line(:shanti, 1), do: "-:4 G:2 ~R:2 ~S:6 -:2"

  # The gat, a word to each matra: the words in brackets divide their matra evenly, and - holds
  # the note before.
  defp cells(:sthayi), do: ~MX"G R S [.D S] R G - [P G] D P [G R] G [P D] S' [D P] [G R]"

  defp cells(:antara), do: ~MX"P D S' - [S' R'] G' R' S' D S' [D P] G [P D] [P G] [R S] [.D S]"

  defp cells(:taan),
    do:
      ~MX"G R S [.D S] R G - [P G] [S R G P] [D S' D P] [G R S R] [G P D S'] [D P G R] [S R G P] [D S' D P] [G R S .D]"

  defp cells(:fast_taan),
    do:
      ~MX"[S R G P] [D P G R] [R G P D] [S' D P G] [G P D S'] [R' S' D P] [P D S' R'] [G' R' S' D] [S' D P G] [D P G R] [P G R S] [G R S .D] S - [P G] [G R]"

  # Three times D P G R S, the last S landing on the next cycle's sam, where shanti begins.
  defp cells(:tihai), do: ~MX"D P G R S - D P G R S - D P G R"

  defp gat(index) do
    Enum.at([:sthayi, :sthayi, :antara, :sthayi, :taan, :antara, :fast_taan, :tihai], index)
  end

  # A pass of the flute, given the section and how many of its passes came before.
  defp flute(:gat, time) do
    base = sa() + 12

    steps(cells(gat(time)), 1,
      words:
        for(name <- ~w(.D D G G' P R R' S S')a, do: {name, swara(Atom.to_string(name), base)}),
      each: fn _step, length ->
        [vel: 0.5, sustain: length * 0.85, release: min(length * 0.3, 0.3)]
      end
    )
  end

  defp flute(section, time) do
    base = sa() + 12

    tokens =
      for token <- section |> line(time) |> String.split() do
        [name, beats] = String.split(token, ":")
        {beats, _} = Float.parse(beats)
        {name, beats}
      end

    notes =
      tokens
      |> Enum.with_index()
      |> Enum.flat_map(fn {{token, beats}, index} ->
        cond do
          token == "-" ->
            [rest(beats)]

          String.starts_with?(token, "~") ->
            []

          true ->
            # One breath lasts through every note glided into after it.
            glides =
              tokens
              |> Enum.drop(index + 1)
              |> Enum.take_while(fn {next, _} -> String.starts_with?(next, "~") end)

            held = beats + Enum.sum(Enum.map(glides, &elem(&1, 1)))

            {changes, _} =
              Enum.map_reduce(glides, beats, fn {glide, length}, at ->
                {{at, note: swara(String.trim_leading(glide, "~"), base)}, at + length}
              end)

            [
              note(swara(token, base), held,
                vel: 0.42,
                sustain: held - 0.4,
                release: 0.6,
                note_slide: 0.6,
                changes: changes
              )
            ]
        end
      end)

    seq(notes)
  end

  # The harp stands in for the tanpura: Pa below Sa, Sa twice and low Sa, plucked in turn, twice a
  # cycle.
  defp tanpura do
    strings = [swara(".P", sa()), sa(), sa(), sa() - 12]

    plucks =
      for {note, vel} <- Enum.zip(strings, [0.4, 0.35, 0.35, 0.45]),
          do: seq([note(note, 0, vel: vel, amp: 1.5), rest(1.5)])

    seq([seq(plucks), rest(2), seq(plucks), rest(2)])
  end

  # The organ's stopped flute holds Sa and Pa like a shruti box, swelling and fading once a cycle,
  # like a breath.
  defp shruti, do: note([sa(), swara("P", sa())], 16, attack: 6, sustain: 6, release: 6, amp: 1.0)

  # The vibraphone's motor turning once every four beats, on Sa and Pa, in the unmetered sections.
  defp bells(section) when section in [:alap, :shanti] do
    seq([
      note([sa() + 12, swara("P", sa() + 12)], 0, vel: 0.25, motor: 0.25, amp: 1.5),
      rest(16)
    ])
  end

  defp bells(_section), do: rest(16)

  # In jor and gat the harp's high strings keep the pulse, as a sitar's chikari strings do, strong
  # on the beat and light off it.
  defp chikari(section) when section in [:jor, :gat] do
    plucks =
      for eighth <- 0..31,
          do:
            {eighth * 0.5,
             note(sa() + 24, 0.5,
               vel: if(rem(eighth, 2) == 0, do: 0.3, else: 0.18),
               sustain: 0.3,
               release: 0.4,
               amp: 2.1
             )}

    at(plucks, 16)
  end

  defp chikari(_section), do: rest(16)

  # The bongos play teentaal's theka as a tabla would, the high drum tuned to Sa: Dha Dhin Dhin
  # Dha, twice, then Na Tin Tin Ta and Ta Dhin Dhin Dha.
  # The low drum, the bayan, rests through the khali, beats 9 to 12, as the tabla's does.
  defp theka do
    Enum.with_index(
      ~w(dha dhin dhin dha dha dhin dhin dha na tin tin ta ta dhin dhin dha),
      fn bol, beat -> {beat, bol} end
    )
  end

  defp dayan(:gat) do
    strokes =
      for {beat, bol} <- theka() do
        vel = if beat == 0, do: 0.6, else: 0.45

        # A light stroke between the beats, closed, as the fingers fill the second half of the
        # matra.
        [
          {beat, hit(vel: vel, muted: if(bol in ["dhin", "tin"], do: 1, else: 0))},
          {beat + 0.5, hit(vel: 0.2, muted: 1)}
        ]
      end

    at(List.flatten(strokes), 16)
  end

  defp dayan(_section), do: rest(16)

  defp bayan(:gat) do
    entries =
      for {beat, bol} <- theka(),
          bol in ["dha", "dhin"],
          do: {beat, hit(vel: if(beat == 0, do: 0.55, else: 0.4))}

    at(entries, 16)
  end

  defp bayan(_section), do: rest(16)

  # The ganzá shimmers in sixteenths through the gat, like ankle bells, its up strokes off the
  # beat: D is the beat's stroke, d a softer one down and u one up.
  defp ganza(:gat) do
    strokes = [D: [vel: 0.22, up: 0], d: [vel: 0.14, up: 0], u: [vel: 0.14, up: 1]]
    steps(List.duplicate(~MX"Dudu"s, 16), 0.25, strokes: strokes, amp: 1.5)
  end

  defp ganza(_section), do: rest(16)

  # A small bell on sam, the first beat of every cycle of the gat and the first of shanti.
  defp sam(section, time) when section == :gat or (section == :shanti and time == 0) do
    seq([note(sa() + 36, 0, vel: 0.5, amp: 4), rest(16)])
  end

  defp sam(_section, _time), do: rest(16)

  defp sa, do: 50

  # Each note is tuned to Sa as a just interval; a dot before it is the octave below and a quote
  # after it the octave above.
  defp swara(token, base) do
    octave =
      if String.starts_with?(token, ".") do
        -12
      else
        if(String.ends_with?(token, "'"), do: 12, else: 0)
      end

    steps = %{"S" => 1, "R" => 9 / 8, "G" => 5 / 4, "P" => 3 / 2, "D" => 5 / 3}
    Float.round(base + octave + ratio(steps[String.trim(token, ".") |> String.trim("'")]), 2)
  end
end
