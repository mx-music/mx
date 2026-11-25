defmodule Mx.Performance do
  @moduledoc """
  Takes the timing and loudness of a recording of a score, for `mix mx.import --recording`.

  The recording is lined up against the score by the energy in each of the 12 pitch classes, frame by frame, so each moment of the score finds the moment of the recording that plays it.
  The song's tempo is the recording's average, rounded to a whole number of beats a minute, and each note starts and lasts as long as it does in the recording, in beats at that tempo, to the nearest 1/48 of a beat.
  A note's vel is the recording's loudness where it starts, the softest note start at 0.3 and the loudest at 1, in proportion to their loudness in decibels.
  """

  alias Mx.{Audio, Engine.Mxs.Native, Score}

  # Score frames are a tenth of a second apart at the score's tempo, and the recording may start
  # within its first 15 seconds.
  @hop 0.1
  @free 15.0
  # A stretch of score whose mean cost passes this, or that the recording plays at under half or
  # over 1.7 times the average speed, is music the two do not share.
  @parted_cost 0.55
  @slowest 0.5
  @fastest 1.7
  # Sound in the recording after the score ends, louder than 15 dB under the music's median level
  # for 3 seconds in all, is music the score does not have.
  @quieter 15
  @sound_after 3.0
  @grid 48

  @doc """
  The score retimed to `recording`, a WAV file, as `{:ok, %{score: score, tempo: tempo, bars: bars}}`, `bars` being each bar's number and the second it starts at in the recording, or `{:error, message}`.
  `bars:` a range of bar numbers lines the recording up with those bars only, and the score keeps those alone.
  """
  def retime(%Score{} = score, recording, opts \\ [])
      when is_binary(recording) and is_list(opts) do
    with :ok <- wav(recording),
         {:ok, score} <- keep_bars(score, opts[:bars]),
         :ok <- once(score),
         {:ok, format, data} <- Audio.raw(recording) do
      timeline = timeline(score)
      tempo = score.tempo || 60
      step = @hop * tempo / 60
      beats = timeline |> List.last() |> then(fn {_number, start, length} -> start + length end)
      frames = frames(score, timeline, step, beats)

      {seconds, costs, levels} =
        Native.align(data, native_format(format), format.rate / 1, frames, @hop, @free)

      at = second_at(List.to_tuple(seconds), step)

      if length(seconds) < length(frames) do
        played = (length(seconds) - 1) * step

        timeline =
          Enum.take_while(timeline, fn {_number, start, length} -> start + length <= played end)

        parted(timeline, costs, step, at, played, []) || ended(timeline, List.last(seconds))
      else
        parted(timeline, costs, step, at, beats, levels) ||
          performance(score, timeline, at, beats, levels)
      end
    end
  end

  defp wav(path) do
    if path |> Path.extname() |> String.downcase() == ".wav" do
      :ok
    else
      {:error, "give the recording as a WAV file, not #{path}"}
    end
  end

  defp keep_bars(score, nil), do: {:ok, score}

  defp keep_bars(score, first..last//_) do
    order = Enum.filter(score.order, &(&1 in first..last))

    if order == [] do
      {:error, "the score has no bars from #{first} to #{last}"}
    else
      {:ok, %{score | order: order, runs: [order]}}
    end
  end

  defp once(score) do
    if length(Enum.uniq(score.order)) == length(score.order) do
      :ok
    else
      {:error, "a score that repeats bars cannot take a recording's timing yet"}
    end
  end

  # Each bar in the order the score plays it, as {number, start, length} in beats.
  defp timeline(score) do
    lengths = Map.new(hd(score.parts).bars, &{&1.number, bar_length(&1)})

    {timeline, _end} =
      Enum.map_reduce(score.order, 0, fn number, start ->
        length = Map.fetch!(lengths, number)
        {{number, start, length}, start + length}
      end)

    timeline
  end

  defp bar_length(bar) do
    bar.voices
    |> Enum.map(fn voice -> Enum.sum_by(voice, & &1.length) end)
    |> Enum.max(fn -> 0 end)
  end

  # The notes sounding in each frame, counted by pitch class.
  defp frames(score, timeline, step, beats) do
    count = max(ceil(beats / step), 1)

    counts =
      for part <- score.parts,
          bars = Map.new(part.bars, &{&1.number, &1}),
          {number, start, _length} <- timeline,
          voice <- Map.fetch!(bars, number).voices,
          {group, onset} <- onsets(voice, start),
          note <- group.notes,
          frame <- trunc(onset / step)..(min(ceil((onset + group.length) / step), count) - 1)//1,
          reduce: %{} do
        counts -> Map.update(counts, {frame, rem(note.midi, 12)}, 1, &(&1 + 1))
      end

    for frame <- 0..(count - 1) do
      for class <- 0..11, do: Map.get(counts, {frame, class}, 0) / 1
    end
  end

  defp onsets(groups, start) do
    {onsets, _end} = Enum.map_reduce(groups, start, &{{&1, &2}, &2 + &1.length})
    onsets
  end

  # The second a beat of the score plays at, between the frames around it, and on at the last
  # frames' pace past them.
  defp second_at(seconds, step) do
    last = tuple_size(seconds) - 1

    fn beat ->
      position = beat / step
      low = position |> trunc() |> min(last - 1) |> max(0)
      high = min(low + 1, last)
      from = elem(seconds, low)
      from + (elem(seconds, high) - from) * (position - low)
    end
  end

  defp parted([], _costs, _step, _at, _beats, _levels), do: nil

  defp parted(timeline, costs, step, at, beats, levels) do
    costs = List.to_tuple(costs)
    pace = (at.(beats) - at.(0)) / beats

    bad =
      Enum.find(timeline, fn {_number, start, length} ->
        frames = trunc(start / step)..max(trunc((start + length) / step) - 1, trunc(start / step))

        mean =
          Enum.sum(for frame <- frames, frame < tuple_size(costs), do: elem(costs, frame)) /
            Enum.count(frames)

        speed = if length > 0, do: (at.(start + length) - at.(start)) / (length * pace), else: 1
        mean > @parted_cost or (length >= 2 and (speed < @slowest or speed > @fastest))
      end)

    cond do
      bad != nil ->
        {number, start, _length} = bad
        before = Enum.take_while(timeline, &(&1 != bad))
        parted = if before == [], do: number, else: before |> List.last() |> elem(0)
        parted_after(parted, at.(start))

      levels != [] and sound_after?(levels, at.(0), at.(beats)) ->
        {number, _start, _length} = List.last(timeline)
        parted_after(number, at.(beats))

      true ->
        nil
    end
  end

  # The recording ends at `second`, after the bars of `played`.
  defp ended(played, second) do
    {number, _start, _length} = List.last(played) || {0, 0, 0}
    parted_after(number, second)
  end

  defp parted_after(number, second) do
    {:error,
     "the recording and the score part ways after bar #{number}, at #{clock(second)} in the recording"}
  end

  defp sound_after?(levels, from, until) do
    slice = fn second -> trunc(second / 0.05) end
    music = Enum.slice(levels, slice.(from)..slice.(until))
    median = music |> Enum.sort() |> Enum.at(div(length(music), 2))
    after_music = Enum.drop(levels, slice.(until + 1.0))
    Enum.count(after_music, &(&1 > median - @quieter)) * 0.05 > @sound_after
  end

  defp clock(second) do
    whole = round(second)
    minutes = div(whole, 60)
    seconds = whole |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{minutes}:#{seconds}"
  end

  defp performance(score, timeline, at, beats, levels) do
    start = at.(0)
    tempo = round(beats / (at.(beats) - start) * 60)
    beat = fn written -> round((at.(written) - start) * tempo / 60 * @grid) / @grid end
    starts = Map.new(timeline, fn {number, start, _length} -> {number, start} end)
    loudness = loudness(levels)

    louds =
      for part <- score.parts,
          bar <- part.bars,
          Map.has_key?(starts, bar.number),
          voice <- bar.voices,
          {group, onset} <- onsets(voice, starts[bar.number]),
          Enum.any?(group.notes, &(not &1.continues)),
          do: loudness.(at.(onset))

    {softest, loudest} = Enum.min_max(louds, fn -> {0, 0} end)

    vel = fn loud ->
      if loudest > softest do
        Float.round(0.3 + 0.7 * (loud - softest) / (loudest - softest), 2)
      else
        1.0
      end
    end

    parts =
      for part <- score.parts do
        bars =
          for bar <- part.bars, Map.has_key?(starts, bar.number) do
            bar_start = starts[bar.number]

            voices =
              for voice <- bar.voices do
                for {group, onset} <- onsets(voice, bar_start) do
                  loud = onset |> at.() |> loudness.() |> vel.()

                  notes = Enum.map(group.notes, &played_at(&1, loud))

                  length = beat.(onset + group.length) - beat.(onset)
                  %{group | notes: notes, onset: beat.(onset) - beat.(bar_start), length: length}
                end
              end

            %{bar | voices: voices}
          end

        %{part | bars: bars, tempo: tempo}
      end

    bars = for {number, start, _length} <- timeline, do: {number, Float.round(at.(start), 2)}
    {:ok, %{score: %{score | parts: parts, tempo: tempo, tempos: []}, tempo: tempo, bars: bars}}
  end

  defp played_at(%{continues: true} = note, _vel), do: note
  defp played_at(note, vel), do: %{note | vel: vel}

  # The loudest of the recording's 50 ms levels from 50 ms before a second to 150 ms after it.
  defp loudness(levels) do
    levels = List.to_tuple(levels)
    last = tuple_size(levels) - 1

    fn second ->
      first = (trunc(second / 0.05) - 1) |> max(0) |> min(last)
      Enum.max(for slice <- first..min(first + 4, last), do: elem(levels, slice))
    end
  end

  defp native_format(%{kind: kind, bits: bits, channels: channels}) do
    {Atom.to_string(kind), bits, channels}
  end
end
