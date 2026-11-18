defmodule Mx.Band do
  @moduledoc """
  Plays a song's loops together, each in its own process, against one shared beat.

  The band keeps the tempo timeline, as `Mx.Tempo` describes it.
  Every loop works out the real time of its notes from that timeline, so loops of any length keep their place against the same beat.
  A saved version with a new tempo starts it on the first whole beat after the notes already sent, so every loop changes on that beat.
  The tempo changes a song's music writes go on the timeline when the first loop cues the pass they are in, before any loop sends a note of that pass.

  When the song changes, a changed loop takes over at the end of its own pass, a new loop starts on the next beat, and a removed loop stops at the end of its pass, unless it is added back before then, when it takes over at that end as a changed loop does.
  The band starts a loop again when its process fails.
  Given `subscribe`, it subscribes to the inputs, and passes each one to the loops whose `on:` waits for it.
  Each version's live audio goes to `live`, which starts, changes and stops it.
  Each version of the song goes through `prepare` first, which loads its samples, so playing starts only once they are ready.
  When every loop has played its last pass, the band calls `on_end`.
  Given `from`, a beat of the song, each loop starts in the pass that holds that beat and plays it from there, so that beat sounds first; a loop whose passes end before it does not start.
  A part a new version of a song written as music adds joins at the next section, with the pass number the other parts play there.
  Every loop with a start beat is handed to `worked_out` with that beat before any loop works out a pass, so no loop's pass reads the shared values before the other loops' set steps are in.
  """

  use GenServer

  alias Mx.Loop

  @doc "Starts the band with the `:song` in `opts`, the `:play` function its notes go to the engine through, as `c:Mx.Engine.play/2` takes them, an optional `:new_id` as `c:Mx.Engine.new_id/0`, optional functions for samples, effects, inputs and live audio, and an optional `:name`."
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @doc "Hands the band a new version of the song, which takes over loop by loop at the end of each one's pass."
  def switch(band, %Mx.Song{} = song) when is_pid(band) or is_atom(band) do
    GenServer.cast(band, {:switch, song})
  end

  @doc "The processes of the loops playing, stopping or waiting to join."
  def loops(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :loops)

  @doc "Sends the calling process where the beat is, as `{:mx_beat, message}`, now and whenever it changes, and `{:mx_beat, :stopped}` when the band stops; `Mx.Beat` says what a message holds."
  def follow(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :follow)

  @doc "The tempo timeline, the latest entry first."
  def timeline(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :timeline)

  @doc "Tells the band that the loop `name` starts a pass at `beat`, so the parts waiting to join start with it and the pass's tempo changes go on the timeline; returns the timeline."
  def cue(band, name, beat, pass \\ 0)
      when (is_pid(band) or is_atom(band)) and is_atom(name) and is_number(beat) and
             is_integer(pass) do
    GenServer.call(band, {:cue, name, beat, pass})
  end

  @doc "The real time, in microseconds, of a beat on a timeline, as `Mx.Tempo.time_at/2` works it out."
  defdelegate time_at(timeline, beat), to: Mx.Tempo

  @doc "The tempo in beats per minute at a beat on a timeline, as `Mx.Tempo.tempo_at/2` works it out."
  defdelegate tempo_at(timeline, beat), to: Mx.Tempo

  @doc "The beat at a real time, in microseconds, on a timeline, as `Mx.Tempo.beat_at/2` works it out."
  defdelegate beat_at(timeline, us), to: Mx.Tempo

  @impl true
  def init(opts) when is_list(opts) do
    Process.flag(:trap_exit, true)
    prepare = Keyword.get(opts, :prepare, & &1)
    song = prepare.(Keyword.fetch!(opts, :song))
    ahead_us = Keyword.get(opts, :ahead_ms, 500) * 1000
    start_us = Keyword.get_lazy(opts, :start_us, fn -> now() + ahead_us end)

    state = %{
      song: song,
      play: Keyword.fetch!(opts, :play),
      ahead_us: ahead_us,
      prepare: prepare,
      load_sample: Keyword.get(opts, :load_sample, fn _path, _loop -> :ok end),
      loop_opts:
        Keyword.take(opts, [:new_id, :start_fx, :stop_fx, :out, :inputs, :set, :worked_out]),
      timeline: Mx.Tempo.new(song.tempo, start_us),
      tempo_pass: -1,
      on_end: Keyword.get(opts, :on_end, fn -> :ok end),
      joining: %{},
      loops: %{},
      stopping: %{},
      delay_us: Keyword.get(opts, :delay, fn _band -> 0 end).(self()),
      followers: Keyword.get(opts, :follow, []),
      told: []
    }

    if subscribe = opts[:subscribe], do: subscribe.(self())
    state = Map.put(state, :live, Keyword.get(opts, :live, fn _lives, _tempo -> :ok end))
    state.live.(song.live, song.tempo)
    from = Keyword.get(opts, :from, 0)
    {:ok, tell(start_loops(state, Enum.flat_map(song.loops, &place(&1, from))))}
  end

  @impl true
  def handle_call(:timeline, {_, _}, %{} = state), do: {:reply, state.timeline, state}

  def handle_call(:follow, {pid, _}, %{} = state) do
    Process.monitor(pid)
    for message <- messages(state), do: send(pid, {:mx_beat, message})
    {:reply, :ok, %{state | followers: [pid | state.followers]}}
  end

  def handle_call(:loops, {_, _}, %{} = state) do
    pids = Map.values(state.loops) ++ Map.values(state.stopping) ++ Map.values(state.joining)
    {:reply, pids, state}
  end

  def handle_call({:cue, name, beat, pass}, {_, _}, %{} = state) do
    if music?(state.song, name) do
      for {_, pid} <- state.joining, do: send(pid, {:join, beat, pass})
      state = %{state | joining: %{}}

      state =
        if pass > state.tempo_pass and sections?(state.song, name) do
          tell(put_changes(state, beat, pass))
        else
          state
        end

      {:reply, state.timeline, state}
    else
      {:reply, state.timeline, state}
    end
  end

  @impl true
  def handle_cast({:switch, song}, %{} = state) do
    song = state.prepare.(song)
    state = if song.tempo != state.song.tempo, do: tell(retempo(state, song.tempo)), else: state
    state.live.(song.live, song.tempo)
    names = Enum.map(song.loops, & &1.name)

    removed = Map.drop(state.loops, names)
    Enum.each(removed, fn {_, pid} -> Loop.stop(pid) end)
    stopping = Map.merge(state.stopping, removed)
    state = %{state | song: song, loops: Map.take(state.loops, names), stopping: stopping}

    state =
      Enum.reduce(song.loops, state, fn loop, state ->
        case Map.fetch(state.loops, loop.name) do
          {:ok, pid} ->
            Loop.switch(pid, loop)
            state

          :error ->
            add_loop(state, loop)
        end
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:input, {kind, input}}, %{} = state) do
    for %{on: on, name: name} <- state.song.loops,
        on == kind or on == {:osc, input[:address]},
        {^name, pid} <- state.loops,
        do: send(pid, {:trigger, input})

    {:noreply, state}
  end

  def handle_info({:mx_delay, delay_us}, %{} = state) do
    {:noreply, tell(%{state | delay_us: delay_us})}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{} = state) do
    {:noreply, %{state | followers: List.delete(state.followers, pid)}}
  end

  def handle_info({:EXIT, pid, reason}, %{} = state) do
    stopping = Map.reject(state.stopping, fn {_, stopping_pid} -> stopping_pid == pid end)
    state = %{state | stopping: stopping}

    case Enum.find(state.loops, fn {_, loop_pid} -> loop_pid == pid end) do
      {name, _} when reason == {:shutdown, :ended} ->
        state = %{state | loops: Map.delete(state.loops, name)}
        if state.loops == %{} and state.stopping == %{}, do: state.on_end.()
        {:noreply, state}

      # It stopped before the version that added it back reached it.
      {name, _} when reason == :normal ->
        loop = Enum.find(state.song.loops, &(&1.name == name))
        {:noreply, start_loops(state, [{loop, later_start(state, loop)}])}

      {name, _} ->
        IO.puts(:stderr, "loop #{name} failed and starts again: #{inspect(reason)}")
        loop = Enum.find(state.song.loops, &(&1.name == name))
        {:noreply, start_loops(state, [{loop, later_start(state, loop)}])}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, %{} = state) do
    for pid <- state.followers, do: send(pid, {:mx_beat, :stopped})
    :ok
  end

  defp messages(state), do: Mx.Beat.messages(state.timeline, state.delay_us, now())

  # Sends the followers each message they were not sent yet.
  defp tell(state) do
    messages = messages(state)

    for message <- messages -- state.told,
        pid <- state.followers,
        do: send(pid, {:mx_beat, message})

    %{state | told: messages}
  end

  # A loop added back while its removed version finishes its pass takes over from that version.
  defp add_loop(state, loop) do
    case Map.pop(state.stopping, loop.name) do
      {nil, _} ->
        start_loops(state, [{loop, later_start(state, loop)}])

      {pid, stopping} ->
        Loop.switch(pid, loop)
        %{state | loops: Map.put(state.loops, loop.name, pid), stopping: stopping}
    end
  end

  # Each loop works out its first pass only once every loop is followed for the shared values.
  defp start_loops(state, starts) do
    worked_out = Keyword.get(state.loop_opts, :worked_out, fn _pid, _beat -> :ok end)

    starts =
      Enum.map(starts, fn
        {loop, start} -> {loop, start, []}
        start -> start
      end)

    state =
      Enum.reduce(starts, state, fn {loop, start, from}, state ->
        start_loop(state, loop, start, from)
      end)

    pids = for {loop, start, _} <- starts, do: {state.loops[loop.name], start, loop.on}
    for {pid, start, nil} <- pids, is_number(start), do: worked_out.(pid, start)

    # A render ticks every loop itself, one at a time, so their notes reach the engine in the same
    # order on every run.
    if not Mx.Clock.rendering?() do
      for {pid, _, _} <- pids, do: send(pid, :tick)
    end

    state
  end

  defp start_loop(state, loop, start, from) do
    opts =
      [
        loop: loop,
        band: self(),
        play: state.play,
        ahead_us: state.ahead_us,
        start: start,
        load_sample: state.load_sample
      ] ++ from ++ state.loop_opts

    {:ok, pid} = Loop.start_link(opts)
    state = put_in(state.loops[loop.name], pid)
    if start == :join, do: put_in(state.joining[loop.name], pid), else: state
  end

  # The pass holding the beat, started that far into it before beat 0, so the beat falls on 0.
  defp place(loop, from) when from == 0 or loop.on != nil, do: [{loop, 0}]

  defp place(loop, from) do
    0
    |> Stream.iterate(&(&1 + 1))
    |> Stream.take_while(&(loop.passes == nil or &1 < loop.passes))
    |> Enum.reduce_while({0, []}, fn pass, {start, []} ->
      case Mx.Pass.events(loop, pass) do
        {:ok, %{beats: beats}} when start + beats <= from and beats > 0 ->
          {:cont, {start + beats, []}}

        _within ->
          skip = from - start
          {:halt, {start, [{loop, -skip, pass: pass, skip: skip}]}}
      end
    end)
    |> elem(1)
  end

  # A part of a song written as music joins at the next section, the next pass another part
  # starts.
  defp later_start(state, %{music: music, name: name}) when music != nil do
    playing =
      Enum.any?(state.loops, fn {other, _} -> other != name and music?(state.song, other) end)

    if playing, do: :join, else: next_beat(state)
  end

  defp later_start(state, _loop), do: next_beat(state)

  defp music?(song, name), do: Enum.any?(song.loops, &(&1.name == name and &1.music != nil))

  # A loop started by input numbers its own passes, which are not the song's sections.
  defp sections?(song, name), do: Enum.any?(song.loops, &(&1.name == name and &1.on == nil))

  defp retempo(state, tempo) do
    %{state | timeline: Mx.Tempo.put(state.timeline, next_beat(state), tempo, 0)}
  end

  defp put_changes(state, start, pass) do
    timeline =
      Enum.reduce(Mx.Tempo.changes(state.song.tempos, pass), state.timeline, fn
        {beat, bpm, over}, timeline -> Mx.Tempo.put(timeline, start + beat, bpm, over)
      end)

    %{state | timeline: timeline, tempo_pass: pass}
  end

  # The first whole beat after every note a loop may already have sent.
  defp next_beat(state) do
    floor(beat_at(state.timeline, now() + state.ahead_us)) + 1
  end

  defp now, do: Mx.Clock.now()
end
