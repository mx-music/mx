defmodule Mx.Instrument do
  @moduledoc """
  Synths written in Elixir, as `defsynth`, which mxs builds when a note starts; the design is in the guide "Instruments defined in Elixir".

  A module that uses `Mx.Instrument` declares each synth's options with `attr` lines, as a Phoenix function component declares its assigns, and `envelope_attrs/1` for the seven options of the note's envelope.
  `defsynth` defines a synth as a function of one map, the note's options, with clauses that match on it; `defsound` and `defsoundp` define pieces a synth calls.

  When the module compiles, each clause runs once with the note's options as placeholders, and what its body does with them is recorded as a graph.
  Data written in the module takes any Elixir, while a placeholder takes only arithmetic, comparisons, `select/3` and the vocabulary of `Mx.Instrument.Vocabulary`.
  An `if` on a placeholder fails then, with its file and line, and so does a synth that ends with neither `note_envelope/2` nor `rings/2`.
  A module compiled outside mix's own compilation, such as one a song file defines, becomes known to mx as it compiles: songs play its synths by name, and mxs builds them from then on, so a `defsynth` saved in a song plays without restarting mx.

  In this first version an option is read once, when the note starts, so a change to it does not reach a playing note.
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
          defsound: 2,
          defsoundp: 2
        ]

      import Mx.Instrument.Vocabulary
      Module.register_attribute(__MODULE__, :mx_pending_attrs, accumulate: true)
      Module.register_attribute(__MODULE__, :mx_synths, accumulate: true)
      @before_compile Mx.Instrument
      @after_compile Mx.Instrument
    end
  end

  @doc "Declares an option of the next synth: its name, its unit or type, and `default:`, `range:`, `values:`, `required:` and `doc:`."
  defmacro attr(name, type, opts \\ []) do
    opts = Keyword.update(opts, :range, nil, &range/1)

    quote do
      @mx_pending_attrs {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc "Declares the seven options of the note's envelope, with the defaults given in place of the usual ones."
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

  @doc "Defines a clause of a synth, a function of the note's options that returns its sound."
  defmacro defsynth(call, do: body) do
    {name, [pattern]} = Macro.decompose_call(call)
    matches = Macro.escape(matches(pattern))
    line = __CALLER__.line

    quote do
      Mx.Instrument.__defsynth__(__MODULE__, unquote(name), unquote(matches), unquote(line))
      def unquote(name)(unquote(pattern)), do: unquote(rewrite(body, __CALLER__))
    end
  end

  @doc "Defines a piece of sound other modules' synths can call."
  defmacro defsound(call, do: body) do
    quote do
      def unquote(call), do: unquote(rewrite(body, __CALLER__))
    end
  end

  @doc "Defines a piece of sound only this module's synths call."
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

    quote do
      @doc false
      def __synths__, do: Mx.Instrument.trace(__MODULE__, unquote(synths), unquote(env.file))
    end
  end

  def __after_compile__(env, _bytecode) do
    env.module.__synths__()
    unless Code.can_await_module_compilation?(), do: known(env.module)
  end

  @doc "Makes a module's synths known to mx: songs can play them, and a running mxs engine builds them."
  def known(module) do
    :persistent_term.put({__MODULE__, :modules}, Enum.uniq(modules() ++ [module]))
    Mx.Synths.forget()

    case :persistent_term.get(Mx.Engine.Mxs, nil) do
      {engine, _origin} -> register(engine, module)
      nil -> :ok
    end
  end

  @doc "The modules whose synths mx knows, in the order they became known."
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

  @doc "Registers each synth of `module` with the mxs engine `engine`, as `Mx.Engine.Mxs.Native` starts it."
  def register(engine, module) do
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

  @doc "A synth's options as mxs declares them, for its catalog."
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
