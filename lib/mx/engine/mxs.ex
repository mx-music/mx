defmodule Mx.Engine.Mxs do
  @moduledoc """
  mx's engine on mxs, mx's sound engine in Rust, through a NIF.

  mxs plays events stamped with seconds on its own clock, so a Unix time in microseconds becomes the second at which mxs renders it, following the sound card's clock as it drifts from the system's; an offline engine counts seconds from its start.
  A note is a note of mxs's synth of the same name, with its pitch as its `note` option, and a sample plays from the number mxs loaded it as.
  An effect chain is mxs's chain, which notes name to play into.
  It renders offline through an engine of its own for each render, so renders never share a clock.

  It plays each live audio of the song from the sound card, with its effects, and reads the sound card's input only when given `input: true`.
  When the input and output run at different rates mxs cannot start, and the message ends with `input_advice:`, by default the advice to take live audio out of the song.
  A changed live audio changes in place, unless its input, channels or effects change; a removed one stops at once.

  Given `record:`, it writes the main output to that WAV file from when it starts.
  On stop it then waits for the notes already playing to fade, for `fade_ms` at most, before it closes the file.
  """

  @behaviour Mx.Engine

  use GenServer

  alias Mx.Engine.Mxs.Native
  alias Mx.Synths

  @rate 48_000

  @impl Mx.Engine
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "The synths, players and effects mxs has, each with its options and their defaults."
  def catalog do
    {_synths, note, sample, effects, effect} = Native.catalog()
    synths = synth_specs()
    playing = defaults(note)
    players = Map.merge(defaults(sample), playing)

    entries =
      Enum.map(synths, fn {name, specs} -> {name, Map.merge(defaults(specs), playing)} end) ++
        [{"mono_player", players}, {"stereo_player", players}] ++
        [
          {"live_audio_mono", Map.put(playing, :input, 1)},
          {"live_audio_stereo", Map.put(playing, :input, 1)}
        ] ++
        Enum.map(effects ++ effect_specs(), fn {name, specs} ->
          {"fx_" <> name, Map.merge(defaults(specs), defaults(effect))}
        end)

    Map.new(entries, fn {name, defaults} -> {String.to_atom(name), defaults} end)
  end

  @doc "Each synth's options that take a range or a set of names, as `{:range, low, high}`, with nil for an open end, or `{:names, names}`."
  def limits do
    Map.new(synth_specs(), fn {name, specs} ->
      limits =
        for spec <- specs, limit = limit(spec), into: %{}, do: {String.to_atom(spec.name), limit}

      {String.to_atom(name), limits}
    end)
  end

  defp limit(%{kind: "name", values: [_ | _] = values}),
    do: {:names, Enum.map(values, &String.to_atom/1)}

  defp limit(%{low: low, high: high}) when low != nil or high != nil, do: {:range, low, high}
  defp limit(_spec), do: nil

  defp effect_specs do
    for module <- Mx.Instrument.modules(),
        effect <- module.__effects__(),
        do: {Atom.to_string(effect.name), Mx.Instrument.specs(effect)}
  end

  defp synth_specs do
    {synths, _note, _sample, _effects, _effect} = Native.catalog()

    synths ++
      for module <- Mx.Instrument.modules(),
          synth <- module.__synths__(),
          do: {Atom.to_string(synth.name), Mx.Instrument.specs(synth)}
  end

  # mxs glides any number option over its _slide partner, so each one is listed.
  defp defaults(specs) do
    Map.new(specs, fn spec ->
      default = if spec.default_name, do: String.to_atom(spec.default_name), else: spec.default
      {String.to_atom(spec.name), default}
    end)
    |> Map.merge(
      Map.new(
        for spec <- specs, spec.kind != "name", do: {String.to_atom(spec.name <> "_slide"), 0}
      )
    )
  end

  @impl GenServer
  def init(opts) do
    live = Keyword.get(opts, :live, true)
    input = Keyword.get(opts, :input, false)
    advice = Keyword.get(opts, :input_advice, "or take live_audio out of the song")

    Process.flag(:trap_exit, true)

    with {:ok, engine} <- Native.start(live, input),
         :ok <- instruments(engine),
         :ok <- record(engine, opts[:record]) do
      origin = System.os_time(:microsecond) - round(Native.now(engine) * 1_000_000)
      :persistent_term.put(__MODULE__, {engine, origin})
      :persistent_term.put({__MODULE__, :ids}, :atomics.new(1, []))

      {:ok,
       %{
         engine: engine,
         samples: %{},
         live: %{},
         inputs: Native.inputs(engine),
         recording: opts[:record] != nil,
         fade_ms: Keyword.get(opts, :fade_ms, 4000)
       }}
    else
      {:error, "the input runs at " <> _ = message} ->
        {:stop,
         """
         mxs cannot start with audio input on, because #{message}.
         Set both to the same sample rate in Audio MIDI Setup#{if advice, do: ", " <> advice}.
         """}

      {:error, message} ->
        {:stop, message}
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

  @impl Mx.Engine
  def load_sample(path, loop), do: GenServer.cast(__MODULE__, {:load_sample, path, loop})

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

  @impl Mx.Engine
  def stop_fx(%{key: key}, at_us) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    Native.stop_effects(engine, key, seconds(engine, at_us, origin))
    :ok
  end

  @impl Mx.Engine
  def set_live(lives, tempo), do: GenServer.call(__MODULE__, {:set_live, lives, tempo})

  @impl Mx.Engine
  def record_input(path, source, at_us),
    do: GenServer.call(__MODULE__, {:record_input, path, source, at_us}, 15_000)

  @impl Mx.Engine
  def stop_input, do: GenServer.call(__MODULE__, :stop_input, 15_000)

  @impl Mx.Engine
  def render_rate, do: @rate

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

  defp floats(binary), do: for(<<x::float-32-native <- binary>>, do: x)

  @impl Mx.Engine
  def new_id, do: :atomics.add_get(:persistent_term.get({__MODULE__, :ids}), 1, 1)

  @impl Mx.Engine
  def play(at_us, events) do
    {engine, origin} = :persistent_term.get(__MODULE__)
    at = seconds(engine, at_us, origin)

    send_events(engine, at, Enum.map(events, &event/1))
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
    {:note, id, Atom.to_string(synth), options(pitch ++ params), key(chain)}
  end

  def event({:sample, id, %{sample: sample}, params, chain}),
    do: {:sample, id, sample, options(params), key(chain)}

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
  def handle_call({:prepare, song}, _from, state) do
    paths = song.loops |> Enum.flat_map(& &1.samples) |> Enum.uniq()
    state = Enum.reduce(paths, state, &load/2)
    loops = Enum.map(song.loops, &%{&1 | buffers: Map.take(state.samples, &1.samples)})
    {:reply, %{song | loops: loops}, state}
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
    now = seconds(engine, System.os_time(:microsecond), origin)
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

  defp recorded({:input, input}, state) when is_integer(input) and input > 0,
    do: {:ok, {:input, input - 1}, state}

  defp recorded({:sample, path}, state) when is_binary(path) do
    state = load(path, state)

    case state.samples[path] do
      %{sample: sample} -> {:ok, {:sample, sample}, state}
      nil -> {:error, "mxs could not load #{path}", state}
    end
  end

  # Changes a live audio's options in place, or starts it anew when its input, channels or effects change.
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
          put_in(state.samples[path], %{sample: sample, channels: channels})

        {:error, message} ->
          IO.puts(:stderr, "mxs could not load sample #{path}: #{message}")
          state
      end
    end
  end
end
