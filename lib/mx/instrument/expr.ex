defmodule Mx.Instrument.Expr do
  @moduledoc "A value a `defsynth` works out from the note's options: one option, or a call of the vocabulary on its arguments and named arguments."
  defstruct [:op, args: [], named: []]

  @doc "Whether `value` depends on the note."
  def traced?(%__MODULE__{}), do: true
  def traced?(list) when is_list(list), do: Enum.any?(list, &traced?/1)
  def traced?(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> traced?()
  def traced?(_), do: false

  @doc "A call of the vocabulary."
  def call(op, args, named \\ []), do: %__MODULE__{op: op, args: args, named: named}
end

defmodule Mx.Instrument.Ops do
  @moduledoc "The arithmetic a `defsynth`'s operators become: on numbers it is Elixir's own, and on anything worked out from the note it records the operation."
  alias Mx.Instrument.Expr

  for {name, op} <- [
        add: :+,
        sub: :-,
        mul: :*,
        div: :/,
        lt: :<,
        gt: :>,
        le: :<=,
        ge: :>=,
        eq: :==,
        ne: :!=,
        max: :max,
        min: :min
      ] do
    @doc false
    def unquote(name)(%Expr{} = a, b), do: Expr.call(unquote(name), [a, b])
    def unquote(name)(a, %Expr{} = b), do: Expr.call(unquote(name), [a, b])
    def unquote(name)(a, b), do: Kernel.unquote(op)(a, b)
  end

  @doc false
  def pow(a, b) when is_number(a) and is_number(b), do: :math.pow(a, b)
  def pow(a, b), do: Expr.call(:pow, [a, b])

  @doc false
  def neg(%Expr{} = a), do: Expr.call(:neg, [a])
  def neg(a), do: -a

  @doc false
  def abs(%Expr{} = a), do: Expr.call(:abs, [a])
  def abs(a), do: Kernel.abs(a)

  @doc false
  def or_else(%Expr{op: :option} = option, fallback), do: Expr.call(:or_else, [option, fallback])
  def or_else(value, fallback), do: if(value, do: value, else: fallback)

  @doc false
  def condition!(%Expr{}, file, line) do
    raise CompileError,
      file: file,
      line: line,
      description:
        "an if cannot depend on the note's options; pick between two values with select(condition, then, else)"
  end

  def condition!(condition, _file, _line), do: condition
end

defmodule Mx.Instrument.Vocabulary do
  @moduledoc """
  The nodes and functions a `defsynth` builds its sound from, named by what they do, with each argument named by its unit.

  Numbers: `hz/1`, `db/1`, `log2/1`, `exp/1`, `sin/1`, `cos/1`, `clamp/3` and `select/3`, worked out at once on numbers and when the note starts on its options.
  Sources: `impulse/0`, `sine/1`, `saw/1`, `square/1`, `triangle/1`, `pulse/1` and `noise/1`.
  Filters: `lowpass/2`, `highpass/2` and `bandpass/2`, at `hz:` with `q:` and `poles:`, `lowshelf/2`, `highshelf/2` and `peak/2`, at `hz:` with `q:` and `db:`, and `mode/2`, a resonator struck by its input at `hz:`, ringing at `level:` and fading 60 dB over `fade:` seconds.
  Shapes: `envelope/1` and `perc/1` are levels over time, and `envelope/2` and `perc/2` scale a sound by them.
  Mixing: `mix/1` adds a list of sounds, and `gain/2` scales one.
  A synth ends with `note_envelope/2`, shaping its sound by the note's envelope, or `rings/2`, ending it after `seconds:`.
  """

  alias Mx.Instrument.Expr

  @doc "The frequency of a MIDI note."
  def hz(note) when is_number(note), do: 440 * :math.pow(2, (note - 69) / 12)
  def hz(note), do: Expr.call(:hz, [note])

  @doc "The gain of a level in decibels."
  def db(decibels) when is_number(decibels), do: :math.pow(10, decibels / 20)
  def db(decibels), do: Expr.call(:db, [decibels])

  for name <- [:log2, :exp, :sin, :cos] do
    @doc false
    def unquote(name)(x) when is_number(x), do: :math.unquote(name)(x)
    def unquote(name)(x), do: Expr.call(unquote(name), [x])
  end

  @doc "`x`, held between `low` and `high`."
  def clamp(x, low, high) when is_number(x) and is_number(low) and is_number(high),
    do: x |> Kernel.max(low) |> Kernel.min(high)

  def clamp(x, low, high), do: Expr.call(:clamp, [x, low, high])

  @doc "`then` where `condition` holds, and `otherwise` elsewhere."
  def select(condition, then, otherwise) when is_boolean(condition),
    do: if(condition, do: then, else: otherwise)

  def select(condition, then, otherwise), do: Expr.call(:select, [condition, then, otherwise])

  @doc "A single sample at the start of the note."
  def impulse, do: Expr.call(:impulse, [])

  for wave <- [:sine, :saw, :square, :triangle, :pulse] do
    @doc false
    def unquote(wave)(opts), do: Expr.call(unquote(wave), [], opts)
  end

  @doc "Noise, `:white` or `:pink`."
  def noise(colour), do: Expr.call(:noise, [colour])

  for filter <- [:lowpass, :highpass, :bandpass, :lowshelf, :highshelf, :peak, :mode] do
    @doc false
    def unquote(filter)(sound, opts), do: Expr.call(unquote(filter), [sound], opts)
  end

  @doc "Segments from silence through each point, `{seconds, level}` straight, `{seconds, level, curve}` bent, or `{seconds, level, :exp}` exponential."
  def envelope(points), do: Expr.call(:envelope, [points])
  def envelope(sound, points), do: Expr.call(:envelope, [sound, points])

  @doc "A quick rise over `attack:` and a fall to silence over `release:`."
  def perc(opts), do: Expr.call(:perc, [], opts)
  def perc(sound, opts), do: Expr.call(:perc, [sound], opts)

  @doc "Sounds added together."
  def mix(sounds), do: Expr.call(:mix, [sounds])

  @doc "A sound scaled by a level."
  def gain(sound, level), do: Expr.call(:gain, [sound, level])

  @doc "A sound shaped by the note's envelope, from the options `envelope_attrs/1` declares."
  def note_envelope(sound, _note), do: Expr.call(:note_envelope, [sound])

  @doc "A sound that rings until it fades by itself, ending after `seconds:`."
  def rings(sound, opts), do: Expr.call(:rings, [sound], opts)
end
