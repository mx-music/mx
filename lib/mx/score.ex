defmodule Mx.Score do
  @moduledoc """
  A MusicXML score read into parts of bars, each bar a list of voices and each voice a list of notes and rests in order.

  Lengths are in quarter notes, pitches are as they sound, and each note carries the `staff` it is written on, 1 for the uppermost, and a tied note that of the note its tie starts on.
  A note led into by grace notes keeps them in order as `graces`, each with its `midi`, its `name` and whether it is `slash`ed, taking no time of its own.
  `order` lists the bars by number in the order the score plays them, its repeats and endings taken.
  `runs` is the same order cut wherever the score jumps or crosses a repeat or an ending, so it can be written as ranges.
  A score read from a MIDI file by `Mx.MIDI` gives each note the `vel` it was struck with, and holds the file's tempo changes after its first tempo in `tempos`, each as `{beat, bpm}` from the start.
  `left_out` names, a line each, what a song written from the score leaves out, and `left_out_counts` gives the same as `{part, kind, count}`, `part` being nil for the whole score.
  A MusicXML score counts its `:syllables` of text, `:slurs`, `:trills`, `:ornaments` besides trills, `:fermatas`, `:grace_notes` and `:articulations`, such as staccato.
  """

  require Record

  Record.defrecordp(
    :element,
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :xml_text,
    :xmlText,
    Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :attribute,
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  @letters %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}
  @sharps ~w(c cs d ds e f fs g gs a as b)
  @flats ~w(c db d eb e f gb g ab a bb b)
  @dynamics ~w(pppp ppp pp p mp mf f ff fff ffff)

  @musicxml_kinds [
    syllables: {"syllable of text", "syllables of text"},
    slurs: {"slur", "slurs"},
    trills: {"trill", "trills"},
    ornaments: {"other ornament", "other ornaments"},
    fermatas: {"fermata", "fermatas"},
    grace_notes: {"grace note", "grace notes"},
    articulations: {"articulation, such as staccato,", "articulations, such as staccato,"}
  ]

  defstruct title: nil,
            tempo: nil,
            tempos: [],
            parts: [],
            order: [],
            runs: [],
            left_out: [],
            left_out_counts: []

  @doc """
  Reads a compressed .mxl or an uncompressed MusicXML file, a MIDI file ending in .mid or .midi, or an ABC file, and returns `{:ok, score}` or `{:error, message}`.
  A MIDI file's notes move to the nearest `grid:`, a fraction of a whole note, 1/16 unless given.
  An ABC file, ending in .abc, gives the tune `tune:` numbers by its X: field, or its first tune.
  """
  def read(path, opts \\ []) when is_binary(path) and is_list(opts) do
    case Path.extname(path) do
      extension when extension in [".mid", ".midi"] ->
        Mx.MIDI.score(path, Keyword.get(opts, :grid, {1, 16}))

      ".abc" ->
        Mx.ABC.score(path, opts[:tune])

      _other ->
        read_musicxml(path)
    end
  end

  defp read_musicxml(path) do
    with {:ok, data} <- read_file(path),
         {:ok, xml} <- unpack(data, path),
         {:ok, root} <- parse(xml, path) do
      score(root, path)
    end
  end

  @doc "The MusicXML text of a compressed or uncompressed score, as `{:ok, xml}` or `{:error, message}`."
  def xml(path) when is_binary(path) do
    with {:ok, data} <- read_file(path), do: unpack(data, path)
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, _reason} -> {:error, "cannot read #{path}"}
    end
  end

  # A compressed score is a zip whose container names the score inside it.
  defp unpack(<<"PK", _::binary>> = data, path) do
    with {:ok, files} <- :zip.unzip(data, [:memory]),
         files = Map.new(files, fn {name, content} -> {to_string(name), content} end),
         {:ok, container} <- Map.fetch(files, "META-INF/container.xml"),
         [_, rootfile] <- Regex.run(~r/full-path="([^"]+)"/, container),
         {:ok, xml} <- Map.fetch(files, rootfile) do
      {:ok, xml}
    else
      _ -> {:error, "#{path} is not a MusicXML score"}
    end
  end

  defp unpack(data, _path), do: {:ok, data}

  defp parse(xml, path) do
    {root, _rest} =
      xml
      |> :binary.bin_to_list()
      |> :xmerl_scan.string(
        quiet: true,
        fetch_fun: fn _uri, state -> {:ok, :not_fetched, state} end
      )

    case element(root, :name) do
      :"score-partwise" -> {:ok, root}
      _other -> {:error, "#{path} is not a MusicXML score"}
    end
  catch
    :exit, _reason -> {:error, "#{path} is not a MusicXML score"}
  end

  defp score(root, path) do
    names =
      for part <- path(root, ["part-list", "score-part"]) do
        name = text(part, "part-name") || text(part, "part-abbreviation")
        {attr(part, "id"), name}
      end

    parts =
      root
      |> children("part")
      |> Enum.with_index(1)
      |> Enum.map(fn {part, index} ->
        id = attr(part, "id")
        name = names |> List.keyfind(id, 0, {id, nil}) |> elem(1)
        name = if name in [nil, ""], do: "Part #{index}", else: name
        read_part(part, name)
      end)

    case parts do
      [] ->
        {:error, "#{path} is not a MusicXML score"}

      parts ->
        title =
          text(root, "movement-title") ||
            Enum.find_value(path(root, ["work"]), &text(&1, "work-title"))

        counts = musicxml_left_out(root)
        left_out = left_out_lines(counts, @musicxml_kinds)
        {:ok, %{build(parts, title) | left_out: left_out, left_out_counts: counts}}
    end
  end

  # What a song written from the score leaves out, counted over the whole score; a trill's wavy
  # line belongs to its trill.
  defp musicxml_left_out(root) do
    all = descendants(root)
    count = fn keep -> Enum.count(all, keep) end
    marks = fn name -> all |> Enum.filter(&(name(&1) == name)) |> Enum.flat_map(&elements/1) end

    counts = [
      syllables: count.(&(name(&1) == "lyric" and child(&1, "text") != nil)),
      slurs: count.(&(name(&1) == "slur" and attr(&1, "type") == "start")),
      trills: count.(&(name(&1) == "trill-mark")),
      ornaments: Enum.count(marks.("ornaments"), &(name(&1) not in ["trill-mark", "wavy-line"])),
      fermatas: count.(&(name(&1) == "fermata")),
      grace_notes: count.(&(name(&1) == "note" and child(&1, "grace") != nil)),
      articulations: length(marks.("articulations"))
    ]

    for {kind, count} <- counts, count > 0, do: {nil, kind, count}
  end

  defp descendants(node), do: Enum.flat_map(elements(node), &[&1 | descendants(&1)])

  @doc false
  # A line for each count, its kind named in words, in the order the kinds are given.
  def left_out_lines(counts, kinds) do
    for {kind, {one, many}} <- kinds,
        {part, ^kind, count} <- counts do
      line = if count == 1, do: "1 #{one} is left out", else: "#{count} #{many} are left out"
      if part, do: "#{part}: #{line}", else: line
    end
  end

  @doc false
  # Parts read as measures, as a MusicXML score's are, into a score.
  def build([first | _] = parts, title) do
    numbers = bar_numbers(first.measures)
    lengths = bar_lengths(parts)
    parts = Enum.map(parts, &finish_part(&1, numbers, lengths))
    runs = order(first.measures, numbers)
    tempo = Enum.find_value(parts, & &1.tempo)

    %__MODULE__{title: title, tempo: tempo, parts: parts, order: Enum.concat(runs), runs: runs}
  end

  defp read_part(part, name) do
    initial = %{divisions: 1, transpose: 0, fifths: nil, tempo: nil, meter: nil, ties: %{}}

    {measures, state} =
      part
      |> children("measure")
      |> Enum.map_reduce(initial, &read_measure/2)

    %{name: name, measures: measures, fifths: state.fifths || 0, tempo: state.tempo}
  end

  defp read_measure(measure, state) do
    acc = %{
      state: state,
      cursor: 0,
      length: 0,
      last_onset: 0,
      notes: [],
      graces: %{},
      dynamics: [],
      forward: false,
      backward: nil,
      ending: nil,
      ending_stops: false
    }

    acc = Enum.reduce(elements(measure), acc, &read_child/2)

    measure = %{
      number: attr(measure, "number"),
      notes: Enum.reverse(acc.notes),
      dynamics: Enum.reverse(acc.dynamics),
      length: acc.length / acc.state.divisions,
      forward: acc.forward,
      backward: acc.backward,
      ending: acc.ending,
      ending_stops: acc.ending_stops,
      fifths: acc.state.fifths || 0,
      meter: acc.state.meter
    }

    {measure, acc.state}
  end

  defp read_child(child, acc) do
    case name(child) do
      "attributes" -> %{acc | state: read_attributes(child, acc.state)}
      "note" -> read_note(child, acc)
      "backup" -> move(acc, -number(child, "duration"))
      "forward" -> move(acc, number(child, "duration"))
      "direction" -> read_direction(child, acc)
      "sound" -> read_sound(child, acc)
      "barline" -> read_barline(child, acc)
      _other -> acc
    end
  end

  defp move(acc, by) do
    cursor = acc.cursor + by
    %{acc | cursor: cursor, length: max(acc.length, cursor)}
  end

  defp read_attributes(attributes, state) do
    divisions = number(attributes, "divisions")
    fifths = path(attributes, ["key", "fifths"]) |> List.first()
    transpose = attributes |> children("transpose") |> List.first()

    state = if divisions, do: %{state | divisions: divisions}, else: state
    state = read_time(attributes, state)

    state = put_fifths(state, fifths)

    if transpose do
      semitones = number(transpose, "chromatic") || 0
      octaves = number(transpose, "octave-change") || 0
      %{state | transpose: trunc(semitones + 12 * octaves)}
    else
      state
    end
  end

  # The key of a part is its first key signature.
  defp put_fifths(%{fifths: nil} = state, fifths) when fifths != nil do
    %{state | fifths: String.to_integer(content(fifths))}
  end

  defp put_fifths(state, _fifths), do: state

  # A time signature's length in quarter notes, with its beats summed when written as 3+2.
  defp read_time(attributes, state) do
    with [time | _] <- children(attributes, "time"),
         beats when is_binary(beats) <- text(time, "beats"),
         beat_type when beat_type != nil <- number(time, "beat-type") do
      beats =
        ~r/\d+/
        |> Regex.scan(beats)
        |> List.flatten()
        |> Enum.map(&String.to_integer/1)
        |> Enum.sum()

      %{state | meter: beats * 4 / beat_type}
    else
      _ -> state
    end
  end

  defp read_note(note, acc) do
    cond do
      child(note, "grace") ->
        add_grace(note, acc)

      child(note, "cue") ->
        move(acc, number(note, "duration") || 0)

      true ->
        add_note(note, acc)
    end
  end

  defp add_grace(note, acc) do
    case pitch(note, acc.state) do
      nil ->
        acc

      {midi, name} ->
        voice = text(note, "voice") || "1"
        grace = %{midi: midi, name: name, slash: attr(child(note, "grace"), "slash") == "yes"}
        %{acc | graces: Map.update(acc.graces, voice, [grace], &(&1 ++ [grace]))}
    end
  end

  defp add_note(note, acc) do
    divisions = acc.state.divisions
    duration = number(note, "duration") || 0
    chord = child(note, "chord") != nil
    onset = if chord, do: acc.last_onset, else: acc.cursor
    ties = for tie <- children(note, "tie"), do: attr(tie, "type")
    voice = text(note, "voice") || "1"
    {graces, pending} = if chord, do: {[], acc.graces}, else: Map.pop(acc.graces, voice, [])
    pitch = pitch(note, acc.state)
    {staff, ties_open} = staff(note, pitch, ties, acc.state.ties)

    entry = %{
      voice: voice,
      graces: graces,
      onset: onset / divisions,
      length: duration / divisions,
      chord: chord,
      pitch: pitch,
      staff: staff,
      tie: "start" in ties,
      continues: "stop" in ties
    }

    state = %{acc.state | ties: ties_open}
    acc = %{acc | notes: [entry | acc.notes], last_onset: onset, graces: pending, state: state}
    if chord, do: acc, else: move(acc, duration)
  end

  # A tied note keeps the staff its tie starts on, held open by its pitch until the tie ends.
  defp staff(note, pitch, ties, open) do
    written =
      case number(note, "staff") do
        nil -> 1
        staff -> trunc(staff)
      end

    case pitch do
      nil ->
        {written, open}

      {midi, _name} ->
        staff = if "stop" in ties, do: Map.get(open, midi, written), else: written
        open = if "start" in ties, do: Map.put(open, midi, staff), else: Map.delete(open, midi)
        {staff, open}
    end
  end

  # A rest has no pitch, and an unpitched note sounds at the pitch it is written at.
  defp pitch(note, state) do
    case child(note, "pitch") || child(note, "unpitched") do
      nil ->
        nil

      pitch ->
        sounding(pitch, state)
    end
  end

  # Spelled as written when it sounds as written with at most one sharp or flat, otherwise from
  # its number, in sharps or in flats as the key has them.
  defp sounding(pitch, state) do
    step = text(pitch, "step") || text(pitch, "display-step")
    octave = number(pitch, "octave") || number(pitch, "display-octave")
    alter = number(pitch, "alter") || 0
    midi = round(12 * (octave + 1) + @letters[step] + alter + state.transpose)

    if state.transpose == 0 and alter in [-1, 0, 1] do
      {midi, spell(step, alter, octave)}
    else
      {midi, spell(midi, state.fifths || 0)}
    end
  end

  defp spell(step, alter, octave) do
    accidental = %{-1 => "b", 0 => "", 1 => "s"}[round(alter)]
    "#{String.downcase(step)}#{accidental}#{trunc(octave)}"
  end

  @doc false
  def spell(midi, fifths) do
    names = if fifths < 0, do: @flats, else: @sharps
    name = Enum.at(names, rem(midi, 12))
    octave = div(midi, 12) - 1
    "#{name}#{octave}"
  end

  defp read_direction(direction, acc) do
    offset = (number(direction, "offset") || 0) / acc.state.divisions
    onset = acc.cursor / acc.state.divisions + offset

    marks =
      for dynamics <- path(direction, ["direction-type", "dynamics"]),
          mark <- elements(dynamics),
          name(mark) in @dynamics,
          do: {onset, name(mark)}

    acc = %{acc | dynamics: Enum.reverse(marks) ++ acc.dynamics}

    case children(direction, "sound") do
      [sound | _] -> read_sound(sound, acc)
      [] -> read_metronome(direction, acc)
    end
  end

  defp read_sound(sound, acc) do
    case attr(sound, "tempo") do
      nil -> acc
      tempo -> put_tempo(acc, parse_number(tempo))
    end
  end

  @units %{"whole" => 4, "half" => 2, "quarter" => 1, "eighth" => 0.5, "16th" => 0.25}

  defp read_metronome(direction, acc) do
    with [metronome | _] <- path(direction, ["direction-type", "metronome"]),
         unit when is_map_key(@units, unit) <- text(metronome, "beat-unit"),
         per_minute when per_minute != nil <- number(metronome, "per-minute") do
      dotted = if child(metronome, "beat-unit-dot"), do: 1.5, else: 1
      put_tempo(acc, per_minute * @units[unit] * dotted)
    else
      _ -> acc
    end
  end

  defp put_tempo(%{state: %{tempo: nil} = state} = acc, tempo)
       when is_number(tempo) and tempo > 0 do
    rounded = if tempo == trunc(tempo), do: trunc(tempo), else: Float.round(tempo * 1.0, 2)
    %{acc | state: %{state | tempo: rounded}}
  end

  defp put_tempo(acc, _tempo), do: acc

  defp read_barline(barline, acc) do
    acc = read_repeat(child(barline, "repeat"), acc)
    read_ending(child(barline, "ending"), acc)
  end

  defp read_repeat(nil, acc), do: acc

  defp read_repeat(repeat, acc) do
    case attr(repeat, "direction") do
      "forward" -> %{acc | forward: true}
      "backward" -> %{acc | backward: parse_number(attr(repeat, "times") || "2")}
      _other -> acc
    end
  end

  defp read_ending(nil, acc), do: acc

  defp read_ending(ending, acc) do
    numbers =
      ~r/\d+/
      |> Regex.scan(attr(ending, "number") || "")
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)

    case attr(ending, "type") do
      "start" -> %{acc | ending: numbers}
      _stop -> %{acc | ending_stops: true}
    end
  end

  # The score's own bar numbers when they name each bar once, otherwise each bar's place from 1.
  defp bar_numbers(measures) do
    numbers = Enum.map(measures, & &1.number)

    if Enum.all?(numbers, &(&1 != nil and &1 =~ ~r/^\d+$/)) and Enum.uniq(numbers) == numbers do
      Enum.map(numbers, &String.to_integer/1)
    else
      Enum.to_list(1..length(measures))
    end
  end

  # Every part's bar lasts as long as the longest part plays it, but no longer than its time
  # signature, so a part whose bar is written too short or too long stays in time with the rest.
  defp bar_lengths(parts) do
    parts
    |> Enum.map(& &1.measures)
    |> Enum.zip_with(fn measures ->
      longest = measures |> Enum.map(& &1.length) |> Enum.max()
      meter = hd(measures).meter
      if meter && longest > meter + 1.0e-6, do: meter, else: longest
    end)
  end

  defp finish_part(part, numbers, lengths) do
    {bars, _mark} =
      part.measures
      |> Enum.zip(numbers)
      |> Enum.zip(lengths)
      |> Enum.map_reduce(nil, fn {{measure, number}, length}, mark ->
        {voices, mark} = voices(measure, mark, length)
        {%{number: number, voices: voices}, mark}
      end)

    %{name: part.name, fifths: part.fifths, tempo: part.tempo, bars: bars}
  end

  # Each voice of a bar as notes and rests in order, gaps filled with rests, and each note
  # carrying the dynamic mark in force where it starts.
  defp voices(measure, mark, length) do
    marks = Enum.sort_by(measure.dynamics, &elem(&1, 0))

    notes =
      for note <- measure.notes do
        Map.put(note, :mark, mark_at(marks, note.onset, mark))
      end

    mark = mark_at(marks, measure.length, mark)

    lanes =
      notes
      |> Enum.group_by(& &1.voice)
      |> Enum.sort_by(fn {voice, _} -> voice_order(voice) end)
      |> Enum.flat_map(fn {_voice, notes} -> lanes(notes) end)
      |> Enum.map(&fill/1)
      |> Enum.map(&clip(&1, length))

    {pad(lanes, length), mark}
  end

  defp mark_at(marks, onset, mark) do
    case Enum.filter(marks, fn {at, _} -> at <= onset + 1.0e-6 end) do
      [] -> mark
      passed -> passed |> List.last() |> elem(1)
    end
  end

  defp voice_order(voice) do
    case Integer.parse(voice) do
      {number, _} -> {0, number}
      :error -> {1, voice}
    end
  end

  # Notes of one voice that overlap without being a chord go to a lane of their own.
  defp lanes(notes) do
    notes
    |> Enum.reduce([], fn note, lanes -> place(lanes, note, []) end)
    |> Enum.map(&Enum.reverse/1)
  end

  defp place([], note, passed), do: Enum.reverse([[group(note)] | passed])

  defp place([[last | rest] = lane | lanes], note, passed) do
    cond do
      note.chord and abs(last.onset - note.onset) < 1.0e-6 ->
        Enum.reverse(passed) ++ [[%{last | notes: last.notes ++ heads(note)} | rest] | lanes]

      note.onset >= last.onset + last.length - 1.0e-6 ->
        Enum.reverse(passed) ++ [[group(note) | lane] | lanes]

      true ->
        place(lanes, note, [lane | passed])
    end
  end

  defp group(note) do
    %{
      onset: note.onset,
      length: note.length,
      notes: heads(note),
      mark: note.mark,
      graces: note.graces
    }
  end

  defp heads(%{pitch: nil}), do: []

  defp heads(%{pitch: {midi, name}} = note) do
    [
      %{
        midi: midi,
        name: name,
        staff: note.staff,
        tie: note.tie,
        continues: note.continues,
        vel: note[:vel]
      }
    ]
  end

  defp fill(groups) do
    {filled, _end} =
      Enum.flat_map_reduce(groups, 0, fn group, cursor ->
        gap = group.onset - cursor

        rest = rest(cursor, gap, group.mark)

        {rest ++ [group], group.onset + group.length}
      end)

    filled
  end

  # A voice written longer than its bar is cut at the bar's end.
  defp clip(lane, length) do
    for group <- lane, group.onset < length - 1.0e-6 do
      %{group | length: min(group.length, length - group.onset)}
    end
  end

  defp rest(cursor, gap, mark) when gap > 1.0e-6 do
    [%{onset: cursor, length: gap, notes: [], mark: mark, graces: []}]
  end

  defp rest(_cursor, _gap, _mark), do: []

  # The first voice rests to the end of the bar, so the bar lasts its length in every part.
  defp pad([], length) when length > 0 do
    [[%{onset: 0, length: length, notes: [], mark: nil, graces: []}]]
  end

  defp pad([], _length), do: []

  defp pad([first | rest], length) do
    last = lane_end(first)

    if length - last > 1.0e-6 do
      [first ++ [%{onset: last, length: length - last, notes: [], mark: nil, graces: []}] | rest]
    else
      [first | rest]
    end
  end

  defp lane_end([]), do: 0
  defp lane_end(lane), do: lane |> List.last() |> then(&(&1.onset + &1.length))

  # The bars in the order the score plays them: a backward repeat goes back to the last
  # forward repeat, or to the start, and an ending plays only on the times through it names.
  defp order(measures, numbers) do
    played = walk(List.to_tuple(measures), 0, %{start: 0, time: 1, played: %{}, ending: nil}, [])
    measures = List.to_tuple(measures)
    numbers = List.to_tuple(numbers)

    played
    |> Enum.chunk_while(
      [],
      fn
        index, [] ->
          {:cont, [index]}

        index, [last | _] = run ->
          if follows?(measures, last, index) do
            {:cont, [index | run]}
          else
            {:cont, Enum.reverse(run), [index]}
          end
      end,
      fn run -> {:cont, Enum.reverse(run), []} end
    )
    |> Enum.reject(&(&1 == []))
    |> Enum.map(fn run -> Enum.map(run, &elem(numbers, &1)) end)
  end

  defp follows?(measures, last, index) do
    before = elem(measures, last)
    next = elem(measures, index)

    index == last + 1 and before.backward == nil and not before.ending_stops and not next.forward and
      next.ending == nil
  end

  defp walk(measures, index, _state, order) when index >= tuple_size(measures) do
    Enum.reverse(order)
  end

  defp walk(measures, index, state, order) do
    measure = elem(measures, index)
    state = enter(measure, index, state)
    ending = measure.ending || state.ending
    state = %{state | ending: if(measure.ending_stops, do: nil, else: ending)}
    played = Map.get(state.played, index, 1)

    cond do
      ending != nil and state.time not in ending ->
        walk(measures, index + 1, state, order)

      measure.backward != nil and played < measure.backward ->
        state = %{
          state
          | played: Map.put(state.played, index, played + 1),
            time: played + 1,
            ending: nil
        }

        walk(measures, state.start, state, [index | order])

      true ->
        walk(measures, index + 1, leave(measure, index, ending, state), [index | order])
    end
  end

  # A forward repeat starts a new section, played for the first time.
  defp enter(%{forward: true}, index, %{start: start} = state) when index != start do
    %{state | start: index, time: 1}
  end

  defp enter(_measure, _index, state), do: state

  # Past a finished repeat the next one goes back no further than here, and past the last
  # ending the times through count from the first again.
  defp leave(%{backward: nil, ending_stops: true}, _index, ending, state) when ending != nil do
    %{state | time: 1}
  end

  defp leave(%{backward: nil}, _index, _ending, state), do: state
  defp leave(_measure, index, nil, state), do: %{state | start: index + 1, time: 1}

  defp leave(%{ending_stops: true}, index, _ending, state) do
    %{state | start: index + 1, time: 1}
  end

  defp leave(_measure, index, _ending, state), do: %{state | start: index + 1}

  defp elements(node) do
    for child <- element(node, :content), Record.is_record(child, :xmlElement), do: child
  end

  defp name(node), do: node |> element(:name) |> Atom.to_string()
  defp children(node, name), do: Enum.filter(elements(node), &(name(&1) == name))
  defp child(node, name), do: node |> children(name) |> List.first()
  defp path(node, []), do: [node]
  defp path(node, [name | rest]), do: node |> children(name) |> Enum.flat_map(&path(&1, rest))

  defp content(node) do
    node
    |> element(:content)
    |> Enum.filter(&Record.is_record(&1, :xmlText))
    |> Enum.map_join(&text_value/1)
    |> String.trim()
  end

  defp text_value(text), do: text |> xml_text(:value) |> to_string()

  defp text(node, name) do
    case child(node, name) do
      nil -> nil
      found -> content(found)
    end
  end

  defp number(node, name) do
    case text(node, name) do
      nil -> nil
      value -> parse_number(value)
    end
  end

  defp parse_number(value) do
    case Float.parse(value) do
      {number, _} -> if number == trunc(number), do: trunc(number), else: number
      :error -> nil
    end
  end

  defp attr(node, name) do
    Enum.find_value(element(node, :attributes), fn attribute ->
      if Atom.to_string(attribute(attribute, :name)) == name do
        attribute |> attribute(:value) |> to_string()
      end
    end)
  end
end
