defmodule Mx.MIDI do
  @moduledoc """
  Reads a Standard MIDI File as a score for `mix mx.import`, and writes a song as one for `mix mx.export`.

  A file read becomes a `Mx.Score`: each track that plays notes is a part, named after the track or numbered among the tracks that play notes, and a file whose notes all lie in one track gives a part for each channel instead.
  Note starts and ends move to the nearest step of the grid, and notes of a part that start and end together are a chord, while notes that overlap otherwise go to as few voices as the overlaps need.
  The first tempo is the score's, each later change is kept at the nearest step of the grid, and its time signatures cut the bars, 4/4 when it has none.
  Notes on channel 10, which General MIDI keeps for drums, the sustain pedal and other controllers are left out, and the score counts them in `left_out` and `left_out_counts` as `:drum_notes`, `:pedal_presses` and `:controls`, part by part, or for the file when its notes lie in one track.

  A file written holds a first track with the song's tempo and each change its music makes at once, its time signature and key, then one track per part that plays notes with a pitch, named after the part, each on its own channel, without channel 10.
  A change made evenly over some beats is written as a change at once where it starts, and named in `left_out`.
  Each note keeps its vel as its velocity, 0.6 when it has none, the default of every synth that takes one, and the tracks name no instrument, since mx's synths have no General MIDI number.
  """

  import Bitwise

  alias Mx.{MusicXML, Page, Score, Song}

  @ticks 480
  @unit 192
  @drums 9
  @pedal 64

  @doc """
  Reads the MIDI file at `path` as a score, moving notes to the nearest `grid`, given as `{1, 16}` for a sixteenth note.
  Returns `{:ok, score}` or `{:error, message}`.
  """
  def score(path, {count, division} = grid) when is_binary(path) and count > 0 and division > 0 do
    with {:ok, data} <- read_file(path),
         {:ok, midi} <- parse(data, path) do
      case parts(midi) do
        {[], counts} ->
          {:error, sentence_error(path, counts)}

        {parts, counts} ->
          to_score(midi, parts, counts, grid)
      end
    end
  end

  @doc """
  The notes of the MIDI file at `path` as they were played, part by part as `score/2` names the parts, none moved to a grid.
  Returns `{:ok, %{ticks: ticks, parts: [%{name: name, notes: notes}]}}`, a note as `%{beat: beat, length: beats, midi: key, vel: velocity}` with its beat and length in quarter notes and its velocity from 0 to 1, or `{:error, message}`.
  """
  def played(path) when is_binary(path) do
    with {:ok, data} <- read_file(path),
         :ok <- whole(data, path),
         {:ok, midi} <- parse(data, path) do
      case parts(midi) do
        {[], counts} ->
          {:error, sentence_error(path, counts)}

        {parts, _counts} ->
          beats = fn tick -> tick / midi.division end

          parts =
            for {name, notes} <- parts do
              notes =
                notes
                |> Enum.sort()
                |> Enum.map(fn {start, stop, key, velocity} ->
                  %{
                    beat: beats.(start),
                    length: beats.(stop - start),
                    midi: key,
                    vel: velocity / 127
                  }
                end)

              %{name: name, notes: notes}
            end

          {:ok, %{ticks: midi.division, parts: parts}}
      end
    end
  end

  @doc """
  What the MIDI file at `path` holds besides its notes, as `Mx.Score.about/1` gives it, or `{:error, message}`.
  """
  def about(path) when is_binary(path) do
    with {:ok, data} <- read_file(path),
         :ok <- whole(data, path),
         {:ok, midi} <- parse(data, path) do
      events = midi.tracks |> Enum.concat() |> Enum.sort_by(&elem(&1, 0))

      meters =
        for {tick, {:meta, 0x58, <<beats, power, _::binary>>}} <- events, do: {tick, beats, power}

      {:ok,
       %{
         tracks: length(midi.tracks),
         tracks_with_notes:
           Enum.count(
             midi.tracks,
             &Enum.any?(&1, fn {_tick, event} -> match?({:on, _, _, _}, event) end)
           ),
         ticks: midi.division,
         meter: written_meter(meters),
         fifths: Enum.find_value(events, 0, &key_event/1),
         tempos: about_tempos(events, meters, midi.division)
       }}
    end
  end

  # Every chunk the file names is all there; a file cut short loses the end of its last track.
  defp whole(<<"MThd", length::32, _header::binary-size(length), chunks::binary>>, path) do
    whole_chunks(chunks, path)
  end

  defp whole(_data, path), do: {:error, "#{path} is not a MIDI file"}

  defp whole_chunks(<<>>, _path), do: :ok

  defp whole_chunks(<<_type::binary-4, length::32, rest::binary>>, path)
       when byte_size(rest) >= length do
    <<_body::binary-size(^length), rest::binary>> = rest
    whole_chunks(rest, path)
  end

  defp whole_chunks(_rest, path), do: {:error, "#{path} is cut short inside a track"}

  defp written_meter([{_tick, beats, power} | _]), do: "#{beats}/#{1 <<< power}"
  defp written_meter([]), do: "4/4"

  defp key_event({_tick, {:meta, 0x59, <<fifths::signed, _::binary>>}}), do: fifths
  defp key_event(_event), do: nil

  # Each change of tempo, the same tempo given again left out, with its beat and the bar it falls in.
  defp about_tempos(events, meters, division) do
    events
    |> Enum.flat_map(&tempo_event/1)
    |> Enum.map(fn {tick, us} -> {tick, bpm(us)} end)
    |> Enum.dedup_by(&elem(&1, 1))
    |> Enum.map(fn {tick, tempo} ->
      %{bar: bar_at(tick, meters, division), beat: tick / division, tempo: tempo}
    end)
  end

  # The bar a tick falls in, counted from 1, through each time signature from the one in force at the start.
  defp bar_at(tick, meters, division) do
    meters = if match?([{0, _, _} | _], meters), do: meters, else: [{0, 4, 2} | meters]

    {bars, from, length} =
      meters
      |> Enum.take_while(fn {at, _beats, _power} -> at <= tick end)
      |> Enum.reduce({0, 0, nil}, fn {at, beats, power}, {bars, from, length} ->
        bars = if length, do: bars + div(at - from, length), else: bars
        {bars, at, div(beats * 4 * division, 1 <<< power)}
      end)

    bars + div(tick - from, length) + 1
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, _reason} -> {:error, "cannot read #{path}"}
    end
  end

  defp sentence_error(path, []), do: "#{path} plays no notes"
  defp sentence_error(path, _left_out), do: "#{path} plays no notes outside channel 10"

  @doc false
  # The file as its division and its tracks, each a list of {tick, event} in order.
  def parse(data, path) do
    case data do
      <<"MThd", length::32, header::binary-size(length), chunks::binary>> when length >= 6 ->
        <<_format::16, _count::16, division::16, _::binary>> = header

        if division >>> 15 == 1 do
          {:error, "#{path} counts time in SMPTE frames, which mx does not read"}
        else
          {:ok, %{division: division, tracks: tracks(chunks, [])}}
        end

      _other ->
        {:error, "#{path} is not a MIDI file"}
    end
  rescue
    _error in [MatchError, CaseClauseError, FunctionClauseError] ->
      {:error, "#{path} is not a MIDI file"}
  end

  defp tracks(<<"MTrk", length::32, body::binary-size(length), rest::binary>>, tracks) do
    tracks(rest, [events(body, 0, nil, []) | tracks])
  end

  defp tracks(<<_type::binary-4, length::32, _body::binary-size(length), rest::binary>>, tracks) do
    tracks(rest, tracks)
  end

  defp tracks(_rest, tracks), do: Enum.reverse(tracks)

  defp events(<<>>, _tick, _running, events), do: Enum.reverse(events)

  defp events(data, tick, running, events) do
    {delta, data} = read_vlq(data, 0)
    tick = tick + delta

    case data do
      <<0xFF, 0x2F, _rest::binary>> ->
        Enum.reverse([{tick, :end} | events])

      <<0xFF, type, rest::binary>> ->
        {length, rest} = read_vlq(rest, 0)
        <<payload::binary-size(^length), rest::binary>> = rest
        events(rest, tick, running, [{tick, {:meta, type, payload}} | events])

      <<status, rest::binary>> when status in [0xF0, 0xF7] ->
        {length, rest} = read_vlq(rest, 0)
        <<_payload::binary-size(^length), rest::binary>> = rest
        events(rest, tick, running, events)

      <<status, rest::binary>> when status >= 0x80 ->
        {event, rest} = channel(status, rest)
        events(rest, tick, status, [{tick, event} | events])

      _data when running != nil ->
        {event, rest} = channel(running, data)
        events(rest, tick, running, [{tick, event} | events])
    end
  end

  defp channel(status, data) do
    channel = status &&& 0x0F

    case {status >>> 4, data} do
      {0x9, <<key, 0, rest::binary>>} -> {{:off, channel, key}, rest}
      {0x9, <<key, velocity, rest::binary>>} -> {{:on, channel, key, velocity}, rest}
      {0x8, <<key, _velocity, rest::binary>>} -> {{:off, channel, key}, rest}
      {0xB, <<number, value, rest::binary>>} -> {{:control, channel, number, value}, rest}
      {kind, <<_, rest::binary>>} when kind in [0xC, 0xD] -> {{:other, channel}, rest}
      {_kind, <<_, _, rest::binary>>} -> {{:other, channel}, rest}
    end
  end

  defp read_vlq(<<byte, rest::binary>>, value) when byte >= 0x80 do
    read_vlq(rest, (value <<< 7) + (byte &&& 0x7F))
  end

  defp read_vlq(<<byte, rest::binary>>, value), do: {(value <<< 7) + byte, rest}

  # Each part as {name, notes, controls}, a note as {start, end, key, velocity} in ticks, and
  # what is left out of the parts, counted as {part, kind, count}.
  defp parts(midi) do
    tracks =
      midi.tracks
      |> Enum.map(fn events -> {name(events), notes(events), controls(events)} end)

    playing = Enum.filter(tracks, fn {_name, notes, _controls} -> notes != [] end)

    case playing do
      [{name, notes, controls}] ->
        channels = notes |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
        pitched = Enum.reject(channels, &(&1 == @drums))

        parts =
          for channel <- pitched do
            part_name =
              if length(pitched) == 1, do: name || "track 1", else: "channel #{channel + 1}"

            on = for {^channel, _, _, _, _} = note <- notes, do: note
            {part_name, on, Enum.filter(controls, &(elem(&1, 0) == channel))}
          end

        drums = Enum.count(notes, &(elem(&1, 0) == @drums))
        drums_left_out = if drums > 0, do: [{nil, :drum_notes, drums}], else: []
        left_out = Enum.flat_map(parts, &controls_left_out/1) ++ drums_left_out

        {Enum.map(parts, &strip/1), left_out}

      playing ->
        {parts, left_out} =
          playing
          |> Enum.with_index(1)
          |> Enum.map_reduce([], fn {{name, notes, controls}, index}, left_out ->
            name = name || "track #{index}"
            pitched = Enum.reject(notes, &(elem(&1, 0) == @drums))

            drums = length(notes) - length(pitched)

            cond do
              pitched == [] ->
                {nil, left_out ++ [{name, :drum_part, drums}]}

              pitched != notes ->
                part = {name, pitched, controls}
                {part, left_out ++ [{name, :drum_notes, drums} | controls_left_out(part)]}

              true ->
                part = {name, notes, controls}
                {part, left_out ++ controls_left_out(part)}
            end
          end)

        {parts |> Enum.reject(&is_nil/1) |> Enum.map(&strip/1), left_out}
    end
  end

  defp strip({name, notes, _controls}) do
    {name,
     Enum.map(notes, fn {_channel, start, stop, key, velocity} -> {start, stop, key, velocity} end)}
  end

  # A press of the sustain pedal is a message that puts it down, at 64 or above, from up.
  defp controls_left_out({name, _notes, controls}) do
    {pedal, others} = Enum.split_with(controls, &(elem(&1, 1) == @pedal))

    {presses, _down} =
      Enum.reduce(pedal, {0, false}, fn {_channel, _number, value}, {presses, down} ->
        if value >= 64 and not down, do: {presses + 1, true}, else: {presses, value >= 64}
      end)

    kind = if pedal == [], do: :controls, else: :other_controls

    [{name, :pedal_presses, presses}, {name, kind, length(others)}]
    |> Enum.filter(&(elem(&1, 2) > 0))
  end

  @kinds [
    drum_notes:
      {"note on channel 10, which General MIDI keeps for drums,",
       "notes on channel 10, which General MIDI keeps for drums,"},
    pedal_presses: {"press of the sustain pedal", "presses of the sustain pedal"},
    other_controls: {"other controller message", "other controller messages"},
    controls: {"controller message", "controller messages"}
  ]

  # The lines naming what is left out, in the order the parts come, a part's kinds in turn.
  defp left_out_lines(counts) do
    Enum.flat_map(counts, fn
      {part, :drum_part, count} ->
        notes = if count == 1, do: "its 1 note is", else: "its #{count} notes are"
        ["#{part} is left out: #{notes} on channel 10, which General MIDI keeps for drums"]

      count ->
        Score.left_out_lines([count], @kinds)
    end)
  end

  defp name(events) do
    Enum.find_value(events, fn
      {_tick, {:meta, 0x03, name}} -> if String.trim(name) != "", do: String.trim(name)
      _other -> nil
    end)
  end

  defp controls(events) do
    for {_tick, {:control, channel, number, value}} <- events, do: {channel, number, value}
  end

  # Each note-on paired with the next note-off of its key and channel, or with the track's end.
  defp notes([]), do: []

  defp notes(events) do
    {last, _event} = List.last(events)

    {notes, open} =
      Enum.reduce(events, {[], %{}}, fn
        {tick, {:on, channel, key, velocity}}, {notes, open} ->
          {notes,
           Map.update(open, {channel, key}, [{tick, velocity}], &(&1 ++ [{tick, velocity}]))}

        {tick, {:off, channel, key}}, {notes, open} ->
          case Map.get(open, {channel, key}, []) do
            [] ->
              {notes, open}

            [{start, velocity} | rest] ->
              {[{channel, start, tick, key, velocity} | notes],
               Map.put(open, {channel, key}, rest)}
          end

        _event, acc ->
          acc
      end)

    unended =
      for {{channel, key}, starts} <- open,
          {start, velocity} <- starts,
          do: {channel, start, last, key, velocity}

    Enum.sort_by(notes ++ unended, fn {channel, start, _, key, _} -> {start, key, channel} end)
  end

  defp to_score(midi, parts, counts, {count, division}) do
    tpq = midi.division
    events = Enum.concat(midi.tracks)
    step = div(4 * count * unit(division), division)
    units = unit(division)
    at = fn tick -> round(tick * units / tpq / step) * step end

    {tempo, tempos} =
      case events |> Enum.flat_map(&tempo_event/1) |> Enum.sort_by(&elem(&1, 0)) do
        [] -> {120, []}
        changes -> tempos(changes, at, units)
      end

    fifths =
      Enum.find_value(events, 0, fn
        {_tick, {:meta, 0x59, <<fifths::signed-8, _mode>>}} -> fifths
        _other -> nil
      end)

    parts =
      for {name, notes} <- parts do
        notes =
          notes
          |> Enum.map(fn {start, stop, key, velocity} ->
            start = at.(start)
            {start, max(at.(stop), start + step), key, Float.round(velocity / 127, 2)}
          end)
          |> Enum.uniq_by(fn {start, _stop, key, _vel} -> {start, key} end)

        {name, voices(notes)}
      end

    last =
      parts |> Enum.flat_map(fn {_name, notes} -> Enum.map(notes, &elem(&1, 1)) end) |> Enum.max()

    bars = bars(meters(events, tpq, units), last, units)
    {ends, length} = List.last(bars)
    tempos = Enum.filter(tempos, fn {beat, _bpm} -> beat < (ends + length) / units end)

    parts =
      for {name, notes} <- parts do
        measures =
          bars
          |> Enum.with_index(1)
          |> Enum.map(fn {{from, length}, number} ->
            notes = measure_notes(notes, from, from + length, units, fifths)

            %{
              number: Integer.to_string(number),
              notes: notes,
              dynamics: [],
              length: length / units,
              forward: false,
              backward: nil,
              ending: nil,
              ending_stops: false,
              fifths: fifths,
              meter: length / units
            }
          end)

        %{name: name, measures: measures, fifths: fifths, tempo: tempo}
      end

    title =
      case midi.tracks do
        [first | _] -> if notes(first) == [], do: name(first)
        [] -> nil
      end

    score = Score.build(parts, title)
    {:ok, %{score | tempos: tempos, left_out: left_out_lines(counts), left_out_counts: counts}}
  end

  # The first tempo, and the changes after it as {beat, bpm}, each at the nearest step of the grid,
  # the last of those at one step, leaving out those that keep the tempo already held.
  defp tempos(changes, at, units) do
    [{_at, first} | later] =
      changes
      |> Enum.map(fn {tick, us} -> {at.(tick), us} end)
      |> Enum.reverse()
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.reverse()

    {kept, _held} =
      Enum.reduce(later, {[], first}, fn
        {_at, us}, {kept, us} -> {kept, us}
        {at, us}, {kept, _held} -> {[{beats(at / units), bpm(us)} | kept], us}
      end)

    {bpm(first), Enum.reverse(kept)}
  end

  defp beats(beats) when beats == trunc(beats), do: trunc(beats)
  defp beats(beats), do: beats

  # Units in a beat, enough that a step of the grid and every bar is a whole number of them.
  defp unit(division), do: div(@unit * division, Integer.gcd(@unit, division))

  defp tempo_event({tick, {:meta, 0x51, <<us::24>>}}), do: [{tick, us}]
  defp tempo_event(_event), do: []

  defp bpm(us) do
    bpm = 60_000_000 / us
    if abs(bpm - round(bpm)) < 0.01, do: round(bpm), else: Float.round(bpm, 2)
  end

  # The time signatures as {unit, bar length in units}, from the start.
  defp meters(events, tpq, units) do
    signatures =
      for {tick, {:meta, 0x58, <<beats, power, _::binary>>}} <- events do
        {round(tick * units / tpq), div(beats * 4 * units, 1 <<< power)}
      end

    case signatures |> Enum.sort_by(&elem(&1, 0)) |> Enum.uniq_by(&elem(&1, 0)) do
      [{0, _length} | _] = signatures -> signatures
      signatures -> [{0, 4 * units} | signatures]
    end
  end

  # Each bar as {start, length} in units, to the end of the last note; a time signature that
  # changes within a bar ends that bar there.
  defp bars(meters, last, units) do
    Stream.unfold({0, meters}, fn
      {from, _meters} when from >= last and from > 0 ->
        nil

      {from, meters} ->
        meters = drop_passed(meters, from)
        [{_at, length} | later] = meters
        length = if length > 0, do: length, else: 4 * units

        length =
          case later do
            [{next, _} | _] when next < from + length -> next - from
            _ -> length
          end

        {{from, length}, {from + length, meters}}
    end)
    |> Enum.to_list()
  end

  defp drop_passed([_current, {at, _} = next | rest], from) when at <= from do
    drop_passed([next | rest], from)
  end

  defp drop_passed(meters, _from), do: meters

  # Notes that start and end together are a chord; each chord goes to the first voice free when it
  # starts, the highest chords first.
  defp voices(notes) do
    {voiced, _ends} =
      notes
      |> Enum.group_by(fn {start, stop, _key, _vel} -> {start, stop} end)
      |> Enum.sort_by(fn {{start, _stop}, chord} ->
        {start, -(chord |> Enum.map(&elem(&1, 2)) |> Enum.max())}
      end)
      |> Enum.flat_map_reduce([], fn {{start, stop}, chord}, ends ->
        voice = Enum.find_index(ends, &(&1 <= start)) || length(ends)

        ends =
          if voice == length(ends), do: ends ++ [stop], else: List.replace_at(ends, voice, stop)

        {Enum.map(chord, &Tuple.insert_at(&1, 4, voice + 1)), ends}
      end)

    voiced
  end

  # The notes sounding in a bar, as `Mx.Score` reads a measure's, cut at its edges and tied over
  # them.
  defp measure_notes(notes, from, to, units, fifths) do
    notes
    |> Enum.filter(fn {start, stop, _key, _vel, _voice} -> start < to and stop > from end)
    |> Enum.sort_by(fn {start, _stop, key, _vel, voice} -> {voice, max(start, from), key} end)
    |> Enum.chunk_by(fn {start, _stop, _key, _vel, voice} -> {voice, max(start, from)} end)
    |> Enum.flat_map(fn chord ->
      Enum.with_index(chord, fn {start, stop, key, vel, voice}, index ->
        onset = max(start, from)

        %{
          onset: (onset - from) / units,
          length: (min(stop, to) - onset) / units,
          pitch: {key, Score.spell(key, fifths)},
          voice: Integer.to_string(voice),
          chord: index > 0,
          staff: 1,
          tie: stop > to,
          continues: start < from,
          graces: [],
          vel: vel
        }
      end)
    end)
  end

  @doc """
  Writes the song at `path` as a MIDI file to `out`, with `time:`, `key:`, `title:` and `force:` as `Mx.MusicXML.write/3` takes them.
  Returns `{:ok, %{parts: parts, left_out: left_out, notes: notes}}`, the parts and what is left out as `Mx.MusicXML.write/3` gives them and `notes` a line for each tempo change written otherwise than the song makes it, or `{:error, message}`.
  """
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    with {:ok, {fifths, mode} = key} <- MusicXML.key(Keyword.get(opts, :key, "c")),
         :ok <- Page.check(out, Keyword.get(opts, :force, false)),
         {:ok, song} <- Song.load(path),
         {:ok, {beats, type}} <- MusicXML.song_time(song, opts),
         {:ok, parts, left_out} <- MusicXML.parts(song, path) do
      length = parts |> Enum.map(&elem(&1, 2)) |> Enum.max(fn -> 0 end)
      title = Keyword.get_lazy(opts, :title, fn -> MusicXML.title(path) end)
      us = round(60_000_000 / song.tempo)
      power = type |> :math.log2() |> round()
      minor = if mode == "minor", do: 1, else: 0
      ending = ticks(length)
      changes = tempo_changes(song)

      tempos =
        for {beat, bpm, _over} <- changes,
            do: {ticks(beat), 0, meta(0x51, <<round(60_000_000 / bpm)::24>>)}

      ramps =
        for {beat, bpm, over} <- changes, over > 0 do
          "the tempo's move to #{bpm} over #{over} beats from beat #{beat} is written as a change at once"
        end

      conductor =
        track(
          [
            {0, 0, meta(0x03, title)},
            {0, 0, meta(0x51, <<us::24>>)},
            {0, 0, meta(0x58, <<beats, power, 24, 8>>)},
            {0, 0, meta(0x59, <<fifths::signed-8, minor>>)}
            | tempos
          ],
          ending
        )

      channels = Enum.reject(0..15, &(&1 == @drums))

      tracks =
        parts
        |> Enum.with_index()
        |> Enum.map(fn {{name, notes, _beats, vels}, index} ->
          channel = Enum.at(channels, rem(index, length(channels)))

          events =
            notes
            |> Enum.zip(vels)
            |> Enum.flat_map(fn {{beat, note, held}, vel} ->
              key = note |> round() |> max(0) |> min(127)
              velocity = (vel || 0.6) |> Kernel.*(127) |> round() |> max(1) |> min(127)
              start = ticks(beat)
              stop = max(ticks(beat + held), start + 1)

              [
                {start, 2, <<0x90 + channel, key, velocity>>},
                {stop, 1, <<0x80 + channel, key, 0>>}
              ]
            end)

          track([{0, 0, meta(0x03, name)} | events], ending)
        end)

      header = <<"MThd", 6::32, 1::16, length(tracks) + 1::16, @ticks::16>>
      File.write!(out, [header, conductor | tracks])

      {:ok,
       %{
         parts: Enum.map(parts, fn {name, notes, _, _} -> MusicXML.summary(name, notes, key) end),
         left_out: left_out,
         notes: ramps
       }}
    end
  end

  # The tempo changes of the song's music once through, as {beat, bpm, over} from its start.
  defp tempo_changes(%Song{tempos: nil}), do: []

  defp tempo_changes(%Song{tempos: %{sections: sections, lengths: lengths}}) do
    {changes, _start} =
      sections
      |> Tuple.to_list()
      |> Enum.zip(Tuple.to_list(lengths))
      |> Enum.flat_map_reduce(0, fn
        {_changes, _length}, :infinity ->
          {[], :infinity}

        {changes, length}, start ->
          next = if length == :infinity, do: :infinity, else: start + length
          {for({beat, bpm, over} <- changes, do: {start + beat, bpm, over}), next}
      end)

    changes
  end

  defp ticks(beats), do: round(beats * @ticks)

  defp meta(type, payload), do: <<0xFF, type>> <> vlq(byte_size(payload)) <> payload

  # A track's events as {tick, order, bytes}, a note's end before another's start at the same
  # tick, and its end no earlier than the song's.
  defp track(events, ending) do
    events = Enum.sort_by(events, fn {tick, order, _bytes} -> {tick, order} end)
    last = events |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 0 end)

    {body, _tick} =
      Enum.map_reduce(events ++ [{max(last, ending), 3, <<0xFF, 0x2F, 0>>}], 0, fn {tick, _order,
                                                                                    bytes},
                                                                                   previous ->
        {[vlq(tick - previous), bytes], tick}
      end)

    body = IO.iodata_to_binary(body)
    <<"MTrk", byte_size(body)::32, body::binary>>
  end

  defp vlq(value), do: vlq(value >>> 7, <<value &&& 0x7F>>)
  defp vlq(0, bytes), do: bytes
  defp vlq(value, bytes), do: vlq(value >>> 7, <<(value &&& 0x7F) ||| 0x80>> <> bytes)
end
