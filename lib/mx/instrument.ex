defmodule Mx.Instrument do
  @moduledoc """
  Synths written in Elixir, as `defsynth`, which mxs builds when a note starts; the design is in the guide "Instruments defined in Elixir".

  A module that uses `Mx.Instrument` declares each synth's options with `attr` lines, as a Phoenix function component declares its assigns, and `envelope_attrs/1` for the seven options of the note's envelope.
  `defsynth` defines a synth as a function of one map, the note's options, with clauses that match on it; `defsound` and `defsoundp` define pieces a synth calls.
  `defeffect` defines an effect as a function of the sound coming in, one channel, and a map of its options, and a song applies it by name with `fx:`.

  When the module compiles, each clause runs once with the note's options as placeholders, and what its body does with them is recorded as a graph.
  Data written in the module takes any Elixir, while a placeholder takes only arithmetic, comparisons, `select/3` and the vocabulary of `Mx.Instrument.Vocabulary`.
  An `if` on a placeholder fails then, with its file and line, and so does a synth that ends with neither `note_envelope/2` nor `rings/2`.
  A module compiled outside mix's own compilation, such as one a song file defines, becomes known to mx as it compiles: songs play its synths by name, and mxs builds them from then on, so a `defsynth` saved in a song plays without restarting mx.

  An option is read once, when the note starts, unless the synth reads it with `follow/1`, which glides with each change the song makes while the note sounds.
  """

  alias Mx.Instrument.{Expr, Ops}

  @envelope [
    attack: {:beats, 0.0, "How long the note takes to rise to attack_level."},
    decay: {:beats, 0.0, "How long it then takes to fall to decay_level."},
    sustain: {:beats, 0.0, "How long it then holds, moving to sustain_level."},
    release: {:beats, 1.0, "How long it then takes to fall silent."},
    attack_level: {:float, 1.0, "The level the attack rises to."},
    decay_level: {:float, -1.0, "The level the decay falls to; sustain_level when below 0."},
    sustain_level: {:float, 1.0, "The level the note holds at."}
  ]

  @operators %{
    +: :add,
    -: :sub,
    *: :mul,
    /: :div,
    **: :pow,
    <: :lt,
    >: :gt,
    <=: :le,
    >=: :ge,
    ==: :eq,
    !=: :ne
  }

  defmacro __using__(_opts) do
    quote do
      import Mx.Instrument,
        only: [
          attr: 2,
          attr: 3,
          envelope_attrs: 0,
          envelope_attrs: 1,
          defsynth: 2,
          defeffect: 2,
          defsound: 2,
          defsoundp: 2
        ]

      import Mx.Instrument.Vocabulary
      Module.register_attribute(__MODULE__, :mx_pending_attrs, accumulate: true)
      Module.register_attribute(__MODULE__, :mx_synths, accumulate: true)
      Module.register_attribute(__MODULE__, :mx_effects, accumulate: true)
      @before_compile Mx.Instrument
      @after_compile Mx.Instrument
    end
  end

  @doc """
  Declares an option of the next `defsynth`.

  An `attr` line applies to the next `defsynth` after it, and only that one.
  Declare the options again before each synth.
  The synth's documentation lists them under "Options", so a `@doc` written above the first `attr` line gains that section.

  `name` is an atom, the key the synth reads from its map: `played.vel` reads the option `:vel`.
  `type` says what the value means: `:float`, `:note` for a MIDI note number, `:beats` for a length in beats, or `:atom` for a choice among names.

  ## Options

    * `:default` - the value a note gets when its song gives none.
    * `:range` - the lowest and highest value the option takes, as a range literal such as `0..1`.
      A song that sets a value outside it is refused when the song is saved.
    * `:values` - for an `:atom` option, the names it takes, as a list.
    * `:required` - when `true`, the option is marked as one a note has to set.
      Defaults to `false`.
    * `:doc` - one sentence saying what the option does, for the synth's documentation and catalog.

  ## Examples

      @doc "A marimba note."
      attr :note, :note, default: 52, doc: "The pitch."
      attr :vel, :float, default: 0.6, range: 0.05..1, doc: "How hard the bar is struck."
      defsynth marimba(hit) do
        ...
      end

  An option that picks among names lists them in `values:`.
  Clauses of the synth can then match on each name:

      attr :bol, :atom, values: [:na, :tun, :te], default: :na, doc: "The stroke."
  """
  defmacro attr(name, type, opts \\ []) do
    opts = Keyword.update(opts, :range, nil, &range/1)

    quote do
      @mx_pending_attrs {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc """
  Declares the seven options of the note's envelope: `attack`, `decay`, `sustain`, `release`, `attack_level`, `decay_level` and `sustain_level`.

  Each has the usual default and documentation, as the module's `@envelope` lists them.
  Pass a keyword list to give some of them another default; the others keep the usual one.
  Like `attr/3`, it applies to the next `defsynth`.

  ## Examples

  The usual envelope:

      envelope_attrs()

  A note that holds a long time and fades in 0.3 beats:

      envelope_attrs sustain: 1000, release: 0.3
  """
  defmacro envelope_attrs(defaults \\ []) do
    for {name, {type, default, doc}} <- @envelope do
      quote do
        @mx_pending_attrs {unquote(name), unquote(type),
                           default:
                             Keyword.get(unquote(defaults), unquote(name), unquote(default)),
                           doc: unquote(doc)}
      end
    end
  end

  defp range({:.., _, [low, high]}), do: {low, high}
  defp range(other), do: other

  @doc """
  Defines a clause of a synth, a function of the note's options that returns its sound.

  The argument is a pattern over the map of options.
  The synth is named after the function, and a song plays it by that name.
  Clauses of one synth sit next to each other, and the one whose pattern matches the note plays.
  Mx records a match only on atoms and numbers, such as `%{bol: :na}`.

  The body takes the arithmetic, comparisons and `select/3` described in the moduledoc, and ends with `note_envelope/2` or `rings/2`.
  Use `select/3` where you would write an `if` on an option.

  ## Examples

  One clause, reading its options by key:

      attr :note, :note, default: 52, doc: "The pitch."
      envelope_attrs()
      defsynth beep(played) do
        sine(hz: hz(played.note))
        |> note_envelope(played)
      end

  A clause per stroke, matched on the option's value:

      attr :bol, :atom, values: [:na, :tun], default: :na, doc: "The stroke."
      defsynth drum(%{bol: :na} = hit), do: ...
      defsynth drum(%{bol: :tun} = hit), do: ...
  """
  defmacro defsynth(call, do: body) do
    {name, [pattern]} = Macro.decompose_call(call)
    matches = Macro.escape(matches(pattern))
    line = __CALLER__.line

    quote do
      Mx.Instrument.__defsynth__(__MODULE__, unquote(name), unquote(matches), unquote(line))
      def unquote(name)(unquote(pattern)), do: unquote(rewrite(body, __CALLER__))
    end
  end

  @doc """
  Defines an effect, a function of the sound coming in and a map of its options, which returns the sound going out.

  `attr` lines before it declare its options, as for a synth.
  The effect shapes each channel on its own, so the sound coming in is one channel, and a song applies it by name with `fx:`.

  ## Examples

      attr :level, :float, default: 0.5, range: 0..1, doc: "How loud the sound comes out."
      defeffect quieter(sound, opts) do
        sound |> gain(opts.level)
      end
  """
  defmacro defeffect(call, do: body) do
    {name, [sound, pattern]} = Macro.decompose_call(call)
    line = __CALLER__.line

    quote do
      Mx.Instrument.__defeffect__(__MODULE__, unquote(name), unquote(line))
      def unquote(name)(unquote(sound), unquote(pattern)), do: unquote(rewrite(body, __CALLER__))
    end
  end

  @doc """
  Defines a piece of sound other modules' synths can call.

  It is a public function whose body takes the same arithmetic as a synth's.
  Use `defsoundp/2` for a piece only this module needs.

  ## Examples

      defsound mallet(hz, corner, slope), do: slope * max(log2(hz / corner), 0)
  """
  defmacro defsound(call, do: body) do
    quote do
      def unquote(call), do: unquote(rewrite(body, __CALLER__))
    end
  end

  @doc """
  Defines a piece of sound only this module's synths call.

  It is the private form of `defsound/2`, so other modules cannot call it.

  ## Examples

      defsoundp above(hz, corner), do: max(log2(hz / corner), 0)

      defsoundp mallet(hz, corner, slope) do
        slope * above(hz, corner)
      end
  """
  defmacro defsoundp(call, do: body) do
    quote do
      defp unquote(call), do: unquote(rewrite(body, __CALLER__))
    end
  end

  @doc false
  def __defsynth__(module, name, matches, line) do
    attrs = module |> Module.get_attribute(:mx_pending_attrs) |> Enum.reverse()
    Module.delete_attribute(module, :mx_pending_attrs)
    Module.put_attribute(module, :mx_synths, {name, attrs, matches, line})

    case {attrs, Module.get_attribute(module, :doc)} do
      {[], _} ->
        :ok

      {_, {doc_line, doc}} when is_binary(doc) ->
        Module.put_attribute(module, :doc, {doc_line, doc <> options_doc(attrs)})

      {_, _} ->
        Module.put_attribute(module, :doc, {line, String.trim_leading(options_doc(attrs))})
    end
  end

  @doc false
  def __defeffect__(module, name, line) do
    attrs = module |> Module.get_attribute(:mx_pending_attrs) |> Enum.reverse()
    Module.delete_attribute(module, :mx_pending_attrs)
    Module.put_attribute(module, :mx_effects, {name, attrs, line})

    with {doc_line, doc} when is_binary(doc) and attrs != [] <- Module.get_attribute(module, :doc) do
      Module.put_attribute(module, :doc, {doc_line, doc <> options_doc(attrs)})
    end
  end

  defp options_doc(attrs) do
    lines = Enum.map(attrs, &option_doc/1)
    joined = Enum.join(lines, "\n")
    "\n\n## Options\n\n#{joined}\n"
  end

  defp option_doc({name, type, opts}) do
    parts =
      [
        if(Keyword.has_key?(opts, :default), do: inspect(opts[:default]) <> " by default"),
        with({low, high} <- opts[:range], do: "from #{low} to #{high}"),
        with(
          [_ | _] = values <- opts[:values],
          do: "one of " <> Enum.map_join(values, ", ", &inspect/1)
        )
      ]
      |> Enum.reject(&is_nil/1)

    described = Enum.join([type | parts], ", ")
    doc = if opts[:doc], do: ": " <> opts[:doc], else: ""
    "- `#{name}`, #{described}#{doc}"
  end

  defmacro __before_compile__(env) do
    synths = env.module |> Module.get_attribute(:mx_synths) |> Enum.reverse() |> Macro.escape()
    effects = env.module |> Module.get_attribute(:mx_effects) |> Enum.reverse() |> Macro.escape()

    quote do
      @doc false
      def __synths__, do: Mx.Instrument.trace(__MODULE__, unquote(synths), unquote(env.file))

      @doc false
      def __effects__,
        do: Mx.Instrument.trace_effects(__MODULE__, unquote(effects), unquote(env.file))
    end
  end

  def __after_compile__(env, _bytecode) do
    env.module.__synths__()
    env.module.__effects__()
    unless Code.can_await_module_compilation?(), do: known(env.module)
  end

  @doc """
  Makes a module's synths known to mx: songs can play them, and a running mxs engine builds them.

  A module compiled outside mix's own compilation becomes known on its own, so call this only for a module compiled some other way.
  Calling it again for the same module is harmless.

  ## Examples

      Mx.Instrument.known(Mx.Instruments.Flute)
  """
  def known(module) do
    :persistent_term.put({__MODULE__, :modules}, Enum.uniq(modules() ++ [module]))
    Mx.Synths.forget()

    case :persistent_term.get(Mx.Engine.Mxs, nil) do
      {engine, _origin} -> register(engine, module)
      nil -> :ok
    end
  end

  @doc """
  The modules whose synths mx knows, in the order they became known.

  ## Examples

      Mx.Instrument.modules()
      #=> [Mx.Instruments.Marimba, Mx.Instruments.Flute]
  """
  def modules, do: :persistent_term.get({__MODULE__, :modules}, [])

  defp matches({:=, _, [left, right]}), do: matches(left) ++ matches(right)

  defp matches({:%{}, _, pairs}),
    do: for({key, value} <- pairs, is_atom(value) or is_number(value), do: {key, value})

  defp matches(_pattern), do: []

  defp rewrite(body, caller) do
    Macro.prewalk(body, fn
      {op, meta, [a, b]} when is_map_key(@operators, op) ->
        {{:., meta, [Ops, Map.fetch!(@operators, op)]}, meta, [a, b]}

      {:-, meta, [a]} ->
        {{:., meta, [Ops, :neg]}, meta, [a]}

      {fun, meta, [_, _] = args} when fun in [:max, :min] ->
        {{:., meta, [Ops, fun]}, meta, args}

      {:||, meta, [_, _] = args} ->
        {{:., meta, [Ops, :or_else]}, meta, args}

      {:abs, meta, [_] = args} ->
        {{:., meta, [Ops, :abs]}, meta, args}

      {:if, meta, [condition | rest]} ->
        line = Keyword.get(meta, :line, caller.line)

        checked =
          quote(
            do:
              Mx.Instrument.Ops.condition!(
                unquote(condition),
                unquote(caller.file),
                unquote(line)
              )
          )

        {:if, meta, [checked | rest]}

      other ->
        other
    end)
  end

  @doc false
  def trace(module, synths, file) do
    synths
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.map(fn [{name, attrs, _, _} | _] = clauses ->
      placeholders =
        Map.new(attrs, fn {option, _, _} -> {option, %Expr{op: :option, args: [option]}} end)

      traced =
        for {_, _, matches, line} <- clauses do
          sound = apply(module, name, [Map.merge(placeholders, Map.new(matches))])

          unless match?(%Expr{op: op} when op in [:note_envelope, :rings], sound) do
            raise CompileError,
              file: file,
              line: line,
              description:
                "#{name} ends with neither note_envelope nor rings, so mx cannot tell when its notes end"
          end

          {matches, sound}
        end

      %{name: name, attrs: attrs, clauses: traced}
    end)
  end

  @doc false
  def trace_effects(module, effects, file) do
    for {name, attrs, line} <- effects do
      placeholders =
        Map.new(attrs, fn {option, _, _} -> {option, %Expr{op: :option, args: [option]}} end)

      sound = apply(module, name, [%Expr{op: :input, args: []}, placeholders])

      if match?(%Expr{op: op} when op in [:note_envelope, :rings], sound) do
        raise CompileError,
          file: file,
          line: line,
          description:
            "#{name} is an effect, so it returns its sound, without note_envelope or rings"
      end

      %{name: name, attrs: attrs, sound: sound}
    end
  end

  @doc """
  Registers each synth and effect of `module` with the mxs engine `engine`, as `Mx.Engine.Mxs.Native` starts it.

  Returns `:ok` once every one is registered, or `{:error, reason}` at the first the engine refuses; the ones after it are not registered.
  `known/1` calls it for a running engine, so call it yourself only with an engine you started.
  """
  def register(engine, module) do
    with :ok <- register_synths(engine, module) do
      Enum.reduce_while(module.__effects__(), :ok, fn effect, :ok ->
        name = Atom.to_string(effect.name)

        case Mx.Engine.Mxs.Native.register_effect_graph(
               engine,
               name,
               specs(effect),
               encode(effect.sound)
             ) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp register_synths(engine, module) do
    Enum.reduce_while(module.__synths__(), :ok, fn synth, :ok ->
      clauses =
        for {matches, sound} <- synth.clauses,
            do: {Enum.map(matches, &encode_match/1), encode(sound)}

      case Mx.Engine.Mxs.Native.register_graph(
             engine,
             Atom.to_string(synth.name),
             specs(synth),
             clauses
           ) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp encode_match({key, value}) when is_atom(value),
    do: {Atom.to_string(key), Atom.to_string(value)}

  defp encode_match({key, value}), do: {Atom.to_string(key), value / 1}

  @doc false
  def encode(number) when is_number(number), do: number / 1
  def encode(true), do: 1.0
  def encode(false), do: 0.0
  def encode(atom) when is_atom(atom), do: {:name, Atom.to_string(atom)}
  def encode(list) when is_list(list), do: {:list, Enum.map(list, &encode/1)}
  def encode(%Expr{op: :option, args: [option]}), do: {:option, Atom.to_string(option)}

  def encode(%Expr{op: op, args: args, named: named}) do
    {:call, Atom.to_string(op), Enum.map(args, &encode/1),
     Enum.map(named, fn {key, value} -> {Atom.to_string(key), encode(value)} end)}
  end

  def encode(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> encode()

  @doc """
  A synth's options as mxs declares them, for its catalog.

  `synth` is one entry of a module's `__synths__/0`.
  Each option becomes a map with its `name`, `kind`, `values`, `default`, `default_name`, `low`, `high`, `required` and `doc`.
  Numbers are floats, and a missing default, low or high is `nil`.
  """
  def specs(synth), do: Enum.map(synth.attrs, &spec/1)

  defp spec({name, type, opts}) do
    {kind, values} =
      case type do
        :atom -> {"name", Enum.map(Keyword.get(opts, :values, []), &Atom.to_string/1)}
        type -> {Atom.to_string(type), []}
      end

    {low, high} = Keyword.get(opts, :range) || {nil, nil}
    default = Keyword.get(opts, :default)

    %{
      name: Atom.to_string(name),
      kind: kind,
      values: values,
      default: if(is_number(default), do: default / 1),
      default_name: if(is_atom(default) and default != nil, do: Atom.to_string(default)),
      low: low && low / 1,
      high: high && high / 1,
      required: Keyword.get(opts, :required, false),
      doc: Keyword.get(opts, :doc, "")
    }
  end
end
