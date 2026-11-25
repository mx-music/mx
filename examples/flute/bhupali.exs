defmodule Bhupali do
  @moduledoc """
  Raga Bhupali for flute and tabla, as a bansuri player lays it out: a slow alap without a beat, a
  drut gat in teentaal, taans, and a tihai landing on sam.
  The gat is built on Bhupali's pakad, G R S .D S R G, and the taans on the alankars that climb
  and fall in threes.
  Each breath is one note whose later changes move it from swara to swara, so the air runs on
  through a phrase: a tongued note dips the breath, a slurred one only moves the pitch, and a
  glide, the bansuri's meend, slides into it.
  """

  use Mx.Song, tempo: 240

  part :flute, synth: :flute
  part :tabla_na, synth: :tabla_na, defaults: [amp: 0.5]
  part :tabla_tun, synth: :tabla_tun, defaults: [amp: 0.5]
  part :tabla_ghe, synth: :tabla_ghe, defaults: [amp: 0.5]

  def song do
    repeat(
      form([:alap, :gat, :gat, :taans, :tihai, :sam], fn section ->
        together(
          flute: flute(section, 0),
          tabla_na: tabla(section, :tabla_na),
          tabla_tun: tabla(section, :tabla_tun),
          tabla_ghe: tabla(section, :tabla_ghe)
        )
      end)
    )
  end

  # A section's breaths one after another from its first beat, at the vel given.
  defp flute(:alap, _pass) do
    breaths = for {beat, vel, text} <- alap(), do: {beat, elem(breath(text, vel), 1)}
    at(breaths, 160)
  end

  defp flute(:gat, _pass), do: run(breaths(:gat), 0.6, 0, 16)

  defp flute(:taans, _pass) do
    [first, second, third, fourth, fifth] = breaths(:taans)
    seq([run([first, second, third], 0.85, 0, 24), run([fourth, fifth], 1.0, 0, 24)])
  end

  defp flute(:tihai, _pass) do
    [tihai] = breaths(:tihai)
    at([{6, elem(breath(tihai, 0.9, 12), 1)}], 16)
  end

  defp flute(:sam, _pass), do: rest(16)

  # A section's theka, every cycle of it, louder on sam; the alap has none, and the last sam only
  # its dha.
  defp tabla(:alap, _synth), do: rest(160)

  defp tabla(:sam, synth) do
    hits = if synth in strokes("dha"), do: [{0, hit(vel: 0.85)}], else: []
    at(hits, 16)
  end

  defp tabla(section, synth) do
    cycles = if section == :taans, do: 3, else: 1

    entries =
      for cycle <- 0..(cycles - 1),
          {bol, matra} <- Enum.with_index(theka()),
          synth in strokes(bol),
          do: {cycle * 16 + matra, hit(vel: if(matra == 0, do: 0.85, else: 0.6))}

    at(entries, cycles * 16)
  end

  # The alap's breaths, each token a swara and its beats: ~ glides into it, _ slurs to it, and a
  # bare swara is tongued; @ moves the breath to that vel over the swara.
  defp alap do
    [
      {0, 0.35, "S:10@0.5 _S:6@0.75 ~.D:4 ~S:10@0.4"},
      {33, 0.45, ".D:2.4 S:2.4 R:4.8@0.6 ~G:10@0.8 _R:3.2 ~S:8.8@0.45"},
      {68, 0.5, "G:3.2 P:6@0.7 ~D:8@0.85 _P:2.8 G:2.8 _R:2.8 ~S:10@0.45"},
      {107, 0.6, "P:2.4 D:2.4 S':12@1.0 D:2.4 _P:2.4 G:3.2 ~R:4 ~S:12@0.4"}
    ]
  end

  # One breath as a note: the first swara starts it and each later one is a change at its beat.
  # A tongued swara dips the breath to a quarter over about 30 ms and brings it back, at 240 beats
  # a minute.
  defp breath(text, vel, last \\ nil) do
    tokens = text |> String.split() |> Enum.map(&token/1)

    tokens =
      if last do
        List.update_at(tokens, -1, fn {kind, swara, _, _} -> {kind, swara, last, 0.5} end)
      else
        tokens
      end

    [{_, first, held, swell} | rest] = tokens
    opening = if swell, do: [{0, vel: swell, vel_slide: held}], else: []

    {changes, {_, length}} =
      Enum.flat_map_reduce(rest, {swell || vel, held}, fn {kind, swara, beats, swell},
                                                          {now, at} ->
        moves = moves(kind, swara(swara), beats, now, at)
        swells = if swell, do: [{at + 0.14, vel: swell, vel_slide: beats}], else: []
        {moves ++ swells, {swell || now, at + beats}}
      end)

    {length,
     note(swara(first), length,
       vel: vel,
       sustain: Float.round(length - 0.2, 3),
       release: 0.6,
       changes: opening ++ changes
     )}
  end

  defp run(texts, vel, start, length) do
    {notes, _} =
      Enum.map_reduce(texts, start, fn text, beat ->
        {held, note} = breath(text, vel)
        {{beat, note}, beat + held}
      end)

    at(notes, length)
  end

  # A breath's tokens from cells, each swara lasting its share of the matra.
  defp breaths(section) do
    for chunk <- String.split(matras(section), "|") do
      chunk
      |> String.split(",")
      |> Enum.flat_map(fn cell ->
        swaras = String.split(cell)
        Enum.map(swaras, &{&1, 1 / length(swaras)})
      end)
      |> Enum.reduce([], fn
        {"-", beats}, [{swara, held} | rest] -> [{swara, held + beats} | rest]
        token, tokens -> [token | tokens]
      end)
      |> Enum.reverse()
      |> Enum.map_join(" ", fn {swara, beats} -> "#{swara}:#{Float.round(beats, 3)}" end)
    end
  end

  defp strokes("dha"), do: [:tabla_na, :tabla_ghe]
  defp strokes("dhin"), do: [:tabla_tun, :tabla_ghe]
  defp strokes("tin"), do: [:tabla_tun]
  defp strokes(_bol), do: [:tabla_na]

  # Teentaal's theka, a bol to each matra from sam: dha is na over ghe, dhin tun over ghe, and the
  # khali, matras 9 to 12, leaves the bayan out.
  defp theka, do: ~w(dha dhin dhin dha dha dhin dhin dha na tin tin na ta dhin dhin dha)

  defp token(text) do
    [body | swell] = String.split(text, "@")
    [name, beats] = String.split(body, ":")
    {beats, ""} = Float.parse(beats)

    swell =
      case swell do
        [text | _] -> text |> Float.parse() |> elem(0)
        [] -> nil
      end

    case name do
      "~" <> swara -> {:glide, swara, beats, swell}
      "_" <> swara -> {:slur, swara, beats, swell}
      swara -> {:tongue, swara, beats, swell}
    end
  end

  defp moves(:tongue, note, _beats, now, at) do
    [
      {max(at - 0.12, 0), vel: now * 0.25, vel_slide: 0.08},
      {at, note: note, note_slide: 0, vel: now, vel_slide: 0.12}
    ]
  end

  defp moves(:slur, note, _beats, _now, at), do: [{at, note: note, note_slide: 0}]

  defp moves(:glide, note, beats, _now, at) do
    [{at, note: note, note_slide: min(beats * 0.5, 1.2)}]
  end

  # Each swara's cents above Sa, as just intervals; a dot before a swara is the octave below, a
  # quote after it the octave above.
  defp swara(token) do
    octave =
      cond do
        String.starts_with?(token, ".") -> -12
        String.ends_with?(token, "'") -> 12
        true -> 0
      end

    name = token |> String.trim_leading(".") |> String.trim_trailing("'")
    steps = %{"S" => 0, "R" => 204, "G" => 386, "P" => 702, "D" => 884}
    Float.round(sa() + octave + cents(steps[name]), 2)
  end

  # The gat and taans as matras, one cell to each: a cell's swaras divide its matra evenly, -
  # holds the swara before, and | takes a breath.
  defp matras(:gat), do: "G R,S .D,S R,G -,P G,D P,G R,S -|G P,D S',D P,G R,G P,D P,G R,S -"

  defp matras(:taans) do
    "S R G R,G P G P,D P D S',- -,S' D P D,P G P G,R G R S,- -|S R,G R,G P,G P,D P,D S',D S',- -|S' D,P D,P G,P G,R G,R S,.D S,- -|" <>
      "S R G P,D S' R' G',P' - - -,G' R' S' D,P G R S,- - - -|S R G R,G P G P,D P D S',R' S' D P"
  end

  # D P G R S three times from the seventh matra, its last Sa on the next sam and held there.
  defp matras(:tihai), do: "D P,G R,S -,- -,D P,G R,S -,- -,D P,G R,S"

  defp sa, do: 67
end
