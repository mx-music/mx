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

  Numbers: `hz/1`, `db/1`, `log2/1`, `exp/1`, `sin/1`, `cos/1`, `clamp/3`, `mod/2`, `select/3` and `draw/2`, a number drawn as the note starts,, worked out at once on numbers and when the note starts on its options.
  Sources: `impulse/1`, `follow/1`, `time/1`, `sine/1`, `vibrato/1`, `partials/2`, `bowed_string/1`, `air_jet/1`, `saw/1`, `square/1`, `triangle/1`, `pulse/1`, `noise/2` and `clicks/1`, clicks at random times at `rate:` a second.
  Filters: `lowpass/2`, `highpass/2` and `bandpass/2`, at `hz:` with `q:`, either of which may change as the note sounds, and `poles:`, `ladder/2`, a four-pole resonant lowpass at `hz:` with `resonance:` from 0 to 1, where it rings on at `hz:`, `lowshelf/2`, `highshelf/2` and `peak/2`, at `hz:` with `q:` and `db:`, `mode/2`, a resonator struck by its input at `hz:`, ringing at `level:` and fading 60 dB over `fade:` seconds, or given lists of the same length a resonator for each, all struck by the one input, `wind_bands/2`, `delay/2`, `struck/2`, a level that rises over `attack:` and falls over `fall:` at each click of its sound, and `dc_block/1` and `dc_block/2`, which take away any offset below `hz:`, 10 unless given.
  Distortion: `saturate/2` rounds a sound off towards `level:`, `clip/2` cuts it off at `level:`, and `fold/2` folds it back at `level:`, each after a `drive:` in dB, worked out at twice the engine's rate.
  Shapes: `envelope/1` and `perc/1` are levels over time, and `envelope/2` and `perc/2` scale a sound by them.
  Mixing: `mix/1` adds a list of sounds, `gain/2` scales one, and `share/2` builds a sound once for a function that uses it several times.
  A synth ends with `note_envelope/2`, shaping its sound by the note's envelope, `rings/2`, ending it after `seconds:`, or `figures/2`, a struck note from one of mxs's tables.
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

  @doc "The remainder of `value` after `divisor`, from 0 up to `divisor` for any `value`, below 0 included."
  def mod(value, divisor) when is_number(value) and is_number(divisor) do
    value - divisor * Float.floor(value / divisor)
  end

  def mod(value, divisor), do: Expr.call(:mod, [value, divisor])

  @doc "`then` where `condition` holds, and `otherwise` elsewhere."
  def select(condition, then, otherwise) when is_boolean(condition) do
    if(condition, do: then, else: otherwise)
  end

  def select(condition, then, otherwise), do: Expr.call(:select, [condition, then, otherwise])

  @doc "A single sample at the start of the note, or at `at:` seconds, and again every `period:` seconds before `until:`."
  def impulse(opts \\ []), do: Expr.call(:impulse, [], opts)

  for wave <- [:sine, :saw, :square, :triangle, :pulse] do
    @doc false
    def unquote(wave)(opts), do: Expr.call(unquote(wave), [], opts)
  end

  @doc "Harmonics of the pitch `hz` at each of `ratios:`, with their `levels:` and starting `phases:` in radians; a level of 0 leaves its harmonic out."
  def partials(hz, opts), do: Expr.call(:partials, [hz], opts)

  @doc "One of the note's options as a sound, gliding to each new value the song gives over the option's `_slide` seconds."
  def follow(%Expr{op: :option} = option), do: Expr.call(:follow, [option])

  @doc "The seconds since the note started, starting over every `every:` seconds if given."
  def time(opts \\ []), do: Expr.call(:time, [], opts)

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

  @doc "The sound `fun` makes of `sound`, which is built once however many times `fun` uses it, so a noise in it plays the same numbers at each use."
  def share(sound, fun) when is_function(fun, 1) do
    Expr.call(:share, [sound], through: fun.(Expr.call(:input, [])))
  end

  @doc "A wind's sound through peaks at mx's bands, `gains:` in dB at each of pp, mf and ff, eight to each for the bands up to 3162 Hz or eleven for all of them up to 12.6 kHz, and `levels:` in dB at each, following `vel:`."
  def wind_bands(sound, opts), do: Expr.call(:wind_bands, [sound], opts)

  @doc "A struck note from one of mxs's tables fitted to recordings, named by its file with or without its extension, such as `:marimba`: `play:` is `:kept`, whose figures carry its loudness, `:fitted`, louder by vel to the power `growth:`, or `:evened`, every note at vel 1 as loud, each at `level:`; it ends the note, as `rings/2` does, and a synth naming a table mxs has not is refused when it registers."
  def figures(table, opts), do: Expr.call(:figures, [table], opts)

  @doc "A slow random sway of about unit size, as a wind player's pitch and level drift while a note holds, its seed drawn from the note."
  def sway, do: Expr.call(:sway, [], [])

  @doc "A note as a wind player's fingers hold it: while `note` glides faster than 6 semitones a second they keep the one it left, for up to 80 ms, then take the one it reaches."
  def fingers(note), do: Expr.call(:fingers, [note], [])

  @doc """
  A reed, or the lips, blown by `breath:` at `hz:` on a bore, sounding through its bell, as mxs's reed and brass winds are; its breath's turbulence draws its seed after its arguments.

  The bore takes `corner:`, its corner as a multiple of the pitch, never under `least_corner:` Hz, `keep:`, what it keeps at each round trip, `conical: true` for a cone, whose missing apex is `apex:` of its length, 0.3 unless given, and `relative: true` for a breath that is a multiple of the least that sounds the note.
  The reed takes `zeta:`, how freely it lets the air through, 0.4 unless given, `tongue:`, the part of the pressure the tongue's release sends in, and `gasp:` and `mend:`, how far the breath falls at a slur and the seconds it takes to come back to a third, 0.02 unless given.
  The bell takes `bell:`, the corner in Hz it lets the sound out above, never under `bell_corner:` times the pitch, `smooth:`, the corner of its two rounding low-passes as a multiple of the pitch, `lift:`, the dB louder an octave up, `catch:`, how far the sound falls at a slur, and three sounds: `steep:`, how much earlier a unit of pressure arrives, `through:`, the part of the wave let through, 1 unless given, and `eased:`, the part of the steepening left, 1 unless given.
  """
  def reed(opts), do: Expr.call(:reed, [], opts)

  @doc "The note's `index`th number from 0 up to 1, counting from 0, drawn from a seed that moves with each note of the synth by `mix:`, a whole number, 0 unless given; each draw and drawn noise of a synth takes the same mix."
  def draw(index, opts \\ []), do: Expr.call(:draw, [index], opts)

  @doc "Noise, `:white` or `:pink`; `seed:`, if given, fixes its numbers instead of drawing a seed from the note, and `drawn:` seeds it from the note's seed that `draw/2` takes, with the same `mix:`, plus `drawn:`."
  def noise(colour, opts \\ []), do: Expr.call(:noise, [colour], opts)

  for filter <- [:lowpass, :highpass, :bandpass, :lowshelf, :highshelf, :peak, :mode] do
    @doc false
    def unquote(filter)(sound, opts), do: Expr.call(unquote(filter), [sound], opts)
  end

  @doc "Clicks at random times, `rate:` a second on average, each of a random level from 0 to 1; `seed:`, if given, fixes them instead of drawing a seed from the note."
  def clicks(opts), do: Expr.call(:clicks, [], opts)

  @doc "A level rising over `attack:` and falling over `fall:` seconds at each click or impulse of `sound`, starting again at the next."
  def struck(sound, opts), do: Expr.call(:struck, [sound], opts)

  @doc "A sound delayed by `seconds:`, which may change as it plays, up to `max:`."
  def delay(sound, opts), do: Expr.call(:delay, [sound], opts)

  @doc "A sound delayed by `seconds:` and fed back into itself `feedback:` times, through a one-pole low-pass at `lowpass:` Hz and high-pass at `highpass:` Hz inside the loop, each left out unless given; it lets the sound in for the first `let_in:` seconds only, or always unless given, and sounds only what comes back, as a plucked string's period or an echo's repeats do. All are numbers known when the note starts."
  def fed_back(sound, opts), do: Expr.call(:fed_back, [sound], opts)

  @doc "A level from 0 to 1 once every `length:` seconds: `wave:` is 0 saw, 1 pulse, 2 triangle, 3 sine or 4 cubic, and 3 unless given, `invert: 1` turns it upside down, `offset:` is where in the cycle it starts, from 0 to 1, and `width:` the part of a pulse that is up, a half unless given."
  def sweep(opts), do: Expr.call(:sweep, [], opts)

  @doc "The level of a sound, as its peaks: a steady tone brings it within a tenth of the tone's peak in `rise:` seconds, and silence within a tenth of 0 in `fall:`."
  def follower(sound, opts), do: Expr.call(:follower, [sound], opts)

  @doc "A sound with every frequency at the same level and its phase shifted around `hz:`, with `q:` 0.707 unless given."
  def allpass(sound, opts), do: Expr.call(:allpass, [sound], opts)

  @doc "A sound that glides to each new value, falling 60 dB short of each step over `seconds:`."
  def lag(sound, opts), do: Expr.call(:lag, [sound], opts)

  @doc "A sound with any constant offset below `hz:`, 10 unless given, taken out."
  def dc_block(sound, opts \\ []), do: Expr.call(:dc_block, [sound], opts)

  @doc "A sound through a four-pole resonant lowpass at `hz:`, with `resonance:` from 0 to 1, where it rings on at `hz:` once set ringing."
  def ladder(sound, opts), do: Expr.call(:ladder, [sound], opts)

  for {shaper, does} <- [
        saturate: "rounded off smoothly towards `level:`, which it never passes",
        clip: "cut off at `level:` either side of 0",
        fold: "folded back each time it passes `level:` either side of 0"
      ] do
    @doc "A sound driven by `drive:` in dB, 0 unless given, and #{does}, 1 unless given."
    def unquote(shaper)(sound, opts), do: Expr.call(unquote(shaper), [sound], opts)
  end

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
