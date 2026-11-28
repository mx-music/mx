defmodule Mx.Band do
  @moduledoc """
  Plays a song's loops together, each in its own process, against one shared beat.

  The band keeps the tempo timeline, as `Mx.Tempo` describes it.
  Every loop works out the real time of its notes from that timeline, so loops of any length keep
  their place against the same beat.
  A saved version with a new tempo starts it on the first whole beat after the notes already sent,
  so every loop changes on that beat.
  The tempo changes a song's music writes go on the timeline when the first loop cues the pass
  they are in, before any loop sends a note of that pass.

  When the song changes, a changed loop takes over at the end of its own pass, a new loop starts
  on the next beat, and a removed loop stops at the end of its pass, unless it is added back
  before then, when it takes over at that end as a changed loop does.
  The band starts a loop again when its process fails.
  Given `subscribe`, it subscribes to the inputs, and passes each one to the loops whose `on:`
  waits for it.
  Each version's live audio goes to `live`, which starts, changes and stops it.
  Given `hand`, each loop hands the engine its passes whole, in beats, as `Mx.Loop` describes;
  `place_beats` is then given the real time of beat 0 as the band starts, and `set_tempo` each
  tempo that goes on the timeline with its beat, so the engine places the passes on the band's
  timeline.
  A saved version with a new tempo then starts it on the first whole beat more than 150 ms away.
  Given `share`, or once `scale_tempo/3` is called, the band plays every tempo of the song, the
  song's own and those its music writes, times that share; `check_share/1` says which shares it
  takes.
  Given `start_part`, each loop plays into a part of the engine by its name, which `mute/3` and
  `solo/2` silence through the `mute` and `solo` functions; a muted part plays on in its place,
  and stays muted through new versions of the song.
  Each version of the song goes through `prepare` first, which loads its samples, so playing
  starts only once they are ready.
  When every loop has played its last pass, the band calls `on_end`.
  Given `from`, a beat of the song, each loop starts in the pass that holds that beat and plays it
  from there, so that beat sounds first; a loop whose passes end before it does not start.
  A part a new version of a song written as music adds joins at the next section, with the pass
  number the other parts play there.
  Every loop with a start beat is handed to `worked_out` with that beat before any loop works out
  a pass, so no loop's pass reads the shared values before the other loops' set steps are in.
  `play_recording/4` plays a sample into a part's effects beside its notes, from the part's chain
  each loop sends the band as `{:part_chain, name, chain}` when it starts one.
  """

  use GenServer

  alias Mx.Loop

  # How far ahead of its sound the engine places an event it holds in beats.
  @tempo_lead_us 150_000

  @doc """
  Starts the band with the `:song` in `opts`, the `:play` function its notes go to the engine
  through, as `c:Mx.Engine.play/2` takes them, an optional `:new_id` as `c:Mx.Engine.new_id/0`,
  optional functions for samples, effects, inputs and live audio, and an optional `:name`.
  """
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @doc """
  Hands the band a new version of the song, which takes over loop by loop at the end of each one's
  pass.
  """
  def switch(band, %Mx.Song{} = song) when is_pid(band) or is_atom(band) do
    GenServer.cast(band, {:switch, song})
  end

  @doc "The processes of the loops playing, stopping or waiting to join."
  def loops(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :loops)

  @doc """
  Sends the calling process where the beat is, as `{:mx_beat, message}`, now and whenever it
  changes, and `{:mx_beat, :stopped}` when the band stops; `Mx.Beat` says what a message holds.
  """
  def follow(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :follow)

  @doc """
  Mutes the part `name` of the song, or lets it be heard again with `muted` false, through the
  band's `:mute` function; refused with `{:error, message}` for a part the song does not have.
  """
  def mute(band, name, muted \\ true)
      when (is_pid(band) or is_atom(band)) and is_boolean(muted) do
    GenServer.call(band, {:mute, name, muted})
  end

  @doc """
  Solos the parts named and no others, through the band's `:solo` function, so only they are
  heard, and every part is with none named; refused with `{:error, message}` for a part the song
  does not have.
  """
  def solo(band, names) when (is_pid(band) or is_atom(band)) and is_list(names) do
    GenServer.call(band, {:solo, names})
  end

  @doc """
  Plays the song at `share` of its own tempo from the band's next 150 ms on, or ahead of every
  note already sent without `hand`, moving there evenly over `over` beats when `over` is above 0.

  Every tempo the song gives, its own and those its music writes, is played times the share, until
  another share is given; 1 plays the song's own tempo.
  A share `check_share/1` refuses is refused with `{:error, message}`.
  """
  def scale_tempo(band, share, over \\ 0)
      when (is_pid(band) or is_atom(band)) and is_number(over) and over >= 0 do
    with :ok <- check_share(share), do: GenServer.call(band, {:scale_tempo, share, over})
  end

  @doc """
  Whether the band plays a song at `share` of its tempo, which takes 0.25 to 4, as `:ok` or
  `{:error, message}`.
  """
  def check_share(share) when is_number(share) and share >= 0.25 and share <= 4, do: :ok

  def check_share(share) do
    shown = inspect(share)
    {:error, "a tempo share takes 0.25 to 4, not #{shown}"}
  end

  @doc """
  Sends the calling process what becomes of each version the band is handed, until it is gone.

  For each part, `{:mx_waits, name, wait}` says when it takes the version over: the beat its next
  pass starts on, `{:stops, beat}` for a part the version removes, `{:joins, beat}` for one it
  adds, `:input` for a loop that waits for input, or `:never` when the part has no pass left.
  `{:mx_took_over, name, beat}` says that a part has, at that beat, and `:mx_version_plays` that
  every part has.
  A version handed over before the last one has taken over replaces it, and its parts are reported
  again.
  """
  def subscribe(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :subscribe)

  @doc """
  Takes the version the band was last handed over now, from the first whole beat 150 ms away, or
  after every note already sent without `hand`, and returns `{:ok, beat}`.

  Each part the version changes ends the pass that sounds then and plays the version's pass from
  that beat of its music, so the band keeps its place, and each part it removes stops there; a
  part it adds joins as it would have.
  """
  def take_over_now(band) when is_pid(band) or is_atom(band) do
    GenServer.call(band, :take_over_now)
  end

  @doc """
  Plays the part `name` with another synth, given as `synth:`, or with options of its synth other
  than the song's, from the first whole beat 150 ms away, or after every note already sent without
  `hand`.

  What is tried adds to what was tried on the part before, holds through new versions of the song,
  and keeps the part's notes, its other options and its effects; an option the song gives that the
  tried synth does not take is left out, and named.
  A part, synth or option that does not exist is refused with `{:error, message}`.
  """
  def try_part(band, name, tried) when (is_pid(band) or is_atom(band)) and is_list(tried) do
    GenServer.call(band, {:try_part, name, tried})
  end

  @doc """
  Plays a loaded sample, as a sample event takes it, into the part `name`'s effects from the first
  whole beat more than 150 ms away, and returns `{:ok, beat}`.

  `opts` are a sample's, `from:` and `to:` in seconds among them, and the part plays on beside it.
  A recording the part is already playing this way stops as the new one starts.
  A part the song does not have is refused with `{:error, message}`.
  """
  def play_recording(band, name, sample, opts)
      when (is_pid(band) or is_atom(band)) and is_map(sample) and is_list(opts) do
    GenServer.call(band, {:play_recording, name, sample, opts})
  end

  @doc """
  Stops the recording `play_recording/4` plays on the part `name`, if one plays, within 150 ms.
  """
  def stop_recording(band, name) when is_pid(band) or is_atom(band) do
    GenServer.call(band, {:stop_recording, name})
  end

  @doc """
  Plays the part `name` as the song gives it again, from the first whole beat 150 ms away, or
  after every note already sent without `hand`.
  """
  def stop_trying(band, name) when is_pid(band) or is_atom(band) do
    GenServer.call(band, {:stop_trying, name})
  end

  @doc "The tempo timeline, the latest entry first."
  def timeline(band) when is_pid(band) or is_atom(band), do: GenServer.call(band, :timeline)

  @doc """
  Tells the band that the loop `name` starts a pass at `beat`, so the parts waiting to join start
  with it and the pass's tempo changes go on the timeline; returns the timeline.
  """
  def cue(band, name, beat, pass \\ 0)
      when (is_pid(band) or is_atom(band)) and is_atom(name) and is_number(beat) and
             is_integer(pass) do
    GenServer.call(band, {:cue, name, beat, pass})
  end

  @doc """
  The real time, in microseconds, of a beat on a timeline, as `Mx.Tempo.time_at/2` works it out.
  """
  defdelegate time_at(timeline, beat), to: Mx.Tempo

  @doc """
  The tempo in beats per minute at a beat on a timeline, as `Mx.Tempo.tempo_at/2` works it out.
  """
  defdelegate tempo_at(timeline, beat), to: Mx.Tempo

  @doc """
  The beat at a real time, in microseconds, on a timeline, as `Mx.Tempo.beat_at/2` works it out.
  """
  defdelegate beat_at(timeline, us), to: Mx.Tempo

  @impl true
  def init(opts) when is_list(opts) do
    Process.flag(:trap_exit, true)
    prepare = Keyword.get(opts, :prepare, & &1)
    song = opts |> Keyword.fetch!(:song) |> prepare.()
    ahead_us = Keyword.get(opts, :ahead_ms, 500) * 1000
    start_us = Keyword.get_lazy(opts, :start_us, fn -> now() + ahead_us end)

    state = %{
      song: song,
      play: Keyword.fetch!(opts, :play),
      ahead_us: ahead_us,
      prepare: prepare,
      load_sample: Keyword.get(opts, :load_sample, fn _path, _loop -> :ok end),
      loop_opts:
        Keyword.take(opts, [
          :new_id,
          :start_fx,
          :stop_fx,
          :start_part,
          :hand,
          :cut,
          :out,
          :inputs,
          :set,
          :worked_out
        ]),
      share: Keyword.get(opts, :share, 1),
      tempo_pass: -1,
      on_end: Keyword.get(opts, :on_end, fn -> :ok end),
      on_fail: Keyword.get(opts, :on_fail),
      joining: %{},
      loops: %{},
      stopping: %{},
      delay_us: Keyword.get(opts, :delay, fn _band -> 0 end).(self()),
      set_tempo: Keyword.get(opts, :set_tempo, fn _beat, _tempo -> :ok end),
      tempo_lead_us: if(opts[:hand], do: @tempo_lead_us, else: ahead_us),
      mute: Keyword.get(opts, :mute, fn _name, _muted -> :ok end),
      solo: Keyword.get(opts, :solo, fn _name, _soloed -> :ok end),
      soloed: [],
      followers: Keyword.get(opts, :follow, []),
      subscribers: [],
      trials: %{},
      chains: %{},
      recordings: %{},
      version: nil,
      told: []
    }

    state = Map.put(state, :timeline, Mx.Tempo.new(song.tempo * state.share, start_us))
    Keyword.get(opts, :place_beats, fn _start_us -> :ok end).(start_us)
    state.set_tempo.(0, song.tempo * state.share)
    if subscribe = opts[:subscribe], do: subscribe.(self())
    state = Map.put(state, :buses, Keyword.get(opts, :buses, fn _song -> :ok end))
    state.buses.(song)
    state = Map.put(state, :live, Keyword.get(opts, :live, fn _lives, _tempo -> :ok end))
    state.live.(song.live, song.tempo)
    state = Map.put(state, :main, Keyword.get(opts, :main, fn _effects -> :ok end))
    state.main.(song.fx)
    from = Keyword.get(opts, :from, 0)
    {:ok, tell(start_loops(state, Enum.flat_map(song.loops, &place(&1, from))))}
  end

  @impl true
  def handle_call(:timeline, {_, _}, %{} = state), do: {:reply, state.timeline, state}

  def handle_call(:subscribe, {pid, _}, %{} = state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  def handle_call(:take_over_now, {_, _}, %{} = state) do
    beat = floor(beat_at(state.timeline, now() + state.tempo_lead_us)) + 1
    for {_, pid} <- Map.merge(state.loops, state.stopping), do: Loop.take_over_now(pid, beat)
    {:reply, {:ok, beat}, state}
  end

  # The tempos already on the timeline after the change are put on it again at the new share.
  def handle_call({:scale_tempo, share, over}, {_, _}, %{} = state) do
    beat = beat_at(state.timeline, now() + state.tempo_lead_us)
    later = state.timeline |> Enum.filter(fn {at, _, _} -> at > beat end) |> Enum.reverse()
    own = tempo_at(state.timeline, beat) / state.share

    state =
      Enum.reduce(later, put_tempo(%{state | share: share}, beat, own, over), fn
        {at, _us, {:ramp, _from, to, beats}}, scaled ->
          put_tempo(scaled, at, to / state.share, beats)

        {at, _us, bpm}, scaled ->
          put_tempo(scaled, at, bpm / state.share, 0)
      end)

    {:reply, :ok, tell(state)}
  end

  def handle_call(:follow, {pid, _}, %{} = state) do
    Process.monitor(pid)
    for message <- messages(state), do: send(pid, {:mx_beat, message})
    {:reply, :ok, %{state | followers: [pid | state.followers]}}
  end

  def handle_call({:mute, name, muted}, {_, _}, %{} = state) do
    case parts(state, [name]) do
      {:ok, [part]} ->
        state.mute.(part, muted)
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:try_part, name, tried}, {_, _}, %{} = state) do
    with {:ok, [part]} <- parts(state, [name]),
         loop = Enum.find(state.song.loops, &(&1.name == part)),
         trial = Map.get(state.trials, part, %{}),
         {synth, opts} = Keyword.pop(tried, :synth, trial[:synth]),
         :ok <- check_synth(synth),
         :ok <- check_options(synth || loop.synth, opts) do
      opts = trial |> Map.get(:opts, []) |> Keyword.merge(opts)
      trial = if synth, do: %{synth: synth, opts: opts}, else: %{opts: opts}
      {:reply, :ok, put_trial(state, part, trial)}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:play_recording, name, sample, opts}, {_, _}, %{} = state) do
    case parts(state, [name]) do
      {:ok, [part]} -> start_recording(state, part, sample, opts)
      error -> {:reply, error, state}
    end
  end

  def handle_call({:stop_recording, name}, {_, _}, %{} = state) do
    case parts(state, [name]) do
      {:ok, [part]} ->
        {id, recordings} = Map.pop(state.recordings, part)
        if id, do: state.play.(now() + @tempo_lead_us, [{:stop, [id]}])
        {:reply, :ok, %{state | recordings: recordings}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:stop_trying, name}, {_, _}, %{} = state) do
    case parts(state, [name]) do
      {:ok, [part]} -> {:reply, :ok, put_trial(state, part, %{})}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:solo, names}, {_, _}, %{} = state) do
    case parts(state, names) do
      {:ok, parts} ->
        for part <- state.soloed -- parts, do: state.solo.(part, false)
        for part <- parts -- state.soloed, do: state.solo.(part, true)
        {:reply, :ok, %{state | soloed: parts}}

      error ->
        {:reply, error, state}
    end
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
    state.buses.(song)
    state.live.(song.live, song.tempo)
    state.main.(song.fx)
    names = Enum.map(song.loops, & &1.name)

    removed = Map.drop(state.loops, names)
    Enum.each(removed, fn {_, pid} -> Loop.stop(pid) end)
    stopping = Map.merge(state.stopping, removed)
    state = %{state | song: song, loops: Map.take(state.loops, names), stopping: stopping}
    told = Map.keys(removed) ++ Enum.filter(names, &is_map_key(state.loops, &1))

    version = %{
      waiting: MapSet.new(names ++ Map.keys(removed)),
      due: MapSet.new(told),
      joins: [],
      beats: []
    }

    state =
      Enum.reduce(song.loops, %{state | version: version}, fn loop, state ->
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
    followers = List.delete(state.followers, pid)
    {:noreply, %{state | followers: followers, subscribers: List.delete(state.subscribers, pid)}}
  end

  # A part added at the next section joins at the next pass the parts that play then start.
  def handle_info({:part_waits, name, wait}, %{version: %{} = version} = state) do
    report(state, {:mx_waits, name, wait})
    beats = if is_number(wait), do: [wait | version.beats], else: version.beats
    version = %{version | due: MapSet.delete(version.due, name), beats: beats}

    version =
      if MapSet.size(version.due) == 0 and version.joins != [] do
        joins = if beats == [], do: :never, else: {:joins, Enum.min(beats)}
        for joining <- version.joins, do: report(state, {:mx_waits, joining, joins})
        %{version | joins: []}
      else
        version
      end

    {:noreply, %{state | version: version}}
  end

  def handle_info({:part_waits, name, wait}, %{} = state) do
    report(state, {:mx_waits, name, wait})
    {:noreply, state}
  end

  def handle_info({:part_chain, name, chain}, %{} = state) do
    {:noreply, put_in(state.chains[name], chain)}
  end

  def handle_info({:part_took_over, name, beat}, %{} = state) do
    report(state, {:mx_took_over, name, beat})

    case state.version do
      %{waiting: waiting} = version ->
        waiting = MapSet.delete(waiting, name)

        if MapSet.size(waiting) == 0 do
          report(state, :mx_version_plays)
          {:noreply, %{state | version: nil}}
        else
          {:noreply, %{state | version: %{version | waiting: waiting}}}
        end

      nil ->
        {:noreply, state}
    end
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

      {name, _} when state.on_fail != nil ->
        state.on_fail.(name, reason)
        {:noreply, %{state | loops: Map.delete(state.loops, name)}}

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
    # A loop is linked, so only a band stopped for a reason other than :normal ends it.
    for {_name, pid} <- Map.merge(state.stopping, state.loops), do: Process.exit(pid, :shutdown)
    for pid <- state.followers, do: send(pid, {:mx_beat, :stopped})
    :ok
  end

  defp messages(state), do: Mx.Beat.messages(state.timeline, state.delay_us, now())

  # The song's parts by the names given, as atoms or strings.
  defp parts(state, names) do
    known = Map.new(state.song.loops, &{Atom.to_string(&1.name), &1.name})

    case Enum.find(names, &(not is_map_key(known, to_string(&1)))) do
      nil -> {:ok, Enum.uniq(for name <- names, do: known[to_string(name)])}
      unknown -> {:error, "the song has no part named #{unknown}"}
    end
  end

  # A recording plays from the first whole beat the engine can still place, stopping the one the
  # part played before.
  defp start_recording(state, part, sample, opts) do
    lead_us = max(state.tempo_lead_us, @tempo_lead_us)
    beat = floor(beat_at(state.timeline, now() + lead_us)) + 1
    at_us = time_at(state.timeline, beat)
    tempo = tempo_at(state.timeline, beat)
    opts = Mx.Synths.to_seconds(:mono_player, Mx.Samples.cut(opts, sample.seconds, tempo), tempo)
    id = Keyword.get(state.loop_opts, :new_id, fn -> System.unique_integer([:positive]) end).()
    stops = for old <- List.wrap(state.recordings[part]), do: {:stop, [old]}
    state.play.(at_us, stops ++ [{:sample, id, sample, opts, state.chains[part]}])
    {:reply, {:ok, beat}, put_in(state.recordings[part], id)}
  end

  # Sends the followers each message they were not sent yet.
  defp tell(state) do
    messages = messages(state)

    for message <- messages -- state.told,
        pid <- state.followers,
        do: send(pid, {:mx_beat, message})

    %{state | told: messages}
  end

  defp report(state, message), do: Enum.each(state.subscribers, &send(&1, message))

  defp put_trial(state, part, trial) do
    beat = floor(beat_at(state.timeline, now() + state.tempo_lead_us)) + 1
    if pid = state.loops[part], do: Loop.try_out(pid, trial, beat)
    %{state | trials: Map.put(state.trials, part, trial)}
  end

  defp check_synth(nil), do: :ok

  defp check_synth(synth) do
    if is_atom(synth) and Mx.Synths.exists?(synth) do
      :ok
    else
      {:error, "there is no synth named #{synth}"}
    end
  end

  defp check_options(synth, opts) do
    case Enum.find(opts, fn {key, _} -> not Mx.Synths.option?(synth, key) end) do
      nil ->
        :ok

      {key, _} ->
        name = if is_atom(synth), do: synth, else: "the part's sampled instrument"
        {:error, "#{name} takes no option #{key}"}
    end
  end

  # A loop added back while its removed version finishes its pass takes over from that version.
  defp add_loop(state, loop) do
    case Map.pop(state.stopping, loop.name) do
      {nil, _} ->
        start = later_start(state, loop)

        state =
          case start do
            :join ->
              update_in(state.version.joins, &[loop.name | &1])

            beat ->
              report(state, {:mx_waits, loop.name, {:joins, beat}})
              state
          end

        start_loops(state, [{loop, start, [announce: true]}])

      {pid, stopping} ->
        Loop.switch(pid, loop)
        version = %{state.version | due: MapSet.put(state.version.due, loop.name)}

        %{
          state
          | loops: Map.put(state.loops, loop.name, pid),
            stopping: stopping,
            version: version
        }
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
        load_sample: state.load_sample,
        trial: Map.get(state.trials, loop.name, %{})
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

  # The engine moves the notes it holds in beats, so the tempo changes sooner when it holds them.
  defp retempo(state, tempo) do
    put_tempo(state, floor(beat_at(state.timeline, now() + state.tempo_lead_us)) + 1, tempo, 0)
  end

  defp put_changes(state, start, pass) do
    state =
      state.song.tempos
      |> Mx.Tempo.changes(pass)
      |> Enum.reduce(state, fn
        {beat, bpm, over}, state -> put_tempo(state, start + beat, bpm, over)
      end)

    %{state | tempo_pass: pass}
  end

  # Puts a change to the song's tempo `bpm` on the timeline at the share, and tells `set_tempo`
  # the entry that starts it.
  defp put_tempo(state, beat, bpm, over) do
    timeline = Mx.Tempo.put(state.timeline, beat, bpm * state.share, over)
    {_beat, _us, tempo} = Enum.find(timeline, fn {entry, _, _} -> entry == beat end)
    state.set_tempo.(beat, tempo)
    %{state | timeline: timeline}
  end

  # The first whole beat after every note a loop may already have sent.
  defp next_beat(state) do
    floor(beat_at(state.timeline, now() + state.ahead_us)) + 1
  end

  defp now, do: Mx.Clock.now()
end
