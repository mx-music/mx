defmodule Mx.Timeline do
  @moduledoc """
  Every step a song sends in a span, each loop's or part's steps at their beats from the start of the song, with each note's options as the engine gets them, so a song written two ways can be compared note for note.
  """

  alias Mx.{Pass, Song, Synths}

  @doc "Each loop's steps over its first passes, and the beats those passes last, by the loop's name."
  def by_passes(path, passes) when is_integer(passes) do
    with_song(path, fn song ->
      for loop <- song.loops, loop.on == nil, into: %{} do
        {events, beats} =
          Enum.reduce(0..(passes - 1), {[], 0}, fn pass, {events, start} ->
            {played, beats} = pass_events(loop, pass)
            {events ++ shift(played, start), start + beats}
          end)

        {loop.name, {normalize(events, loop), beats}}
      end
    end)
  end

  @doc "Each loop's steps until the beats given for its name, by the loop's name."
  def by_beats(path, spans) when is_map(spans) do
    with_song(path, fn song ->
      for loop <- song.loops, loop.on == nil, into: %{} do
        span = Map.get(spans, loop.name, 0)
        {loop.name, {normalize(events_until(loop, span), loop), span}}
      end
    end)
  end

  defp events_until(loop, span) do
    0
    |> Stream.iterate(&(&1 + 1))
    |> Enum.reduce_while({[], 0}, fn pass, {events, start} ->
      if start >= span or (loop.passes != nil and pass >= loop.passes) do
        {:halt, {events, start}}
      else
        {played, beats} = pass_events(loop, pass)
        {:cont, {events ++ shift(played, start), start + beats}}
      end
    end)
    |> elem(0)
    |> Enum.filter(fn {beat, _, _} -> beat < span end)
  end

  defp with_song(path, fun) do
    {:ok, song} = Song.load(path)
    fun.(song)
  end

  defp pass_events(loop, pass) do
    {:ok, %{events: events, beats: beats}} = Pass.events(loop, pass)

    # A control names sounds by their place in the pass, which differs between notations, so it
    # names them by beat and note.
    indexed = events |> Enum.with_index(fn event, index -> {index, event} end) |> Map.new()

    events =
      Enum.map(events, fn
        {beat, {:control, {:sounds, indexes}, synth}, opts} ->
          sounds =
            for index <- indexes, {at, note, _} <- [indexed[index]], do: {round_beat(at), note}

          {beat, {:control, sounds, synth}, opts}

        event ->
          event
      end)

    {events, beats}
  end

  defp shift(events, start) do
    Enum.map(events, fn {beat, step, opts} -> {beat + start, step, opts} end)
  end

  defp normalize(events, loop) do
    events
    |> Enum.map(fn {beat, step, opts} ->
      {round_beat(beat), step(step), options(step, opts, loop)}
    end)
    |> Enum.sort()
  end

  defp step({:sample, ref, _path}), do: {:sample, ref}
  defp step(note) when is_number(note), do: round_beat(note)
  defp step(step), do: step

  defp options({:sample, _ref, _path}, opts, _loop), do: seconds(:stereo_player, opts)

  defp options(note, opts, loop) when is_number(note) or note == :own_note do
    seconds(loop.synth, opts)
  end

  defp options(_step, opts, _loop), do: Enum.sort(opts)

  defp seconds(synth, opts) do
    synth
    |> Synths.to_seconds(opts, 60)
    |> Enum.map(fn {key, value} ->
      {key, if(is_float(value), do: Float.round(value, 6), else: value)}
    end)
    |> Enum.sort()
  end

  defp round_beat(beat), do: Float.round(beat / 1, 6)
end
