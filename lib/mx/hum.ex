defmodule Mx.Hum do
  @moduledoc """
  Turns a recording of one voice humming, singing or whistling a melody into notes on beats, and writes them as a song.

  The recording is filtered below 7 kHz and resampled to 16 kHz, and its pitch is followed every 10 ms over 30 ms frames, from 60 Hz to 2500 Hz, which takes in a low hum and a high whistle, with YIN, from de Cheveigné and Kawahara's paper of 2002.
  A frame has a pitch when YIN finds it periodic and the 10 ms at its middle are no more than 35 dB below the loudest frame and 20 dB below the loudest within 200 ms, so breath, clicks and noise have none, and neither does a dip between two notes sung at one pitch.

  The pitch curve is cut into notes by the cheapest path through silence and the semitones, frame by frame, as Tony's note model does.
  A frame costs the square of its distance from the semitone, up to a cap, and moving to another note costs more than a vibrato or a quick slide spends away from it, so a note held with vibrato stays one note, at the semitone it centres on, and a slide is the note it starts on and the note it lands on.
  A frame without pitch costs a note more than it costs silence, so a break of 30 ms or more in the voice ends a note, and two notes at one pitch with a break between them are two notes.
  A note starts with the pitched frames just before it that are on their way to it, as when a voice scoops up into a note.

  Notes are placed on quarter beats from the first, which starts on beat 0, or from `beat_0:`, the seconds into the recording beat 0 falls on, when the recording was made against a click; a note that starts before beat 0 is then left out.
  A voice or a player lets go of a note before its length is up, so a note's end is taken a tenth of a beat later before it is placed.
  A sound shorter than an eighth of a beat is left out, a silence of a quarter beat or less between two notes is the breath between them, so the first note lasts until the second, and the melody lasts until the end of the bar of 4 beats its last note ends in.
  The melody plays again from there, so the last note lasts until the end of the bar too when a quarter beat or less is left.
  """

  alias Mx.{Measure, Signal}

  @rate 16_000
  @hop 160
  @window 480
  @lowest_hz 60
  @highest_hz 2500
  @threshold 0.15
  @aperiodic 0.35
  @floor_db -35
  @dip_db -20
  @around 20

  @spread 0.35
  @cap 4.0
  @unpitched 2.5
  @pitched_silence 4.0
  @change 10.0
  @let_go 0.1
  @silence_change 3.0

  @doc """
  The notes of a recording at a tempo, as `%{notes: notes, beats: beats, left_out: count}`.
  Each note is `{beat, note, beats}`, `beats` is how long the melody lasts, and `left_out` counts the notes that started before `beat_0:`.
  """
  def transcribe(samples, rate, tempo, opts \\ [])
      when is_list(samples) and is_integer(rate) and is_number(tempo) and tempo > 0 and
             is_list(opts) do
    samples
    |> pitches(rate)
    |> notes()
    |> place(60 / tempo, opts[:beat_0])
  end

  @doc "The pitch of each 10 ms frame as a fractional MIDI note, or nil where it has none."
  def pitches(samples, rate) when is_list(samples) and is_integer(rate) do
    sound = samples |> resample(rate) |> List.to_tuple()
    longest = div(@rate, @lowest_hz)
    shortest = div(@rate, @highest_hz)
    starts = 0..(tuple_size(sound) - @window - longest - 1)//@hop

    levels = Enum.map(starts, &level(sound, &1 + div(@window - @hop, 2)))
    loudest = Enum.max(levels, fn -> 0.0 end)
    floor = loudest * 10 ** (@floor_db / 20)
    around = levels |> List.to_tuple() |> nearby_peaks()

    [starts, levels, around]
    |> Enum.zip_with(fn [start, level, peak] ->
      if level > 0 and level >= floor and level >= peak * 10 ** (@dip_db / 20),
        do: pitch(sound, start, shortest, longest)
    end)
  end

  @doc "The notes a pitch curve holds, as `{first_frame, frames, note}`."
  def notes(pitches) when is_list(pitches) do
    case Enum.reject(pitches, &is_nil/1) do
      [] ->
        []

      pitched ->
        states = [
          :silence | Enum.to_list((floor(Enum.min(pitched)) - 1)..(ceil(Enum.max(pitched)) + 1))
        ]

        runs =
          pitches
          |> path(List.to_tuple(states))
          |> Enum.zip(pitches)
          |> Enum.with_index()
          |> Enum.chunk_by(fn {{state, _}, _} -> state end)

        [[] | runs]
        |> Enum.zip(runs)
        |> Enum.flat_map(fn
          {_, [{{:silence, _}, _} | _]} -> []
          {before, [{{note, _}, first} | _] = run} -> [note(before, first, length(run), note)]
        end)
    end
  end

  # Pitched frames the path left as silence just before a note are the voice reaching for it.
  defp note([{{:silence, _}, _} | _] = before, first, frames, note) do
    reach =
      before |> Enum.reverse() |> Enum.take_while(fn {{_, pitch}, _} -> pitch end) |> length()

    {first - reach, frames + reach, note}
  end

  defp note(_before, first, frames, note), do: {first, frames, note}

  @doc "Checks a song can be written to a path: `:ok`, or `{:error, message}` naming it when it exists without `force`."
  def check(out, force) when is_binary(out) and is_boolean(force) do
    if File.exists?(out) and not force,
      do: {:error, "#{out} already exists; give --force to write over it"},
      else: :ok
  end

  @doc "Writes notes to a song file, and returns the line saying where, how many notes, and their lowest and highest."
  def write(out, notes, beats, tempo) when is_binary(out) and is_list(notes) do
    File.write!(out, song(notes, beats, tempo))
    {lowest, highest} = notes |> Enum.map(&elem(&1, 1)) |> Enum.min_max()
    count = length(notes)
    unit = if count == 1, do: "note", else: "notes"
    lowest = Measure.name(lowest)
    highest = Measure.name(highest)
    "Wrote #{out}: #{count} #{unit}, from #{lowest} to #{highest}."
  end

  @doc "Writes notes as a song file's text: the tempo, and one part, hum, playing them again and again."
  def song(notes, beats, tempo) when is_list(notes) and is_number(beats) and is_number(tempo) do
    {items, last} =
      Enum.flat_map_reduce(notes, 0, fn {beat, note, held}, at ->
        rest = if beat > at, do: ["r: #{number(beat - at)}"], else: []
        {rest ++ ["#{Measure.name(note)}: #{number(held)}"], beat + held}
      end)

    items = if beats > last, do: items ++ ["r: #{number(beats - last)}"], else: items
    tempo = number(tempo)
    seq = Enum.join(items, ", ")
    text = "import Mx\n\nsong(tempo: #{tempo}, music: repeat(part(:hum, seq(#{seq}))))\n"
    IO.iodata_to_binary([Code.format_string!(text), "\n"])
  end

  defp resample(samples, rate) do
    filtered = Signal.low_pass(samples, rate, 7000) |> List.to_tuple()
    count = floor((tuple_size(filtered) - 1) * @rate / rate)

    for index <- 0..count//1 do
      at = index * rate / @rate
      before = trunc(at)
      after_ = min(before + 1, tuple_size(filtered) - 1)
      share = at - before
      elem(filtered, before) * (1 - share) + elem(filtered, after_) * share
    end
  end

  defp level(sound, start) do
    sum = Enum.reduce(start..(start + @hop - 1), 0.0, &(elem(sound, &1) ** 2 + &2))
    :math.sqrt(sum / @hop)
  end

  defp nearby_peaks(levels) do
    last = tuple_size(levels) - 1

    for index <- 0..last//1 do
      Enum.max(
        for near <- max(index - @around, 0)..min(index + @around, last), do: elem(levels, near)
      )
    end
  end

  # YIN: the difference between the frame and itself shifted by each lag, each normalized by the mean of the differences up to it; the pitch is the first lag whose normalized difference dips below the threshold, refined between samples.
  defp pitch(sound, start, shortest, longest) do
    frame = for index <- start..(start + @window + longest - 1), do: elem(sound, index)
    own = Enum.take(frame, @window)

    {differences, _} =
      Enum.map_reduce(1..longest, tl(frame), fn _, shifted ->
        difference = Enum.zip_reduce(own, shifted, 0.0, fn a, b, sum -> sum + (a - b) ** 2 end)
        {difference, tl(shifted)}
      end)

    {normalized, _} =
      differences
      |> Enum.with_index(1)
      |> Enum.map_reduce(0.0, fn {difference, lag}, sum ->
        sum = sum + difference
        {if(sum > 0, do: difference * lag / sum, else: 1.0), sum}
      end)

    normalized = List.to_tuple([1.0 | normalized])
    lag = dip(normalized, shortest, longest)

    if elem(normalized, lag) <= @aperiodic do
      lag = refine(normalized, lag, longest)
      69 + 12 * :math.log2(@rate / lag / 440)
    end
  end

  defp dip(normalized, shortest, longest) do
    case Enum.find(shortest..longest, &(elem(normalized, &1) < @threshold)) do
      nil -> Enum.min_by(shortest..longest, &elem(normalized, &1))
      lag -> descend(normalized, lag, longest)
    end
  end

  defp descend(normalized, lag, longest) do
    if lag < longest and elem(normalized, lag + 1) < elem(normalized, lag),
      do: descend(normalized, lag + 1, longest),
      else: lag
  end

  defp refine(normalized, lag, longest) when lag > 1 and lag < longest do
    {a, b, c} = {elem(normalized, lag - 1), elem(normalized, lag), elem(normalized, lag + 1)}
    curve = a - 2 * b + c
    if curve > 0, do: lag + (a - c) / (2 * curve), else: lag
  end

  defp refine(_normalized, lag, _longest), do: lag

  # Viterbi through the states, keeping for each frame the cheapest way to reach each state.
  defp path(pitches, states) do
    count = tuple_size(states)
    start = Tuple.duplicate(0.0, count)

    {costs, pointers} =
      Enum.reduce(pitches, {start, []}, fn pitch, {costs, pointers} ->
        best = best_notes(costs)

        {step, from} =
          for state <- 0..(count - 1) do
            {before, from} = cheapest_way(costs, state, best)
            {before + cost(elem(states, state), pitch), from}
          end
          |> Enum.unzip()

        {List.to_tuple(step), [List.to_tuple(from) | pointers]}
      end)

    last = Enum.min_by(0..(count - 1), &elem(costs, &1))

    {path, _} =
      Enum.map_reduce(pointers, last, fn from, state ->
        {elem(states, state), elem(from, state)}
      end)

    Enum.reverse(path)
  end

  # The two cheapest notes, so each note can come from the cheapest other one.
  defp best_notes(costs) do
    1..(tuple_size(costs) - 1)
    |> Enum.map(&{elem(costs, &1), &1})
    |> Enum.sort()
    |> Enum.take(2)
  end

  defp cheapest_way(costs, 0, [{best, from} | _]) do
    Enum.min([{elem(costs, 0), 0}, {best + @silence_change, from}])
  end

  defp cheapest_way(costs, state, best) do
    changes = for {cost, from} <- best, from != state, do: {cost + @change, from}
    Enum.min([{elem(costs, state), state}, {elem(costs, 0) + @silence_change, 0} | changes])
  end

  defp cost(:silence, nil), do: 0.0
  defp cost(:silence, _pitch), do: @pitched_silence
  defp cost(_note, nil), do: @unpitched
  defp cost(note, pitch), do: min(((pitch - note) / @spread) ** 2, @cap)

  defp place(notes, beat_seconds, beat_0) do
    frame_beats = @hop / @rate / beat_seconds
    kept = Enum.filter(notes, fn {_, frames, _} -> frames * frame_beats >= 0.125 end)

    # A frame's moment is its middle, which only matters against a click.
    origin =
      case {kept, beat_0} do
        {[{first, _, _} | _], nil} -> first
        {_, nil} -> 0
        _ -> (beat_0 * @rate - @window / 2) / @hop
      end

    quarters = fn frame, later -> round(((frame - origin) * frame_beats + later) * 4) / 4 end

    {early, placed} =
      kept
      |> Enum.map(fn {from, frames, note} ->
        beat = quarters.(from, 0)
        {beat, note, max(quarters.(from + frames, @let_go), beat + 0.25), frames}
      end)
      |> Enum.chunk_by(&elem(&1, 0))
      |> Enum.map(fn same_beat -> Enum.max_by(same_beat, &elem(&1, 3)) end)
      |> Enum.split_with(fn {beat, _, _, _} -> beat < 0 end)

    case placed do
      [] ->
        %{notes: [], beats: 0, left_out: length(early)}

      _ ->
        {_, _, ends, _} = List.last(placed)
        bar = ceil(ends / 4) * 4
        notes = join(placed ++ [{bar, nil, bar, 0}]) |> Enum.drop(-1)
        %{notes: notes, beats: bar, left_out: length(early)}
    end
  end

  # Each note ends where the next starts if it would run into it or leave no more than a quarter beat before it.
  defp join(notes) do
    notes
    |> Enum.zip(tl(notes) ++ [nil])
    |> Enum.map(fn
      {{beat, note, ends, _}, nil} ->
        {beat, note, ends - beat}

      {{beat, note, ends, _}, {next, _, _, _}} when next - ends <= 0.25 ->
        {beat, note, next - beat}

      {{beat, note, ends, _}, _} ->
        {beat, note, ends - beat}
    end)
  end

  defp number(value) when value == trunc(value), do: Integer.to_string(trunc(value))
  defp number(value), do: Float.to_string(value / 1)
end
