import Mx

# A meditation in raga Bhupali, the five notes Sa, Re, Ga, Pa and Dha, on Sa D.
# A beat is a matra and a pass is one cycle of teentaal's 16, about 16 seconds at 60 bpm.
defmodule Meditation do
  import Mx

  def sa, do: 50

  # Each note is tuned to Sa as a just interval; a dot before it is the octave below and a quote after it the octave above.
  def swara(token, base) do
    octave =
      if String.starts_with?(token, ".") do
        -12
      else
        if(String.ends_with?(token, "'"), do: 12, else: 0)
      end

    steps = %{"S" => 1, "R" => 9 / 8, "G" => 5 / 4, "P" => 3 / 2, "D" => 5 / 3}
    Float.round(base + octave + ratio(steps[String.trim(token, ".") |> String.trim("'")]), 2)
  end

  # The flute's unmetered lines: each token is a note and its length in beats, ~ glides into it from the note before, and - rests.
  def line(:alap, 0), do: "-:2 S:4 .D:1.5 ~S:4.5 -:4"
  def line(:alap, 1), do: "-:1 S:1 R:1.5 ~G:4 R:1 ~S:3.5 -:4"
  def line(:alap, 2), do: "-:1 G:1.5 P:2 ~D:1 ~P:3 G:1 R:1.5 ~G:2 -:3"
  def line(:alap, 3), do: "-:1 P:1 D:1.5 S':5 D:1 ~P:1.5 G:1 ~R:1 ~S:3"
  def line(:jor, 0), do: "S:1 R:1 G:2 R:1 G:1 P:2 G:1 R:1 S:2 .D:1 S:3"
  def line(:jor, 1), do: "G:1 P:1 D:2 P:1 D:1 S':2 D:1 P:1 G:2 R:1 G:3"
  def line(:jor, 2), do: "P:1 D:1 S':1 R':1 G':2 R':1 S':1 D:2 P:1 D:1 S':4"
  def line(:jor, 3), do: "D:1 P:1 G:1 P:1 D:2 P:1 G:1 R:1 G:1 R:1 S:1 .D:1 S:3"
  def line(:shanti, 0), do: "S:6 .D:1 ~S:5 -:4"
  def line(:shanti, 1), do: "-:4 G:2 ~R:2 ~S:6 -:2"

  # The gat, one cell to each matra: a cell of several notes divides its matra evenly, and - holds the note before.
  def cells(:sthayi) do
    [
      "G",
      "R",
      "S",
      ".D S",
      "R",
      "G",
      "-",
      "P G",
      "D",
      "P",
      "G R",
      "G",
      "P D",
      "S'",
      "D P",
      "G R"
    ]
  end

  def cells(:antara) do
    [
      "P",
      "D",
      "S'",
      "-",
      "S' R'",
      "G'",
      "R'",
      "S'",
      "D",
      "S'",
      "D P",
      "G",
      "P D",
      "P G",
      "R S",
      ".D S"
    ]
  end

  def cells(:taan) do
    [
      "G",
      "R",
      "S",
      ".D S",
      "R",
      "G",
      "-",
      "P G",
      "S R G P",
      "D S' D P",
      "G R S R",
      "G P D S'",
      "D P G R",
      "S R G P",
      "D S' D P",
      "G R S .D"
    ]
  end

  def cells(:fast_taan) do
    [
      "S R G P",
      "D P G R",
      "R G P D",
      "S' D P G",
      "G P D S'",
      "R' S' D P",
      "P D S' R'",
      "G' R' S' D",
      "S' D P G",
      "D P G R",
      "P G R S",
      "G R S .D",
      "S",
      "-",
      "P G",
      "G R"
    ]
  end

  # Three times D P G R S, the last S landing on the next cycle's sam, where shanti begins.
  def cells(:tihai) do
    ["D", "P", "G", "R", "S", "-", "D", "P", "G", "R", "S", "-", "D", "P", "G", "R"]
  end

  def gat(index) do
    Enum.at([:sthayi, :sthayi, :antara, :sthayi, :taan, :antara, :fast_taan, :tihai], index)
  end

  # The notes of a gat part as {beat, token, length}, a held cell lengthening the note before it.
  def notes(part) do
    part
    |> cells()
    |> Enum.with_index()
    |> Enum.flat_map(fn {cell, matra} ->
      tokens = String.split(cell)

      Enum.with_index(tokens, fn token, index ->
        {matra + index / length(tokens), token, 1 / length(tokens)}
      end)
    end)
    |> Enum.reduce([], fn
      {_, "-", length}, [{beat, token, held} | rest] -> [{beat, token, held + length} | rest]
      note, notes -> [note | notes]
    end)
    |> Enum.reverse()
  end

  # A pass of the flute, given the section and how many of its passes came before.
  def flute(:gat, time) do
    base = sa() + 12

    notes =
      for {beat, token, length} <- notes(gat(time)),
          do:
            {beat,
             note(swara(token, base), length,
               vel: 0.5,
               sustain: length * 0.85,
               release: min(length * 0.3, 0.3)
             )}

    at(notes, 16)
  end

  def flute(section, time) do
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

  # The harp stands in for the tanpura: Pa below Sa, Sa twice and low Sa, plucked in turn, twice a cycle.
  def tanpura do
    strings = [swara(".P", sa()), sa(), sa(), sa() - 12]

    plucks =
      for {note, vel} <- Enum.zip(strings, [0.4, 0.35, 0.35, 0.45]),
          do: seq([note(note, 0, vel: vel, amp: 1.5), rest(1.5)])

    seq([seq(plucks), rest(2), seq(plucks), rest(2)])
  end

  # The organ's stopped flute holds Sa and Pa like a shruti box, swelling and fading once a cycle, like a breath.
  def shruti, do: note([sa(), swara("P", sa())], 16, attack: 6, sustain: 6, release: 6, amp: 1.0)

  # The vibraphone's motor turning once every four beats, on Sa and Pa, in the unmetered sections.
  def bells(section) when section in [:alap, :shanti] do
    seq([
      note([sa() + 12, swara("P", sa() + 12)], 0, vel: 0.25, motor: 0.25, amp: 1.5),
      rest(16)
    ])
  end

  def bells(_section), do: rest(16)

  # In jor and gat the harp's high strings keep the pulse, as a sitar's chikari strings do, strong on the beat and light off it.
  def chikari(section) when section in [:jor, :gat] do
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

  def chikari(_section), do: rest(16)

  # The bongos play teentaal's theka as a tabla would, the high drum tuned to Sa: Dha Dhin Dhin Dha, twice, then Na Tin Tin Ta and Ta Dhin Dhin Dha.
  # The low drum, the bayan, rests through the khali, beats 9 to 12, as the tabla's does.
  def theka do
    Enum.with_index(
      ~w(dha dhin dhin dha dha dhin dhin dha na tin tin ta ta dhin dhin dha),
      fn bol, beat -> {beat, bol} end
    )
  end

  def dayan(:gat) do
    strokes =
      for {beat, bol} <- theka() do
        vel = if beat == 0, do: 0.6, else: 0.45

        # A light stroke between the beats, closed, as the fingers fill the second half of the matra.
        [
          {beat, hit(vel: vel, muted: if(bol in ["dhin", "tin"], do: 1, else: 0))},
          {beat + 0.5, hit(vel: 0.2, muted: 1)}
        ]
      end

    at(List.flatten(strokes), 16)
  end

  def dayan(_section), do: rest(16)

  def bayan(:gat) do
    entries =
      for {beat, bol} <- theka(),
          bol in ["dha", "dhin"],
          do: {beat, hit(vel: if(beat == 0, do: 0.55, else: 0.4))}

    at(entries, 16)
  end

  def bayan(_section), do: rest(16)

  # The ganzá shimmers in sixteenths through the gat, like ankle bells, its up strokes off the beat.
  def ganza(:gat) do
    entries =
      for sixteenth <- 0..63,
          do:
            {sixteenth * 0.25,
             hit(
               vel: if(rem(sixteenth, 4) == 0, do: 0.22, else: 0.14),
               up: rem(sixteenth, 2),
               amp: 1.5
             )}

    at(entries, 16)
  end

  def ganza(_section), do: rest(16)

  # A small bell on sam, the first beat of every cycle of the gat and the first of shanti.
  def sam(section, time) when section == :gat or (section == :shanti and time == 0) do
    seq([note(sa() + 36, 0, vel: 0.5, amp: 4), rest(16)])
  end

  def sam(_section, _time), do: rest(16)

  # Alap opens over the drone alone, jor finds a pulse, gat brings in the tabla, and shanti settles back on Sa.
  def form do
    for {section, count} <- [alap: 4, jor: 4, gat: 8, shanti: 2], time <- 0..(count - 1) do
      together([
        part(:flute, flute(section, time),
          synth: :flute,
          defaults: [vibrato: 0.1, pan: 0.1, amp: 2.2],
          fx: [reverb: [room: 0.85, mix: 0.4]]
        ),
        part(:tanpura, tanpura(),
          synth: :harp,
          defaults: [pan: -0.3],
          fx: [reverb: [room: 0.9, mix: 0.45]]
        ),
        part(:shruti, shruti(), synth: :organ, fx: [reverb: [room: 0.9, mix: 0.5]]),
        part(:bells, bells(section),
          synth: :vibraphone,
          defaults: [pan: -0.2],
          fx: [reverb: [room: 0.9, mix: 0.5]]
        ),
        part(:chikari, chikari(section),
          synth: :harp,
          defaults: [pan: 0.35],
          fx: [reverb: [room: 0.8, mix: 0.35]]
        ),
        part(:dayan, dayan(section),
          synth: :high_bongo,
          defaults: [note: 62, pan: 0.25, amp: 2.7],
          fx: [reverb: [room: 0.6, mix: 0.25]]
        ),
        part(:bayan, bayan(section),
          synth: :low_bongo,
          defaults: [note: 50, pan: 0.15, amp: 4.4],
          fx: [reverb: [room: 0.6, mix: 0.25]]
        ),
        part(:ganza, ganza(section), synth: :ganza, defaults: [pan: 0.45]),
        part(:sam, sam(section, time),
          synth: :glockenspiel,
          defaults: [pan: -0.1],
          fx: [reverb: [room: 0.9, mix: 0.5]]
        )
      ])
    end
  end
end

song(tempo: 60, music: repeat(seq(Meditation.form())))
