defmodule Mx.ABC do
  @moduledoc """
  Reads ABC notation written one system of music at a time, and writes the systems out as one MusicXML score.

  Each system is a header and one line per voice, the subset of ABC that the rokot-omr-2b music recognition model writes.
  A voice named by a staff number, such as V:1, is a part, and a voice named after a staff, such as V:2b, is a further voice of that staff's part.
  Slurs, grace notes, annotations and decorations other than dynamics are left out, as mx plays none of them.
  """

  @divisions 96
  @steps %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}
  @sharps ~w(F C G D A E B)
  @keys %{
    "C" => 0,
    "G" => 1,
    "D" => 2,
    "A" => 3,
    "E" => 4,
    "B" => 5,
    "F#" => 6,
    "C#" => 7,
    "F" => -1,
    "Bb" => -2,
    "Eb" => -3,
    "Ab" => -4,
    "Db" => -5,
    "Gb" => -6,
    "Cb" => -7
  }
  @dynamics ~w(pppp ppp pp p mp mf f ff fff ffff)
  @alters %{"^^" => 2, "^" => 1, "=" => 0, "_" => -1, "__" => -2}

  @token ~r/
    (?<field>\[[A-Za-z]:[^\]]*\])
    |(?<deco>![^!]*!)
    |(?<text>"[^"]*")
    |(?<grace>\{[^}]*\})
    |(?<tuplet>\(\d(?::\d*)?(?::\d*)?)
    |(?<chord>\[[^\]|:]*\][\d\/]*-?)
    |(?<note>(?:\^\^|\^|__|_|=)?[A-Ga-g][,']*[\d\/]*-?)
    |(?<rest>[zx][\d\/]*)
    |(?<bar>:*\|+[\]:]*\d*|:+|\[\d)
  /x

  @note ~r/^(\^\^|\^|__|_|=)?([A-Ga-g])([,']*)([\d\/]*)(-?)$/

  @doc "The MusicXML text of a score made of the given systems, each its ABC text."
  def musicxml(systems) when is_list(systems) do
    systems = Enum.map(systems, &system/1)

    staves =
      systems
      |> Enum.flat_map(&Map.keys(&1.voices))
      |> Enum.map(&staff/1)
      |> Enum.uniq()
      |> Enum.sort_by(&staff_order/1)

    tempo = Enum.find_value(systems, & &1.tempo)

    bars = Enum.map(staves, &staff_bars(&1, systems))

    lengths =
      bars
      |> Enum.zip_with(fn bars ->
        bars
        |> Enum.flat_map(fn {voices, _system} -> voices end)
        |> Enum.map(&bar_length/1)
        |> Enum.max()
      end)

    parts =
      staves
      |> Enum.zip(bars)
      |> Enum.map(fn {staff, bars} -> part(staff, bars, lengths, tempo) end)

    list =
      staves
      |> Enum.with_index(1)
      |> Enum.map_join(fn {_staff, index} ->
        ~s(<score-part id="P#{index}"><part-name></part-name></score-part>)
      end)

    body =
      parts
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {measures, index} ->
        ~s(<part id="P#{index}">#{measures}</part>)
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0"><part-list>#{list}</part-list>
    #{body}
    </score-partwise>
    """
  end

  # The header and each voice's bars of one system.
  defp system(abc) do
    lines = abc |> String.split("\n") |> Enum.map(&String.trim/1)
    header = %{unit: {1, 8}, meter: nil, fifths: 0, tempo: nil, clefs: %{}}

    {header, bodies} =
      Enum.reduce(lines, {header, []}, fn line, {header, bodies} ->
        case line do
          "L:" <> value -> {%{header | unit: fraction(String.trim(value))}, bodies}
          "M:" <> value -> {%{header | meter: meter(value)}, bodies}
          "K:" <> value -> {%{header | fifths: fifths(value)}, bodies}
          "Q:" <> value -> {%{header | tempo: tempo(value)}, bodies}
          "V:" <> value -> {%{header | clefs: put_clef(header.clefs, value)}, bodies}
          "[V:" <> rest -> {header, [voice_line(rest) | bodies]}
          _other -> {header, bodies}
        end
      end)

    voices =
      bodies
      |> Enum.reverse()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {name, texts} -> {name, bars(Enum.join(texts, " "), header)} end)

    Map.put(header, :voices, voices)
  end

  defp voice_line(rest) do
    [name, body] = String.split(rest, "]", parts: 2)
    {String.trim(name), body}
  end

  defp put_clef(clefs, value) do
    [name | rest] = String.split(value)

    case Enum.find_value(rest, &clef_sign/1) do
      nil -> clefs
      sign -> Map.put(clefs, name, sign)
    end
  end

  defp clef_sign("clef=treble"), do: {"G", 2}
  defp clef_sign("clef=bass"), do: {"F", 4}
  defp clef_sign("clef=alto"), do: {"C", 3}
  defp clef_sign("clef=tenor"), do: {"C", 4}
  defp clef_sign(_other), do: nil

  defp meter(value) do
    case Regex.run(~r/(\d+)\/(\d+)/, value) do
      [_, beats, type] -> {String.to_integer(beats), String.to_integer(type)}
      nil -> if String.trim(value) == "C|", do: {2, 2}, else: {4, 4}
    end
  end

  defp fifths(value) do
    name = value |> String.split() |> List.first() || "C"

    if String.starts_with?(name, "clef") do
      0
    else
      name = name |> String.replace("maj", "") |> String.replace("min", "m")

      case String.split_at(name, -1) do
        {minor, "m"} -> Map.get(@keys, minor, 3) - 3
        _major -> Map.get(@keys, name, 0)
      end
    end
  end

  # A tempo written as 1/8=120 is 60 quarter notes a minute.
  defp tempo(value) do
    case Regex.run(~r/(\d+)\/(\d+)\s*=\s*(\d+)/, value) do
      [_, top, bottom, per_minute] ->
        String.to_integer(per_minute) * 4 * String.to_integer(top) / String.to_integer(bottom)

      nil ->
        nil
    end
  end

  # A voice's bars, each its notes and rests with lengths in divisions and pitches resolved
  # against the key and the accidentals earlier in the bar.
  defp bars(body, header) do
    initial = %{
      header: header,
      fifths: header.fifths,
      bar: new_bar(),
      bars: [],
      alters: %{},
      tuplet: nil,
      mark: nil,
      ending: nil
    }

    state =
      @token
      |> Regex.scan(body, capture: :all_names)
      |> Enum.map(&kind/1)
      |> Enum.reduce(initial, &read_token/2)

    state = if state.bar.items == [], do: state, else: close(state, false)
    state.bars |> Enum.reverse() |> stop_open_ending()
  end

  # Regex.scan names its captures alphabetically: bar, chord, deco, field, grace, note, rest,
  # text, tuplet.
  defp kind([bar, chord, deco, field, grace, note, rest, text, tuplet]) do
    Enum.find_value(
      [
        bar: bar,
        chord: chord,
        deco: deco,
        field: field,
        grace: grace,
        note: note,
        rest: rest,
        text: text,
        tuplet: tuplet
      ],
      fn {kind, value} -> if value != "", do: {kind, value} end
    )
  end

  defp new_bar do
    %{items: [], forward: false, backward: false, ending: nil, ending_stops: false}
  end

  defp read_token({:field, field}, state) do
    case Regex.run(~r/^\[([A-Za-z]):(.*)\]$/, field) do
      [_, "K", value] -> if value =~ "clef", do: state, else: %{state | fifths: fifths(value)}
      [_, "M", value] -> put_in(state.header.meter, meter(value))
      _other -> state
    end
  end

  defp read_token({:deco, deco}, state) do
    mark = String.trim(deco, "!")
    if mark in @dynamics, do: %{state | mark: mark}, else: state
  end

  defp read_token({kind, _value}, state) when kind in [:text, :grace], do: state

  # ABC writes a tuplet (p:q:r): p notes in the time of q, over the next r notes.
  defp read_token({:tuplet, tuplet}, state) do
    [notes | rest] = tuplet |> String.trim_leading("(") |> String.split(":")
    notes = String.to_integer(notes)
    time = rest |> Enum.at(0, "") |> integer_or(if notes in [2, 4, 8], do: 3, else: 2)
    count = rest |> Enum.at(1, "") |> integer_or(notes)
    %{state | tuplet: {time, notes, count}}
  end

  defp read_token({:bar, "[" <> number}, state), do: start_ending(state, number)

  defp read_token({:bar, bar}, state) do
    backward = String.starts_with?(bar, ":")
    forward = String.ends_with?(bar, ":")
    ending = Regex.run(~r/(\d+)$/, bar, capture: :all_but_first)
    final = bar in ["||", "|]"] or forward

    state =
      if state.bar.items == [] and not backward do
        state
      else
        close(state, backward, final)
      end

    state = if forward, do: put_in(state.bar.forward, true), else: state
    if ending, do: start_ending(state, hd(ending)), else: state
  end

  defp read_token({:rest, rest}, state) do
    length = length(state, String.slice(rest, 1..-1//1))
    add(state, %{pitches: [], length: length, tie: false})
  end

  defp read_token({:note, note}, state) do
    [_, accidental, letter, octave, own, tie] = Regex.run(@note, note)
    {midi, state} = pitch(state, accidental, letter, octave)
    add(state, %{pitches: [midi], length: length(state, own), tie: tie == "-"})
  end

  defp read_token({:chord, chord}, state) do
    [_, inner, outer, tie] = Regex.run(~r/^\[([^\]]*)\]([\d\/]*)(-?)$/, chord)

    heads =
      ~r/(?:\^\^|\^|__|_|=)?[A-Ga-g][,']*[\d\/]*-?/
      |> Regex.scan(inner)
      |> List.flatten()
      |> Enum.map(&Regex.run(@note, &1))

    {heads, state} =
      Enum.map_reduce(heads, state, fn [_, accidental, letter, octave, own, own_tie], state ->
        {midi, state} = pitch(state, accidental, letter, octave)
        {{midi, own, own_tie == "-" or tie == "-"}, state}
      end)

    case heads do
      [] ->
        state

      heads ->
        {lengths, ties} =
          heads
          |> Enum.map(fn {_midi, own, tied} -> {own, tied} end)
          |> Enum.unzip()

        lengths = Enum.map(lengths, &(fraction(&1) |> multiply(fraction(outer))))
        shortest = Enum.min_by(lengths, fn {n, d} -> n / d end)
        pitches = Enum.map(heads, &elem(&1, 0))

        add(state, %{pitches: pitches, length: divisions(state, shortest), tie: ties, chord: true})
    end
  end

  defp integer_or("", default), do: default
  defp integer_or(text, _default), do: String.to_integer(text)

  defp start_ending(state, number) do
    state = if state.ending, do: stop_ending(state), else: state
    %{state | ending: number, bar: %{state.bar | ending: number}}
  end

  # An ending runs to the next repeat or double bar line, as ABC has it.
  defp stop_ending(%{bars: [last | rest]} = state) do
    %{state | ending: nil, bars: [%{last | ending_stops: true} | rest]}
  end

  defp stop_ending(state), do: %{state | ending: nil}

  defp stop_open_ending(bars) do
    case Enum.find_index(Enum.reverse(bars), & &1.ending) do
      nil ->
        bars

      from_end ->
        index = length(bars) - 1 - from_end

        if Enum.any?(Enum.drop(bars, index), & &1.ending_stops) do
          bars
        else
          List.update_at(bars, index, &%{&1 | ending_stops: true})
        end
    end
  end

  defp close(state, backward, final \\ false) do
    bar = %{state.bar | items: Enum.reverse(state.bar.items), backward: backward}
    bar = if state.ending && (backward or final), do: %{bar | ending_stops: true}, else: bar
    ending = if bar.ending_stops, do: nil, else: state.ending
    %{state | bars: [bar | state.bars], bar: new_bar(), alters: %{}, ending: ending}
  end

  defp pitch(state, accidental, letter, octave) do
    step = String.upcase(letter)
    number = 60 + @steps[step] + if(letter == step, do: 0, else: 12)
    number = number + 12 * count(octave, "'") - 12 * count(octave, ",")
    place = {step, div(number, 12)}

    {alter, state} =
      if accidental != "" do
        alter = @alters[accidental]
        {alter, put_in(state.alters[place], alter)}
      else
        {Map.get(state.alters, place, key_alter(state.fifths, step)), state}
      end

    {{number + alter, {step, alter, div(number, 12) - 1}}, state}
  end

  defp key_alter(fifths, step) when fifths > 0 do
    if(step in Enum.take(@sharps, fifths), do: 1, else: 0)
  end

  defp key_alter(fifths, step) when fifths < 0 do
    if(step in Enum.take(Enum.reverse(@sharps), -fifths), do: -1, else: 0)
  end

  defp key_alter(_fifths, _step), do: 0

  defp count(text, char), do: text |> String.graphemes() |> Enum.count(&(&1 == char))

  defp length(state, text), do: divisions(state, fraction(text))

  # A length in divisions of a quarter note, scaled by the tuplet in force.
  defp divisions(state, {top, bottom}) do
    {unit_top, unit_bottom} = state.header.unit

    {time, notes} =
      case state.tuplet do
        {time, notes, _count} -> {time, notes}
        nil -> {1, 1}
      end

    round(@divisions * 4 * unit_top * top * time / (unit_bottom * bottom * notes))
  end

  defp fraction(""), do: {1, 1}

  defp fraction(text) do
    case String.split(text, "/", parts: 2) do
      [top] ->
        {String.to_integer(top), 1}

      [top, bottom] ->
        top = if top == "", do: 1, else: String.to_integer(top)
        slashes = count(text, "/")

        bottom =
          case String.trim(bottom, "/") do
            "" -> Integer.pow(2, slashes)
            digits -> String.to_integer(digits)
          end

        {top, bottom}
    end
  end

  defp multiply({top, bottom}, {other_top, other_bottom}) do
    {top * other_top, bottom * other_bottom}
  end

  # Adds a note, a chord or a rest to the bar, counting down the tuplet.
  defp add(state, item) do
    ties = item.tie
    ties = if is_list(ties), do: ties, else: Enum.map(item.pitches, fn _ -> ties end)

    heads =
      Enum.zip_with(item.pitches, ties, fn {midi, spelled}, tie ->
        %{midi: midi, spelled: spelled, tie: tie, continues: false}
      end)

    entry = %{heads: heads, length: item.length, mark: state.mark}
    state = %{state | bar: %{state.bar | items: [entry | state.bar.items]}, mark: nil}

    case state.tuplet do
      {_time, _notes, 1} -> %{state | tuplet: nil}
      {time, notes, count} -> %{state | tuplet: {time, notes, count - 1}}
      nil -> state
    end
  end

  defp staff(name) do
    case Regex.run(~r/^(\d+)/, name) do
      [_, number] -> number
      nil -> name
    end
  end

  defp staff_order(staff) do
    case Integer.parse(staff) do
      {number, ""} -> {0, number}
      _other -> {1, staff}
    end
  end

  defp staff_bars(staff, systems) do
    systems
    |> Enum.flat_map(fn system -> system_bars(staff, system) end)
    |> link_ties()
  end

  defp bar_length(bar), do: bar.items |> Enum.map(& &1.length) |> Enum.sum()

  # One part's measures across the systems, each lasting as long as the longest part's bar.
  defp part(staff, bars, lengths, tempo) do
    {measures, _} =
      bars
      |> Enum.zip(lengths)
      |> Enum.with_index(1)
      |> Enum.map_reduce(nil, fn {{{bar_voices, system}, length}, number}, last ->
        attributes = {system.fifths, system.meter, system.clefs[staff]}
        head = measure_attributes(attributes, last)

        tempo_mark =
          if number == 1 and tempo do
            ~s(<direction><sound tempo="#{format(tempo)}"/></direction>)
          else
            ""
          end

        {measure(number, head <> tempo_mark, bar_voices, length), attributes}
      end)

    Enum.join(measures)
  end

  # A note continues a tie when the voice's note before it, in this system or the last one,
  # started a tie at the same pitch.
  defp link_ties(bars) do
    {bars, _tied} =
      Enum.map_reduce(bars, %{}, fn {voices, system}, tied ->
        {voices, tied} =
          voices
          |> Enum.with_index()
          |> Enum.map_reduce(tied, fn {bar, index}, tied ->
            {items, last} =
              Enum.map_reduce(bar.items, Map.get(tied, index, MapSet.new()), fn item, last ->
                heads = Enum.map(item.heads, &%{&1 | continues: &1.midi in last})

                {%{item | heads: heads}, heads |> Enum.filter(& &1.tie) |> MapSet.new(& &1.midi)}
              end)

            {%{bar | items: items}, Map.put(tied, index, last)}
          end)

        {{voices, system}, tied}
      end)

    bars
  end

  # This staff's bars in one system as a list of voices per bar, padded to the system's
  # longest voice so every part has the same bars.
  defp system_bars(staff, system) do
    count = system.voices |> Map.values() |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)

    voices =
      system.voices
      |> Enum.filter(fn {name, _bars} -> staff(name) == staff end)
      |> Enum.sort_by(fn {name, _bars} -> name end)
      |> Enum.map(fn {_name, bars} -> bars ++ List.duplicate(new_bar(), count - length(bars)) end)

    voices = if voices == [], do: [List.duplicate(new_bar(), count)], else: voices

    voices
    |> Enum.zip()
    |> Enum.map(&{Tuple.to_list(&1), system})
  end

  defp measure_attributes({fifths, meter, clef} = attributes, last) do
    if attributes == last do
      ""
    else
      divisions = if last == nil, do: "<divisions>#{@divisions}</divisions>", else: ""
      key = "<key><fifths>#{fifths}</fifths></key>"

      time =
        case meter do
          {beats, type} -> "<time><beats>#{beats}</beats><beat-type>#{type}</beat-type></time>"
          nil -> ""
        end

      clef =
        case clef do
          {sign, line} -> "<clef><sign>#{sign}</sign><line>#{line}</line></clef>"
          nil -> ""
        end

      "<attributes>#{divisions}#{key}#{time}#{clef}</attributes>"
    end
  end

  defp measure(number, head, [first | _] = voices, length) do
    left =
      if first.forward do
        ~s(<barline location="left"><repeat direction="forward"/></barline>)
      else
        ""
      end

    left = left <> ending_start(first)

    notes =
      voices
      |> Enum.with_index(1)
      |> Enum.map_join(fn {bar, voice} ->
        written = bar_length(bar)
        bar = if voice == 1 or written > 0, do: fill(bar, length - written), else: bar
        filled = bar_length(bar)
        notes = Enum.map_join(bar.items, &item(&1, voice))

        if filled > 0 do
          notes <> "<backup><duration>#{filled}</duration></backup>"
        else
          notes
        end
      end)

    right = right_barline(first)
    ~s(<measure number="#{number}">#{head}#{left}#{notes}#{right}</measure>)
  end

  defp fill(bar, gap) when gap > 0 do
    %{bar | items: bar.items ++ [%{heads: [], length: gap, mark: nil}]}
  end

  defp fill(bar, _gap), do: bar

  defp ending_start(%{ending: nil}), do: ""

  defp ending_start(%{ending: number}) do
    ~s(<barline location="left"><ending number="#{number}" type="start"/></barline>)
  end

  defp right_barline(%{backward: false, ending_stops: false}), do: ""

  defp right_barline(bar) do
    ending =
      if bar.ending_stops, do: ~s(<ending number="#{bar_ending(bar)}" type="stop"/>), else: ""

    repeat = if bar.backward, do: ~s(<repeat direction="backward"/>), else: ""
    ~s(<barline location="right">#{ending}#{repeat}</barline>)
  end

  defp bar_ending(%{ending: nil}), do: "1"
  defp bar_ending(%{ending: number}), do: number

  defp item(%{heads: [], length: length, mark: mark}, voice) do
    dynamics(mark) <> "<note><rest/><duration>#{length}</duration><voice>#{voice}</voice></note>"
  end

  defp item(%{heads: heads, length: length, mark: mark}, voice) do
    notes =
      heads
      |> Enum.with_index()
      |> Enum.map_join(fn {head, index} ->
        chord = if index > 0, do: "<chord/>", else: ""
        stop = if head.continues, do: ~s(<tie type="stop"/>), else: ""
        start = if head.tie, do: ~s(<tie type="start"/>), else: ""

        "<note>#{chord}#{pitch_xml(head.spelled)}<duration>#{length}</duration>#{stop}#{start}<voice>#{voice}</voice></note>"
      end)

    dynamics(mark) <> notes
  end

  defp dynamics(nil), do: ""

  defp dynamics(mark) do
    "<direction><direction-type><dynamics><#{mark}/></dynamics></direction-type></direction>"
  end

  defp pitch_xml({step, alter, octave}) do
    alter = if alter == 0, do: "", else: "<alter>#{alter}</alter>"
    "<pitch><step>#{step}</step>#{alter}<octave>#{octave}</octave></pitch>"
  end

  defp format(number) when number == trunc(number), do: Integer.to_string(trunc(number))
  defp format(number), do: Float.to_string(number)
end
