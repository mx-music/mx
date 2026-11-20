defmodule Mx.Engine.Mxs do
  @moduledoc """
  mx's engine on mxs, mx's sound engine in Rust, through a NIF.

  mxs plays events stamped with seconds on its own clock, so a Unix time in microseconds becomes the second at which mxs renders it, following the sound card's clock as it drifts from the system's; an offline engine counts seconds from its start.
  A note is a note of mxs's synth of the same name, with its pitch as its `note` option, and a sample plays from the number mxs loaded it as.
  An effect chain is mxs's chain, which notes name to play into.
  It renders offline through an engine of its own for each render, so renders never share a clock.

  Live, it plays through the devices named by `devices:`, `output:` and `input:`, at its `rate:` in Hz and with its `buffer:` frames, each the device's default when not given, and stops with mxs's message when a device cannot take them.
  It plays each live audio of the song from the sound card, with its effects, and reads the sound card's input only when given `input: true`.
  When the input and output run at different rates mxs cannot start, and the message ends with `input_advice:`, by default the advice to name another input or rate, or to take live audio out of the song.
  A changed live audio changes in place, unless its input, channels or effects change; a removed one stops at once.

  A part started with `start_part/2` is a part of mxs by its name, which `mute/2` and `solo/2` silence and bring back while it plays.

  `output/1` gives the device it plays to, its sample rate and its delay, and tells the caller when the engine reports another output.
  `voices/1` has the number of notes that sound sent to the caller about once a second, until `stop_voices/1`.
  `levels/1` has the levels of what it plays sent to the caller twenty times a second, the output's and each part's, until `stop_levels/1`.

  Given `record:`, it writes the main output to that WAV file from when it starts.
  On stop it then waits for the notes already playing to fade, for `fade_ms` at most, before it closes the file.
  """

  @behaviour Mx.Engine

  use GenServer

  alias Mx.Engine.Mxs.Native
  alias Mx.Synths

  # Whether each part named is muted and soloed, for a part started after it was asked, and the
  # process that started it.
  @parts __MODULE__.Parts

  @impl Mx.Engine
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "The synths, players and effects mxs has, each with its options and their defaults, every name as a string."
  def catalog do
    Map.new(entries(), fn {name, specs} ->
      defaults = defaults(specs)

      defaults =
        if name in ~w(live_audio_mono live_audio_stereo) do
          Map.put(defaults, "input", 1)
        else
          defaults
        end

      {name, defaults}
    end)
  end

  @doc "Each synth's and effect's options declared in beats, which a song gives in beats and mxs takes in seconds."
  def beats do
    Map.new(entries(), fn {name, specs} ->
      {name, MapSet.new(for %{kind: "beats"} = spec <- specs, do: spec.name)}
    end)
  end

  # Each entry's own options, then those every note or effect takes, which win over its own.
  defp entries do
    {_synths, note, sample, effects, effect, input} = Native.catalog()

    synths = for {name, specs} <- synth_specs(), do: {name, specs ++ note}

    synths ++
      [{"mono_player", sample}, {"stereo_player", sample}] ++
      [{"live_audio_mono", input}, {"live_audio_stereo", input}] ++
      for {name, specs} <- effects ++ effect_specs(), do: {"fx_" <> name, specs ++ effect}
  end

  @doc "Each synth's options that take a range or a set of names, as `{:range, low, high}`, with nil for an open end, or `{:names, names}`."
  def limits do
    Map.new(synth_specs(), fn {name, specs} ->
      limits =
        for spec <- specs, limit = limit(spec), into: %{}, do: {spec.name, limit}

      {name, limits}
    end)
  end

  defp limit(%{kind: "name", values: [_ | _] = values}) do
    {:names, values}
  end

  defp limit(%{low: low, high: high}) when low != nil or high != nil, do: {:range, low, high}
  defp limit(_spec), do: nil

  defp effect_specs do
    for module <- Mx.Instrument.modules(),
        effect <- module.__effects__(),
        do: {Atom.to_string(effect.name), Mx.Instrument.specs(effect)}
  end

  defp synth_specs do
    {synths, _note, _sample, _effects, _effect, _input} = Native.catalog()

    synths ++
      for module <- Mx.Instrument.modules(),
          synth <- module.__synths__(),
          do: {Atom.to_string(synth.name), Mx.Instrument.specs(synth)}
  end

  # mxs glides any number option over its _slide partner, so each one is listed.
  defp defaults(specs) do
    Map.new(specs, fn spec ->
      {spec.name, spec.default_name || spec.default}
    end)
    |> Map.merge(Map.new(for spec <- specs, spec.kind != "name", do: {spec.name <> "_slide", 0}))
  end

  @impl GenServer
  def init(opts) do
    live = Keyword.get(opts, :live, true)
    input = Keyword.get(opts, :input, false)

    advice =
      Keyword.get(
        opts,
        :input_advice,
        "name another input with --input, give a rate both run at with --rate, or take live_audio out of the song"
      )

    Process.flag(:trap_exit, true)

    with {:ok, engine} <- start(live, input, Keyword.get(opts, :devices, [])),
         :ok <- instruments(engine),
         :ok <- record(engine, opts[:record]) do
      {reports, output} = reports(engine, live)
      origin = Mx.Clock.now() - round(Native.now(engine) * 1_000_000)
      :persistent_term.put(__MODULE__, {engine, origin})
      :persistent_term.put({__MODULE__, :ids}, :atomics.new(1, []))
      :ets.new(@parts, [:named_table, :public])

      {:ok,
       %{
         engine: engine,
         samples: %{},
         live: %{},
         reports: reports,
         output: output,
         output_followers: [],
         delay_us: round((output.delay_ms || 0) * 1000),
         delay_followers: [],
         asked: %{},
         inputs: Native.inputs(engine),
         recording: opts[:record] != nil,
         fade_ms: Keyword.get(opts, :fade_ms, 4000)
       }}
    else
      {:error, "the input runs at " <> _ = message} ->
        advice = if advice, do: ", " <> advice

        {:stop,
         """
         mxs cannot start with audio input on, because #{message}.
         Set both to the same sample rate in Audio MIDI Setup#{advice}.
         """}

      {:error, message} ->
        {:stop, message}
    end
  end

  defp start(false, input, _devices), do: Native.start(false, input)

  defp start(true, input, devices) do
    Native.start_with(
      input,
      {devices[:output], devices[:input], devices[:rate], devices[:buffer]}
    )
  end

  # The output's report comes at once, so the output is known before anyone asks for it.
  defp reports(engine, live) do
    kinds = if live, do: ["clock", "output", "passes"], else: ["output", "passes"]
    reports = Native.subscribe(engine, self(), kinds)

    receive do
      {:mxs_report, {:output, _seconds, device, rate, delay_ms}} ->
        {reports, %{device: device, rate: rate, delay_ms: delay_ms}}
    after
      1000 -> {reports, %{device: nil, rate: nil, delay_ms: nil}}
    end
  end

  defp record(_engine, nil), do: :ok

  defp record(engine, path) do
    case Native.record_output(engine, path, Native.now(engine)) do
      :ok -> :ok
      {:error, message} -> {:error, "mxs could not record to #{path}: #{message}"}
    end
  end

  @impl Mx.Engine
  def prepare(song), do: GenServer.call(__MODULE__, {:prepare, song}, 60_000)

  @doc "The output's delay in microseconds, the time from the engine filling a frame to the sound card playing it; `pid` is then sent `{:mx_delay, delay_us}` whenever it has moved by more than 2 ms."
  def delay(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:delay, pid})

  @doc """
  The output the engine plays to, as `%{device: name, rate: hz, delay_ms: ms}`; `pid` is then sent `{:mx_output, output}` whenever the engine reports another output.

  The delay is the time from the engine filling a frame to the sound card playing it, in milliseconds, as `delay/1` gives it in microseconds.
  An engine that renders offline has no device and no delay, and gives nil for both.
  """
  def output(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:output, pid})

  @doc """
  How filling audio went since the last call, as `%{buffers: n, mean_percent: p, worst_percent: p, late: n}`: how many buffers the engine filled, the time filling took as a share of the time they last, over all of them and at worst, and how many reached the sound card too late to be heard on time.
  An engine that renders offline counts each stretch it renders as a buffer, and none late.
  """
  def buffer_load, do: GenServer.call(__MODULE__, :buffer_load)

  @doc "Sends `pid` `{:mx_voices, count}`, the number of notes that sound, about once a second, until `stop_voices/1` or until `pid` is gone."
  def voices(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:ask, "voices", pid})

  @doc "Stops what `voices/1` started for `pid`; the engine counts no voices while no one is sent them."
  def stop_voices(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:stop, "voices", pid})

  @doc """
  Sends `pid` `{:mx_levels, levels}`, the levels of what the engine plays, twenty times a second, until `stop_levels/1` or until `pid` is gone.

  Each holds the twentieth of a second before it, of the sound as it reaches the output, so it matches a recording made at the same time:

    * `peak:` the loudest sample of the left and the right channel, as `{left, right}`, where 1 is full scale;
    * `rms:` the RMS level of each, as `{left, right}`;
    * `full_scale:` whether a sample of either channel reached full scale;
    * `wave:` the wave of both channels mixed to one, as 64 points from -1 to 1, each the sample furthest from 0 in its stretch;
    * `bands:` the level in dB of both channels mixed to one in each of the bands `bands/0` gives, over the last 8192 frames, where a band with no sound reads -120.0;
    * `parts:` the `peak:` and `rms:` of each part started with `start_part/2`, after its effects, by its name as a string; a sound that plays into no part is in the output's levels alone;
    * `seconds:` the engine's seconds at its end.
  """
  def levels(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:ask, "levels", pid})

  @doc "The bands a levels report holds, the lowest first, each as its lowest and highest frequency in Hz: 25 bands from 50 Hz to 16 kHz, each as wide as the last on a log scale, about a third of an octave."
  def bands, do: Native.level_bands()

  @doc "Stops what `levels/1` started for `pid`; the engine measures no levels while no one is sent them."
  def stop_levels(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:stop, "levels", pid})

  @doc "Renders an engine started with `live: false` on to the Unix time `at_us`, and returns whether a sound still plays."
  def render_to(at_us) when is_integer(at_us) do
    GenServer.call(__MODULE__, {:render_to, at_us}, :infinity)
  end

  @impl Mx.Engine
  def load_sample(path, loop), do: GenServer.cast(__MODULE__, {:load_sample, path, loop})

  @doc "Loads the sample at `path` now, unless it is loaded already, and returns it as a sample event takes it, `{:ok, sample}`, or `{:error, message}`."
  def sample(path) when is_binary(path), do: GenServer.call(__MODULE__, {:sample, path}, 60_000)

  @doc """
  Plays a recording alone, beside any song and through no part, from 150 ms on, and returns `{:ok, id}`, the id `stop_sounds/1` takes.

  It takes a sample's options, `from:` and `to:` in seconds among them, and refuses a file that cannot play or a range outside it with `{:error, message}`.
  """
  def play_recording(ref, opts \\ []) when is_list(opts) do
    with {:ok, path} <- Mx.Samples.check(ref, opts),
         {:ok, sample} <- sample(path) do
      id = new_id()
      opts = Mx.Samples.cut(opts, sample.seconds, 60)
      play(Mx.Clock.now() + 150_000, [{:sample, id, sample, opts, nil}])
      {:ok, id}
    end
  end

  @doc "Stops the sounds of the ids given, such as a recording `play_recording/2` plays, within 150 ms."
  def stop_sounds(ids) when is_list(ids), do: play(Mx.Clock.now() + 150_000, [{:stop, ids}])

  @impl Mx.Engine
  def start_fx(effects) do
    {engine, _} = :persistent_term.get(__MODULE__)

    effects =
      for {effect, opts} <- effects, do: {Atom.to_string(effect), options(opts)}

    case Native.start_effects(engine, effects) do
      {:ok, key} -> %{key: key}
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Starts the part `name` with a part's effects, none for a part without any, and returns the chain its notes play into, as `start_fx/1` does.

  The part starts muted or soloed if `mute/2` or `solo/2` left its name so, and a part of that name already started is removed first.
  With `beats: true`, the options the effects declare in beats are given in beats, and follow the tempo `set_tempo/2` gives the engine.
  The calling process is the one `pass/5` has told when the part's last pass ends.
  """
  def start_part(name, effects, opts \\ []) when is_atom(name) and is_list(opts) do
    {engine, _} = :persistent_term.get(__MODULE__)
    part = Atom.to_string(name)

    effects =
      for {effect, opts} <- effects, do: {Atom.to_string(effect), options(opts)}

    case Native.start_part(engine, part, effects, Keyword.get(opts, :beats, false)) do
      {:ok, key} ->
        :ets.insert_new(@parts, {part, false, false, nil})
        :ets.update_element(@parts, part, {4, self()})
        [{_part, muted, soloed, _pid}] = :ets.lookup(@parts, part)
        if muted, do: Native.mute_part(engine, part, true)
        if soloed, do: Native.solo_part(engine, part, true)
        %{key: key, part: part}

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  @doc "Mutes the part `name` at once, the notes already handed over included, or lets it be heard again; a part started later by that name starts as it was left."
  def mute(name, muted) when is_boolean(muted) do
    {engine, _} = :persistent_term.get(__MODULE__)
    part = to_string(name)
    :ets.insert_new(@parts, {part, false, false, nil})
    :ets.update_element(@parts, part, {2, muted})
    Native.mute_part(engine, part, muted)
    :ok
  end

  @doc "Solos the part `name` at once, or ends its solo: while any part is soloed, only the soloed parts are heard; a part started later by that name starts as it was left."
  def solo(name, soloed) when is_boolean(soloed) do
    {engine, _} = :persistent_term.get(__MODULE__)
    part = to_string(name)
    :ets.insert_new(@parts, {part, false, false, nil})
    :ets.update_element(@parts, part, {3, soloed})
    Native.solo_part(engine, part, soloed)
    :ok
  end

  @doc "Places beat 0 of the engine's tempo map at the Unix time `at_us` in microseconds; it is at the engine's start until placed."
  def place_beats(at_us) when is_integer(at_us) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    Native.place_beats(engine, at_us, origin)
  end

  @doc "Changes the engine's tempo from `beat` on, to beats a minute or to `{:ramp, from, to, beats}`, as a timeline of `Mx.Tempo` holds them; the tempo is 120 until changed, and the events handed over in beats move with it."
  def set_tempo(beat, {:ramp, from, to, over}) when is_number(beat) do
    {engine, _} = :persistent_term.get(__MODULE__)
    Native.set_tempo(engine, beat / 1, to / 1, {from / 1, over / 1})
  end

  def set_tempo(beat, bpm) when is_number(beat) and is_number(bpm) do
    {engine, _} = :persistent_term.get(__MODULE__)
    Native.set_tempo(engine, beat / 1, bpm / 1, nil)
  end

  @doc """
  Hands the part `name`, started with `start_part/3`, a pass over the beats `{from, to}`: each event as `play/2` takes it, with its beat, as `{beat, event}`.

  The engine places every event from its beat by its tempo map, so an event moves with a tempo change made before it sounds.
  An option a synth declares in beats, and every slide, is given in beats.
  `label` is a number of the caller's, such as the pass's number.
  With `notice:`, a number of beats, the process that started the part is sent `{:mx_pass_ending, name, to}` that many beats before the pass ends, unless another pass was handed to the part by then.
  """
  def pass(name, {from, to}, label, events, opts \\ []) when is_atom(name) and is_list(events) do
    {engine, _} = :persistent_term.get(__MODULE__)
    events = for {beat, event} <- events, do: {beat / 1, event(event)}
    notice = if notice = opts[:notice], do: notice / 1
    span = {from / 1, to / 1}
    {reply, warnings} = Native.pass(engine, Atom.to_string(name), span, label, notice, events)
    with {:error, message} <- reply, do: IO.puts(:stderr, "mxs: #{message}")
    Enum.each(warnings, &IO.puts(:stderr, &1))
  end

  @doc "Drops every event handed to the part `name` in a pass for `beat` or after that has not started, so another pass can take its place."
  def cut(name, beat) when is_atom(name) and is_number(beat) do
    {engine, _} = :persistent_term.get(__MODULE__)
    Native.cut(engine, Atom.to_string(name), beat / 1)
  end

  @impl Mx.Engine
  def stop_fx(%{key: key, part: part}, at_us) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    Native.stop_part(engine, part, key, seconds(engine, at_us, origin))
    :ok
  end

  def stop_fx(%{key: key}, at_us) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    Native.stop_effects(engine, key, seconds(engine, at_us, origin))
    :ok
  end

  @impl Mx.Engine
  def set_live(lives, tempo), do: GenServer.call(__MODULE__, {:set_live, lives, tempo})

  @impl Mx.Engine
  def record_input(path, source, at_us) do
    GenServer.call(__MODULE__, {:record_input, path, source, at_us}, 15_000)
  end

  @impl Mx.Engine
  def stop_input, do: GenServer.call(__MODULE__, :stop_input, 15_000)

  @impl Mx.Engine
  def render_rate, do: Native.offline_rate()

  @impl Mx.Engine
  def render_note(synth, params, seconds, _dir, changes) do
    {:ok, engine} = Native.start(false, false)
    :ok = instruments(engine)
    note = event({:note, 1, synth, nil, params, nil})
    sets = for {at, change} <- changes, do: {at / 1, event({:set, {:sounds, [1]}, change})}
    :ok = Native.play(engine, [{0.0, note} | sets])
    {left, _right} = render(engine, seconds)
    left
  end

  @impl Mx.Engine
  def render_through(synth, params, seconds, _dir, effects) do
    {:ok, engine} = Native.start(false, false)
    :ok = instruments(engine)
    effects = for {effect, opts} <- effects, do: {Atom.to_string(effect), options(opts)}
    {:ok, key} = Native.start_effects(engine, effects)
    :ok = Native.play(engine, [{0.0, event({:note, nil, synth, nil, params, %{key: key}})}])
    render(engine, seconds)
  end

  defp instruments(engine) do
    Enum.reduce_while(Mx.Instrument.modules(), :ok, fn module, :ok ->
      case Mx.Instrument.register(engine, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp render(engine, seconds) do
    {:ok, {left, right}} = Native.render(engine, seconds / 1)
    {floats(left), floats(right)}
  end

  defp floats(binary) do
    for <<sample::float-32-native <- binary>>, do: sample
  end

  @impl Mx.Engine
  def new_id, do: :atomics.add_get(:persistent_term.get({__MODULE__, :ids}), 1, 1)

  @impl Mx.Engine
  def play(at_us, events) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    {reply, warnings} = Native.play_at(engine, at_us, origin, Enum.map(events, &event/1))
    with {:error, message} <- reply, do: IO.puts(:stderr, "mxs: #{message}")
    Enum.each(warnings, &IO.puts(:stderr, &1))
  end

  defp send_events(engine, at, events) do
    case Native.play(engine, Enum.map(events, &{at, &1})) do
      :ok -> :ok
      {:error, message} -> IO.puts(:stderr, "mxs: #{message}")
    end

    for warning <- Native.warnings(engine), do: IO.puts(:stderr, warning)
    :ok
  end

  @doc "An event in the form the NIF takes."
  def event({:note, id, synth, note, params, chain}) do
    pitch = if note == nil, do: [], else: [note: note]
    {:note, id, to_string(synth), options(pitch ++ params), key(chain)}
  end

  def event({:sample, id, %{sample: sample}, params, chain}) do
    {:sample, id, sample, options(params), key(chain)}
  end

  def event({:stop, ids}), do: {:stop, ids}

  def event({:set, target, params}) do
    changes = for {name, value} <- params, do: {Atom.to_string(name), value / 1}
    {:set, target(target), changes}
  end

  defp target({:sounds, ids}), do: {:sounds, ids}
  defp target({:part, chain}), do: {:part, key(chain)}
  defp target({:effect, chain, index}), do: {:effect, key(chain), index}

  defp key(nil), do: nil
  defp key(%{key: key}), do: key

  defp options(params) do
    for {name, value} <- params, do: {Atom.to_string(name), value(value)}
  end

  defp value(true), do: 1.0
  defp value(false), do: 0.0
  defp value(value) when is_atom(value), do: Atom.to_string(value)
  defp value(value) when is_number(value), do: value / 1

  defp seconds(engine, at_us, origin) do
    case Native.seconds_at(engine, at_us) do
      nil -> (at_us - origin) / 1_000_000
      seconds -> seconds
    end
  end

  @impl GenServer
  def handle_call({:sample, path}, _from, state) do
    state = load(path, state)

    case Map.fetch(state.samples, path) do
      {:ok, sample} -> {:reply, {:ok, sample}, state}
      :error -> {:reply, {:error, "mxs could not load sample #{path}"}, state}
    end
  end

  def handle_call({:prepare, song}, _from, state) do
    paths = song.loops |> Enum.flat_map(& &1.samples) |> Enum.uniq()
    state = Enum.reduce(paths, state, &load/2)
    loops = Enum.map(song.loops, &%{&1 | buffers: Map.take(state.samples, &1.samples)})
    {:reply, %{song | loops: loops}, state}
  end

  def handle_call({:delay, pid}, _from, state) do
    {:reply, state.delay_us, %{state | delay_followers: [pid | state.delay_followers]}}
  end

  def handle_call(:buffer_load, _from, state) do
    {buffers, mean, worst, late} = Native.buffer_load(state.engine)
    percent = fn share -> Float.round(share * 100, 1) end

    load = %{
      buffers: buffers,
      mean_percent: percent.(mean),
      worst_percent: percent.(worst),
      late: late
    }

    {:reply, load, state}
  end

  def handle_call({:output, pid}, _from, state) do
    {:reply, current(state), %{state | output_followers: [pid | state.output_followers]}}
  end

  def handle_call({:ask, kind, pid}, _from, state) do
    {reports, followers} =
      Map.get_lazy(state.asked, kind, fn ->
        {Native.subscribe(state.engine, self(), [kind]), %{}}
      end)

    followers = Map.put_new_lazy(followers, pid, fn -> Process.monitor(pid) end)
    {:reply, :ok, put_in(state.asked[kind], {reports, followers})}
  end

  def handle_call({:stop, kind, pid}, _from, state) do
    {:reply, :ok, stop_sending(state, kind, pid)}
  end

  def handle_call({:render_to, at_us}, _from, state) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    seconds = (at_us - origin) / 1_000_000 - Native.now(engine)
    if seconds > 0, do: {:ok, _} = Native.render(engine, seconds)
    {:reply, Native.sounding(engine), state}
  end

  def handle_call({:set_live, [_ | _], _tempo}, _from, state)
      when state.live == %{} and state.inputs == 0 do
    IO.puts(
      :stderr,
      "live_audio needs audio input, which mxs started without; restart mx to hear it."
    )

    {:reply, :ok, state}
  end

  def handle_call({:set_live, lives, tempo}, _from, state) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    now = seconds(engine, Mx.Clock.now(), origin)
    names = Enum.map(lives, & &1.name)

    for {name, playing} <- state.live, name not in names do
      stop_live(engine, playing, now)
    end

    live =
      Map.new(lives, fn live ->
        {live.name, put_live(engine, state.live[live.name], live, tempo, now)}
      end)

    {:reply, :ok, %{state | live: live}}
  end

  def handle_call({:record_input, path, source, at_us}, _from, state) do
    {engine, origin} = :persistent_term.get(__MODULE__)

    case recorded(source, state) do
      {:ok, source, state} ->
        case Native.record(engine, path, source, seconds(engine, at_us, origin)) do
          :ok ->
            {:reply, :ok, state}

          {:error, message} ->
            {:reply, {:error, "mxs could not record to #{path}: #{message}"}, state}
        end

      {:error, message, state} ->
        {:reply, {:error, message}, state}
    end
  end

  def handle_call(:stop_input, _from, state) do
    {:reply, Native.stop_recording(state.engine), state}
  end

  @impl GenServer
  def handle_cast({:load_sample, path, loop}, state) do
    state = load(path, state)

    case Map.fetch(state.samples, path) do
      {:ok, sample} -> send(loop, {:sample_loaded, path, sample})
      :error -> :ok
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:mxs_report, {:clock, _seconds, _unix_us, delay}}, state) do
    delay_us = round(delay * 1_000_000)

    if abs(delay_us - state.delay_us) > 2000 do
      for pid <- state.delay_followers, do: send(pid, {:mx_delay, delay_us})
      {:noreply, %{state | delay_us: delay_us}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:mxs_report, {:output, _seconds, device, rate, delay_ms}}, state) do
    delay_us = if delay_ms, do: round(delay_ms * 1000), else: state.delay_us

    state = %{
      state
      | output: %{device: device, rate: rate, delay_ms: delay_ms},
        delay_us: delay_us
    }

    output = current(state)
    for pid <- state.output_followers, do: send(pid, {:mx_output, output})
    {:noreply, state}
  end

  def handle_info({:mxs_report, {:voices, _seconds, sounding}}, state) do
    for pid <- asked(state, "voices"), do: send(pid, {:mx_voices, sounding})
    {:noreply, state}
  end

  def handle_info(
        {:mxs_report, {:levels, seconds, {peak, rms, full_scale}, wave, bands, parts}},
        state
      ) do
    levels = %{
      seconds: seconds,
      peak: peak,
      rms: rms,
      full_scale: full_scale,
      wave: wave,
      bands: bands,
      parts: Map.new(parts, fn {name, peak, rms} -> {name, %{peak: peak, rms: rms}} end)
    }

    for pid <- asked(state, "levels"), do: send(pid, {:mx_levels, levels})
    {:noreply, state}
  end

  def handle_info({:mxs_report, {:pass_ending, _seconds, part, beat}}, state) do
    with [{_part, _muted, _soloed, pid}] when is_pid(pid) <- :ets.lookup(@parts, part) do
      send(pid, {:mx_pass_ending, String.to_existing_atom(part), beat})
    end

    {:noreply, state}
  end

  def handle_info({:mxs_report, _report}, state), do: {:noreply, state}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, Enum.reduce(Map.keys(state.asked), state, &stop_sending(&2, &1, pid))}
  end

  # The clock's reports keep the delay current, which the output's report gives only as the device
  # opens.
  defp current(%{output: %{device: nil} = output}), do: output
  defp current(state), do: %{state.output | delay_ms: state.delay_us / 1000}

  defp asked(state, kind) do
    case state.asked do
      %{^kind => {_reports, followers}} -> Map.keys(followers)
      _none -> []
    end
  end

  # Ends the engine's reports of a kind with the last process sent them.
  defp stop_sending(state, kind, pid) do
    with %{^kind => {reports, followers}} <- state.asked,
         {ref, followers} when ref != nil <- Map.pop(followers, pid) do
      Process.demonitor(ref, [:flush])

      if followers == %{} do
        Native.unsubscribe(reports)
        %{state | asked: Map.delete(state.asked, kind)}
      else
        put_in(state.asked[kind], {reports, followers})
      end
    else
      _not_sent -> state
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.recording do
      fade(state.engine, System.monotonic_time(:millisecond) + state.fade_ms)
      Native.stop_recording_output(state.engine)
    end

    :persistent_term.erase(__MODULE__)
    :ok
  end

  defp fade(engine, deadline) do
    if Native.sounding(engine) and System.monotonic_time(:millisecond) < deadline do
      Process.sleep(50)
      fade(engine, deadline)
    end
  end

  defp recorded({:input, input}, state) when is_integer(input) and input > 0 do
    {:ok, {:input, input - 1}, state}
  end

  defp recorded({:sample, path}, state) when is_binary(path) do
    state = load(path, state)

    case state.samples[path] do
      %{sample: sample} -> {:ok, {:sample, sample}, state}
      nil -> {:error, "mxs could not load #{path}", state}
    end
  end

  # Changes a live audio's options in place, or starts it anew when its input, channels or effects
  # change.
  defp put_live(engine, playing, live, tempo, now) do
    synth = if live.stereo, do: :live_audio_stereo, else: :live_audio_mono
    opts = Synths.to_seconds(synth, live.opts, tempo)

    chain =
      for {effect, opts} <- live.fx, do: {effect, Synths.effect_to_seconds(effect, opts, tempo)}

    case playing do
      %{input: input, stereo: stereo, chain: ^chain}
      when {input, stereo} == {live.input, live.stereo} ->
        send_events(engine, now, [event({:set, {:sounds, [playing.id]}, opts})])
        playing

      _ ->
        if playing, do: stop_live(engine, playing, now)
        fx = if chain == [], do: nil, else: start_fx(chain)
        id = new_id()
        channels = if live.stereo, do: 2, else: 1
        send_events(engine, now, [{:input, id, live.input - 1, channels, options(opts), key(fx)}])
        %{id: id, input: live.input, stereo: live.stereo, chain: chain, fx: fx}
    end
  end

  defp stop_live(engine, playing, now) do
    send_events(engine, now, [{:stop, [playing.id]}])
    if playing.fx, do: Native.stop_effects(engine, playing.fx.key, now)
  end

  defp load(path, state) do
    if Map.has_key?(state.samples, path) do
      state
    else
      case Native.load_sample(state.engine, path) do
        {:ok, {sample, channels}} ->
          seconds = Mx.Samples.seconds(path)
          put_in(state.samples[path], %{sample: sample, channels: channels, seconds: seconds})

        {:error, message} ->
          IO.puts(:stderr, "mxs could not load sample #{path}: #{message}")
          state
      end
    end
  end
end
