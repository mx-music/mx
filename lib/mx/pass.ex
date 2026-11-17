defmodule Mx.Pass do
  @moduledoc """
  Runs one pass of a loop and returns what it played, with each note's beat
  within the pass.

  Random numbers are seeded from the loop name and the pass number, so the
  same pass always plays the same notes.
  Inputs and shared values come from the snapshot given in `:inputs`, and `trigger` from `:trigger`, so a pass given the same ones plays the same notes too.

  `record_play` and `record_sample` return a handle naming the events they recorded, and `effect` a handle naming one of the loop's effects.
  A control step is recorded as `{beat, {:control, target, synth}, opts}`, where the target is `{:sounds, indexes}` or `{:effect, index}`, and the synth is the one whose options it changes, or `{:effect, effect}` for an effect's.
  """

  alias Mx.{Notes, Samples, Synths}

  defmodule Handle do
    @moduledoc "What record_play, record_sample and effect return: the events or effect a later control step changes, and the synth whose options they are."
    defstruct [:target, :synth]
  end

  @envelope ~w(attack decay sustain release attack_level decay_level sustain_level env_curve)a

  @key :mx_pass

  @doc """
  Runs a pass of a loop, and returns `{:ok, %{events: events, beats: beats, notes: notes, vels: vels}}` or `{:error, message}` naming the line.
  `vels` holds the vel each of `notes` is played at, in the same order, nil for a note given none.
  """
  def events(%Mx.Song.Loop{} = loop, pass, opts \\ []) when is_integer(pass) and is_list(opts) do
    :rand.seed(:exsss, {:erlang.phash2(loop.name), pass, 1})

    Process.put(@key, %{
      beat: 0,
      events: [],
      notes: [],
      count: 0,
      synth: loop.synth,
      defaults: loop.defaults,
      fx: loop.fx,
      osc_to: loop.osc_to,
      inputs: Keyword.get(opts, :inputs, %{}),
      trigger: opts[:trigger]
    })

    try do
      Mx.Music.replay(loop.music, pass)
      %{beat: beats, events: events, notes: notes} = Process.get(@key)

      if beats > 0 do
        events = events |> Enum.reverse() |> take_turns(pass)
        written = notes |> Enum.reverse() |> Enum.sort_by(&elem(&1, 0))
        notes = Enum.map(written, fn {beat, note, held, _vel} -> {beat, note, held} end)
        vels = Enum.map(written, &elem(&1, 3))
        {:ok, %{events: events, beats: beats, notes: notes, vels: vels}}
      else
        {:error, "loop #{loop.name} never waits, so its pass has no length"}
      end
    rescue
      error -> {:error, format(error, __STACKTRACE__, loop)}
    after
      Process.delete(@key)
    end
  end

  # A sampled key plays its takes in turn, each pass carrying on as though the passes before it
  # played the key as often, so a pass always plays the same takes.
  defp take_turns(events, pass) do
    played = Enum.frequencies(for {_, {:sampled, takes, _}, _} <- events, do: takes)

    {events, _} =
      Enum.map_reduce(events, %{}, fn
        {beat, {:sampled, takes, rate}, opts}, turns ->
          turn = Map.get(turns, takes, 0)
          path = Enum.at(takes, rem(pass * played[takes] + turn, length(takes)))
          {{beat, {:sample, path, path}, opts ++ [rate: rate]}, Map.put(turns, takes, turn + 1)}

        event, turns ->
          {event, turns}
      end)

    events
  end

  @doc "Whether notes with these options would play on a synth with these defaults, as `:ok` or `{:error, message}`, checked as a play step checks them."
  def check_play(synth, defaults, notes, opts) when is_list(opts) do
    previous = Process.get(@key)

    Process.put(@key, %{
      beat: 0,
      events: [],
      notes: [],
      count: 0,
      synth: synth,
      defaults: defaults
    })

    try do
      record_play(notes, opts)
      :ok
    rescue
      error in ArgumentError -> {:error, Exception.message(error)}
    after
      if previous, do: Process.put(@key, previous), else: Process.delete(@key)
    end
  end

  @doc """
  Records the notes of a play step at the current beat, and returns a handle to them.
  Given the beats the notes are written to last, one for all or a list of one per note, it also records each note as written, as `{beat, note, beats}`, which `events/3` returns as `notes`.
  """
  def record_play(notes, opts, written \\ nil)

  def record_play([{key, _} | _] = opts, [], written) when is_atom(key) do
    record_play(:own_note, opts, written)
  end

  def record_play(notes, opts, written)
      when (is_number(notes) or is_atom(notes) or is_list(notes)) and is_list(opts) do
    %{synth: synth, defaults: defaults} = Process.get(@key)
    chord? = is_list(notes)
    opts = opts ++ Keyword.drop(defaults, Keyword.keys(opts))
    {strum, opts} = Keyword.pop(opts, :strum, 0)
    notes = Enum.map(List.wrap(notes), &if(&1 == :own_note, do: &1, else: Notes.note(&1)))

    case notes != [] && Enum.find(Keyword.keys(opts), &(not Synths.option?(synth, &1))) do
      option when is_atom(option) and option not in [nil, false] ->
        owner = Synths.owner(synth)
        raise ArgumentError, "#{owner} has no option #{option}"

      _ ->
        :ok
    end

    written = if is_list(written), do: written, else: List.duplicate(written, length(notes))

    indexes =
      [notes, note_opts(opts, length(notes), chord?), written]
      |> Enum.zip()
      |> strum_order(strum)
      |> Enum.with_index(fn {note, opts, written}, i ->
        offset = i * abs(strum)
        if written && note != :own_note, do: record_written(note, offset, written, opts[:vel])
        record(step(synth, note, opts), offset)
      end)

    %Handle{target: {:sounds, indexes}, synth: player(synth)}
  end

  defp step(%Mx.Sampled{} = sampled, note, opts) do
    {vel, opts} = Keyword.pop(opts, :vel, 1)

    case Mx.Sampled.pick(sampled, note, vel) do
      {:ok, {_key, takes, rate}} ->
        {{:sampled, takes, rate}, Keyword.put(opts, :amp, Keyword.get(opts, :amp, 1) * vel)}

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  defp step(_synth, note, opts), do: {note, opts}

  # A sampled instrument's notes play as samples, so changes reach them as they reach samples.
  defp player(%Mx.Sampled{}), do: :stereo_player
  defp player(synth), do: synth

  # Each note's options, taking its own value from an option given a list, one value per note as
  # written.
  defp note_opts(opts, count, chord?) do
    for {option, values} <- opts, is_list(values) do
      given = length(values)

      if not chord? do
        raise ArgumentError, "play gives #{option} a list for one note"
      end

      if given != count do
        raise ArgumentError, "play gives #{option} #{given} values for #{count} notes"
      end
    end

    for index <- 0..(count - 1)//1 do
      Enum.map(opts, fn
        {option, values} when is_list(values) -> {option, Enum.at(values, index)}
        option -> option
      end)
    end
  end

  defp strum_order(notes, strum) when strum > 0, do: Enum.sort_by(notes, &elem(&1, 0))
  defp strum_order(notes, strum) when strum < 0, do: Enum.sort_by(notes, &elem(&1, 0), :desc)
  defp strum_order(notes, _strum), do: notes

  @doc "Records a sample step at the current beat, and returns a handle to it."
  def record_sample(ref, opts)
      when (is_atom(ref) or is_binary(ref) or is_tuple(ref)) and is_list(opts) do
    case Enum.find(
           Keyword.keys(opts),
           &(not (Synths.option?(:stereo_player, &1) or Samples.cut_option?(&1)))
         ) do
      nil ->
        with {:ok, path} <- Samples.path(ref),
             :ok <- Samples.check_cut(ref, path, opts) do
          index = record({{:sample, ref, path}, opts})
          %Handle{target: {:sounds, [index]}, synth: :stereo_player}
        else
          {:error, message} -> raise ArgumentError, message
        end

      option ->
        raise ArgumentError, "samples have no option #{option}"
    end
  end

  @doc "Moves the current beat forward."
  def record_wait(beats) when is_number(beats), do: update(&%{&1 | beat: &1.beat + beats})

  @doc "Runs the function for each entry at its beat from the current beat, in the order of the beats, and leaves the current beat where it was."
  def record_at(entries, fun) when is_list(entries) and is_function(fun, 1) do
    start = Process.get(@key).beat

    entries
    |> Enum.map(&{entry_beat(&1), &1})
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.each(fn {beat, entry} ->
      update(&%{&1 | beat: start + beat})
      fun.(entry)
    end)

    update(&%{&1 | beat: start})
    :ok
  end

  defp entry_beat(beat) when is_number(beat) and beat >= 0, do: beat

  defp entry_beat(beat) when is_number(beat) do
    raise ArgumentError, "at takes beats from 0 up, not #{beat}"
  end

  defp entry_beat(entry) when tuple_size(entry) > 0 and is_number(elem(entry, 0)) do
    entry_beat(elem(entry, 0))
  end

  defp entry_beat(entry) do
    entry = inspect(entry)
    raise ArgumentError, "at takes beats, or tuples that start with a beat, not #{entry}"
  end

  @doc "Records a MIDI note at the current beat, refusing an option or value MIDI does not take."
  def record_midi(note, opts) when (is_number(note) or is_atom(note)) and is_list(opts) do
    opts = Keyword.merge([velocity: 100, channel: 1, length: 1], opts)

    case Enum.find(Keyword.keys(opts), &(&1 not in [:velocity, :channel, :length])) do
      nil -> :ok
      option -> raise ArgumentError, "midi has no option #{option}"
    end

    Mx.Music.check_range("midi velocity", opts[:velocity], 0, 127)
    Mx.Music.check_range("midi channel", opts[:channel], 1, 16)

    if opts[:length] <= 0 do
      length = opts[:length]
      raise ArgumentError, "midi length must be more than 0 beats, not #{length}"
    end

    record({{:midi_note, Notes.note(note)}, opts})
    :ok
  end

  @doc "Records a MIDI controller change at the current beat, refusing an option or value MIDI does not take."
  def record_midi_cc(number, value, opts)
      when is_integer(number) and is_integer(value) and is_list(opts) do
    opts = Keyword.merge([channel: 1], opts)

    case Enum.find(Keyword.keys(opts), &(&1 != :channel)) do
      nil -> :ok
      option -> raise ArgumentError, "midi_cc has no option #{option}"
    end

    Mx.Music.check_range("midi_cc number", number, 0, 127)
    Mx.Music.check_range("midi_cc value", value, 0, 127)
    Mx.Music.check_range("midi channel", opts[:channel], 1, 16)
    record({{:midi_cc, number, value}, opts})
    :ok
  end

  @doc "Records an OSC message at the current beat, refusing it when the song names no `osc_to`."
  def record_osc(address, args)
      when is_binary(address) and (is_list(args) or is_number(args) or is_binary(args)) do
    if Process.get(@key).osc_to == nil do
      raise ArgumentError, "osc needs osc_to host, port in the song"
    end

    if not String.starts_with?(address, "/") do
      address = inspect(address)
      raise ArgumentError, "osc address must be a string starting with /, not #{address}"
    end

    args = List.wrap(args)

    case Enum.find(args, &(not (is_number(&1) or is_binary(&1)))) do
      nil ->
        :ok

      arg ->
        arg = inspect(arg)
        raise ArgumentError, "osc arguments must be numbers or strings, not #{arg}"
    end

    record({{:osc, address, args}, []})
    :ok
  end

  @doc "Every input and shared value in the pass's snapshot."
  def inputs, do: Process.get(@key).inputs

  @doc "The input that started the pass, or nil."
  def trigger, do: Process.get(@key).trigger

  @doc "Records a step that shares a value with the other loops."
  def record_set(name, value) when is_atom(name) do
    record({{:set, name, value}, []})
    :ok
  end

  @doc "A handle to one of the loop's effects, refusing an effect the loop does not have."
  def effect(effect) when is_atom(effect) do
    case Enum.find_index(Process.get(@key).fx, fn {name, _} -> name == effect end) do
      nil -> raise ArgumentError, "the loop has no effect #{effect}"
      index -> %Handle{target: {:effect, index}, synth: effect}
    end
  end

  @doc "Records a control step that changes the sounds or effect a handle names, refusing an option they do not take."
  def record_control(%Handle{target: {:effect, _} = target, synth: effect}, opts)
      when is_list(opts) do
    check_control(
      opts,
      &Synths.effect_option?(effect, &1),
      fn _ -> false end,
      "effect #{effect} has"
    )

    record({{:control, target, {:effect, effect}}, control_values(opts)})
    :ok
  end

  def record_control(%Handle{target: target, synth: synth}, opts) when is_list(opts) do
    owner = if synth == :stereo_player, do: "samples have", else: "synth #{synth} has"
    check_control(opts, &Synths.option?(synth, &1), &Synths.fixed?(synth, &1), owner)
    record({{:control, target, synth}, control_values(opts)})
    :ok
  end

  def record_control(other, opts) when is_list(opts) do
    other = inspect(other)
    raise ArgumentError, "control takes a handle from play, sample or fx, not #{other}"
  end

  @doc "Refuses a change to a sound of a synth, or with `{:effect, effect}` to an effect, that it cannot take."
  def check_change({:effect, effect}, opts) when is_list(opts) do
    check_control(
      opts,
      &Synths.effect_option?(effect, &1),
      fn _ -> false end,
      "effect #{effect} has"
    )

    :ok
  end

  def check_change(synth, opts) when is_list(opts) do
    owner = if synth == :stereo_player, do: "samples have", else: Synths.owner(synth) <> " has"
    check_control(opts, &Synths.option?(synth, &1), &Synths.fixed?(synth, &1), owner)
    :ok
  end

  @doc "Records a control step that changes every sound of the loop still playing."
  def record_change(opts) when is_list(opts) do
    %{synth: synth} = Process.get(@key)
    check_change(synth, opts)
    record({{:control, :part, player(synth)}, control_values(opts)})
    :ok
  end

  defp check_control(opts, option?, fixed?, owner) do
    for {option, _} <- opts do
      cond do
        option in @envelope or fixed?.(option) ->
          raise ArgumentError, "#{option} cannot change once a sound plays"

        not option?.(option) ->
          raise ArgumentError, "#{owner} no option #{option}"

        true ->
          :ok
      end
    end
  end

  defp control_values(opts) do
    Enum.map(opts, fn {option, value} -> {option, control_value(option, value)} end)
  end

  defp control_value(:note, note), do: Notes.note(note)
  defp control_value(_option, value), do: value

  defp record({step, opts}, offset \\ 0) do
    %{count: index} = Process.get(@key)
    update(&%{&1 | events: [{&1.beat + offset, step, opts} | &1.events], count: index + 1})
    index
  end

  defp record_written(note, offset, beats, vel) do
    update(&%{&1 | notes: [{&1.beat + offset, note, beats, vel} | &1.notes]})
  end

  defp update(fun), do: Process.put(@key, fun.(Process.get(@key)))

  defp format(%Mx.Music.LoopError{line: line} = error, _stacktrace, loop) when is_integer(line) do
    "#{loop.file}:#{line}: #{Exception.message(error)}"
  end

  defp format(error, stacktrace, loop) do
    message = Exception.message(error)
    file = Path.expand(loop.file)

    case Enum.find(stacktrace, fn {_, _, _, info} ->
           info[:file] && Path.expand(to_string(info[:file])) == file
         end) do
      {_, _, _, info} ->
        line = info[:line]
        "#{loop.file}:#{line}: part #{loop.name}: #{message}"

      nil ->
        "part #{loop.name}: #{message}"
    end
  end
end
