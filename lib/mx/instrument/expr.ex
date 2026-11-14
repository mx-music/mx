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
    def unquote(name)(%Expr{} = left, right), do: Expr.call(unquote(name), [left, right])
    def unquote(name)(left, %Expr{} = right), do: Expr.call(unquote(name), [left, right])
    def unquote(name)(left, right), do: Kernel.unquote(op)(left, right)
  end

  @doc false
  def pow(base, exponent) when is_number(base) and is_number(exponent) do
    :math.pow(base, exponent)
  end

  def pow(base, exponent), do: Expr.call(:pow, [base, exponent])

  @doc false
  def neg(%Expr{} = value), do: Expr.call(:neg, [value])
  def neg(value), do: -value

  @doc false
  def abs(%Expr{} = value), do: Expr.call(:abs, [value])
  def abs(value), do: Kernel.abs(value)

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
  Sources: `impulse/0`, `follow/1`, `time/0`, `sine/1`, `vibrato/1`, `partials/2`, `bowed_string/1`, `air_jet/1`, `saw/1`, `square/1`, `triangle/1`, `pulse/1` and `noise/1`.
  Filters: `lowpass/2`, `highpass/2` and `bandpass/2`, at `hz:` with `q:` and `poles:`, `lowshelf/2`, `highshelf/2` and `peak/2`, at `hz:` with `q:` and `db:`, `mode/2`, a resonator struck by its input at `hz:`, ringing at `level:` and fading 60 dB over `fade:` seconds, `wind_bands/2`, `delay/2`, and `dc_block/1`.
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
    def unquote(name)(value) when is_number(value), do: :math.unquote(name)(value)
    def unquote(name)(value), do: Expr.call(unquote(name), [value])
  end

  @doc "`value`, held between `low` and `high`."
  def clamp(value, low, high) when is_number(value) and is_number(low) and is_number(high) do
    value |> Kernel.max(low) |> Kernel.min(high)
  end

  def clamp(value, low, high), do: Expr.call(:clamp, [value, low, high])

  @doc "`then` where `condition` holds, and `otherwise` elsewhere."
  def select(condition, then, otherwise) when is_boolean(condition) do
    if(condition, do: then, else: otherwise)
  end

  def select(condition, then, otherwise), do: Expr.call(:select, [condition, then, otherwise])

  @doc "A single sample at the start of the note."
  def impulse, do: Expr.call(:impulse, [])

  for wave <- [:sine, :saw, :square, :triangle, :pulse] do
    @doc false
    def unquote(wave)(opts), do: Expr.call(unquote(wave), [], opts)
  end

  @doc "Harmonics of the pitch `hz` at each of `ratios:`, with their `levels:` and starting `phases:` in radians; a level of 0 leaves its harmonic out."
  def partials(hz, opts), do: Expr.call(:partials, [hz], opts)

  @doc "One of the note's options as a sound, gliding to each new value the song gives over the option's `_slide` seconds."
  def follow(%Expr{op: :option} = option), do: Expr.call(:follow, [option])

  @doc "The seconds since the note started."
  def time, do: Expr.call(:time, [])

  @doc "A bowed string at the MIDI `note:`, bowed at `speed:` and `force:`, reached over `takes:` seconds, at `position:` along it from the bridge, its speed swayed by `rosin:` times pink noise."
  def bowed_string(opts), do: Expr.call(:bowed_string, [], opts)

  @doc "A vibrato's swing `depth:` deep at `hz:`, growing in from a quarter second after the note starts over 1.2 more, its depth drifting by about a third and its rate wandering about 6 percent, as a player's do."
  def vibrato(opts), do: Expr.call(:vibrato, [], opts)

  @doc """
  A flute's air jet at the pitch `hz:`, blown at the pressure `breath:`, its sound taking `even:` of its square for the even harmonics.
  `wander:` drifts the breath as a note holds, `catch:` lets it fall at a slur, `corner:` is the bore's corner in Hz, `tuned:` the breath at which the jet is in tune, and `lift:` makes high notes louder; each is 0 unless given.
  `sound:` and `side:` are functions of the jet's sound and of the side of the edge it flows to, from 0 to 1, and the jet plays what they give added together.
  """
  def air_jet(opts) do
    Expr.call(:air_jet, [], Enum.map(opts, &through/1))
  end

  defp through({key, fun}) when is_function(fun, 1), do: {key, fun.(Expr.call(:input, []))}
  defp through(option), do: option

  @doc "A wind's sound through peaks at mx's eight bands up to 3162 Hz, `gains:` eight in dB at each of pp, mf and ff, and `levels:` in dB at each, following `vel:`."
  def wind_bands(sound, opts), do: Expr.call(:wind_bands, [sound], opts)

  @doc "Noise, `:white` or `:pink`."
  def noise(colour), do: Expr.call(:noise, [colour])

  for filter <- [:lowpass, :highpass, :bandpass, :lowshelf, :highshelf, :peak, :mode] do
    @doc false
    def unquote(filter)(sound, opts), do: Expr.call(unquote(filter), [sound], opts)
  end

  @doc "A sound delayed by `seconds:`, which may change as it plays, up to `max:`."
  def delay(sound, opts), do: Expr.call(:delay, [sound], opts)

  @doc "A sound with any constant offset taken out."
  def dc_block(sound), do: Expr.call(:dc_block, [sound])

  @doc "Segments from silence through each point, `{seconds, level}` straight, `{seconds, level, curve}` bent, or `{seconds, level, :exp}` exponential."
  def envelope(points), do: Expr.call(:envelope, [points])

  @doc "A sound scaled by the level `envelope/1` gives for `points`."
  def envelope(sound, points), do: Expr.call(:envelope, [sound, points])

  @doc "A quick rise over `attack:` and a fall to silence over `release:`."
  def perc(opts), do: Expr.call(:perc, [], opts)

  @doc "A sound scaled by the level `perc/1` gives for `opts`."
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
