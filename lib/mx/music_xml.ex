defmodule Mx.MusicXML do
  @moduledoc """
  Writes a song as a MusicXML score, for `mix mx.export`.

  The score holds the whole of the song's music once, each part that plays notes as one part of the score, with the notes `Mx.Pass` records as written.
  Starts and lengths snap to a 24th of a beat, a beat being a quarter note, and a note between semitones is written at the nearest one.
  Notes of a part that start together and last as long are a chord, and notes that overlap otherwise go to as few voices as the overlaps need.
  The first voice fills every bar with notes and rests, and every other voice fills only the bars it has a note in.
  A note that crosses a bar line, or whose length no single note value writes, is written as tied notes.
  """

  alias Mx.{Page, Pass, Render, Song}

  @divisions 24

  @plain [
    {144, "whole", 1},
    {96, "whole", 0},
    {72, "half", 1},
    {48, "half", 0},
    {36, "quarter", 1},
    {24, "quarter", 0},
    {18, "eighth", 1},
    {12, "eighth", 0},
    {9, "16th", 1},
    {6, "16th", 0},
    {3, "32nd", 0}
  ]

  @triplets [{32, "half"}, {16, "quarter"}, {8, "eighth"}, {4, "16th"}, {2, "32nd"}, {1, "64th"}]

  @letters [{"C", 0}, {"D", 2}, {"E", 4}, {"F", 5}, {"G", 7}, {"A", 9}, {"B", 11}]
  @sharp_order ~w(F C G D A E B)
  @sharps [C: 0, C: 1, D: 0, D: 1, E: 0, F: 0, F: 1, G: 0, G: 1, A: 0, A: 1, B: 0]
  @flats [C: 0, D: -1, D: 0, E: -1, E: 0, F: 0, G: -1, G: 0, A: -1, A: 0, B: -1, B: 0]

  @major ~w(cb gb db ab eb bb f c g d a e b fs cs)
  @minor ~w(ab eb bb f c g d a e b fs cs gs ds as)

  @doc """
  Writes the song at `path` as a score to `out`, compressed when `out` ends in .mxl, with `time:`, the song's meter over 4 unless given, `key:`, `pickup:`, `title:` and `force:`.
  Returns `{:ok, %{parts: parts, left_out: left_out}}`, each part as its name, how many notes it holds and its lowest and highest note, and each part left out as its name and why; or `{:error, message}`.
  """
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    with :ok <- Page.check(out, Keyword.get(opts, :force, false)),
         {:ok, song} <- Song.load(path),
         {:ok, key} <- key(song_key(song, opts)),
         {:ok, time} <- song_time(song, opts),
         {:ok, pickup} <- pickup(Keyword.get(opts, :pickup), time),
         {:ok, parts, left_out} <- parts(song, path) do
      beats = parts |> Enum.map(&elem(&1, 2)) |> Enum.max(fn -> 0 end)
      title = Keyword.get_lazy(opts, :title, fn -> title(path) end)

      xml =
        score(Enum.map(parts, fn {name, notes, _, _} -> {name, notes} end),
          tempo: song.tempo,
          time: time,
          key: key,
          title: title,
          beats: beats,
          pickup: pickup
        )

      File.write!(out, if(Path.extname(out) == ".mxl", do: compress(xml), else: xml))

      {:ok,
       %{
         parts: Enum.map(parts, fn {name, notes, _, _} -> summary(name, notes, key) end),
         left_out: left_out
       }}
    end
  end

  @doc "The time signature given as `time:` in `opts`, or else the song's meter over 4, as `time/1` gives it."
  def song_time(song, opts) do
    meter = song.meter
    time(Keyword.get(opts, :time, "#{meter}/4"))
  end

  @doc "A time signature such as `12/8` as `{:ok, {12, 8}}`, or `{:error, message}`."
  def time(text) when is_binary(text) do
    with [beats, type] <- String.split(text, "/"),
         {beats, ""} when beats > 0 <- Integer.parse(beats),
         {type, ""} when type in [1, 2, 4, 8, 16, 32] <- Integer.parse(type) do
      {:ok, {beats, type}}
    else
      _ -> {:error, "--time takes a time signature such as 4/4 or 12/8, not #{text}"}
    end
  end

  @doc "A pickup's length in beats, such as `0.5`, as `{:ok, beats}` when it is shorter than a bar of `time`, `{:ok, 0}` when there is none, or `{:error, message}`."
  def pickup(nil, _time), do: {:ok, 0}

  def pickup(text, {beats, type}) when is_binary(text) do
    bar = beats * 4 / type

    case Float.parse(text) do
      {pickup, ""} when pickup > 0 and pickup < bar ->
        {:ok, pickup}

      _other ->
        bar = if bar == trunc(bar), do: trunc(bar), else: bar

        {:error,
         "--pickup takes a number of beats shorter than a bar of #{bar} beats, such as 0.5, not #{text}"}
    end
  end

  @doc "The key given as `key:` in `opts`, or else the key the song states, or else C major, as text such as `em`."
  def song_key(song, opts) do
    Keyword.get_lazy(opts, :key, fn -> if song.key, do: Atom.to_string(song.key), else: "c" end)
  end

  @doc "A key such as `d`, `bm` or `fsm` as `{:ok, {fifths, mode}}`, sharps counting up and flats down, or `{:error, message}`."
  def key(text) when is_binary(text) do
    name = String.downcase(text)

    {tonic, mode, keys} =
      if String.ends_with?(name, "m") do
        {String.trim_trailing(name, "m"), "minor", @minor}
      else
        {name, "major", @major}
      end

    case Enum.find_index(keys, &(&1 == tonic)) do
      nil -> {:error, "--key takes a key such as d, bm or fsm, not #{text}"}
      index -> {:ok, {index - 7, mode}}
    end
  end

  @doc """
  The MusicXML text of parts given as `{name, notes}`, each note `{beat, note, beats}`, with `tempo:`, `time:`, `key:`, `title:`, `beats:`, the song's length, and `pickup:`, the beats of a pickup bar, none unless given.
  """
  def score(parts, opts) when is_list(parts) and is_list(opts) do
    {beats, type} = Keyword.fetch!(opts, :time)
    {fifths, _mode} = key = Keyword.fetch!(opts, :key)
    bar = div(beats * @divisions * 4, type)

    parts = Enum.map(parts, fn {name, notes} -> {name, notes, staves(notes)} end)

    ends =
      for {_, _, staves} <- parts,
          {_staff, voices} <- staves,
          voice <- voices,
          {start, length, _} <- voice,
          do: start + length

    length = Enum.max([round(Keyword.fetch!(opts, :beats) * @divisions) | ends], fn -> 0 end)
    pickup = round(Keyword.get(opts, :pickup, 0) * @divisions)
    bars = bars(length, bar, pickup)

    list = Enum.with_index(parts, 1)

    IO.iodata_to_binary([
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">\n),
      ~s(<score-partwise version="4.0">\n),
      "  <work><work-title>",
      escape(Keyword.fetch!(opts, :title)),
      "</work-title></work>\n",
      "  <part-list>\n",
      for {{name, _, _}, index} <- list do
        name = escape(name)
        ~s(    <score-part id="P#{index}"><part-name>#{name}</part-name></score-part>\n)
      end,
      "  </part-list>\n",
      for {{_name, notes, staves}, index} <- list do
        clefs = if length(staves) == 2, do: :grand, else: clef(notes)
        attributes = attributes(key, {beats, type}, clefs)
        tempo = if index == 1, do: tempo(Keyword.fetch!(opts, :tempo)), else: ""

        [
          ~s(  <part id="P#{index}">\n),
          for {number, from, ticks} <- bars do
            first = if from == 0, do: [attributes, tempo], else: []
            implicit = if number == 0, do: ~s( implicit="yes"), else: ""

            [
              ~s(    <measure number="#{number}"#{implicit}>\n),
              first,
              measure(staves, {from, ticks}, pickup, fifths),
              "    </measure>\n"
            ]
          end,
          "  </part>\n"
        ]
      end,
      "</score-partwise>\n"
    ])
  end

  @doc false
  # Each part laid out in bars as `score/2` lays it out, for another writer: `{bar, bars, parts}`,
  # `bar` the ticks in a bar at 24 a beat, and each part `{name, voices}`, each voice its bars,
  # and each bar its pieces as `{start, notes, values, {tied_in, tied_out}}`, `notes` nil for a
  # rest and `values` the note values that write its length; a pickup of `pickup` beats is the
  # first bar.
  def layout(parts, {beats, type}, length, pickup \\ 0) do
    bar = div(beats * @divisions * 4, type)
    pickup = round(pickup * @divisions)

    parts =
      Enum.map(parts, fn {name, notes} ->
        {name, notes |> Enum.map(&quantize/1) |> chords() |> voices()}
      end)

    ends = for {_, voices} <- parts, voice <- voices, {start, held, _} <- voice, do: start + held
    bars = bars(Enum.max([round(length * @divisions) | ends]), bar, pickup)

    parts =
      for {name, voices} <- parts do
        voices =
          for voice <- voices do
            for {_number, from, ticks} <- bars, do: bar_pieces(voice, from, ticks, pickup)
          end

        {name, voices}
      end

    {bar, length(bars), parts}
  end

  defp bar_pieces(voice, from, ticks, pickup) do
    for {start, held, notes, ties} <- pieces(voice, from, ticks) do
      values = if notes, do: values(held), else: rest_values(start - pickup, held)
      {start, notes, Enum.map(values, &elem(&1, 0)), ties}
    end
  end

  # The bars that hold `length` ticks as `{number, from, ticks}`: a pickup of `pickup` ticks as
  # bar 0 when there is one, then full bars from 1.
  defp bars(length, bar, 0) do
    for number <- 1..max(1, ceil(length / bar)), do: {number, (number - 1) * bar, bar}
  end

  defp bars(length, bar, pickup) do
    [
      {0, 0, pickup}
      | for number <- 1..max(1, ceil((length - pickup) / bar)) do
          {number, pickup + (number - 1) * bar, bar}
        end
    ]
  end

  # A part whose notes reach both below C3 and above C5 goes on a grand staff, its notes from
  # middle C up on the treble staff and the rest on the bass staff; any other part goes on one
  # staff.
  defp staves(notes) do
    pitches = Enum.map(notes, &elem(&1, 1))

    if Enum.any?(pitches, &(&1 < 48)) and Enum.any?(pitches, &(&1 > 72)) do
      {treble, bass} = Enum.split_with(notes, &(round(elem(&1, 1)) >= 60))
      [{1, layered(treble)}, {2, layered(bass)}]
    else
      [{nil, layered(notes)}]
    end
  end

  defp layered(notes), do: notes |> Enum.map(&quantize/1) |> chords() |> voices()

  defp quantize({beat, note, beats}) do
    start = round(beat * @divisions)
    {start, max(round((beat + beats) * @divisions) - start, 1), round(note)}
  end

  # A note played twice at once, as two voices meeting on it, is a chord of its own, so it goes
  # to a voice of its own.
  defp chords(notes) do
    notes
    |> Enum.group_by(fn {start, length, _} -> {start, length} end, &elem(&1, 2))
    |> Enum.flat_map(fn {{start, length}, notes} ->
      for notes <- unisons(Enum.sort(notes)), do: {start, length, notes}
    end)
  end

  defp unisons([]), do: []

  defp unisons(notes) do
    once = Enum.uniq(notes)
    [once | unisons(notes -- once)]
  end

  # Each chord goes to the first voice free when it starts, the higher chords first.
  defp voices(chords) do
    chords
    |> Enum.sort_by(fn {start, _, notes} -> {start, -List.last(notes)} end)
    |> Enum.reduce([], fn {start, _, _} = chord, voices ->
      case Enum.find_index(voices, fn [{last, held, _} | _] -> last + held <= start end) do
        nil -> voices ++ [[chord]]
        index -> List.update_at(voices, index, &[chord | &1])
      end
    end)
    |> Enum.map(&Enum.reverse/1)
  end

  # Each staff's voices are numbered on from the staff above's, and each staff writes its first
  # voice even when it rests the whole bar.
  defp measure(staves, {from, bar}, pickup, fifths) do
    {written, _count} =
      Enum.flat_map_reduce(staves, 0, fn {staff, voices}, count ->
        written =
          voices
          |> Enum.with_index(1)
          |> Enum.map(fn {voice, index} -> {index, pieces(voice, from, bar)} end)
          |> Enum.filter(fn {index, pieces} ->
            index == 1 or Enum.any?(pieces, &(elem(&1, 2) != nil))
          end)
          |> Enum.map(fn {index, pieces} ->
            write_voice(pieces, count + index, bar, {pickup, fifths, staff})
          end)

        {written, count + length(voices)}
      end)

    Enum.intersperse(written, "      <backup><duration>#{bar}</duration></backup>\n")
  end

  # The voice's notes and rests within the bar from `from`, as `{start, length, notes, tied}`, a
  # note carried over from the bar before tied into and one carried into the next tied out of.
  defp pieces(voice, from, bar) do
    to = from + bar

    {pieces, cursor} =
      voice
      |> Enum.filter(fn {start, length, _} -> start < to and start + length > from end)
      |> Enum.flat_map_reduce(from, fn {start, length, notes}, cursor ->
        first = max(start, from)
        last = min(start + length, to)
        rest = if first > cursor, do: [{cursor, first - cursor, nil, {false, false}}], else: []
        {rest ++ [{first, last - first, notes, {start < from, start + length > to}}], last}
      end)

    if cursor < to, do: pieces ++ [{cursor, to - cursor, nil, {false, false}}], else: pieces
  end

  defp write_voice([{_, bar, nil, _}], voice, bar, {_pickup, _fifths, staff}) do
    staff = staff_tag(staff)

    ~s(      <note><rest measure="yes"/><duration>#{bar}</duration><voice>#{voice}</voice>#{staff}</note>\n)
  end

  # Rests fill to the beat from the first full bar's downbeat, after any pickup.
  defp write_voice(pieces, voice, _bar, {pickup, fifths, staff}) do
    for {start, length, notes, {tied_in, tied_out}} <- pieces do
      values = if notes, do: values(length), else: rest_values(start - pickup, length)
      count = length(values)

      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        stop = tied_in or index > 0
        start = tied_out or index < count - 1
        write_value(notes, value, {voice, staff}, {stop, start}, fifths)
      end)
    end
  end

  defp write_value(nil, value, voice, _ties, _fifths) do
    {duration, rest} = duration_parts(value, voice)
    ["      <note><rest/>", duration, rest, "</note>\n"]
  end

  defp write_value(notes, value, voice, {stop, start}, fifths) do
    ties = [
      if(stop, do: ~s(<tie type="stop"/>), else: ""),
      if(start, do: ~s(<tie type="start"/>), else: "")
    ]

    tied = [
      if(stop, do: ~s(<tied type="stop"/>), else: ""),
      if(start, do: ~s(<tied type="start"/>), else: "")
    ]

    notations = if stop or start, do: ["<notations>", tied, "</notations>"], else: ""

    notes
    |> Enum.with_index()
    |> Enum.map(fn {note, index} ->
      chord = if index > 0, do: "<chord/>", else: ""
      {duration, rest} = duration_parts(value, voice)
      ["      <note>", chord, pitch(note, fifths), duration, ties, rest, notations, "</note>\n"]
    end)
  end

  defp duration_parts({ticks, type, dots, triplet}, {voice, staff}) do
    dots = String.duplicate("<dot/>", dots)

    modification =
      if triplet do
        "<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>"
      else
        ""
      end

    {"<duration>#{ticks}</duration>",
     "<voice>#{voice}</voice><type>#{type}</type>#{dots}#{modification}#{staff_tag(staff)}"}
  end

  # A length as note values, from the plain ones when it is a whole number of 32nd notes and from
  # the triplets otherwise.
  # A rest that starts off the beat first fills to the beat.
  defp rest_values(start, length) do
    to_beat = Integer.mod(-start, @divisions)

    if to_beat > 0 and to_beat < length do
      values(to_beat) ++ values(length - to_beat)
    else
      values(length)
    end
  end

  defp values(length) when rem(length, 3) == 0 do
    plain = for {ticks, type, dots} <- @plain, do: {ticks, type, dots, false}
    greedy(length, plain)
  end

  defp values(length) do
    triplets = for {ticks, type} <- @triplets, do: {ticks, type, 0, true}
    greedy(length, triplets)
  end

  defp greedy(0, _values), do: []

  defp greedy(length, values) do
    {ticks, _, _, _} = value = Enum.find(values, fn {ticks, _, _, _} -> ticks <= length end)
    [value | greedy(length - ticks, values)]
  end

  defp pitch(note, fifths) do
    {step, alter, octave} = spell(note, fifths)
    alter = if alter == 0, do: "", else: "<alter>#{alter}</alter>"
    "<pitch><step>#{step}</step>#{alter}<octave>#{octave}</octave></pitch>"
  end

  @doc "A note number spelled in a key of `fifths` sharps, or flats when negative, as `{step, alter, octave}`."
  def spell(note, fifths) when is_integer(note) and is_integer(fifths) do
    class = Integer.mod(note, 12)

    {step, alter} =
      Enum.find_value(@letters, fn {step, pitch} ->
        alter = key_alter(step, fifths)
        if Integer.mod(pitch + alter, 12) == class, do: {step, alter}
      end) || fallback(class, fifths)

    {step, alter, div(note - alter, 12) - 1}
  end

  defp key_alter(step, fifths) when fifths > 0 do
    if step in Enum.take(@sharp_order, fifths), do: 1, else: 0
  end

  defp key_alter(step, fifths) when fifths < 0 do
    if step in Enum.take(Enum.reverse(@sharp_order), -fifths), do: -1, else: 0
  end

  defp key_alter(_step, 0), do: 0

  defp fallback(class, fifths) do
    {step, alter} = Enum.at(if(fifths < 0, do: @flats, else: @sharps), class)
    {to_string(step), alter}
  end

  defp attributes({fifths, mode}, {beats, type}, :grand) do
    [
      "      <attributes><divisions>#{@divisions}</divisions>",
      "<key><fifths>#{fifths}</fifths><mode>#{mode}</mode></key>",
      "<time><beats>#{beats}</beats><beat-type>#{type}</beat-type></time>",
      "<staves>2</staves>",
      ~s(<clef number="1"><sign>G</sign><line>2</line></clef>),
      ~s(<clef number="2"><sign>F</sign><line>4</line></clef></attributes>\n)
    ]
  end

  defp attributes({fifths, mode}, {beats, type}, {sign, line}) do
    [
      "      <attributes><divisions>#{@divisions}</divisions>",
      "<key><fifths>#{fifths}</fifths><mode>#{mode}</mode></key>",
      "<time><beats>#{beats}</beats><beat-type>#{type}</beat-type></time>",
      "<clef><sign>#{sign}</sign><line>#{line}</line></clef></attributes>\n"
    ]
  end

  defp tempo(tempo) do
    tempo = if tempo == trunc(tempo), do: trunc(tempo), else: tempo

    [
      ~s(      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit>),
      "<per-minute>#{tempo}</per-minute></metronome></direction-type>",
      ~s(<sound tempo="#{tempo}"/></direction>\n)
    ]
  end

  # A part whose notes lie mostly below middle C reads in the bass clef.
  defp staff_tag(nil), do: ""
  defp staff_tag(staff), do: "<staff>#{staff}</staff>"

  defp clef([]), do: {"G", 2}

  defp clef(notes) do
    sorted = notes |> Enum.map(&elem(&1, 1)) |> Enum.sort()
    if Enum.at(sorted, div(length(sorted), 2)) < 60, do: {"F", 4}, else: {"G", 2}
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @doc false
  # Each part that plays notes with a pitch as {name, notes, beats, vels}, and each part left out
  # as {name, why}, as `{:ok, parts, left_out}` or `{:error, message}`.
  def parts(song, path) do
    with {:ok, played} <- played(song), do: pitched(played, path)
  end

  # Each part as its notes through the whole of its music once, their vels and its length in
  # beats, or why it is left out.
  defp played(song) do
    Render.map_ok(song.loops, fn
      %{on: on} = loop when on != nil ->
        {:ok, {loop.name, {:left_out, "it waits for input"}}}

      loop ->
        passes = loop.music.sections |> tuple_size() |> Kernel.-(1)

        played =
          Enum.reduce_while(0..passes, {:ok, [], [], 0}, fn pass, {:ok, notes, vels, start} ->
            case Pass.events(loop, pass) do
              {:ok, %{notes: played, vels: played_vels, beats: beats}} ->
                played = Enum.map(played, fn {beat, note, held} -> {start + beat, note, held} end)
                {:cont, {:ok, notes ++ played, vels ++ played_vels, start + beats}}

              {:error, message} ->
                {:halt, {:error, message}}
            end
          end)

        case played do
          {:ok, [], _, _} -> {:ok, {loop.name, {:left_out, "it plays no notes with a pitch"}}}
          {:ok, notes, vels, beats} -> {:ok, {loop.name, {:notes, notes, beats, vels}}}
          error -> error
        end
    end)
  end

  defp pitched(played, path) do
    case Enum.split_with(played, &match?({_name, {:notes, _, _, _}}, &1)) do
      {[], _left_out} ->
        {:error, "#{path} has no part that plays notes with a pitch"}

      {parts, left_out} ->
        parts =
          for {name, {:notes, notes, beats, vels}} <- parts,
              do: {to_string(name), notes, beats, vels}

        left_out = for {name, {:left_out, why}} <- left_out, do: {to_string(name), why}
        {:ok, parts, left_out}
    end
  end

  @doc false
  def summary(name, notes, {fifths, _mode}) do
    pitches = Enum.map(notes, &round(elem(&1, 1)))

    %{
      name: name,
      notes: length(notes),
      low: name(Enum.min(pitches), fifths),
      high: name(Enum.max(pitches), fifths)
    }
  end

  defp name(note, fifths) do
    {step, alter, octave} = spell(note, fifths)
    accidental = %{-2 => "bb", -1 => "b", 0 => "", 1 => "s", 2 => "ss"}[alter]
    letter = String.downcase(step)
    "#{letter}#{accidental}#{octave}"
  end

  defp compress(xml) do
    container = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container><rootfiles><rootfile full-path="score.musicxml" media-type="application/vnd.recordare.musicxml+xml"/></rootfiles></container>
    """

    files = [
      {~c"mimetype", "application/vnd.recordare.musicxml"},
      {~c"META-INF/container.xml", container},
      {~c"score.musicxml", xml}
    ]

    {:ok, {_name, zip}} = :zip.create(~c"score.mxl", files, [:memory])
    zip
  end

  @doc false
  def title(path) do
    path |> Path.basename() |> Path.rootname() |> String.replace("_", " ") |> String.capitalize()
  end
end
