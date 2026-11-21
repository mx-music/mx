defmodule Mx.Song do
  @moduledoc """
  A song loaded from a file: its tempo, its `meter` in beats to a bar, its `key`, nil when it states none, and its parts, each played as a loop, in the order of the song.
  `tempos` holds the tempo changes its music writes, each section's as `Mx.Tempo` takes them, or nil when it writes none.

  A song file is either a script that ends with `Mx.song/1`, or a module that uses `Mx.Song`:

      defmodule Paredao do
        @moduledoc "A kick and an 808 bass at 92 beats a minute."

        use Mx.Song, tempo: 92

        part :kick, synth: :kick, fx: [level: [amp: 0.6]]
        part :bass, synth: :sub808

        def song, do: together([part(:kick, steps("x...", 1)), part(:bass, note(:g1, 4))])
      end

  `use Mx.Song` imports `Mx` and takes the options of `Mx.song/1` but `music:`, which is what the module's `song/0` returns.
  `part/2` written in the module's body declares a part with its options, once, and written in a function it is that part playing some music, with those options.
  A part that is not declared does not compile.
  `together/1` in a function takes declared parts by name, as `together(kick: steps("x...", 1), bass: note(:g1, 4))`.
  `kit/2` in the body declares a kit of strokes, each played by a declared part, and `kit/3` in a function plays one pattern on all of them.
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

  defstruct tempo: 60,
            meter: 4,
            key: nil,
            tempos: nil,
            osc_to: nil,
            osc_from: nil,
            loops: [],
            live: [],
            played: []

  @key :mx_song
  @modules_key :mx_song_modules

  defmacro __using__(opts) do
    quote do
      import Mx, except: [part: 2, together: 1]
      import Mx.Song, only: [part: 2, together: 1, kit: 2, kit: 3, kit: 4]
      Module.register_attribute(__MODULE__, :mx_parts, accumulate: true)
      Module.register_attribute(__MODULE__, :mx_kits, accumulate: true)
      @mx_song unquote(opts)
      @before_compile Mx.Song
    end
  end

  @doc "In a module's body, declares a part with its options; in a function, that part playing music with the options it was declared with."
  defmacro part(name, given) do
    if __CALLER__.function do
      declared = Module.get_attribute(__CALLER__.module, :mx_parts)

      if is_atom(name) and not List.keymember?(declared, name, 0) do
        refuse(
          __CALLER__,
          "part #{name} is not declared; declare it with part :#{name}, synth: ..."
        )
      end

      quote do
        Mx.part(unquote(name), unquote(given), Mx.Song.declared(__mx_parts__(), unquote(name)))
      end
    else
      quote do
        @mx_parts {unquote(name), unquote(given)}
      end
    end
  end

  @doc "Music whose items all start at once, as `Mx.together/1`, where an item given as `{name, music}` is that declared part playing the music."
  defmacro together(items) do
    location = [file: String.to_charlist(__CALLER__.file), line: __CALLER__.line]

    quote do
      Mx.Song.together_parts(__mx_parts__(), unquote(items), unquote(location))
    end
  end

  @doc false
  def together_parts(declared, items, location) when is_list(items) do
    items
    |> Enum.map(fn
      {name, music} when is_atom(name) and not is_number(music) ->
        if not List.keymember?(declared, name, 0) do
          message = "part #{name} is not declared; declare it with part :#{name}, synth: ..."
          # together is often the song's last call, whose frame the stacktrace drops.
          reraise ArgumentError, [message: message], [{__MODULE__, :together, 1, location}]
        end

        Mx.part(name, music, declared(declared, name))

      item ->
        item
    end)
    |> Mx.together()
  end

  def together_parts(_declared, items, _location), do: Mx.together(items)

  @doc "In a module's body, declares a kit: its strokes, each with the declared part that plays it and its options, or as a list of other strokes it plays together."
  defmacro kit(name, strokes) do
    if __CALLER__.function do
      refuse(
        __CALLER__,
        "kit takes a pattern and a step in a function, as kit(:#{name}, ~MX\"o h\", 0.25)"
      )
    end

    line = __CALLER__.line

    quote do
      @mx_kits {unquote(name), unquote(strokes), unquote(line)}
    end
  end

  @doc "In a function, the kit playing a pattern: each of its parts plays the strokes that name it, at the beats `Mx.steps/3` gives them, and the options are those of steps but `strokes:`."
  defmacro kit(name, pattern, step, opts \\ []) do
    declared = Module.get_attribute(__CALLER__.module, :mx_kits)

    if is_atom(name) and not Enum.any?(declared, &(elem(&1, 0) == name)) do
      refuse(__CALLER__, "kit #{name} is not declared; declare it with kit :#{name}, ...")
    end

    location = [file: String.to_charlist(__CALLER__.file), line: __CALLER__.line]

    quote do
      Mx.Song.play_kit(
        __mx_kits__(),
        __mx_parts__(),
        unquote(name),
        unquote(pattern),
        unquote(step),
        unquote(opts),
        unquote(location)
      )
    end
  end

  @doc false
  def play_kit(kits, parts, name, pattern, step, opts, location) do
    strokes = Keyword.fetch!(kits, name)
    cells = Mx.Music.pattern_cells(pattern)
    words = for {stroke, _} <- strokes, do: to_string(stroke)

    for %{tokens: tokens} <- cells, token <- tokens, token not in words do
      reraise ArgumentError,
              [message: "kit #{name} has no stroke #{token}"],
              [{__MODULE__, :kit, 3, location}]
    end

    played = for {stroke, _} <- strokes, do: {stroke, struck(strokes, stroke)}
    kit_parts = played |> Enum.flat_map(fn {_, hits} -> Keyword.keys(hits) end) |> Enum.uniq()

    Mx.together(
      for part <- kit_parts do
        own = for {stroke, hits} <- played, {^part, hit} <- hits, do: {stroke, hit}
        plays = for {stroke, _} <- own, do: to_string(stroke)

        part_cells =
          for cell <- cells,
              cell = %{cell | tokens: Enum.filter(cell.tokens, &(&1 in plays))},
              not (Map.get(cell, :grace, false) and cell.tokens == []),
              do: cell

        Mx.part(part, Mx.steps(part_cells, step, [strokes: own] ++ opts), declared(parts, part))
      end
    )
  end

  # The hits a stroke plays, as {part, options}, a stroke of other strokes playing theirs.
  defp struck(strokes, stroke) do
    case Keyword.fetch!(strokes, stroke) do
      [name | _] = names when is_atom(name) -> Enum.flat_map(names, &struck(strokes, &1))
      opts -> [Keyword.pop!(opts, :part)]
    end
  end

  defmacro __before_compile__(env) do
    parts = env.module |> Module.get_attribute(:mx_parts) |> Enum.reverse()
    names = Keyword.keys(parts)

    case names -- Enum.uniq(names) do
      [] -> :ok
      [name | _] -> refuse(env, "part #{name} is declared twice")
    end

    kits = env.module |> Module.get_attribute(:mx_kits) |> Enum.reverse()
    check_kits(env, kits, names)

    if not Module.defines?(env.module, {:song, 0}) do
      refuse(env, "a module that uses Mx.Song returns its music from song/0")
    end

    if Process.get(@key), do: Process.put(@modules_key, [env.module | modules()])

    quote do
      @doc false
      def __mx_parts__, do: unquote(Macro.escape(parts))

      @doc false
      def __mx_kits__,
        do: unquote(Macro.escape(for {name, strokes, _} <- kits, do: {name, strokes}))

      @doc false
      def __mx_song__, do: Mx.song([music: song()] ++ @mx_song)
    end
  end

  defp check_kits(env, kits, parts) do
    Enum.reduce(kits, [], fn {name, strokes, line}, seen ->
      at = %{env | line: line}

      if name in seen, do: refuse(at, "kit #{name} is declared twice")

      if not Keyword.keyword?(strokes) or strokes == [] do
        refuse(at, "kit #{name} takes its strokes, such as kit :#{name}, o: [part: :thumb]")
      end

      for {stroke, given} <- strokes do
        case given do
          [other | _] = others when is_atom(other) ->
            for other <- others, not Keyword.has_key?(strokes, other) do
              refuse(
                at,
                "kit #{name}'s stroke #{stroke} names stroke #{other}, which the kit does not have"
              )
            end

          opts when is_list(opts) ->
            case Keyword.fetch(opts, :part) do
              {:ok, part} when is_atom(part) ->
                if part not in parts do
                  refuse(at, "kit #{name} names part #{part}, which is not declared")
                end

              _ ->
                refuse(
                  at,
                  "kit #{name}'s stroke #{stroke} names no part:, as #{stroke}: [part: :thumb]"
                )
            end
        end
      end

      [name | seen]
    end)
  end

  @doc false
  def declared(parts, name) do
    case List.keyfind(parts, name, 0) do
      {_, opts} -> opts
      nil -> raise ArgumentError, "part #{name} is not declared"
    end
  end

  defp refuse(env, description) do
    raise CompileError, file: env.file, line: env.line, description: description
  end

  defp modules, do: Process.get(@modules_key, [])

  @chain_error "fx: takes an effect or a list of effects, such as fx: [echo: [phase: 0.5], reverb: []]"

  @doc "Loads a song file, or with `source:` that text as though it were the file at `path`, which need not exist, and returns `{:ok, song}` or `{:error, message}` naming the file and line."
  def load(path, opts \\ []) when is_binary(path) and is_list(opts) do
    case read(path, opts) do
      :module -> {:error, "#{path} does not end with a song"}
      read -> read
    end
  end

  @doc "Reads a song file as `load/2` does, but returns `:module` for a file that compiles, ends with a module and describes no song, as a file of modules other songs use does."
  def read(path, opts \\ []) when is_binary(path) and is_list(opts) do
    Process.put(@key, %__MODULE__{})

    try do
      # Seeded from the file, so the random numbers a song's music is built with are the same on
      # every load.
      :rand.seed(:exsss, {:erlang.phash2(Path.expand(path)), 0, 0})

      value = eval_file(path, opts[:source])
      if match?(%Mx.Music.Song{}, value), do: Mx.Music.load(value)

      song = Process.get(@key)
      loops = Enum.map(Enum.reverse(song.loops), &%{&1 | file: path, osc_to: song.osc_to})

      live = Enum.reverse(song.live)

      with :ok <- check(loops, path, live, value),
           {:ok, live} <- check_live(live, path),
           {:ok, loops} <- find_effects(loops),
           {:ok, loops} <- find_samples(loops) do
        Enum.each(level_warnings(song.played), &IO.puts(:stderr, &1))
        {:ok, %{song | loops: loops, live: live, played: []}}
      end
    rescue
      error -> {:error, Exception.message(error)}
    after
      Process.delete(@key)
      Process.delete(@modules_key)
    end
  end

  # Elixir logs why a module did not compile and raises without the line, so the first error it
  # logged names it.
  defp eval_file(path, source) do
    {result, diagnostics} =
      Code.with_diagnostics([log: true], fn ->
        # A module the song file defines is compiled again on every load, which is no conflict to
        # warn about.
        ignoring = Code.get_compiler_option(:ignore_module_conflict)
        Code.put_compiler_option(:ignore_module_conflict, true)

        try do
          {value, _binding} =
            if source,
              do: Code.eval_string(source, [], file: path),
              else: Code.eval_file(path)

          {:ok, written(value, path)}
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
            if error.line && error.description do
              line = error.line
              description = error.description
              reraise ArgumentError, [message: "#{path}:#{line}: #{description}"], stacktrace
            else
              reraise error, stacktrace
            end
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

  # The song a file ends with, or the song of the module in it that uses Mx.Song.
  defp written(%Mx.Music.Song{} = song, _path), do: song

  defp written(value, path) do
    case modules() do
      [] ->
        value

      [module] ->
        module.__mx_song__()

      [second, first | _] ->
        first = inspect(first)
        second = inspect(second)
        raise ArgumentError, "#{path} holds two songs, #{first} and #{second}"
    end
  end

  # The line of the song file running when an error was raised, which Elixir keeps in the
  # stacktrace even for code at the top of the file.
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

  @doc "Records a sample the song being loaded plays, and whether it plays normalized, so a silent or quiet file is named once it has loaded."
  def put_played(ref, path, normalized?) do
    if Process.get(@key), do: update(&%{&1 | played: [{ref, path, normalized?} | &1.played]})
    :ok
  end

  # One line for each file that is silent, or too quiet to hear where it plays without normalize.
  defp level_warnings(played) do
    played
    |> Enum.reverse()
    |> Enum.group_by(fn {_ref, path, _} -> path end)
    |> Enum.sort_by(fn {_path, [{ref, _, _} | _]} -> Samples.name(ref) end)
    |> Enum.flat_map(fn {path, [{ref, _, _} | _] = uses} ->
      normalized? = Enum.all?(uses, fn {_, _, normalized?} -> normalized? end)
      List.wrap(Samples.level_warning(ref, Samples.peak(path), normalized?))
    end)
  end

  @doc "Records the tempo of the song being loaded."
  def put_tempo(bpm) when is_number(bpm), do: update(&%{&1 | tempo: bpm})

  @doc "Records the beats to a bar of the song being loaded."
  def put_meter(beats) when is_integer(beats), do: update(&%{&1 | meter: beats})

  @doc "Records the key the song being loaded states, such as `:em`."
  def put_key(key) when is_atom(key), do: update(&%{&1 | key: key})

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

  defp check([], _path, [], {:module, _, _, _}), do: :module
  defp check([], path, [], _value), do: {:error, "#{path} does not end with a song"}

  defp check(loops, path, _live, _value) do
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
