defmodule Mx.MIDI do
  @moduledoc """
  Reads a Standard MIDI File as a score for `mix mx.import`, and writes a song as one for `mix mx.export`.

  A file read becomes a `Mx.Score`: each track that plays notes is a part, named after the track or numbered among the tracks that play notes, and a file whose notes all lie in one track gives a part for each channel instead.
  Note starts and ends move to the nearest step of the grid, and notes of a part that start and end together are a chord, while notes that overlap otherwise go to as few voices as the overlaps need.
  The first tempo is the score's, and its time signatures cut the bars, 4/4 when it has none.
  Notes on channel 10, which General MIDI keeps for drums, the sustain pedal, other controllers and later tempo changes are left out, and the score names them in `left_out`.

  A file written holds a first track with the song's tempo, time signature and key, then one track per part that plays notes with a pitch, named after the part, each on its own channel, without channel 10.
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
        {[], left_out} ->
          {:error, sentence_error(path, left_out)}

        {parts, left_out} ->
          to_score(midi, parts, left_out, grid)
      end
    end
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
  # what is left out of the parts.
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

        left_out =
          Enum.flat_map(parts, &controls_left_out/1) ++
            if(@drums in channels,
              do: ["the notes on channel 10, which General MIDI keeps for drums, are left out"],
              else: []
            )

        {Enum.map(parts, &strip/1), left_out ++ tempo_left_out(midi)}

      playing ->
        {parts, left_out} =
          playing
          |> Enum.with_index(1)
          |> Enum.map_reduce([], fn {{name, notes, controls}, index}, left_out ->
            name = name || "track #{index}"
            pitched = Enum.reject(notes, &(elem(&1, 0) == @drums))

            cond do
              pitched == [] ->
                {nil,
                 left_out ++
                   [
                     "#{name} is left out: it plays only on channel 10, which General MIDI keeps for drums"
                   ]}

              pitched != notes ->
                part = {name, pitched, controls}

                drums =
                  "#{name}: its notes on channel 10, which General MIDI keeps for drums, are left out"

                {part, left_out ++ [drums | controls_left_out(part)]}

              true ->
                part = {name, notes, controls}
                {part, left_out ++ controls_left_out(part)}
            end
          end)

        {parts |> Enum.reject(&is_nil/1) |> Enum.map(&strip/1), left_out ++ tempo_left_out(midi)}
    end
  end

  defp strip({name, notes, _controls}) do
    {name,
     Enum.map(notes, fn {_channel, start, stop, key, velocity} -> {start, stop, key, velocity} end)}
  end

  defp controls_left_out({name, _notes, controls}) do
    numbers = controls |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    case {@pedal in numbers, Enum.any?(numbers, &(&1 != @pedal))} do
      {true, true} -> ["#{name}: the sustain pedal and other controllers are left out"]
      {true, false} -> ["#{name}: the sustain pedal is left out"]
      {false, true} -> ["#{name}: its controllers are left out"]
      {false, false} -> []
    end
  end

  defp tempo_left_out(midi) do
    changes =
      midi.tracks
      |> Enum.flat_map(&tempos/1)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))
      |> Enum.dedup()

    case changes do
      [_first, _second | _] -> ["the tempo changes after the first are left out"]
      _one -> []
    end
  end

  defp name(events) do
    Enum.find_value(events, fn
      {_tick, {:meta, 0x03, name}} -> if String.trim(name) != "", do: String.trim(name)
      _other -> nil
    end)
  end

  defp controls(events) do
    for {_tick, {:control, channel, number, _value}} <- events, do: {channel, number}
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

  defp tempos(events), do: for({tick, {:meta, 0x51, <<us::24>>}} <- events, do: {tick, us})

  defp to_score(midi, parts, left_out, {count, division}) do
    tpq = midi.division
    events = Enum.concat(midi.tracks)
    step = div(4 * count * unit(division), division)
    units = unit(division)
    at = fn tick -> round(tick * units / tpq / step) * step end

    tempo =
      case events |> Enum.flat_map(&tempo_event/1) |> Enum.sort_by(&elem(&1, 0)) do
        [] -> 120
        [{_tick, us} | _] -> bpm(us)
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

    {:ok, %{Score.build(parts, title) | left_out: left_out}}
  end

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

  defp drop_passed([_current, {at, _} = next | rest], from) when at <= from,
    do: drop_passed([next | rest], from)

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
  Returns `{:ok, %{parts: parts, left_out: left_out}}` as `Mx.MusicXML.write/3` does, or `{:error, message}`.
  """
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    with {:ok, {beats, type}} <- MusicXML.time(Keyword.get(opts, :time, "4/4")),
         {:ok, {fifths, mode} = key} <- MusicXML.key(Keyword.get(opts, :key, "c")),
         :ok <- Page.check(out, Keyword.get(opts, :force, false)),
         {:ok, song} <- Song.load(path),
         {:ok, parts, left_out} <- MusicXML.parts(song, path) do
      length = parts |> Enum.map(&elem(&1, 2)) |> Enum.max(fn -> 0 end)
      title = Keyword.get_lazy(opts, :title, fn -> MusicXML.title(path) end)
      us = round(60_000_000 / song.tempo)
      power = type |> :math.log2() |> round()
      minor = if mode == "minor", do: 1, else: 0
      ending = ticks(length)

      conductor =
        track(
          [
            {0, 0, meta(0x03, title)},
            {0, 0, meta(0x51, <<us::24>>)},
            {0, 0, meta(0x58, <<beats, power, 24, 8>>)},
            {0, 0, meta(0x59, <<fifths::signed-8, minor>>)}
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
         left_out: left_out
       }}
    end
  end

  defp ticks(beats), do: round(beats * @ticks)

  defp meta(type, payload), do: <<0xFF, type>> <> vlq(byte_size(payload)) <> payload

  # A track's events as {tick, order, bytes}, a note's end before another's start at the same tick,
  # and its end no earlier than the song's.
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
