defmodule Mx.ABC do
  @moduledoc """
  Reads a tune written in ABC notation as a score for `mix mx.import`.

  A file holds one tune or several, each starting at its `X:` field.
  The tune's meter, unit note length, key and tempo come from its `M:`, `L:`, `K:` and `Q:` fields, and change where the tune changes them.
  Without `L:` the unit is an eighth note, or a sixteenth in a meter under 3/4, as ABC has it, and without `Q:` the tempo is 120 quarter notes a minute.
  Each voice a `V:` field names is a part named after the voice, and a tune without voices is one part named after its title.
  Repeats, first and second endings, ties, chords, broken rhythms and tuplets play as written, and grace notes are kept with the note they lead into.
  Chord symbols, decorations, lyrics and other text are left out, and the score counts them in `left_out` and `left_out_counts` as `:chords`, `:decorations`, `:lyrics` and `:text`.

  A song written as ABC is one tune, each part that plays notes with a pitch a voice named after the part, and a part whose notes overlap without forming chords a further voice for each overlap, named after the part and numbered.
  Lengths are written as plain and dotted note values, tied where one value does not write a note, and triplets as fractions of the unit note.
  Velocity, the pedal, each part's synth and its effects are left out, as ABC has no place for them.
  """

  alias Mx.{MusicXML, Page, Score, Song}

  @kinds [
    chords: {"chord symbol", "chord symbols"},
    decorations: {"decoration", "decorations"},
    lyrics: {"line of lyrics", "lines of lyrics"},
    text: {"piece of text", "pieces of text"}
  ]

  @whole 241_920
  @steps %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}
  @sharps ~w(F C G D A E B)
  @tonics %{
    "C" => 0,
    "G" => 1,
    "D" => 2,
    "A" => 3,
    "E" => 4,
    "B" => 5,
    "F#" => 6,
    "C#" => 7,
    "G#" => 8,
    "D#" => 9,
    "A#" => 10,
    "F" => -1,
    "Bb" => -2,
    "Eb" => -3,
    "Ab" => -4,
    "Db" => -5,
    "Gb" => -6,
    "Cb" => -7,
    "Fb" => -8
  }
  @modes [
    {"maj", 0},
    {"ion", 0},
    {"mix", -1},
    {"dor", -2},
    {"min", -3},
    {"aeo", -3},
    {"m", -3},
    {"phr", -4},
    {"loc", -5},
    {"lyd", 1}
  ]
  @alters %{"^^" => 2, "^" => 1, "=" => 0, "_" => -1, "__" => -2}

  @token ~r/\G(?:
    (?<field>\[[A-Za-z]:[^\]]*\])
    |(?<ending>\[\d+(?:[,-]\d+)*)
    |(?<bar>\[\||:\|\]|\|\]|::|:*\|+:*(?:\d+(?:[,-]\d+)*)?|:+)
    |(?<deco>![^!]*!|\+[^+\s]*\+|[~.H-Wh-w])
    |(?<text>"[^"]*")
    |(?<grace>\{[^}]*\})
    |(?<tuplet>\(\d(?::\d*)?(?::\d*)?)
    |(?<chord>\[[^\]]*\][\d\/]*-?)
    |(?<note>(?:\^\^|\^|__|_|=)?[A-Ga-g][,']*[\d\/]*-?)
    |(?<rest>[zx][\d\/]*)
    |(?<bars>Z\d*)
    |(?<broken><+|>+)
    |(?<skip>[\s()`y$*])
  )/x

  @note ~r/^(\^\^|\^|__|_|=)?([A-Ga-g])([,']*)([\d\/]*)(-?)$/

  @doc "The tunes in the ABC file at `path`, as `{:ok, [{number, title}]}` or `{:error, message}`."
  def tunes(path) when is_binary(path) do
    with {:ok, text} <- read_file(path) do
      {:ok, Enum.map(split(text), fn {number, lines} -> {number, title(lines)} end)}
    end
  end

  @doc """
  Reads the tune numbered `tune` in the ABC file at `path`, or its first tune when `tune` is nil, as a score.
  Returns `{:ok, score}` or `{:error, message}`.
  """
  def score(path, tune) when is_binary(path) do
    with {:ok, text} <- read_file(path),
         {:ok, {_number, lines}} <- pick(split(text), tune, path) do
      read_tune(lines, path)
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, _reason} -> {:error, "cannot read #{path}"}
    end
  end

  # Each tune as {number, lines}, a line as {line number, text}.
  defp split(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.with_index(1)
    |> Enum.chunk_while(
      nil,
      fn {line, index}, tune ->
        case {Regex.run(~r/^X:\s*(\d+)/, line), tune} do
          {[_, number], nil} ->
            {:cont, {String.to_integer(number), [{index, line}]}}

          {[_, number], tune} ->
            {:cont, finish(tune), {String.to_integer(number), [{index, line}]}}

          {nil, nil} ->
            {:cont, nil}

          {nil, {number, lines}} ->
            {:cont, {number, [{index, line} | lines]}}
        end
      end,
      fn
        nil -> {:cont, nil}
        tune -> {:cont, finish(tune), nil}
      end
    )
  end

  defp finish({number, lines}), do: {number, Enum.reverse(lines)}

  defp title(lines) do
    Enum.find_value(lines, fn {_index, line} ->
      case Regex.run(~r/^T:\s*(.*\S)/, line) do
        [_, title] -> title
        nil -> nil
      end
    end)
  end

  defp pick([], _tune, path), do: {:error, "#{path} holds no tune"}
  defp pick([first | _], nil, _path), do: {:ok, first}

  defp pick(tunes, number, path) do
    case List.keyfind(tunes, number, 0) do
      nil ->
        numbers = Enum.map_join(tunes, ", ", &elem(&1, 0))
        {:error, "#{path} has no tune X:#{number}; its tunes are #{numbers}"}

      tune ->
        {:ok, tune}
    end
  end

  defp read_tune(lines, path) do
    {header, body} =
      Enum.split_while(lines, fn {_index, line} -> not String.match?(line, ~r/^K:/) end)

    case body do
      [] ->
        {:error, "#{path} has a tune without a K: field"}

      [{_index, key} | body] ->
        tune =
          Enum.reduce(
            header,
            %{meter: {4, 4}, unit: nil, tempo: nil, voices: [], title: title(lines)},
            &header_field/2
          )

        state = %{
          meter: tune.meter,
          unit: tune.unit || default_unit(tune.meter),
          fifths: fifths(String.trim_leading(key, "K:")),
          tempo: tune.tempo
        }

        voices = Enum.map(tune.voices, fn {id, name} -> {id, voice(id, name, state)} end)
        acc = %{state: state, voices: voices, current: nil, counts: %{}, path: path}

        try do
          acc = body |> join_continued() |> Enum.reduce(acc, &body_line/2)
          {:ok, to_score(acc, tune)}
        catch
          {:unreadable, index, text} -> {:error, "#{path}: line #{index}: cannot read #{text}"}
        end
    end
  end

  defp header_field({_index, line}, tune) do
    case Regex.run(~r/^([A-Za-z]):\s*(.*?)\s*$/, line) do
      [_, "M", value] -> %{tune | meter: meter(value)}
      [_, "L", value] -> %{tune | unit: fraction(value)}
      [_, "Q", value] -> %{tune | tempo: tempo(value, tune.unit || default_unit(tune.meter))}
      [_, "V", value] -> %{tune | voices: tune.voices ++ [voice_field(value)]}
      _other -> tune
    end
  end

  defp meter(value) do
    case String.trim(value) do
      "C" -> {4, 4}
      "C|" -> {2, 2}
      "none" -> nil
      value -> value |> String.split(" ") |> hd() |> fraction()
    end
  end

  defp default_unit({top, bottom}) when top / bottom < 0.75, do: {1, 16}
  defp default_unit(_meter), do: {1, 8}

  # Q:1/4=90 is 90 quarter notes a minute, Q:3/8=60 60 dotted quarters, and a bare Q:90 counts
  # unit notes; text in quotes is left out.
  defp tempo(value, unit) do
    value = value |> String.replace(~r/"[^"]*"/, "") |> String.trim()

    case String.split(value, "=") do
      [beat, count] ->
        {top, bottom} = beat |> String.split(" ") |> Enum.map(&fraction/1) |> Enum.reduce(&add/2)
        bpm(count, top * 4 / bottom)

      [count] ->
        {top, bottom} = unit
        bpm(count, top * 4 / bottom)
    end
  end

  defp bpm(count, quarters) do
    case Float.parse(String.trim(count)) do
      {count, _} ->
        tempo = count * quarters
        if tempo == trunc(tempo), do: trunc(tempo), else: Float.round(tempo, 2)

      :error ->
        nil
    end
  end

  defp voice_field(value) do
    [id | rest] = value |> String.trim() |> String.split(~r/\s+/, parts: 2)

    name =
      case Regex.run(~r/(?:name|nm)="([^"]*)"/, Enum.join(rest)) do
        [_, name] when name != "" -> name
        _other -> id
      end

    {id, name}
  end

  # The key's sharps as a positive count and its flats as a negative one.
  defp fifths(value) do
    value = value |> String.trim() |> String.split(~r/\s+/) |> hd()

    case Regex.run(~r/^([A-G][#b]?)(.*)$/, value) do
      [_, tonic, mode] ->
        mode = String.downcase(mode)

        offset =
          Enum.find_value(@modes, 0, fn {name, offset} ->
            if String.starts_with?(mode, name), do: offset
          end)

        Map.get(@tonics, tonic, 0) + offset

      nil ->
        if value == "Hp", do: 2, else: 0
    end
  end

  defp voice(id, name, state) do
    %{
      id: id,
      name: name,
      measures: [],
      items: [],
      cursor: 0,
      accidentals: %{},
      ties: MapSet.new(),
      tuplet: nil,
      graces: [],
      broken: nil,
      forward: false,
      ending: nil,
      open: false,
      meter: state.meter,
      unit: state.unit,
      fifths: state.fifths
    }
  end

  # A line ending in a backslash goes on in the next.
  defp join_continued(lines) do
    Enum.chunk_while(
      lines,
      nil,
      fn {index, line}, open ->
        line = String.replace(line, ~r/%.*$/, "")

        {start, text} =
          if open, do: {elem(open, 0), elem(open, 1) <> " " <> line}, else: {index, line}

        if String.ends_with?(String.trim_trailing(text), "\\") do
          {:cont, {start, text |> String.trim_trailing() |> String.trim_trailing("\\")}}
        else
          {:cont, {start, text}, nil}
        end
      end,
      fn
        nil -> {:cont, nil}
        open -> {:cont, open, nil}
      end
    )
  end

  defp body_line({index, line}, acc) do
    cond do
      String.trim(line) == "" ->
        acc

      String.starts_with?(line, "%") ->
        acc

      match = Regex.run(~r/^([wW]):/, line) ->
        [_, _kind] = match
        count(acc, :lyrics)

      match = Regex.run(~r/^([A-Za-z]):\s*(.*?)\s*$/, line) ->
        [_, field, value] = match
        field(acc, field, value)

      true ->
        music(acc, line, index)
    end
  end

  defp count(acc, kind), do: %{acc | counts: Map.update(acc.counts, kind, 1, &(&1 + 1))}

  defp field(acc, "V", value) do
    {id, name} = voice_field(value)

    voices =
      if List.keymember?(acc.voices, id, 0) do
        acc.voices
      else
        acc.voices ++ [{id, voice(id, name, acc.state)}]
      end

    %{acc | voices: voices, current: id}
  end

  defp field(acc, "K", value), do: change(acc, :fifths, fifths(value))
  defp field(acc, "M", value), do: change(acc, :meter, meter(value))
  defp field(acc, "L", value), do: change(acc, :unit, fraction(value))
  defp field(acc, _field, _value), do: acc

  # A change in the body holds for the voice it is written in, and for voices that start after it.
  defp change(acc, key, value) do
    acc = %{acc | state: Map.put(acc.state, key, value)}

    case acc.current do
      nil -> acc
      id -> update_voice(acc, id, &Map.put(&1, key, value))
    end
  end

  defp update_voice(acc, id, fun) do
    %{
      acc
      | voices:
          List.keyreplace(
            acc.voices,
            id,
            0,
            {id, fun.(elem(List.keyfind!(acc.voices, id, 0), 1))}
          )
    }
  end

  defp music(acc, line, index) do
    acc = if acc.current == nil, do: field(acc, "V", "tune"), else: acc
    tokens(line, 0, index, acc)
  end

  defp tokens(line, at, _index, acc) when at >= byte_size(line), do: acc

  defp tokens(line, at, index, acc) do
    case Regex.run(@token, line, offset: at, capture: :all_names, return: :index) do
      nil ->
        throw(
          {:unreadable, index,
           inspect(String.slice(binary_part(line, at, byte_size(line) - at), 0, 1))}
        )

      captures ->
        {kind, {start, length}} =
          Enum.find(
            Enum.zip(
              ~w(bar bars broken chord deco ending field grace note rest skip text tuplet)a,
              captures
            ),
            fn {_kind, {start, _length}} -> start >= 0 end
          )

        text = binary_part(line, start, length)
        tokens(line, start + length, index, token(acc, kind, text))
    end
  end

  defp token(acc, :skip, _text), do: acc
  defp token(acc, :deco, _text), do: count(acc, :decorations)

  defp token(acc, :text, "\"" <> text) do
    if String.first(text) in ~w(^ _ < > @), do: count(acc, :text), else: count(acc, :chords)
  end

  defp token(acc, :field, "[" <> field) do
    [name, value] = field |> String.trim_trailing("]") |> String.split(":", parts: 2)
    field(acc, name, value)
  end

  defp token(acc, kind, text), do: update_voice(acc, acc.current, &voice_token(&1, kind, text))

  defp voice_token(voice, :grace, "{" <> text) do
    text = String.trim_trailing(text, "}")
    slash = String.starts_with?(text, "/")

    graces =
      for [note] <- Regex.scan(~r/(?:\^\^|\^|__|_|=)?[A-Ga-g][,']*/, text) do
        [_, accidental, letter, octave, _, _] = Regex.run(@note, note)
        {midi, name} = pitch(voice, accidental, letter, octave)
        %{midi: midi, name: name, slash: slash}
      end

    %{voice | graces: voice.graces ++ graces}
  end

  defp voice_token(voice, :tuplet, "(" <> text) do
    [notes | rest] = text |> String.split(":") |> Enum.map(&Integer.parse/1)
    {notes, ""} = notes
    into = Enum.at(rest, 0, :error)
    count = Enum.at(rest, 1, :error)
    into = if match?({_, ""}, into), do: elem(into, 0), else: default_into(notes, voice.meter)
    count = if match?({_, ""}, count), do: elem(count, 0), else: notes
    %{voice | tuplet: {count, into, notes}}
  end

  defp voice_token(voice, :broken, text) do
    count = String.length(text)
    {longer, shorter} = {2 * :math.pow(2, count) - 1, :math.pow(2, count)}
    factors = if String.starts_with?(text, ">"), do: {longer, 1}, else: {1, longer}
    %{voice | broken: {factors, shorter}}
  end

  defp voice_token(voice, :rest, <<_rest, length::binary>>) do
    add(voice, [], length(voice, length), false)
  end

  defp voice_token(voice, :bars, "Z" <> count) do
    count = if count == "", do: 1, else: String.to_integer(count)

    Enum.reduce(1..count, voice, fn _, voice ->
      voice
      |> add([], bar_ticks(voice), false)
      |> close_bar("|")
    end)
  end

  defp voice_token(voice, :note, note) do
    [_, accidental, letter, octave, length, tie] = Regex.run(@note, note)
    {voice, head} = head(voice, accidental, letter, octave, tie == "-")
    add(voice, [head], length(voice, length), false)
  end

  defp voice_token(voice, :chord, "[" <> chord) do
    [inside, length, tie] = Regex.run(~r/^(.*)\]([\d\/]*)(-?)$/, chord, capture: :all_but_first)

    {voice, heads} =
      ~r/(?:\^\^|\^|__|_|=)?[A-Ga-g][,']*[\d\/]*-?/
      |> Regex.scan(inside)
      |> Enum.map_reduce(voice, fn [note], voice ->
        [_, accidental, letter, octave, _length, own_tie] = Regex.run(@note, note)
        {voice, head} = head(voice, accidental, letter, octave, own_tie == "-" or tie == "-")
        {head, voice}
      end)
      |> then(fn {heads, voice} -> {voice, heads} end)

    add(voice, heads, length(voice, length), false)
  end

  defp voice_token(voice, :ending, "[" <> numbers), do: open_ending(voice, numbers)
  defp voice_token(voice, :bar, bar), do: close_bar(voice, bar)

  # ABC's defaults: 2 and 4 notes in the time of 3, 3 and 6 in the time of 2, 8 in the time of 3,
  # and 5, 7 and 9 in the time of 3 in compound meter and of 2 otherwise.
  defp default_into(notes, _meter) when notes in [2, 4, 8], do: 3
  defp default_into(notes, _meter) when notes in [3, 6], do: 2
  defp default_into(_notes, {top, _bottom}) when rem(top, 3) == 0 and top > 3, do: 3
  defp default_into(_notes, _meter), do: 2

  defp head(voice, accidental, letter, octave, tie) do
    {midi, name} = pitch(voice, accidental, letter, octave)

    voice =
      if accidental != "", do: put_accidental(voice, letter, octave, accidental), else: voice

    continues = midi in voice.ties
    {voice, %{midi: midi, name: name, tie: tie, continues: continues}}
  end

  defp put_accidental(voice, letter, octave, accidental) do
    %{voice | accidentals: Map.put(voice.accidentals, {letter, octave}, @alters[accidental])}
  end

  # A note sounds with its own accidental, or the one written before it in the bar, or the key's.
  defp pitch(voice, accidental, letter, octave) do
    step = String.upcase(letter)
    base = if letter == step, do: 4, else: 5
    octave = base + occurrences(octave, "'") - occurrences(octave, ",")

    alter =
      cond do
        accidental != "" -> @alters[accidental]
        Map.has_key?(voice.accidentals, {letter, octave}) -> voice.accidentals[{letter, octave}]
        true -> key_alter(voice.fifths, step)
      end

    midi = 12 * (octave + 1) + @steps[step] + alter

    name =
      case alter do
        -1 -> "#{String.downcase(step)}b#{octave}"
        0 -> "#{String.downcase(step)}#{octave}"
        1 -> "#{String.downcase(step)}s#{octave}"
        _double -> Score.spell(midi, voice.fifths)
      end

    {midi, name}
  end

  defp occurrences(text, char) when is_binary(text) do
    text |> String.graphemes() |> Enum.count(&(&1 == char))
  end

  defp key_alter(fifths, step) when fifths > 0 do
    if step in Enum.take(@sharps, fifths), do: 1, else: 0
  end

  defp key_alter(fifths, step) when fifths < 0 do
    if step in Enum.take(Enum.reverse(@sharps), -fifths), do: -1, else: 0
  end

  defp key_alter(_fifths, _step), do: 0

  defp length(voice, text) do
    {top, bottom} = multiply(voice.unit, fraction(text))
    div(@whole * top, bottom)
  end

  defp bar_ticks(%{meter: nil} = voice), do: max(voice.cursor, 1)
  defp bar_ticks(%{meter: {top, bottom}}), do: div(@whole * top, bottom)

  defp fraction(""), do: {1, 1}

  defp fraction(text) do
    case Regex.run(~r/^(\d*)(\/*)(\d*)$/, String.trim(text)) do
      [_, top, slashes, bottom] ->
        top = if top == "", do: 1, else: String.to_integer(top)

        bottom =
          cond do
            bottom != "" -> String.to_integer(bottom)
            slashes == "" -> 1
            true -> Integer.pow(2, String.length(slashes))
          end

        {top, bottom}

      nil ->
        {1, 8}
    end
  end

  defp multiply({top, bottom}, {other_top, other_bottom}) do
    {top * other_top, bottom * other_bottom}
  end

  defp add({top, bottom}, {other_top, other_bottom}) do
    {top * other_bottom + other_top * bottom, bottom * other_bottom}
  end

  # An item takes the time a tuplet or a broken rhythm gives it; a broken rhythm also changes the
  # item before it.
  defp add(voice, heads, ticks, _grace) do
    {ticks, tuplet} =
      case voice.tuplet do
        {count, into, notes} when count > 0 ->
          {div(ticks * into, notes), if(count > 1, do: {count - 1, into, notes})}

        _none ->
          {ticks, nil}
      end

    {voice, ticks} =
      case voice.broken do
        {{previous, next}, shorter} ->
          {stretch_last(voice, previous / shorter), round(ticks * next / shorter)}

        nil ->
          {voice, ticks}
      end

    ties = heads |> Enum.filter(& &1.tie) |> MapSet.new(& &1.midi)
    item = %{onset: voice.cursor, ticks: ticks, heads: heads, graces: voice.graces}

    %{
      voice
      | items: [item | voice.items],
        cursor: voice.cursor + ticks,
        tuplet: tuplet,
        broken: nil,
        graces: [],
        ties: ties
    }
  end

  defp stretch_last(%{items: [last | rest]} = voice, factor) do
    ticks = round(last.ticks * factor)
    %{voice | items: [%{last | ticks: ticks} | rest], cursor: last.onset + ticks}
  end

  defp stretch_last(voice, _factor), do: voice

  defp open_ending(voice, numbers) do
    numbers =
      numbers
      |> String.split(",")
      |> Enum.flat_map(fn part ->
        case String.split(part, "-") do
          [from, to] -> Enum.to_list(String.to_integer(from)..String.to_integer(to))
          [one] -> [String.to_integer(one)]
        end
      end)

    voice = if voice.open, do: stop_ending(voice), else: voice
    %{voice | ending: numbers, open: true}
  end

  # A bar line ends the bar written before it: colons before it repeat back, colons after it
  # start a repeat, and a number after it starts an ending, which a double bar, a repeat sign or
  # the next ending ends.
  defp close_bar(voice, bar) do
    backward = String.starts_with?(bar, ":")
    forward = String.ends_with?(bar, ":") or bar == "::"
    backward = backward or bar == "::"
    ending = Regex.run(~r/(\d+(?:[,-]\d+)*)$/, bar, capture: :all_but_first)
    stops = backward or forward or ending != nil or String.contains?(bar, ["||", "]", "[|"])

    voice = end_measure(voice, backward, stops)
    voice = if forward, do: %{voice | forward: true}, else: voice

    case ending do
      [numbers] -> open_ending(voice, numbers)
      nil -> voice
    end
  end

  defp end_measure(voice, backward, stops) do
    if voice.items == [] and voice.cursor == 0 do
      voice
      |> then(&if(backward, do: mark_last(&1, :backward, 2), else: &1))
      |> then(&if(stops and &1.open and &1.ending == nil, do: stop_ending(&1), else: &1))
    else
      measure = measure(voice, if(backward, do: 2))

      voice = %{
        voice
        | measures: [measure | voice.measures],
          items: [],
          cursor: 0,
          accidentals: %{},
          forward: false,
          ending: nil
      }

      if stops and voice.open, do: stop_ending(voice), else: voice
    end
  end

  defp mark_last(%{measures: [last | rest]} = voice, key, value) do
    %{voice | measures: [Map.put(last, key, value) | rest]}
  end

  defp mark_last(voice, _key, _value), do: voice

  defp stop_ending(voice), do: %{mark_last(voice, :ending_stops, true) | open: false}

  defp measure(voice, backward) do
    notes =
      voice.items
      |> Enum.reverse()
      |> Enum.flat_map(fn item ->
        Enum.with_index(item.heads, fn head, index ->
          %{
            onset: item.onset / @whole * 4,
            length: item.ticks / @whole * 4,
            pitch: {head.midi, head.name},
            voice: "1",
            chord: index > 0,
            staff: 1,
            tie: head.tie,
            continues: head.continues,
            graces: if(index == 0, do: item.graces, else: []),
            vel: nil
          }
        end)
      end)

    %{
      number: nil,
      notes: notes,
      dynamics: [],
      length: voice.cursor / @whole * 4,
      forward: voice.forward,
      backward: backward,
      ending: voice.ending,
      ending_stops: false,
      fifths: voice.fifths,
      meter: meter_beats(voice.meter)
    }
  end

  defp meter_beats(nil), do: nil
  defp meter_beats({top, bottom}), do: top * 4 / bottom

  defp to_score(acc, tune) do
    voices =
      for {_id, voice} <- acc.voices do
        voice = if voice.items != [], do: close_bar(voice, "|]"), else: voice
        voice = if voice.open, do: stop_ending(voice), else: voice
        %{voice | measures: Enum.reverse(voice.measures)}
      end
      |> Enum.reject(&(&1.measures == []))

    count = voices |> Enum.map(&length(&1.measures)) |> Enum.max(fn -> 0 end)
    title = tune.title
    single = length(voices) == 1

    parts =
      for voice <- voices do
        padding = List.duplicate(empty(voice), count - length(voice.measures))

        measures =
          (voice.measures ++ padding)
          |> Enum.with_index(1)
          |> Enum.map(fn {measure, number} -> %{measure | number: Integer.to_string(number)} end)

        name = if single and voice.id == "tune", do: title || "Tune", else: voice.name
        %{name: name, measures: measures, fifths: voice.fifths, tempo: acc.state.tempo || 120}
      end

    counts =
      for {kind, _words} <- @kinds,
          count = Map.get(acc.counts, kind, 0),
          count > 0,
          do: {nil, kind, count}

    %{
      Score.build(parts, title)
      | left_out: Score.left_out_lines(counts, @kinds),
        left_out_counts: counts
    }
  end

  defp empty(voice) do
    %{measure(%{voice | items: [], cursor: 0}, nil) | forward: false, ending: nil}
  end

  @doc """
  Writes the song at `path` as an ABC tune to `out`, with `time:`, `key:`, `pickup:`, `title:` and `force:` as `Mx.MusicXML.write/3` takes them.
  Returns `{:ok, %{parts: parts, left_out: left_out, notes: notes}}`, as `Mx.MusicXML.write/3` returns and with `notes` saying what ABC leaves out, or `{:error, message}`.
  """
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    with :ok <- Page.check(out, Keyword.get(opts, :force, false)),
         {:ok, song} <- Song.load(path),
         key_text = MusicXML.song_key(song, opts),
         {:ok, {fifths, _mode} = key} <- MusicXML.key(key_text),
         {:ok, {beats, type} = time} <- MusicXML.song_time(song, opts),
         {:ok, pickup} <- opts |> Keyword.get(:pickup) |> MusicXML.pickup(time),
         {:ok, parts, left_out} <- MusicXML.parts(song, path) do
      length = parts |> Enum.map(&elem(&1, 2)) |> Enum.max(fn -> 0 end)
      title = Keyword.get_lazy(opts, :title, fn -> MusicXML.title(path) end)

      {_bar, _bars, laid} =
        parts
        |> Enum.map(fn {name, notes, _, _} -> {name, notes} end)
        |> MusicXML.layout(
          time,
          length,
          pickup
        )

      voices =
        for {name, part_voices} <- laid,
            {bars, index} <- Enum.with_index(part_voices, 1),
            do: {if(index == 1, do: name, else: "#{name} #{index}"), bars}

      unit = unit_ticks(voices)
      tempo = song.tempo
      tempo = if tempo == trunc(tempo), do: trunc(tempo), else: tempo

      header = [
        "X:1\n",
        "T:#{title}\n",
        "M:#{beats}/#{type}\n",
        "L:1/#{div(96, unit)}\n",
        "Q:1/4=#{tempo}\n",
        voice_lines(voices),
        "K:#{key_name(key_text)}\n"
      ]

      body =
        for {{_name, bars}, id} <- Enum.with_index(voices, 1) do
          lines =
            bars
            |> Enum.map(&bar_text(&1, unit, fifths))
            |> Enum.chunk_every(4)
            |> Enum.map_join(" |\n", &Enum.join(&1, " | "))

          ["V:#{id}\n", lines, " |]\n"]
        end

      File.write!(out, [header, body])

      {:ok,
       %{
         parts: Enum.map(parts, fn {name, notes, _, _} -> MusicXML.summary(name, notes, key) end),
         left_out: left_out,
         notes: ["ABC leaves out velocity, the pedal, each part's synth and its effects"]
       }}
    end
  end

  defp voice_lines(voices) do
    for {{name, _bars}, id} <- Enum.with_index(voices, 1), do: ~s(V:#{id} name="#{name}"\n)
  end

  # The unit note suits the median note: a quarter, an eighth or a sixteenth, in ticks of 24 a
  # beat.
  defp unit_ticks(voices) do
    lengths =
      for {_name, bars} <- voices,
          pieces <- bars,
          {_start, notes, values, _ties} <- pieces,
          notes != nil,
          value <- values,
          do: value

    case Enum.sort(lengths) do
      [] -> 12
      sorted -> sorted |> Enum.at(div(length(sorted), 2)) |> unit()
    end
  end

  defp unit(median) when median >= 24, do: 24
  defp unit(median) when median >= 12, do: 12
  defp unit(_median), do: 6

  defp length_text(ticks, unit) do
    gcd = Integer.gcd(ticks, unit)

    case {div(ticks, gcd), div(unit, gcd)} do
      {1, 1} -> ""
      {top, 1} -> "#{top}"
      {1, 2} -> "/"
      {top, bottom} when top == 1 -> "/#{bottom}"
      {top, bottom} -> "#{top}/#{bottom}"
    end
  end

  defp key_name(text) do
    name = String.downcase(text)

    {tonic, minor} =
      if String.ends_with?(name, "m") do
        {String.trim_trailing(name, "m"), "m"}
      else
        {name, ""}
      end

    {letter, accidental} = String.split_at(tonic, 1)
    String.upcase(letter) <> String.replace(accidental, "s", "#") <> minor
  end

  # A bar's pieces, each written as its note values, tied to one another and to the next bar where
  # the note goes on; an accidental holds to the end of the bar, as ABC reads it.
  defp bar_text(pieces, unit, fifths) do
    {tokens, _accidentals} =
      Enum.flat_map_reduce(pieces, %{}, fn {_start, notes, values, {_tied_in, tied_out}},
                                           accidentals ->
        count = length(values)

        values
        |> Enum.with_index()
        |> Enum.map_reduce(accidentals, fn {ticks, index}, accidentals ->
          tie = if notes != nil and (index < count - 1 or tied_out), do: "-", else: ""
          length = length_text(ticks, unit)

          case notes do
            nil ->
              {"z" <> length, accidentals}

            [note] ->
              {pitch, accidentals} = abc_pitch(note, fifths, accidentals)
              {pitch <> length <> tie, accidentals}

            notes ->
              {pitches, accidentals} =
                Enum.map_reduce(notes, accidentals, &abc_pitch(&1, fifths, &2))

              {"[" <> Enum.join(pitches) <> "]" <> length <> tie, accidentals}
          end
        end)
      end)

    Enum.join(tokens, " ")
  end

  defp abc_pitch(note, fifths, accidentals) do
    {step, alter, octave} = MusicXML.spell(note, fifths)
    in_effect = Map.get_lazy(accidentals, {step, octave}, fn -> key_alter(fifths, step) end)

    {sign, accidentals} =
      if alter == in_effect do
        {"", accidentals}
      else
        {%{-2 => "__", -1 => "_", 0 => "=", 1 => "^", 2 => "^^"}[alter],
         Map.put(accidentals, {step, octave}, alter)}
      end

    letter =
      if octave >= 5 do
        String.downcase(step) <> String.duplicate("'", octave - 5)
      else
        step <> String.duplicate(",", 4 - octave)
      end

    {sign <> letter, accidentals}
  end
end
