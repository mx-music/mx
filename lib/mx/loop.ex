defmodule Mx.Loop do
  @moduledoc """
  Plays one loop of a song, pass after pass.

  A pass is worked out `ahead_ms` before it starts, and each of its notes is sent `ahead_ms`
  before it plays, stamped with the real time of its beat on the band's timeline.
  Notes are stamped from the timeline rather than from the previous note, so nothing adds up to a
  drift.
  A pass worked out later than its start is late: its notes more than a quarter of a beat late are
  dropped, and the rest play as soon as the engine gets them.

  A new version takes over when the next pass is worked out, and a stopped loop ends with its
  current pass.
  A loop with a number of passes ends once its last pass has played to its end, exiting with
  `{:shutdown, :ended}`.
  A loop started with `pass` and `skip` plays that pass first, leaving out its notes before beat
  `skip` of it.
  A loop started with `start: :join` waits for the band to send `{:join, beat, pass}`, and plays
  that pass from that beat.

  The loop sends the band `{:part_waits, name, wait}` when it is handed a new version or told to
  stop: the beat its next pass starts on, `:never` when it has no pass left, `:input` when it
  waits for input, or `{:stops, beat}`.
  It sends `{:part_chain, name, chain}` when it starts its effects, the chain its notes play into.
  It sends `{:part_took_over, name, beat}` when the new version's first pass starts, when it
  stops, and, started with `announce: true`, when its own first pass starts.
  `take_over_now/2` ends the pass that sounds at a beat, and plays the new version's pass from
  that beat, or stops there; given `hand`, `cut` is given that beat first, to drop what the engine
  holds from there on.
  `try_out/3` plays the loop's notes with another synth or other options from a beat, working the
  pass that sounds then out again from that beat, as `take_over_now/2` does, and keeps them
  through new versions.

  A sample plays from the buffer the song loaded for it.
  A sample named while the pass runs has no buffer yet, so the loop asks for it with
  `load_sample`, leaves it out, and plays it from the next pass once it is loaded.

  A loop with effects starts its chain with `start_fx` before its first pass, and plays its notes
  into the chain.
  The chain lasts from pass to pass, and is replaced at the start of a pass whose effects or tempo
  give it other options.
  A replaced chain, or the chain of a stopped loop, is handed to `stop_fx` with the end of its
  last pass, so its sounds finish through it.
  Given `start_part`, every loop has a chain, started by the loop's name with its effects, so the
  engine can mute and solo it by that name.

  Given `hand`, the loop hands the engine each pass whole as it is worked out, every sound and
  change at its beat with its times in beats, and the engine places them by the tempo the band
  gives it.
  The loop is then sent `{:mx_pass_ending, name, beat}` two beats before the pass ends, and works
  out the next pass at once; without that word it works it out `ahead_ms` before the pass starts,
  as it does the first.
  The effects' options stay in beats too, so a tempo change leaves the chain as it is, and only
  MIDI and OSC are still sent step by step.

  MIDI and OSC steps go to `out` with the real time of their beat, as the loop's notes go to the
  engine through `play`; a MIDI note is a note on and a note off after its length.

  A pass reads the inputs as `inputs` returns them for its first beat, waiting at most until its
  start, and a set step hands its value to `set` with its beat and that beat's real time as soon
  as its pass is worked out.
  Each pass then tells `worked_out` the beat it has worked out up to, so the other loops' passes
  wait for its set steps, and nil once it works out no more passes on its own.
  A loop with `on:` plays no pass on its own: the band sends it each input it waits for, and it
  plays a pass at once, 10 ms ahead so its first notes are on time.

  A sound a control step changes starts with an id of its own from `new_id`, and the step sets its
  options at its beat; other sounds have none.
  """

  use GenServer

  @trigger_lead_us 10_000
  @grid_grace_us 20_000
  @notice_beats 2

  alias Mx.{Band, OSC, Pass, Song, Synths}

  @doc "Starts playing a loop from the version, band and functions in `opts`."
  def start_link(opts) when is_list(opts), do: GenServer.start_link(__MODULE__, opts)

  @doc """
  Hands the loop a new version of itself, which takes over when its next pass is worked out.
  """
  def switch(loop, %Song.Loop{} = version) when is_pid(loop) do
    GenServer.cast(loop, {:switch, version})
  end

  @doc "Stops the loop once its current pass ends."
  def stop(loop) when is_pid(loop), do: GenServer.cast(loop, :stop)

  @doc """
  Plays the loop's notes from `beat`, a beat not yet worked out, with the synth and options of
  `trial`, a map of `:synth` and `:opts` as `{name, value}`, and as the song gives them again with
  an empty map.
  """
  def try_out(loop, trial, beat) when is_pid(loop) and is_map(trial) and is_number(beat) do
    GenServer.cast(loop, {:try_out, trial, beat})
  end

  @doc """
  Ends the pass that sounds at `beat`, a beat not yet worked out, and plays the new version's pass
  from that beat, or stops there when stopping; a loop with neither carries on.
  """
  def take_over_now(loop, beat) when is_pid(loop) and is_number(beat) do
    GenServer.cast(loop, {:take_over_now, beat})
  end

  @impl true
  def init(opts) when is_list(opts) do
    start = Keyword.fetch!(opts, :start)

    state = %{
      loop: Keyword.fetch!(opts, :loop),
      pending: nil,
      stopping: false,
      stopped_start: nil,
      band: Keyword.fetch!(opts, :band),
      play: Keyword.fetch!(opts, :play),
      new_id: Keyword.get(opts, :new_id, fn -> System.unique_integer([:positive]) end),
      ahead_us: Keyword.fetch!(opts, :ahead_us),
      pass: Keyword.get(opts, :pass, 0),
      skip: Keyword.get(opts, :skip, 0),
      next_start: if(start == :join or triggered?(opts), do: nil, else: start),
      inputs: Keyword.get(opts, :inputs, fn _beat, _until_us -> %{} end),
      set: Keyword.get(opts, :set, fn _name, _value, _beat, _at_us -> :ok end),
      worked_out: Keyword.get(opts, :worked_out, fn _pid, _beat -> :ok end),
      trigger: nil,
      pass_end: nil,
      ended: false,
      queue: [],
      timer: nil,
      wake_us: nil,
      load_sample: Keyword.get(opts, :load_sample, fn _path, _loop -> :ok end),
      out: Keyword.get(opts, :out, fn _at_us, _message -> :ok end),
      start_fx: Keyword.get(opts, :start_fx, fn _chain -> nil end),
      stop_fx: Keyword.get(opts, :stop_fx, fn _fx, _at_us -> :ok end),
      start_part: Keyword.get(opts, :start_part),
      hand: Keyword.get(opts, :hand),
      cut: Keyword.get(opts, :cut, fn _name, _beat -> :ok end),
      announce: Keyword.get(opts, :announce, false),
      trial: Keyword.get(opts, :trial, %{}),
      left_out: MapSet.new(),
      handed: [],
      retaking: false,
      chain: [],
      fx: nil,
      loaded: %{},
      arrived: %{},
      requested: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:switch, version}, %{} = state) do
    next_start = state.next_start || state.stopped_start

    wait =
      cond do
        state.loop.on -> :input
        next_start -> next_start
        true -> :never
      end

    send(state.band, {:part_waits, state.loop.name, wait})

    {:noreply,
     %{state | pending: version, stopping: false, next_start: next_start, stopped_start: nil}}
  end

  def handle_cast(:stop, %{} = state) do
    send(state.band, {:part_waits, state.loop.name, {:stops, state.next_start || state.pass_end}})
    {:noreply, %{state | stopping: true}}
  end

  def handle_cast({:take_over_now, beat}, %{} = state) do
    if state.pending != nil or state.stopping do
      {:noreply, retake(state, beat, :version)}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:try_out, trial, beat}, %{} = state) do
    {:noreply, retake(%{state | trial: trial}, beat, :trial)}
  end

  @impl true
  def handle_info({:join, beat, pass}, %{next_start: nil, pass_end: nil} = state) do
    state = %{state | next_start: beat, pass: pass}
    {:noreply, if(Mx.Clock.rendering?(), do: state, else: tick(state))}
  end

  def handle_info({:join, _beat, _pass}, %{} = state), do: {:noreply, state}

  # An input that comes while a pass waits for its grid's beat starts nothing more.
  def handle_info({:trigger, _input}, %{next_start: start} = state) when start != nil do
    {:noreply, state}
  end

  def handle_info({:trigger, input}, %{} = state) do
    timeline = Band.timeline(state.band)
    start = trigger_start(timeline, state.loop.music[:grid])
    {:noreply, tick(%{state | next_start: start, trigger: input})}
  end

  def handle_info({:sample_loaded, path, buffer}, %{} = state) do
    {:noreply, put_in(state.arrived[path], buffer)}
  end

  def handle_info({:mx_pass_ending, _part, beat}, %{next_start: start} = state)
      when start != nil and start == beat do
    {:noreply, tick(state, beat)}
  end

  def handle_info({:mx_pass_ending, _part, _beat}, %{} = state), do: {:noreply, state}

  def handle_info(:tick, %{} = state) do
    state = tick(state)

    if state.ended and state.queue == [] and now() >= pass_end_us(state) do
      if state.fx, do: state.stop_fx.(state.fx, pass_end_us(state))
      {:stop, {:shutdown, :ended}, %{state | fx: nil}}
    else
      stop_or_continue(state)
    end
  end

  defp stop_or_continue(state) do
    if state.stopping and state.queue == [] and state.next_start == nil do
      if state.fx, do: state.stop_fx.(state.fx, pass_end_us(state))
      send(state.band, {:part_took_over, state.loop.name, state.stopped_start || state.pass_end})
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  # Drops what was worked out from `beat` on, and works the pass that sounds then out again from
  # that beat, with the new version or only the trial, or stops there.
  defp retake(state, beat, kind) do
    case Enum.find(state.handed, fn {_pass, start, ends} -> start <= beat and beat < ends end) do
      {pass, start, _ends} ->
        state.cut.(state.loop.name, beat)
        queue = Enum.reject(state.queue, &(elem(&1, 0) >= beat))
        state = %{state | queue: queue, handed: [], pass_end: beat}

        if state.stopping and kind == :version do
          %{state | next_start: nil, stopped_start: beat}
        else
          tick(%{state | pass: pass, next_start: start, skip: beat - start, retaking: kind})
        end

      nil ->
        state
    end
  end

  @impl true
  def terminate(_reason, %{} = state) do
    if state.fx, do: state.stop_fx.(state.fx, now() + state.ahead_us)
  end

  # Takes the time before asking for the timeline, so a tempo change the band makes meanwhile
  # starts after every note sent here.
  # Given a beat, it works out the pass that starts there however far ahead that is.
  defp tick(state, beat \\ nil) do
    now = now()
    timeline = Band.timeline(state.band)
    horizon = now + state.ahead_us
    pass_horizon = if beat, do: max(horizon, Band.time_at(timeline, beat)), else: horizon

    {state, timeline} = run_passes(state, timeline, now, pass_horizon)

    state
    |> send_due(timeline, horizon)
    |> schedule(timeline, now)
  end

  defp run_passes(%{next_start: start} = state, timeline, now, horizon)
       when start != nil do
    cond do
      Band.time_at(timeline, start) > horizon ->
        {state, timeline}

      state.stopping ->
        state.worked_out.(self(), nil)
        {%{state | next_start: nil, stopped_start: start}, timeline}

      true ->
        {state, timeline} = run_pass(state, timeline)
        run_passes(state, timeline, now, horizon)
    end
  end

  defp run_passes(state, timeline, _now, _horizon), do: {state, timeline}

  # The cue puts the pass's tempo changes on the timeline, so every time in the pass is worked out
  # from the timeline it returns.
  defp run_pass(state, timeline) do
    start = state.next_start
    state = %{state | loaded: Map.merge(state.loaded, state.arrived), arrived: %{}}
    if !state.loop.on, do: state.worked_out.(self(), start)
    {state, events, beats} = next_pass(state, Band.time_at(timeline, start))
    {skip, state} = {state.skip, %{state | skip: 0}}
    events = Enum.reject(events, fn {beat, step, _} -> beat < skip and skipped?(step) end)
    name = state.loop.name

    # A pass worked out again from a beat within it was cued when it was first worked out.
    timeline =
      if state.retaking, do: timeline, else: Band.cue(state.band, name, start, state.pass)

    if state.announce, do: send(state.band, {:part_took_over, name, start})

    for {beat, {:set, set_name, value}, _} <- events do
      state.set.(set_name, value, start + beat, Band.time_at(timeline, start + beat))
    end

    state = put_chain(state, timeline, start)
    now = now()
    pass_end = start + beats
    {queued, state} = Enum.map_reduce(queue_pass(events, start, state), state, &try_item/2)
    {state, queued} = hand(state, queued, timeline, {start, pass_end})
    {dropped, queued} = drop_late(queued, timeline, now)

    late_ms = div(now - Band.time_at(timeline, start + skip), 1000)

    cond do
      dropped > 0 -> warn("loop #{name} is #{late_ms} ms late and dropped #{notes(dropped)}")
      late_ms > 0 -> warn("loop #{name} is #{late_ms} ms late")
      true -> :ok
    end

    ended = state.loop.passes != nil and state.pass + 1 >= state.loop.passes
    next_start = if state.loop.on || ended, do: nil, else: pass_end
    state.worked_out.(self(), next_start)

    state = %{
      state
      | queue: Enum.sort_by(state.queue ++ queued, &elem(&1, 0)),
        pass: state.pass + 1,
        pass_end: pass_end,
        next_start: next_start,
        ended: ended,
        announce: false,
        retaking: false,
        handed: Enum.take([{state.pass, start, pass_end} | state.handed], 2)
    }

    {state, timeline}
  end

  # Hands the engine the pass's sounds and changes whole, each at its beat, and leaves what goes
  # out as MIDI or OSC to be sent at its time.
  defp hand(%{hand: nil} = state, queued, _timeline, _span), do: {state, queued}

  defp hand(state, queued, timeline, span) do
    {out, sounds} = Enum.split_with(queued, &match?({_, _, {:out, _}, _, _, _}, &1))

    {state, handed} =
      Enum.reduce(sounds, {state, []}, fn {beat, synth, step, opts, fx, id}, {state, handed} ->
        tempo = Band.tempo_at(timeline, beat)

        case events(state, synth, step, opts, tempo, fx, id, :beats) do
          {:ok, events} -> {state, Enum.reduce(events, handed, &[{beat, &1} | &2])}
          {:missing, ref, path} -> {request_sample(state, ref, path), handed}
        end
      end)

    # A render ticks each loop in its turn, so it asks for no word from the engine.
    notice = if Mx.Clock.rendering?(), do: [], else: [notice: @notice_beats]
    events = Enum.reverse(handed)
    state.hand.(state.loop.name, span, state.pass, events, notice)
    {state, out}
  end

  # A note plays the synth and options tried in place of the song's, with the options the tried
  # synth does not take left out, each named once.
  defp try_item({beat, synth, step, opts, fx, id} = item, state) do
    case state.trial do
      trial when trial == %{} or is_tuple(step) or synth == nil ->
        {item, state}

      trial ->
        synth = Map.get(trial, :synth, synth)
        opts = Keyword.merge(opts, Map.get(trial, :opts, []))
        {kept, left} = Enum.split_with(opts, fn {key, _} -> Synths.option?(synth, key) end)

        left_out =
          Enum.reduce(left, state.left_out, fn {key, _}, left_out ->
            if {synth, key} not in left_out do
              warn(
                "loop #{state.loop.name}: #{inspect(synth)} takes no option #{key}, so it is left out"
              )
            end

            MapSet.put(left_out, {synth, key})
          end)

        {{beat, synth, step, kept, fx, id}, %{state | left_out: left_out}}
    end
  end

  defp queue_pass(events, start, %{loop: loop, fx: fx} = state) do
    controlled =
      for {_, {:control, {:sounds, indexes}, _}, _} <- events, index <- indexes, do: index

    ids = Map.new(controlled, &{&1, state.new_id.()})

    events
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {{beat, {:control, target, key}, opts}, _} ->
        [{start + beat, key, {:control, control_target(target, ids, fx)}, opts, fx, nil}]

      {{_, {:set, _, _}, _}, _} ->
        []

      {{beat, step, opts}, index} ->
        case out_messages(step, opts, loop) do
          nil ->
            [{start + beat, loop.synth, step, opts, fx, ids[index]}]

          messages ->
            for {offset, message} <- messages,
                do: {start + beat + offset, nil, {:out, message}, [], fx, nil}
        end
    end)
  end

  defp out_messages({:midi_note, note}, opts, loop) do
    channel = opts[:channel] - 1
    note = round(note)
    velocity = opts[:velocity]

    [
      {0, {:midi, loop.midi, <<0x90 + channel, note, velocity>>}},
      {opts[:length], {:midi, loop.midi, <<0x80 + channel, note, 0>>}}
    ]
  end

  defp out_messages({:midi_cc, number, value}, opts, loop) do
    channel = opts[:channel] - 1
    [{0, {:midi, loop.midi, <<0xB0 + channel, number, value>>}}]
  end

  defp out_messages({:osc, address, args}, _opts, loop) do
    [{0, {:osc, loop.osc_to, OSC.message(address, args)}}]
  end

  defp out_messages(_step, _opts, _loop), do: nil

  defp drop_late(queued, timeline, now) do
    {late, kept} =
      Enum.split_with(queued, fn {beat, _, step, _, _, _} ->
        quarter_us = 15_000_000 / Band.tempo_at(timeline, beat)
        droppable?(step) and Band.time_at(timeline, beat) < now - quarter_us
      end)

    {length(late), kept}
  end

  defp skipped?({:set, _, _}), do: false
  defp skipped?({:control, _, _}), do: false
  defp skipped?(_step), do: true

  defp droppable?({:control, _}), do: false
  defp droppable?(_step), do: true

  defp pass_opts(state, until_us) do
    [inputs: state.inputs.(state.next_start, until_us), trigger: state.trigger]
  end

  defp triggered?(opts), do: Keyword.fetch!(opts, :loop).on != nil

  defp trigger_start(timeline, nil), do: Band.beat_at(timeline, now() + @trigger_lead_us)

  # A grid beat less than 20 ms gone still starts the pass, its first notes that much late.
  defp trigger_start(timeline, grid) do
    beat = Band.beat_at(timeline, now() - @grid_grace_us)
    Float.ceil(beat / grid) * grid
  end

  defp notes(1), do: "1 note"
  defp notes(count), do: "#{count} notes"

  defp control_target({:sounds, indexes}, ids, _fx), do: {:sounds, Enum.map(indexes, &ids[&1])}
  defp control_target(:part, _ids, nil), do: nil
  defp control_target(:part, _ids, fx), do: {:part, fx}
  defp control_target({:main, index}, _ids, _fx), do: {:effect, :main, index}
  defp control_target({:bus, bus, index}, _ids, _fx), do: {:effect, {:bus, bus}, index}
  defp control_target({:send, _bus}, _ids, nil), do: nil
  defp control_target({:send, bus}, _ids, fx), do: {:send, fx, bus}
  defp control_target({:effect, _}, _ids, nil), do: nil
  defp control_target({:effect, index}, _ids, fx), do: {:effect, fx, index}

  defp put_chain(state, timeline, start) do
    tempo = Band.tempo_at(timeline, start)

    chain =
      if state.hand do
        state.loop.fx
      else
        for {effect, opts} <- state.loop.fx,
            do: {effect, Synths.effect_to_seconds(effect, opts, tempo)}
      end

    # A part that changes all its playing sounds plays them in a group of its own, which an empty
    # chain gives it.
    grouped =
      chain != [] or match?(%{changed: true}, state.loop.music) or state.start_part != nil

    if chain == state.chain and grouped == (state.fx != nil) do
      state
    else
      if state.fx, do: state.stop_fx.(state.fx, Band.time_at(timeline, start))
      fx = if grouped, do: start_chain(state, chain)
      send(state.band, {:part_chain, state.loop.name, fx})
      %{state | chain: chain, fx: fx}
    end
  end

  defp start_chain(%{start_part: nil} = state, chain), do: state.start_fx.(chain)
  defp start_chain(state, chain), do: state.start_part.(state.loop.name, chain)

  defp next_pass(%{pending: nil} = state, until_us), do: own_pass(state, until_us)
  defp next_pass(%{retaking: :trial} = state, until_us), do: own_pass(state, until_us)

  defp next_pass(%{pending: version} = state, until_us) do
    case Pass.events(version, state.pass, pass_opts(state, until_us)) do
      {:ok, %{events: events, beats: beats}} ->
        send(state.band, {:part_took_over, version.name, state.next_start + state.skip})
        {%{state | loop: version, pending: nil}, events, beats}

      {:error, message} ->
        warn(message <> "\nThe previous version keeps playing.")
        next_pass(%{state | pending: nil}, until_us)
    end
  end

  defp own_pass(state, until_us) do
    case Pass.events(state.loop, state.pass, pass_opts(state, until_us)) do
      {:ok, %{events: events, beats: beats}} ->
        {state, events, beats}

      {:error, message} ->
        warn(message)
        {state, [], 1}
    end
  end

  defp send_due(state, timeline, horizon) do
    {due, queue} =
      Enum.split_while(state.queue, fn {beat, _, _, _, _, _} ->
        Band.time_at(timeline, beat) <= horizon
      end)

    state =
      Enum.reduce(due, state, fn
        {beat, _, {:out, message}, _, _, _}, state ->
          time = Band.time_at(timeline, beat)
          state.out.(time, message)
          state

        {beat, synth, step, opts, fx, id}, state ->
          tempo = Band.tempo_at(timeline, beat)

          case events(state, synth, step, opts, tempo, fx, id, :seconds) do
            {:ok, []} ->
              state

            {:ok, events} ->
              time = Band.time_at(timeline, beat)
              state.play.(time, events)
              state

            {:missing, ref, path} ->
              request_sample(state, ref, path)
          end
      end)

    %{state | queue: queue}
  end

  # With times in beats, an option's times stay as the song gives them, for the engine to place.
  defp events(_state, _synth, {:control, nil}, _opts, _tempo, _fx, _id, _times), do: {:ok, []}

  defp events(_state, synth, {:control, target}, opts, tempo, _fx, _id, :seconds) do
    {:ok, [{:set, target, Synths.given_to_seconds(synth, opts, tempo)}]}
  end

  defp events(_state, _synth, {:control, target}, opts, tempo, _fx, _id, :beats) do
    {:ok, [{:set, target, Synths.rates_to_seconds(opts, tempo)}]}
  end

  defp events(state, _synth, {:sample, ref, path}, opts, tempo, fx, id, times) do
    case state.loop.buffers[path] || state.loaded[path] do
      nil ->
        {:missing, ref, path}

      # Both sample players take the same options.
      sample ->
        opts = Mx.Samples.cut(opts, sample[:seconds], tempo)
        {:ok, [{:sample, id, sample, timed(:mono_player, opts, tempo, times), fx}]}
    end
  end

  defp events(_state, synth, note, opts, tempo, fx, id, times) do
    note = if note == :own_note, do: nil, else: note
    {:ok, [{:note, id, synth, note, timed(synth, opts, tempo, times), fx}]}
  end

  defp timed(synth, opts, tempo, :seconds), do: Synths.to_seconds(synth, opts, tempo)
  defp timed(_synth, opts, tempo, :beats), do: Synths.rates_to_seconds(opts, tempo)

  defp request_sample(state, ref, path) do
    if path in state.requested do
      state
    else
      name = state.loop.name
      ref = Mx.Samples.name(ref)
      warn("loop #{name} loads sample #{ref}, which plays from its next pass")
      state.load_sample.(path, self())
      %{state | requested: MapSet.put(state.requested, path)}
    end
  end

  # Waits at most half the lead, so a faster tempo set meanwhile still leaves time to send.
  # A render ticks every loop in turn itself, so a timer of its own would tick it out of turn; it
  # reads `wake_us` instead, which a loop that has ended sets to its pass's end.
  defp schedule(state, timeline, now) do
    if state.timer, do: Process.cancel_timer(state.timer)
    delay_ms = delay_ms(state, timeline, now)

    if Mx.Clock.rendering?() do
      ending = if state.ended, do: [Band.time_at(timeline, state.pass_end)], else: []
      %{state | timer: nil, wake_us: Enum.min([now + delay_ms * 1000 | ending])}
    else
      %{state | timer: Process.send_after(self(), :tick, delay_ms)}
    end
  end

  defp delay_ms(state, timeline, now) do
    beats = Enum.map(state.queue, &elem(&1, 0)) ++ List.wrap(state.next_start)
    max_ms = div(state.ahead_us, 2000)

    delay_ms =
      case beats do
        [] ->
          max_ms

        _ ->
          next = Band.time_at(timeline, Enum.min(beats))
          div(next - state.ahead_us - now, 1000)
      end

    delay_ms |> max(0) |> min(max_ms)
  end

  defp pass_end_us(state), do: state.band |> Band.timeline() |> Band.time_at(state.pass_end)

  defp warn(message), do: IO.puts(:stderr, message)

  defp now, do: Mx.Clock.now()
end
