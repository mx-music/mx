# Raga Yaman for tanpura, sitar and tabla, laid out as a Hindustani recital: the drone first, a
# slow alap, a jor to a pulse, and a gat with the tabla in teentaal.
# The gat is "Yaman–Trital (Madhyalay)" from V. N. Bhatkhande's Kramik Pustak Malika, second book,
# Hindi edition, Bombay 1946, printed page 33, in the public domain:
# https://archive.org/details/dsnn-hindusthani-sangeet-paddhati-kramik-pustakmalika-d/page/n48/mode/1up
# The sitar plays it as a sitarist would: each pluck rings until the next, the other notes of a
# matra, its grace notes and its glides are fingered on the ringing string,
# and the chikari, the high strings tuned to Sa, are struck between the notes.
# The tabla's dayan is tuned to Sa, its bayan bends on sam, and the three sit in a hall, the
# tanpura to the left and the tabla to the right.
defmodule Raga do
  use Mx.Song, tempo: 80

  @sa 49
  @room [reverb: [room: 0.6, mix: 0.18]]

  part :tanpura,
    synth: :tanpura,
    defaults: [amp: 0.8, pan: -0.25],
    fx: [reverb: [room: 0.8, mix: 0.3]]

  part :sitar, synth: :sitar, defaults: [sa: @sa, amp: 1.3], fx: [reverb: [room: 0.75, mix: 0.25]]

  part :chikari,
    synth: :sitar,
    defaults: [sa: @sa, amp: 0.65],
    fx: [reverb: [room: 0.75, mix: 0.25]]

  # tabla_na rings two semitones below its note, so this is the drum on Sa.
  part :tabla_na, synth: :tabla_na, defaults: [note: @sa + 14, amp: 0.7, pan: 0.25], fx: @room
  part :tabla_tun, synth: :tabla_tun, defaults: [note: @sa + 12, amp: 0.7, pan: 0.25], fx: @room
  part :tabla_ghe, synth: :tabla_ghe, defaults: [amp: 0.55, pan: 0.2], fx: @room

  def song do
    passes =
      for {section, count} <- [alap: 6, jor: 3, gat: 7],
          time <- 0..(count - 1),
          do: pass(section, time)

    repeat(seq(passes))
  end

  # A pass of a section, given how many of its passes came before.
  defp pass(section, time) do
    together([
      part(:tanpura, tanpura(section, time)),
      part(:sitar, sitar(section, time)),
      part(:chikari, chikari_strokes(section, time)),
      part(:tabla_na, tabla(section, :tabla_na)),
      part(:tabla_tun, tabla(section, :tabla_tun)),
      part(:tabla_ghe, tabla(section, :tabla_ghe))
    ])
  end

  # The drone sounds from the first beat through the whole recital.
  defp tanpura(:alap, 0), do: note(@sa, 16, vel: 0.5, gap: 1, sustain: length())
  defp tanpura(_section, _time), do: rest(16)

  # A pass of the sitar, given the section and how many of its passes came before.
  defp sitar(:alap, time) do
    tokens =
      for token <- String.split(alap(time)) do
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
            glides =
              tokens
              |> Enum.drop(index + 1)
              |> Enum.take_while(fn {next, _} -> String.starts_with?(next, "~") end)

            held = beats + Enum.sum(Enum.map(glides, &elem(&1, 1)))

            {changes, _} =
              Enum.map_reduce(glides, beats, fn {glide, length}, at ->
                {{at, note: swara(String.trim_leading(glide, "~"))}, at + length}
              end)

            [
              note(swara(token), held,
                vel: 0.6,
                sustain: held,
                release: 0.3,
                note_slide: 0.6,
                changes: changes
              )
            ]
        end
      end)

    seq(notes)
  end

  defp sitar(:jor, time) do
    notes =
      time
      |> jor()
      |> Enum.with_index()
      |> Enum.reduce([], fn
        {"-", _}, [{beat, note, held} | rest] -> [{beat, note, held + 1} | rest]
        {note, beat}, notes -> [{beat, note, 1} | notes]
      end)

    entries =
      for {beat, note, held} <- notes,
          do: {beat, note(swara(note), held, vel: 0.6, sustain: held, release: 0.1)}

    at(entries, 16)
  end

  defp sitar(:gat, time) do
    start = time * 16

    notes =
      for {beat, note, length, changes} <- plucks(), beat >= start and beat < start + 16 do
        changes =
          for {offset, to, slide} <- changes, do: {offset, note: swara(to), note_slide: slide}

        {beat - start,
         note(swara(note), length,
           vel: 0.6,
           sustain: length,
           release: 0.1,
           note_slide: 0,
           changes: changes
         )}
      end

    at(notes, 16)
  end

  # The alap unfolds the raga slowly from Sa, below it first, then up through the book's
  # characteristic phrase of Yaman, .N R G, R S, to the upper Sa and back:
  # each token is a note and its beats, ~ glides into it on the same pluck, and - rests.
  defp alap(0), do: "S:6 .N:2 ~S:4 -:4"
  defp alap(1), do: ".N:2 .D:2 ~.N:3 R:2 ~S:5 -:2"
  defp alap(2), do: ".N:1.5 R:1.5 ~G:4 R:2 ~S:5 -:2"
  defp alap(3), do: "G:3 R:1 ~G:2 M:2 ~G:3 R:1.5 ~S:3.5"
  defp alap(4), do: ".N:1 R:1 G:1 M:1 ~P:4 M:1.5 ~G:2 R:1.5 ~S:3"
  defp alap(5), do: "G:1 M:1 D:1 N:1 ~S':4 N:1 ~D:1 P:1 M:1 ~G:1 R:1 ~S:2"

  # The jor plucks the raga's notes to a steady beat, as the book's ascent .N R G M P D N S' and
  # descent S' N D P M G R S go, and - lets a note ring on.
  defp jor(0), do: ~w(S - .N R G - R S .N R G M G R S -)
  defp jor(1), do: ~w(.N R G M P - M G R G M D P M G R)
  defp jor(2), do: ~w(G M D N S' - N D P M G R G R S -)

  # The gat as the book notates it, one cell to each matra from khali, its ninth matra the first
  # sam:
  # a cell's notes divide its matra evenly, - holds the note before, ^ marks a grace note played
  # just before the beat,
  # ~ glides into a note on the same pluck, and a note in brackets, which the book ornaments,
  # plays plainly.
  defp sthayi do
    [
      [
        "S R",
        "G M",
        "P D",
        "N S'",
        "N D",
        "P M",
        "G R",
        "S S",
        "P",
        "-",
        "~G",
        "^P M P D",
        "P",
        "^G R",
        "-",
        "R"
      ],
      [
        "^N S'",
        "(S')",
        "-",
        "^D N N",
        "(P)",
        "-",
        "^P M P",
        "D N",
        "S'",
        "^G R",
        "-",
        "P",
        "^G R",
        "^R .N",
        "R",
        "S"
      ]
    ]
  end

  defp antara do
    [
      [
        "^M P",
        "-",
        "S'",
        "S'",
        "^N S'",
        "R'",
        "S'",
        "-",
        "^N S'",
        "R' S'",
        "R'",
        "G' R'",
        "(S')",
        "^D N",
        "(P)",
        "P"
      ],
      [
        "^P S'",
        "(S')",
        "-",
        "N - D N",
        "(P)",
        "-",
        "^P M P",
        "D N",
        "S'",
        "^G R",
        "-",
        "P",
        "^G R",
        "^R .N",
        "R",
        "S"
      ]
    ]
  end

  defp matras, do: List.flatten(sthayi() ++ antara() ++ sthayi())

  # The gat's matras from the first gat pass's sam, the book's first matra falling on khali, beat
  # 9; the last Sa rings to the end of the cycle.
  defp cells, do: Enum.with_index(matras() ++ List.duplicate("-", 8), 8)

  # Each note of a matra as {kind, beat, note}: the first is plucked, the others are fingered or
  # glided into, and a grace note is plucked just before the beat.
  defp strokes do
    Enum.flat_map(cells(), fn {cell, matra} ->
      tokens = cell |> String.replace(["(", ")"], "") |> String.split()
      {graces, notes} = Enum.split_with(tokens, &String.starts_with?(&1, "^"))
      step = 1 / length(notes)

      Enum.map(graces, &{:grace, matra - 0.12, String.trim_leading(&1, "^")}) ++
        for {note, index} <- Enum.with_index(notes), note != "-" do
          cond do
            String.starts_with?(note, "~") ->
              {:glide, matra + index * step, String.trim_leading(note, "~")}

            index == 0 ->
              {:pluck, matra, note}

            true ->
              {:finger, matra + index * step, note}
          end
        end
    end)
  end

  # The gat's plucks as {beat, note, length, changes}, each change {offset, note, slide} moving
  # the ringing string.
  # A grace note's pluck moves on to the note it ornaments, and a note fingered again at the pitch
  # the string already sounds is plucked again.
  defp plucks do
    starts =
      strokes()
      |> Enum.reduce([], fn
        {:pluck, beat, note}, [{start, first, [], _} | rest] when beat - start < 0.2 ->
          [{start, first, [{Float.round((beat - start) / 1, 3), note, 0.03}], note} | rest]

        {kind, beat, note}, [{start, first, changes, current} | rest]
        when kind in [:finger, :glide] and note != current ->
          slide = if kind == :glide, do: 0.4, else: 0

          [
            {start, first, changes ++ [{Float.round((beat - start) / 1, 3), note, slide}], note}
            | rest
          ]

        {_kind, beat, note}, plucks ->
          [{beat, note, [], note} | plucks]
      end)
      |> Enum.reverse()

    ends = Enum.map(Enum.drop(starts, 1), &elem(&1, 0)) ++ [8 + length(cells())]

    Enum.zip_with(starts, ends, fn {start, note, changes, _}, next ->
      {start, note, Float.round((next - start) / 1, 3), changes}
    end)
  end

  defp chikari_strokes(section, time) do
    entries =
      for beat <- chikari(section, time * 16),
          do: {beat, note([@sa + 12, @sa + 24], 0.3, vel: 0.4, sustain: 0.3, release: 0.3)}

    at(entries, 16)
  end

  # The chikari's beats in a gat pass: halfway through each matra the book holds.
  defp chikari(:gat, start) do
    for {"-", matra} <- cells(), matra >= start and matra < start + 16, do: matra - start + 0.5
  end

  defp chikari(:jor, _start), do: Enum.map(0..15, &(&1 + 0.5))
  defp chikari(:alap, _start), do: []

  # A pass of one tabla stroke; on sam the bayan glides up two semitones as the heel presses the
  # head.
  defp tabla(:gat, synth) do
    entries =
      for {bol, beat} <- Enum.with_index(theka()), synth in strokes(bol) do
        vel = tabla_vel(bol, beat)

        if synth == :tabla_ghe and beat == 0 do
          {beat, hit(vel: vel, note_slide: 0.5, changes: [{0, note: 44.25}])}
        else
          {beat, hit(vel: vel)}
        end
      end

    at(entries, 16)
  end

  defp tabla(_section, _synth), do: rest(16)

  # Teentaal's theka in the gat, a bol to each beat from sam: dha is na over ghe and dhin tun over
  # ghe, and the khali, beats 9 to 12, leaves the bayan out.
  defp theka, do: ~w(dha dhin dhin dha dha dhin dhin dha na tin tin na ta dhin dhin dha)

  defp strokes("dha"), do: [:tabla_na, :tabla_ghe]
  defp strokes("dhin"), do: [:tabla_tun, :tabla_ghe]
  defp strokes("tin"), do: [:tabla_tun]
  defp strokes(_bol), do: [:tabla_na]

  # Sam is struck hardest, the khali lightest, and the strokes that bring the bayan back lead to
  # the next sam.
  defp tabla_vel(_bol, 0), do: 0.85
  defp tabla_vel("dhin", _beat), do: 0.5
  defp tabla_vel("tin", _beat), do: 0.45
  defp tabla_vel("na", _beat), do: 0.55
  defp tabla_vel(_bol, _beat), do: 0.65

  # The song's length in beats, for the drone to hold through.
  defp length, do: 16 * 16

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
    Float.round(@sa + octave + cents(steps[name]), 2)
  end
end
