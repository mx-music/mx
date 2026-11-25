defmodule Mx.Synths do
  @moduledoc """
  The synths mx ships, with the options each one takes and their defaults, as mxs lists them.

  A song measures time options in beats: those a synth or effect declares in beats, such as attack, decay, sustain, release and an echo's phase, and every option ending in `_slide`.
  `to_seconds/3` turns them into the seconds the engine expects, defaults included, so a synth sounds the same against the beat at any tempo; `given_to_seconds/3` turns only the options given, for changing a sound that plays.
  A negative time is left alone, since the sample players read a sustain of -1 as "until the end of the sample".
  `tremolo` and `motor` are rates, picks and pulses per beat, so they are sent per second.

  The effects are the synths named `fx_` followed by the effect's name, and are not synths a loop can play.
  Its `in_bus` and `out_bus` are mx's to set, so a song cannot give them.
  The live audio synths read the sound card for `live_audio`, and the sample players play `sample`, so neither are synths a loop can play.
  `tail_seconds/1` is how long an effect chain keeps sounding after its last note ends, as Sonic Pi works it out for each effect.
  """

  alias Mx.Engine.Mxs

  @rate_options ~w(tremolo motor)
  @bands %{eq: [:low, :mid, :high]}
  @effect_buses [:in_bus, :out_bus]
  @not_playable ~w(live_audio_mono live_audio_stereo mono_player stereo_player recorder)
  @engine_beats Map.new(
                  ~w(attack decay sustain release gap phase max_phase)a,
                  &{Atom.to_string(&1), &1}
                )

  @doc "Whether a loop can play a synth, a sampled instrument among them."
  def exists?(%Mx.Sampled{}), do: true

  def exists?(synth) when is_atom(synth) or is_binary(synth) do
    name = to_string(synth)
    name not in @not_playable and not effect_name?(name) and Map.has_key?(catalog(), name)
  end

  @doc "Whether a synth takes an option."
  def option?(synth, :held), do: option?(synth, :sustain)
  def option?(%Mx.Sampled{}, option) when is_atom(option), do: Mx.Sampled.option?(option)

  def option?(synth, option) when (is_atom(synth) or is_binary(synth)) and is_atom(option) do
    options = Map.fetch!(catalog(), to_string(synth))
    Map.has_key?(options, Atom.to_string(option))
  end

  @doc "The default of a synth's option, or nil when it has none or the synth takes no such option."
  def default(synth, option) when (is_atom(synth) or is_binary(synth)) and is_atom(option) do
    catalog() |> Map.fetch!(to_string(synth)) |> Map.get(Atom.to_string(option))
  end

  @doc "The option of `synth` named `name`, a string such as one given on the command line, or nil when the synth takes no such option."
  def option(synth, name) when (is_atom(synth) or is_binary(synth)) and is_binary(name) do
    options = Map.get(catalog(), to_string(synth), %{})
    if Map.has_key?(options, name), do: String.to_atom(name)
  end

  @doc "The family a synth belongs to: `:keys`, `:plucked_strings`, `:bowed_strings`, `:winds`, `:mallets`, `:synths` or `:drums`."
  def family(synth) when is_atom(synth) or is_binary(synth) do
    families() |> Map.fetch!(to_string(synth)) |> elem(0)
  end

  @doc """
  The lowest and highest MIDI notes a synth is meant to play, as `{low, high}`, or nil for a synth with no range of its own, such as `saw` or a drum.
  A note outside the range still plays.
  """
  def range(synth) when is_atom(synth) or is_binary(synth) do
    families() |> Map.fetch!(to_string(synth)) |> elem(1)
  end

  @doc "Every synth a loop can play, by name."
  def synths, do: catalog() |> Map.keys() |> Enum.filter(&exists?/1)

  @doc "Every effect, by its name in a song as a string."
  def effects do
    for name <- Map.keys(catalog()), effect_name?(name), do: effect(name)
  end

  @doc "Whether an effect exists."
  def effect?(effect), do: is_atom(effect) and Map.has_key?(catalog(), fx(effect))

  @doc "Whether an effect takes an option; its buses are mx's own, so they are not options."
  def effect_option?(effect, option) when is_atom(effect) and is_atom(option) do
    option not in @effect_buses and option?(fx(effect), option)
  end

  @doc """
  An effect's options with each band's written out as the effect's own, as `{:ok, options}`: `mid: [gain: 3]` given to an effect that takes `mid_gain` becomes `mid_gain: 3`.
  A band given an option it does not take, or anything but a list of options, is `{:error, message}`.
  """
  def bands(effect, opts) when is_atom(effect) and is_list(opts) do
    bands = Map.get(@bands, effect, [])

    Enum.reduce_while(opts, {:ok, []}, fn {name, value}, {:ok, flat} ->
      if name in bands do
        prefix = Atom.to_string(name) <> "_"

        case band(effect, name, prefix, value) do
          {:ok, band} -> {:cont, {:ok, flat ++ band}}
          error -> {:halt, error}
        end
      else
        {:cont, {:ok, flat ++ [{name, value}]}}
      end
    end)
  end

  defp band(effect, name, prefix, value) do
    if is_list(value) and Keyword.keyword?(value) do
      band =
        for {option, value} <- value,
            do: {option, String.to_atom(prefix <> Atom.to_string(option)), value}

      case Enum.find(band, fn {_, option, _} -> not effect_option?(effect, option) end) do
        nil ->
          options = for {_, option, value} <- band, do: {option, value}
          {:ok, options}

        {option, _, _} ->
          {:error, "effect #{effect}'s #{name} has no option #{option}"}
      end
    else
      value = inspect(value)

      {:error,
       "effect #{effect}'s #{name} takes a list of its options, such as [gain: 3], not #{value}"}
    end
  end

  @doc "An effect's options with its times in seconds, given in beats at a tempo."
  def effect_to_seconds(effect, opts, tempo)
      when is_atom(effect) and is_list(opts) and is_number(tempo) do
    to_seconds(fx(effect), opts, tempo)
  end

  @doc "How long an effect chain keeps sounding after its last note ends."
  def tail_seconds(chain) when is_list(chain) do
    Enum.sum_by(chain, fn {effect, opts} ->
      given = Map.new(opts, fn {key, value} -> {Atom.to_string(key), value} end)
      defaults = Map.fetch!(catalog(), fx(effect))
      opts = Map.merge(defaults, given)
      tail(effect, opts)
    end)
  end

  defp tail(:reverb, opts), do: min(opts["room"] * 10 + 1, 11)
  defp tail(:echo, opts), do: opts["decay"]
  defp tail(:chorus, opts), do: opts["decay"]
  defp tail(_effect, _opts), do: 1

  @doc "A synth's options with its times in seconds at a tempo, adding its time defaults, which are in beats too."
  def to_seconds(synth, opts, tempo)
      when (is_atom(synth) or is_binary(synth)) and is_list(opts) and is_number(tempo) do
    seconds_per_beat = 60 / tempo
    defaults = Map.fetch!(catalog(), to_string(synth))
    given = given_to_seconds(synth, opts, tempo)

    implied =
      for {name, default} <- defaults,
          time_option?(synth, name),
          default > 0,
          key = option_key(name),
          not Keyword.has_key?(opts, key),
          do: {key, default * seconds_per_beat}

    given ++ Enum.sort(implied)
  end

  @doc "The options given with their rates per second at a tempo, and their times left in beats, for an engine that places a pass from its beats."
  def rates_to_seconds(opts, tempo) when is_list(opts) and is_number(tempo) do
    Enum.map(opts, fn {key, value} ->
      if Atom.to_string(key) in @rate_options, do: {key, value * tempo / 60}, else: {key, value}
    end)
  end

  @doc "The options given with their times in seconds at a tempo, and their rates per second."
  def given_to_seconds({:effect, effect}, opts, tempo) do
    given_to_seconds(fx(effect), opts, tempo)
  end

  def given_to_seconds(synth, opts, tempo)
      when (is_atom(synth) or is_binary(synth)) and is_list(opts) and is_number(tempo) do
    seconds_per_beat = 60 / tempo
    Enum.map(opts, fn {key, value} -> {key, scale(synth, key, value, seconds_per_beat)} end)
  end

  defp scale(synth, key, value, seconds_per_beat) do
    cond do
      time_option?(synth, Atom.to_string(key)) and value > 0 -> value * seconds_per_beat
      Atom.to_string(key) in @rate_options -> value / seconds_per_beat
      true -> value
    end
  end

  defp time_option?(synth, name) do
    String.ends_with?(name, "_slide") or name in Map.get(beats(), to_string(synth), MapSet.new())
  end

  # An engine option in beats nobody names in Elixir has no atom yet, so those are listed; a
  # defsynth option is already one.
  defp option_key(name), do: @engine_beats[name] || String.to_existing_atom(name)

  defp fx(effect), do: "fx_" <> Atom.to_string(effect)

  defp effect_name?(name), do: String.starts_with?(name, "fx_")

  defp effect("fx_" <> effect), do: effect

  @doc "Whether an option picks a synth's sound when the note starts, so it cannot change while the note sounds: one that takes names, or one a clause of a synth written in Elixir matches on."
  def fixed?(%Mx.Sampled{}, option), do: fixed?("stereo_player", option)

  def fixed?(synth, option) do
    match?({:names, _}, limit(synth, option)) or
      option in Mx.Instrument.matched(synth)
  end

  @doc "How messages name a synth or a sampled instrument."
  def owner(%Mx.Sampled{} = sampled), do: to_string(sampled)
  def owner({:effect, effect}), do: "effect #{effect}"
  def owner(synth), do: "synth #{synth}"

  @doc "Refuses a value a synth's option, or with `{:effect, effect}` an effect's, cannot take: a number outside its range, a name it does not take, or anything but a number where it takes one, naming what it takes."
  def check_value(_synth, :note, _value), do: :ok
  def check_value(_synth, :held, held) when is_number(held) and held > 0, do: :ok

  def check_value(_synth, :held, held) do
    held = inspect(held)
    {:error, "held: takes the share of a note's length it sounds for, above 0, not #{held}"}
  end

  def check_value(synth, option, values) when is_list(values) do
    Enum.find_value(values, :ok, fn value ->
      with :ok <- check_value(synth, option, value), do: nil
    end)
  end

  def check_value(synth, option, value) do
    limit = limit(synth, option)

    if within?(limit, value) do
      :ok
    else
      takes = takes(limit)
      value = String.trim_leading(inspect(value), ":")
      owner = owner(synth)
      {:error, "#{owner} takes #{option} #{takes}, not #{value}"}
    end
  end

  defp limit({:effect, effect}, option), do: limit(fx(effect), option)
  defp limit(%Mx.Sampled{}, :vel), do: {:range, 0, 1}
  defp limit(%Mx.Sampled{}, option), do: limit("stereo_player", option)

  defp limit(synth, option) do
    limits() |> Map.get(to_string(synth), %{}) |> Map.get(Atom.to_string(option))
  end

  defp within?({:range, low, high}, value) when is_number(value) do
    (low == nil or value >= low) and (high == nil or value <= high)
  end

  defp within?({:range, _low, _high}, value), do: is_boolean(value)
  defp within?({:names, names}, value) when is_atom(value), do: Atom.to_string(value) in names
  defp within?({:names, _names}, _value), do: true
  defp within?(nil, value), do: is_number(value) or is_boolean(value)

  defp takes(nil), do: "a number"
  defp takes({:range, low, nil}), do: "from #{number(low)} up"
  defp takes({:range, nil, high}), do: "up to #{number(high)}"
  defp takes({:range, low, high}), do: "from #{number(low)} to #{number(high)}"

  defp takes({:names, names}) do
    {rest, [last]} = Enum.split(names, -1)
    Enum.join(rest, ", ") <> " or #{last}"
  end

  defp number(value) when value == trunc(value), do: Integer.to_string(trunc(value))
  defp number(value), do: Float.to_string(value)

  @doc "Forgets the catalog read from the engine, so the next use reads it again, with the synths written in Elixir known since."
  def forget do
    :persistent_term.erase(__MODULE__)
    :persistent_term.erase({__MODULE__, :limits})
    :persistent_term.erase({__MODULE__, :beats})
    :persistent_term.erase({__MODULE__, :families})
  end

  defp limits, do: cached(:limits, &Mxs.limits/0)
  defp beats, do: cached(:beats, &Mxs.beats/0)

  defp families do
    cached(:families, fn ->
      native = Mx.Engine.Mxs.Native.families()

      Map.new(native, fn {name, family, range} ->
        range = with {low, high} <- range, do: {trunc(low), trunc(high)}
        {name, {String.to_atom(family), range}}
      end)
    end)
  end

  defp cached(key, read) do
    case :persistent_term.get({__MODULE__, key}, nil) do
      nil ->
        value = read.()
        :persistent_term.put({__MODULE__, key}, value)
        value

      value ->
        value
    end
  end

  defp catalog do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        catalog = Mxs.catalog()
        :persistent_term.put(__MODULE__, catalog)
        catalog

      catalog ->
        catalog
    end
  end
end
