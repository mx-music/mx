import Mx

# Raga Yaman for tanpura, sitar and tabla, laid out as a Hindustani recital: the drone first, a slow alap, a jor to a pulse, and a gat with the tabla in teentaal.
# The gat is "Yaman–Trital (Madhyalay)" from V. N. Bhatkhande's Kramik Pustak Malika, second book, Hindi edition, Bombay 1946, printed page 33, in the public domain:
# https://archive.org/details/dsnn-hindusthani-sangeet-paddhati-kramik-pustakmalika-d/page/n48/mode/1up
# The sitar plays it as a sitarist would: each pluck rings until the next, the other notes of a matra, its grace notes and its glides are fingered on the ringing string,
# and the chikari, the high strings tuned to Sa, are struck between the notes.
defmodule Raga do
  import Mx

  def sa, do: 49

  # The song's length in beats, for the drone to hold through.
  def length, do: 16 * 16

  # Each note's cents above Sa, as just intervals; M is the sharp Ma, a dot before a note is the octave below and a quote after it the octave above.
  def swara(token) do
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

  # The alap unfolds the raga slowly from Sa, below it first, then up through the book's characteristic phrase of Yaman, .N R G, R S, to the upper Sa and back:
  # each token is a note and its beats, ~ glides into it on the same pluck, and - rests.
  def alap(0), do: "S:6 .N:2 ~S:4 -:4"
  def alap(1), do: ".N:2 .D:2 ~.N:3 R:2 ~S:5 -:2"
  def alap(2), do: ".N:1.5 R:1.5 ~G:4 R:2 ~S:5 -:2"
  def alap(3), do: "G:3 R:1 ~G:2 M:2 ~G:3 R:1.5 ~S:3.5"
  def alap(4), do: ".N:1 R:1 G:1 M:1 ~P:4 M:1.5 ~G:2 R:1.5 ~S:3"
  def alap(5), do: "G:1 M:1 D:1 N:1 ~S':4 N:1 ~D:1 P:1 M:1 ~G:1 R:1 ~S:2"

  # The jor plucks the raga's notes to a steady beat, as the book's ascent .N R G M P D N S' and descent S' N D P M G R S go, and - lets a note ring on.
  def jor(0), do: ~w(S - .N R G - R S .N R G M G R S -)
  def jor(1), do: ~w(.N R G M P - M G R G M D P M G R)
  def jor(2), do: ~w(G M D N S' - N D P M G R G R S -)

  # The gat as the book notates it, one cell to each matra from khali, its ninth matra the first sam:
  # a cell's notes divide its matra evenly, - holds the note before, ^ marks a grace note played just before the beat,
  # ~ glides into a note on the same pluck, and a note in brackets, which the book ornaments, plays plainly.
  def sthayi do
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

  def antara do
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

  def matras, do: List.flatten(sthayi() ++ antara() ++ sthayi())

  # The gat's matras from the first gat pass's sam, the book's first matra falling on khali, beat 9; the last Sa rings to the end of the cycle.
  def cells, do: Enum.with_index(matras() ++ List.duplicate("-", 8), 8)

  # Each note of a matra as {kind, beat, note}: the first is plucked, the others are fingered or glided into, and a grace note is plucked just before the beat.
  def strokes do
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

  # The gat's plucks as {beat, note, length, changes}, each change {offset, note, slide} moving the ringing string.
  # A grace note's pluck moves on to the note it ornaments, and a note fingered again at the pitch the string already sounds is plucked again.
  def plucks do
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

  # The chikari's beats in a gat pass: halfway through each matra the book holds.
  def chikari(:gat, start) do
    for {"-", matra} <- cells(), matra >= start and matra < start + 16, do: matra - start + 0.5
  end

  def chikari(:jor, _start), do: Enum.map(0..15, &(&1 + 0.5))
  def chikari(:alap, _start), do: []

  # Teentaal's theka in the gat, a bol to each beat from sam: dha is na over ghe and dhin tun over ghe, and the khali, beats 9 to 12, leaves the bayan out.
  def theka, do: ~w(dha dhin dhin dha dha dhin dhin dha na tin tin na ta dhin dhin dha)

  def strokes("dha"), do: [:tabla_na, :tabla_ghe]
  def strokes("dhin"), do: [:tabla_tun, :tabla_ghe]
  def strokes("tin"), do: [:tabla_tun]
  def strokes(_bol), do: [:tabla_na]

  def theka_beats(synth) do
    for {bol, beat} <- Enum.with_index(theka()), synth in strokes(bol), do: beat
  end

  # The drone sounds from the first beat through the whole recital.
  def tanpura(:alap, 0), do: note(sa(), 16, vel: 0.5, gap: 1, sustain: length())
  def tanpura(_section, _time), do: rest(16)

  # A pass of the sitar, given the section and how many of its passes came before.
  def sitar(:alap, time) do
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

  def sitar(:jor, time) do
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

  def sitar(:gat, time) do
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

  def chikari_strokes(section, time) do
    entries =
      for beat <- chikari(section, time * 16),
          do: {beat, note([sa() + 12, sa() + 24], 0.3, vel: 0.4, sustain: 0.3, release: 0.3)}

    at(entries, 16)
  end

  def tabla(:gat, synth, accent) do
    entries =
      for beat <- theka_beats(synth),
          do: {beat, hit(vel: if(beat == 0, do: accent, else: 0.6))}

    at(entries, 16)
  end

  def tabla(_section, _synth, _accent), do: rest(16)

  def form do
    for {section, count} <- [alap: 6, jor: 3, gat: 7], time <- 0..(count - 1) do
      together([
        part(:tanpura, tanpura(section, time), synth: :tanpura, defaults: [amp: 0.5]),
        part(:sitar, sitar(section, time), synth: :sitar, defaults: [sa: 49]),
        part(:chikari, chikari_strokes(section, time),
          synth: :sitar,
          defaults: [sa: 49, amp: 0.5]
        ),
        part(:tabla_na, tabla(section, :tabla_na, 0.85), synth: :tabla_na, defaults: [amp: 0.7]),
        part(:tabla_tun, tabla(section, :tabla_tun, 0.6),
          synth: :tabla_tun,
          defaults: [amp: 0.7]
        ),
        part(:tabla_ghe, tabla(section, :tabla_ghe, 0.85),
          synth: :tabla_ghe,
          defaults: [amp: 0.7]
        )
      ])
    end
  end
end

song(tempo: 80, music: repeat(seq(Raga.form())))
