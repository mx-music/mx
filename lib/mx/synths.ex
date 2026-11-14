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
  @effect_buses [:in_bus, :out_bus]
  @not_playable [:live_audio_mono, :live_audio_stereo, :mono_player, :stereo_player, :recorder]

  @doc "Whether a loop can play a synth, a sampled instrument among them."
  def exists?(%Mx.Sampled{}), do: true

  def exists?(synth) do
    is_atom(synth) and synth not in @not_playable and not effect_name?(synth) and
      Map.has_key?(catalog(), synth)
  end

  @doc "Whether a synth takes an option."
  def option?(%Mx.Sampled{}, option) when is_atom(option), do: Mx.Sampled.option?(option)

  def option?(synth, option) when is_atom(synth) and is_atom(option) do
    Map.has_key?(Map.fetch!(catalog(), synth), option)
  end

  @doc "Every synth a loop can play."
  def synths, do: catalog() |> Map.keys() |> Enum.filter(&exists?/1)

  @doc "Every effect, by its name in a song."
  def effects do
    for name <- Map.keys(catalog()), effect_name?(name), do: effect(name)
  end

  @doc "Whether an effect exists."
  def effect?(effect), do: is_atom(effect) and Map.has_key?(catalog(), fx(effect))

  @doc "Whether an effect takes an option; its buses are mx's own, so they are not options."
  def effect_option?(effect, option) when is_atom(effect) and is_atom(option) do
    option not in @effect_buses and option?(fx(effect), option)
  end

  @doc "An effect's options with its times in seconds, given in beats at a tempo."
  def effect_to_seconds(effect, opts, tempo)
      when is_atom(effect) and is_list(opts) and is_number(tempo) do
    to_seconds(fx(effect), opts, tempo)
  end

  @doc "The synth an effect runs as."
  def effect_synth(effect) when is_atom(effect), do: fx(effect)

  @doc "How long an effect chain keeps sounding after its last note ends."
  def tail_seconds(chain) when is_list(chain) do
    chain
    |> Enum.map(fn {effect, opts} ->
      opts = Map.merge(Map.fetch!(catalog(), fx(effect)), Map.new(opts))
      tail(effect, opts)
    end)
    |> Enum.sum()
  end

  defp tail(:reverb, opts), do: min(opts.room * 10 + 1, 11)
  defp tail(:echo, opts), do: opts.decay
  defp tail(:chorus, opts), do: opts.decay
  defp tail(_effect, _opts), do: 1

  @doc "A synth's options with its times in seconds at a tempo, adding its time defaults, which are in beats too."
  def to_seconds(synth, opts, tempo) when is_atom(synth) and is_list(opts) and is_number(tempo) do
    seconds_per_beat = 60 / tempo
    defaults = Map.fetch!(catalog(), synth)
    given = given_to_seconds(synth, opts, tempo)

    implied =
      for {key, default} <- defaults,
          time_option?(synth, key),
          default > 0,
          not Keyword.has_key?(opts, key),
          do: {key, default * seconds_per_beat}

    given ++ Enum.sort(implied)
  end

  @doc "The options given with their times in seconds at a tempo, and their rates per second."
  def given_to_seconds(synth, opts, tempo)
      when is_atom(synth) and is_list(opts) and is_number(tempo) do
    seconds_per_beat = 60 / tempo
    Enum.map(opts, fn {key, value} -> {key, scale(synth, key, value, seconds_per_beat)} end)
  end

  defp scale(synth, key, value, seconds_per_beat) do
    cond do
      time_option?(synth, key) and value > 0 -> value * seconds_per_beat
      Atom.to_string(key) in @rate_options -> value / seconds_per_beat
      true -> value
    end
  end

  defp time_option?(synth, key) do
    String.ends_with?(Atom.to_string(key), "_slide") or
      MapSet.member?(Map.get(beats(), synth, MapSet.new()), key)
  end

  defp fx(effect), do: :"fx_#{effect}"

  defp effect_name?(name), do: String.starts_with?(Atom.to_string(name), "fx_")

  defp effect(name) do
    "fx_" <> effect = Atom.to_string(name)
    String.to_atom(effect)
  end

  @doc "Whether an option picks a synth's sound when the note starts, so it cannot change while the note sounds: one that takes names, or one a clause of a synth written in Elixir matches on."
  def fixed?(%Mx.Sampled{}, option), do: fixed?(:stereo_player, option)

  def fixed?(synth, option) do
    match?({:names, _}, limits() |> Map.get(synth, %{}) |> Map.get(option)) or
      option in Mx.Instrument.matched(synth)
  end

  @doc "How messages name a synth or a sampled instrument."
  def owner(%Mx.Sampled{} = sampled), do: to_string(sampled)
  def owner(synth), do: "synth #{synth}"

  @doc "Refuses a number outside the range a synth's option takes, or a name it does not take, naming what it takes."
  def check_value(synth, option, value) do
    limit = limit(synth, option)

    if within?(limit, value) do
      :ok
    else
      takes = takes(limit)
      value = inspect(value) |> String.trim_leading(":")
      owner = owner(synth)
      {:error, "#{owner} takes #{option} #{takes}, not #{value}"}
    end
  end

  defp limit(%Mx.Sampled{}, :vel), do: {:range, 0, 1}
  defp limit(%Mx.Sampled{}, option), do: limit(:stereo_player, option)
  defp limit(synth, option), do: limits() |> Map.get(synth, %{}) |> Map.get(option)

  defp within?({:range, low, high}, value) when is_number(value) do
    (low == nil or value >= low) and (high == nil or value <= high)
  end

  defp within?({:names, names}, value) when is_atom(value), do: value in names
  defp within?(_limit, _value), do: true

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
  end

  defp limits, do: cached(:limits, &Mxs.limits/0)
  defp beats, do: cached(:beats, &Mxs.beats/0)

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
