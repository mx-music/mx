defmodule Mx.Song do
  @moduledoc """
  A song loaded from a file: its tempo and its parts, each played as a loop, in the order of the song.
  `tempos` holds the tempo changes its music writes, each section's as `Mx.Tempo` takes them, or nil when it writes none.
  """

  alias Mx.{Samples, Synths}

  defmodule Loop do
    @moduledoc "A part of the song played as a loop, with the music it replays and the samples it uses."
    defstruct [
      :name,
      :synth,
      :file,
      :midi,
      :osc_to,
      :on,
      :line,
      :music,
      :passes,
      fx: [],
      defaults: [],
      samples: [],
      buffers: %{}
    ]
  end

  defmodule Live do
    @moduledoc "A live audio input the song declares: the sound card input it plays, in mono or stereo, with its options and effects."
    defstruct [:name, input: 1, stereo: false, opts: [], fx: []]
  end

  defstruct tempo: 60, tempos: nil, osc_to: nil, osc_from: nil, loops: [], live: []

  @key :mx_song

  @chain_error "fx: takes an effect or a list of effects, such as fx: [echo: [phase: 0.5], reverb: []]"

  @doc "Loads a song file, and returns `{:ok, song}` or `{:error, message}` naming the file and line."
  def load(path) when is_binary(path) do
    Process.put(@key, %__MODULE__{})

    try do
      # Seeded from the file, so the random numbers a song's music is built with are the same on every load.
      :rand.seed(:exsss, {:erlang.phash2(Path.expand(path)), 0, 0})

      case eval_file(path) do
        %Mx.Music.Song{} = song -> Mx.Music.load(song)
        _ -> :ok
      end

      song = Process.get(@key)
      loops = Enum.map(Enum.reverse(song.loops), &%{&1 | file: path, osc_to: song.osc_to})

      live = Enum.reverse(song.live)

      with :ok <- check(loops, path, live),
           {:ok, live} <- check_live(live, path),
           {:ok, loops} <- find_effects(loops),
           {:ok, loops} <- find_samples(loops) do
        {:ok, %{song | loops: loops, live: live}}
      end
    rescue
      error -> {:error, Exception.message(error)}
    after
      Process.delete(@key)
    end
  end

  # Elixir logs why a module did not compile and raises without the line, so the first error it logged names it.
  defp eval_file(path) do
    {result, diagnostics} =
      Code.with_diagnostics([log: true], fn ->
        # A module the song file defines is compiled again on every load, which is no conflict to warn about.
        ignoring = Code.get_compiler_option(:ignore_module_conflict)
        Code.put_compiler_option(:ignore_module_conflict, true)

        try do
          {value, _binding} = Code.eval_file(path)
          {:ok, value}
        rescue
          error -> {:error, error, __STACKTRACE__}
        after
          Code.put_compiler_option(:ignore_module_conflict, ignoring)
        end
      end)

    case result do
      {:ok, value} ->
        value

      {:error, %CompileError{} = error, stacktrace} ->
        case Enum.find(diagnostics, &(&1.severity == :error)) do
          %{position: position, message: message} ->
            line = if is_tuple(position), do: elem(position, 0), else: position
            [first | _] = String.split(message, "\n")
            raise ArgumentError, "#{path}:#{line}: #{first}"

          nil ->
            reraise error, stacktrace
        end

      {:error, error, stacktrace} ->
        message = Exception.message(error)
        line = song_line(stacktrace, path)

        if line && not String.starts_with?(message, path) do
          reraise ArgumentError, [message: "#{path}:#{line}: #{message}"], stacktrace
        else
          reraise error, stacktrace
        end
    end
  end

  # The line of the song file running when an error was raised, which Elixir keeps in the stacktrace even for code at the top of the file.
  defp song_line(stacktrace, path) do
    file = Path.expand(path)

    Enum.find_value(stacktrace, fn {_, _, _, info} ->
      if info[:file] && Path.expand(to_string(info[:file])) == file, do: info[:line]
    end)
  end

  @doc "Records a part of the song being loaded as a loop that replays its music, ending after a number of passes, or never with nil."
  def put_music_loop(%Mx.Music.Part{} = part, music, passes, on \\ nil)
      when is_map(music) and (is_integer(passes) or is_nil(passes)) do
    loop = %Loop{
      name: part.name,
      synth: part.synth,
      fx: part.fx,
      defaults: part.defaults,
      midi: part.midi,
      line: 1,
      music: music,
      passes: passes,
      on: on,
      samples: Map.get(music, :samples, [])
    }

    update(&%{&1 | loops: [loop | &1.loops]})
  end

  @doc "Records the tempo of the song being loaded."
  def put_tempo(bpm) when is_number(bpm), do: update(&%{&1 | tempo: bpm})

  @doc "Records the tempo changes the music of the song being loaded writes."
  def put_tempos(tempos) when is_map(tempos), do: update(&%{&1 | tempos: tempos})

  @doc "Records where the song being loaded sends OSC."
  def put_osc_to(host, port) when is_binary(host) and is_integer(port) do
    update(&%{&1 | osc_to: {host, port}})
  end

  @doc "Records the port the song being loaded takes OSC from."
  def put_osc_from(port) when is_integer(port), do: update(&%{&1 | osc_from: port})

  @doc "Records a live audio input of the song being loaded."
  def put_live(name, opts) when is_atom(name) and is_list(opts) do
    live = %Live{name: name, opts: opts}
    update(&%{&1 | live: [live | &1.live]})
  end

  defp check([], path, []), do: {:error, "#{path} does not end with a song"}

  defp check(loops, path, _live) do
    names = Enum.map(loops, & &1.name)
    duplicate = List.first(names -- Enum.uniq(names))
    unknown = Enum.find(loops, &(not Synths.exists?(&1.synth)))
    trigger = Enum.find(loops, &(not trigger?(&1.on)))

    cond do
      duplicate ->
        {:error, "#{path} describes loop #{duplicate} twice"}

      unknown ->
        name = unknown.name
        synth = unknown.synth
        {:error, "loop #{name} uses synth #{synth}, which mx does not have"}

      trigger ->
        name = trigger.name
        on = inspect(trigger.on)
        {:error, "loop #{name}: on: takes :midi_note, :midi_cc or {:osc, address}, not #{on}"}

      true ->
        check_defaults(loops, path)
    end
  end

  defp check_defaults(loops, path) do
    Enum.find_value(loops, :ok, fn loop ->
      name = loop.name
      line = loop.line
      synth = loop.synth

      if Keyword.keyword?(loop.defaults) do
        case Enum.find(Keyword.keys(loop.defaults), &(not Synths.option?(synth, &1))) do
          nil ->
            nil

          option ->
            {:error, "#{path}:#{line}: loop #{name}: synth #{synth} has no option #{option}"}
        end
      else
        {:error,
         "#{path}:#{line}: loop #{name}: defaults: takes a list of options, such as defaults: [amp: 0.5]"}
      end
    end)
  end

  defp trigger?(on) do
    on in [nil, :midi_note, :midi_cc] or match?({:osc, address} when is_binary(address), on)
  end

  defp find_effects(loops) do
    found = Enum.map(loops, &find_loop_effects/1)

    case Enum.find(found, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(found, fn {:ok, loop} -> loop end)}
      error -> error
    end
  end

  defp check_live(live, path) do
    names = Enum.map(live, & &1.name)

    case List.first(names -- Enum.uniq(names)) do
      nil ->
        found = Enum.map(live, &check_one_live/1)

        case Enum.find(found, &match?({:error, _}, &1)) do
          nil -> {:ok, Enum.map(found, fn {:ok, live} -> live end)}
          error -> error
        end

      duplicate ->
        {:error, "#{path} describes live_audio #{duplicate} twice"}
    end
  end

  defp check_one_live(%Live{name: name, opts: opts} = live) do
    input = Keyword.get(opts, :input, 1)
    stereo = Keyword.get(opts, :stereo, false)
    synth_opts = Keyword.drop(opts, [:input, :stereo, :fx])
    synth = if stereo, do: :live_audio_stereo, else: :live_audio_mono

    unknown =
      Enum.find(Keyword.keys(synth_opts), &(&1 == :out_bus or not Synths.option?(synth, &1)))

    cond do
      unknown ->
        {:error, "live_audio #{name} has no option #{unknown}"}

      not (is_integer(input) and input >= 1) ->
        input = inspect(input)
        {:error, "live_audio #{name}: input must be 1 or more, not #{input}"}

      true ->
        with {:ok, chain} <- chain(Keyword.get(opts, :fx, [])),
             :ok <- check_effects(chain) do
          {:ok, %{live | input: input, stereo: stereo == true, opts: synth_opts, fx: chain}}
        else
          {:error, message} -> {:error, "live_audio #{name}: #{message}"}
        end
    end
  end

  @doc "Checks an fx: option, an effect or a list of effects with their options, as `:ok` or `{:error, message}`."
  def check_fx(fx) do
    with {:ok, chain} <- chain(fx), do: check_effects(chain)
  end

  defp find_loop_effects(loop) do
    name = loop.name

    with {:ok, chain} <- chain(loop.fx),
         :ok <- check_effects(chain) do
      {:ok, %{loop | fx: chain}}
    else
      {:error, message} -> {:error, "loop #{name}: #{message}"}
    end
  end

  defp chain(effect) when is_atom(effect) and effect != nil, do: chain([effect])

  defp chain(effects) when is_list(effects) do
    chain =
      Enum.map(effects, fn
        effect when is_atom(effect) and effect != nil -> {effect, []}
        {effect, opts} when is_atom(effect) and is_list(opts) -> {effect, opts}
        _ -> nil
      end)

    if nil in chain or not Enum.all?(chain, fn {_, opts} -> Keyword.keyword?(opts) end) do
      chain(nil)
    else
      {:ok, chain}
    end
  end

  defp chain(_fx), do: {:error, @chain_error}

  defp check_effects(chain) do
    Enum.find_value(chain, :ok, fn {effect, opts} ->
      if Synths.effect?(effect) do
        case Enum.find(Keyword.keys(opts), &(not Synths.effect_option?(effect, &1))) do
          nil -> nil
          option -> {:error, "effect #{effect} has no option #{option}"}
        end
      else
        {:error, "mx has no effect #{effect}"}
      end
    end)
  end

  defp find_samples(loops) do
    found = Enum.map(loops, &find_loop_samples/1)

    case Enum.find(found, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(found, fn {:ok, loop} -> loop end)}
      error -> error
    end
  end

  defp sampled_files(%Mx.Sampled{keys: keys}) do
    for {_note, strengths} <- keys, takes <- Tuple.to_list(strengths), path <- takes, do: path
  end

  defp sampled_files(_synth), do: []

  defp find_loop_samples(loop) do
    found = Enum.map(loop.samples ++ sampled_files(loop.synth), &Samples.path/1)

    case Enum.find(found, &match?({:error, _}, &1)) do
      nil ->
        {:ok, %{loop | samples: Enum.map(found, fn {:ok, path} -> path end)}}

      {:error, message} ->
        name = loop.name
        {:error, "loop #{name}: #{message}"}
    end
  end

  defp update(fun), do: Process.put(@key, fun.(Process.get(@key)))
end
