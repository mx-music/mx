defmodule Mix.Tasks.Mx.Print do
  @shortdoc "Prints the notes of a song without playing it"

  @moduledoc """
  Prints each part's notes with their beats from the start of the song, through the whole of its music once, and makes no sound.
  Given `--pass`, it prints that pass of each part, a pass being a section, or the length of the longest loop in music that plays until mx stops.

      mix mx.print song.exs
      mix mx.print song.exs --pass 4

  `--cc 74=64`, `--note 60=100`, `--osc /trigger=1,a` and `--get root=40` print the pass as if those inputs had arrived or that value had been set, and each can be given more than once.
  A loop started by input prints only what starts it.
  Each part's tempo is the tempo it starts at, and the tempo changes in what it prints, with their beats.
  A part with effects names them after its tempo, in the order its notes go through them.
  """

  use Mix.Task

  alias Mx.{Pass, Samples, Song, Tempo}

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} =
      OptionParser.parse!(args,
        strict: [pass: :integer, cc: :keep, note: :keep, osc: :keep, get: :keep]
      )

    pass = Keyword.get(opts, :pass)

    song =
      case Song.load(path) do
        {:ok, song} -> song
        {:error, message} -> Mx.Command.fail(message)
      end

    inputs = inputs(opts)

    song.loops
    |> Enum.map_join("\n", &format_pass(&1, pass, song, inputs))
    |> IO.write()
  end

  defp format_pass(%{on: on} = loop, _pass, _song, _inputs) when on != nil do
    name = loop.name
    on = format_trigger(on)
    "#{name} plays a pass on each #{on}\n"
  end

  defp format_pass(%{music: %{sections: sections, forever: forever}} = loop, nil, song, inputs) do
    {events, beats} =
      Enum.reduce(0..(tuple_size(sections) - 1), {[], 0}, fn pass, {events, start} ->
        case Pass.events(loop, pass, inputs: inputs) do
          {:ok, %{events: played, beats: beats}} ->
            {events ++ Enum.map(played, fn {beat, step, opts} -> {start + beat, step, opts} end),
             start + beats}

          {:error, message} ->
            Mx.Command.fail(message)
        end
      end)

    name = loop.name
    length = format_beat(beats)
    unit = if beats == 1, do: "beat", else: "beats"
    fx = format_fx(loop.fx)
    again = if forever, do: ", played again and again", else: ""
    last = tuple_size(sections) - 1
    {timeline, _} = Tempo.through(song.tempos, song.tempo, last, elem(sections, last).beats)
    tempo = Tempo.describe(timeline, 0, beats)
    events = with_rates(events, timeline, 0)
    "#{name}, #{length} #{unit} at #{tempo}#{fx}#{again}\n" <> format_events(events)
  end

  defp format_pass(loop, pass, song, inputs) do
    pass = pass || 0

    case Pass.events(loop, pass, inputs: inputs) do
      {:ok, %{events: events, beats: beats}} ->
        name = loop.name
        length = format_beat(beats)
        unit = if beats == 1, do: "beat", else: "beats"
        fx = format_fx(loop.fx)
        {timeline, start} = pass_timeline(song, loop, pass)
        tempo = Tempo.describe(timeline, start, start + beats)
        events = with_rates(events, timeline, start)
        "#{name}, pass #{pass}, #{length} #{unit} at #{tempo}#{fx}\n" <> format_events(events)

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp pass_timeline(song, loop, pass) do
    sections = loop.music.sections
    window = elem(sections, tuple_size(sections) - 1).beats
    Tempo.through(song.tempos, song.tempo, pass, window)
  end

  # A sample fitted to beats also shows the rate that fits it, at the tempo where it starts.
  defp with_rates(events, timeline, start) do
    Enum.map(events, fn
      {beat, {:sample, _ref, path} = step, opts} = event ->
        if opts[:beats] do
          tempo = Tempo.tempo_at(timeline, start + beat)
          rate = Samples.cut(opts, Samples.seconds(path), tempo)[:rate]
          {beat, step, opts ++ [rate: Float.round(rate, 4)]}
        else
          event
        end

      event ->
        event
    end)
  end

  defp format_trigger({:osc, address}), do: "OSC message to #{address}"
  defp format_trigger(:midi_note), do: "MIDI note on"
  defp format_trigger(:midi_cc), do: "MIDI controller change"

  defp inputs(opts) do
    for {kind, given} <- opts, kind in [:cc, :note, :osc, :get], into: %{} do
      [key, value] = String.split(given, "=", parts: 2)

      case kind do
        :cc -> {{:cc, String.to_integer(key)}, String.to_integer(value)}
        :note -> {{:note, String.to_integer(key)}, String.to_integer(value)}
        :osc -> {{:osc, key}, value |> String.split(",") |> Enum.map(&parse_value/1)}
        :get -> {{:value, value_name(key)}, parse_value(value)}
      end
    end
  end

  # A value the song never names stays a string, so it matches nothing.
  defp value_name(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp parse_value(text) do
    case {Integer.parse(text), Float.parse(text)} do
      {{integer, ""}, _} -> integer
      {_, {float, ""}} -> float
      _ -> text
    end
  end

  defp format_fx([]), do: ""
  defp format_fx(chain), do: ", through " <> Enum.map_join(chain, " then ", &format_effect/1)

  defp format_effect({effect, []}), do: to_string(effect)

  defp format_effect({effect, opts}) do
    opts = format_opts(opts)
    "#{effect} (#{opts})"
  end

  defp format_events(events) do
    events = Enum.sort_by(events, fn {beat, _, _} -> beat end)
    beats = Enum.map(events, fn {beat, _, _} -> format_beat(beat) end)
    width = beats |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)

    Enum.map_join(Enum.zip(beats, events), fn {beat, {_, note, opts}} ->
      beat = String.pad_trailing(beat, width)
      opts = format_opts(opts)
      step = format_step(note)
      String.trim_trailing("beat #{beat}  #{step} #{opts}") <> "\n"
    end)
  end

  defp format_step({:sample, ref, _path}), do: "sample #{Samples.name(ref)}"
  defp format_step({:control, _target, _synth}), do: "control"
  defp format_step({:midi_note, note}), do: "midi #{note}"
  defp format_step({:midi_cc, number, value}), do: "midi_cc #{number}, #{value}"

  defp format_step({:set, name, value}) do
    value = inspect(value)
    "set #{name} #{value}"
  end

  defp format_step({:osc, address, args}) do
    args = inspect(args)
    "osc #{address} #{args}"
  end

  defp format_step(:own_note), do: "play"
  defp format_step(note), do: "play #{note}"

  defp format_opts(opts), do: Enum.map_join(opts, ", ", fn {key, value} -> "#{key}: #{value}" end)

  defp format_beat(beat) when is_float(beat) do
    rounded = Float.round(beat, 3)
    if rounded == trunc(rounded), do: Integer.to_string(trunc(rounded)), else: to_string(rounded)
  end

  defp format_beat(beat), do: to_string(beat)
end
