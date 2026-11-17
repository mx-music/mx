defmodule Mx.Fit.Struck do
  @moduledoc """
  Fits a synth of struck notes to recordings partial by partial, and checks it against them.

  The recordings are a folder of single notes named as NSynth names them, ending in the MIDI note and velocity, such as `keyboard_electronic_098-064-025.wav`, each measured over its first 2.9 seconds, before NSynth lets its notes go.
  Or they are a list, a text file with one line a file: the notes it holds, the velocity it was played at from 1 to 127, `kept` when the recordings keep their levels from one velocity to the next, and the file, relative to the list.

      C4:B4 40 kept Marimba.yarn.pp.C4B4.aif
      C4 127 kept EWHarp_Normal_C3_v3_RR1.wav
      C4,D4,E4 80 Some.run.aif
      125.6Hz 127 kept Timpani3_Hit_v4_rr1_Sum.wav

  The notes are one note, a run from the first to the last a semitone apart, the notes a run holds, or for a drum with no pitch, the frequency of its lowest partial.
  A run is split into its notes, each named by the loudest fundamental among the notes the line gives.
  A note that sounds an octave away from its name or more than a quarter tone from it, or that was found already, is left out and says why, and each note the line gives that was not found is named.
  A note is measured until the next note of its file starts, or its file ends, for at most 30 seconds.
  A drum given in Hz is measured with that frequency as its pitch, and its figures go under the nearest MIDI note.

  Fitting renders each note's partials as sines, measures the render the same way, and corrects each partial's level at 37 times from the strike to 28 seconds until the render matches the recording, then fits the strike's noise in each band one ERB wide from 50 Hz to 8 kHz to what the recording holds beyond the sines.
  After the last time a recording reaches, each partial falls on at its last slope.
  The figures keep every partial of every recording, each at its own level, for mxs to play: a note or velocity that was not recorded takes its figures from the recordings nearest it.

  Checking renders the synth at each recording's note and velocity and compares the two in the same way, each brought to the same total over its first half second:
  partial by partial, the gap over the first 20 ms and the mean gap over the note while either stands 10 dB above the recording's noise floor;
  and in ERB bands, the mean gap over the note while either stands clear of the floor.
  The fit's own render, each recording's figures played as sines and noise with no synth, is checked in the same way, as the closest a synth playing those figures can come.
  """

  alias Mx.{Audio, Measure, Notes, Signal}
  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native

  @nsynth 2.9
  @longest 30.0
  @whole 0xFFFF_FFFF_FFFF

  @doc "The recordings in a folder named as NSynth names them, in order of note and velocity, those whose note is in `notes` when given."
  def recordings(folder, notes \\ nil) when is_binary(folder) do
    case File.ls(folder) do
      {:ok, names} ->
        found =
          for name <- Enum.sort(names),
              [note, velocity] <- [
                Regex.run(~r/-(\d+)-(\d+)\.(wav|aiff?)$/i, name, capture: [1, 2])
              ],
              note = String.to_integer(note),
              notes == nil or note in notes,
              do: whole(Path.join(folder, name), note, String.to_integer(velocity))

        if found == [],
          do: {:error, "found no recordings named like name-064-025.wav in #{folder}"},
          else: {:ok, Enum.sort_by(found, &{&1.note, &1.velocity})}

      {:error, reason} ->
        reason = :file.format_error(reason)
        {:error, "cannot read #{folder}: #{reason}"}
    end
  end

  @doc """
  The recordings a list gives, those whose note is in `notes` when given, and what each line found.
  Returns `{:ok, recordings, lines}`, each line with its `path`, the `notes` it gives, the notes it `found`, those it `left_out` as `{note, seconds, why}`, and those `missing`; or `{:error, message}`.
  """
  def listed(list, notes \\ nil) when is_binary(list) do
    with {:ok, text} <- read(list),
         {:ok, lines} <- lines(text, Path.dirname(list)) do
      found = Enum.map(lines, &split/1)

      case Enum.find(found, &match?({:error, _}, &1)) do
        {:error, message} ->
          {:error, message}

        nil ->
          recordings =
            for {:ok, recordings, _line} <- found,
                recording <- recordings,
                notes == nil or recording.note in notes,
                do: recording

          {:ok, Enum.sort_by(recordings, &{&1.note, &1.velocity}),
           for({:ok, _recordings, line} <- found, do: line)}
      end
    end
  end

  @doc "The figures fitted to the recordings, as mxs reads them."
  def figures(recordings) when is_list(recordings) do
    raws = raws(recordings)
    recordings |> Enum.map(&struck(&1, raws)) |> Native.fit_struck()
  end

  @doc """
  Renders `synth` at each recording's note and velocity and compares it with the recording.
  Returns one check a recording, with its `note`, `velocity`, `kept`, `erb` gap, `levels` of the recording and the render over their first half second, and `partials`, each partial with its `ratio`, `harmonic`, `below` the loudest in dB, `strike` gap and `mean` gap.
  """
  def check(synth, recordings) when is_list(recordings) do
    recordings
    |> Task.async_stream(
      fn recording ->
        rendered = render(synth, recording)
        check = Native.check_struck(struck(recording, raws([recording])), rendered)
        Map.merge(check, Map.take(recording, [:note, :velocity, :kept]))
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, check} -> check end)
  end

  @doc """
  Checks the fit's own render of each recording against it, as `check/2` checks a synth: the figures fitted to the recording played as sines and noise, with no synth.
  Each check is kept in the system's temporary folder and reused until the recording or mxs changes.
  """
  def own(recordings) when is_list(recordings) do
    recordings
    |> Task.async_stream(&own_check/1, timeout: :infinity)
    |> Enum.map(fn {:ok, check} -> check end)
  end

  @doc """
  One recording beside `synth`, or with `nil` the fit's own render alone, frame by frame at `times` seconds after the strike.
  Returns its `pitch` in Hz, the second of its file the `strike` was found at, and `partials`, each within 60 dB of the loudest, lowest first, and ERB `bands`, each with its `at`, `floor` and `rows`: the recording, the synth, the fit's own render, and that render's sines and noise apart, in dB against the loudest partial.
  A partial's `at` is its ratio to the pitch and its harmonic, 0 between harmonics; a band's is its edges in Hz.
  """
  def frames(synth, recording, times) when is_list(times) do
    {{_data, _packing, rate}, {from, _to}, _note} = struck = struck(recording, raws([recording]))
    rendered = synth && render(synth, recording)
    frames = Native.frames_struck(struck, rendered, times)
    %{frames | strike: from / rate + frames.strike}
  end

  @doc "Each synth check with the fit's own check of the same recording under `own`, and each of its partials with the fit's own partial under `own`."
  def beside(checks, owns) do
    for {check, own} <- Enum.zip(checks, owns) do
      partials =
        for {partial, ours} <- Enum.zip(check.partials, own.partials),
            do: Map.put(partial, :own, ours)

      %{check | partials: partials} |> Map.put(:own, own)
    end
  end

  @doc "A tour for listening of `count` recordings spread over the notes and velocities, each followed by `synth` at its note and velocity, as `{samples, rate}`, the samples as 32-bit floats."
  def tour(synth, recordings, count) when is_list(recordings) and count > 0 do
    picked = spread(recordings, count)
    raws = raws(picked)

    pairs =
      picked
      |> Task.async_stream(&{struck(&1, raws), render(synth, &1)}, timeout: :infinity)
      |> Enum.map(fn {:ok, pair} -> pair end)

    {Native.tour_struck(pairs), Mxs.render_rate()}
  end

  @doc "`count` recordings in order of note and velocity, spread evenly from the first to the last."
  def spread(recordings, count) do
    sorted = Enum.sort_by(recordings, &{&1.note, &1.velocity})
    last = length(sorted) - 1

    if count > last,
      do: sorted,
      else:
        for(i <- 0..(count - 1), do: Enum.at(sorted, round(i * last / max(count - 1, 1))))
        |> Enum.uniq()
  end

  @doc """
  The checks summed up: the partials within 30 dB of each note's loudest, `strong`, and those 30 to 60 dB down, `weaker`, each as a count and the share within 2 dB over the first 20 ms (`strike`), within 2 dB on average for the strong (`mean`), or within 4 dB on average for the weaker; and the ERB gap at the median note and the worst.
  """
  def summary(checks) when is_list(checks) do
    partials = Enum.flat_map(checks, & &1.partials)
    strong = Enum.filter(partials, &(&1.below <= 30))
    weaker = Enum.filter(partials, &(&1.below > 30 and &1.below <= 60))
    erbs = checks |> Enum.map(& &1.erb) |> Enum.sort()

    %{
      strong: %{
        count: length(strong),
        strike: share(strong, &(abs(&1.strike) <= 2)),
        mean: share(strong, &(&1.mean <= 2))
      },
      weaker: %{count: length(weaker), mean: share(weaker, &(&1.mean <= 4))},
      erb: %{median: Enum.at(erbs, div(length(erbs), 2)), worst: List.last(erbs)}
    }
  end

  @doc """
  For the checks of recordings that keep their levels, each note recorded at more than one velocity: each velocity below the note's loudest, with how far under it the recording and the render are over their first half second, in dB.
  """
  def loudness(checks) when is_list(checks) do
    checks
    |> Enum.filter(& &1.kept)
    |> Enum.group_by(& &1.note)
    |> Enum.filter(fn {_note, checks} -> length(checks) > 1 end)
    |> Enum.sort()
    |> Enum.flat_map(fn {note, checks} ->
      %{levels: {top_recording, top_render}} = Enum.max_by(checks, & &1.velocity)

      for %{velocity: velocity, levels: {recording, render}} <-
            Enum.sort_by(checks, & &1.velocity),
          velocity < Enum.max_by(checks, & &1.velocity).velocity,
          do: %{
            note: note,
            velocity: velocity,
            recording: recording - top_recording,
            render: render - top_render
          }
    end)
  end

  @doc "The `count` partials within 60 dB of their note's loudest furthest off on average, each with its note and velocity, furthest first."
  def furthest_partials(checks, count) do
    checks
    |> Enum.flat_map(fn check ->
      for partial <- check.partials,
          partial.below <= 60,
          do: Map.merge(partial, Map.take(check, [:note, :velocity]))
    end)
    |> Enum.sort_by(& &1.mean, :desc)
    |> Enum.take(count)
  end

  @doc "The `count` notes furthest off in ERB bands, furthest first."
  def furthest_notes(checks, count),
    do: checks |> Enum.sort_by(& &1.erb, :desc) |> Enum.take(count)

  @doc "A recording's note and velocity as the check prints them, such as `e4 vel 25`."
  def label(%{note: note, velocity: velocity}) do
    name = Measure.name(note)
    "#{name} vel #{velocity}"
  end

  defp whole(path, note, velocity) do
    %{
      path: path,
      note: note,
      pitch: note / 1,
      velocity: velocity,
      span: {0, @whole},
      seconds: @nsynth,
      exact: false,
      kept: false
    }
  end

  defp read(list) do
    case File.read(list) do
      {:ok, text} ->
        {:ok, text}

      {:error, reason} ->
        reason = :file.format_error(reason)
        {:error, "cannot read #{list}: #{reason}"}
    end
  end

  defp lines(text, folder) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _number} -> String.trim(line) in [""] or comment?(line) end)
    |> Enum.reduce_while({:ok, []}, fn {line, number}, {:ok, lines} ->
      case line(String.trim(line), folder) do
        {:ok, line} -> {:cont, {:ok, [line | lines]}}
        :error -> {:halt, {:error, "cannot read line #{number}: #{line}"}}
      end
    end)
    |> then(fn
      {:ok, []} -> {:error, "the list gives no recordings"}
      {:ok, lines} -> {:ok, Enum.reverse(lines)}
      error -> error
    end)
  end

  defp comment?(line), do: String.starts_with?(String.trim_leading(line), "#")

  defp line(line, folder) do
    with [notes, velocity, rest] <- String.split(line, ~r/\s+/, parts: 3),
         {velocity, ""} when velocity in 1..127 <- Integer.parse(velocity),
         {:ok, notes} <- notes(notes) do
      {kept, file} =
        case String.split(rest, ~r/\s+/, parts: 2) do
          ["kept", file] -> {true, file}
          _ -> {false, rest}
        end

      {:ok, %{path: Path.expand(file, folder), notes: notes, velocity: velocity, kept: kept}}
    else
      _ -> :error
    end
  end

  defp notes(text) do
    cond do
      hz = Regex.run(~r/^(\d+(?:\.\d+)?)Hz$/i, text, capture: :all_but_first) ->
        {hz, _rest} = Float.parse(hd(hz))
        {:ok, {:hz, hz}}

      String.contains?(text, ":") ->
        with [first, last] <- String.split(text, ":"),
             {:ok, first} <- note(first),
             {:ok, last} <- note(last),
             true <- first <= last do
          {:ok, Enum.to_list(first..last)}
        else
          _ -> :error
        end

      true ->
        text
        |> String.split(",")
        |> Enum.reduce_while({:ok, []}, fn name, {:ok, notes} ->
          case note(name) do
            {:ok, note} -> {:cont, {:ok, notes ++ [note]}}
            :error -> {:halt, :error}
          end
        end)
    end
  end

  defp note(text) do
    {:ok, text |> String.replace("#", "s") |> Notes.from_text()}
  rescue
    ArgumentError -> :error
  end

  defp split(%{path: path} = line) do
    case Audio.raw(path) do
      {:ok, %{rate: rate} = format, data} -> {:ok, pieces(line, format, data, rate), line}
      {:error, message} -> {:error, message}
    end
    |> case do
      {:ok, {recordings, report}, line} -> {:ok, recordings, Map.merge(line, report)}
      error -> error
    end
  end

  defp pieces(%{notes: {:hz, hz}} = line, format, data, rate) do
    seconds = min(byte_size(data) / frame_size(format) / rate, @longest)
    pitch = 69 + 12 * :math.log2(hz / 440)
    note = round(pitch)

    recording = %{
      path: line.path,
      note: note,
      pitch: pitch,
      velocity: line.velocity,
      span: {0, @whole},
      seconds: seconds,
      exact: true,
      kept: line.kept
    }

    {[recording], %{found: [note], left_out: [], missing: []}}
  end

  defp pieces(line, format, data, rate) do
    pieces = Native.split_struck(data, Signal.native(format), rate / 1, line.notes)

    recordings =
      for %{left_out: nil, note: note, from: from, to: to} <- pieces,
          do: %{
            path: line.path,
            note: note,
            pitch: note / 1,
            velocity: line.velocity,
            span: {from, to},
            seconds: min((to - from) / rate, @longest),
            exact: false,
            kept: line.kept
          }

    found = Enum.map(recordings, & &1.note)

    left_out =
      for %{left_out: why, note: note, from: from} <- pieces, why, do: {note, from / rate, why}

    named = Enum.map(left_out, &elem(&1, 0))
    {recordings, %{found: found, left_out: left_out, missing: line.notes -- (found ++ named)}}
  end

  defp frame_size(%{channels: channels, bits: bits}), do: channels * div(bits + 7, 8)

  defp raws(recordings) do
    recordings
    |> Enum.map(& &1.path)
    |> Enum.uniq()
    |> Map.new(fn path ->
      {:ok, %{rate: rate} = format, data} = Audio.raw(path)
      {path, {data, Signal.native(format), rate / 1}}
    end)
  end

  defp struck(recording, raws) do
    {raws[recording.path], recording.span,
     {recording.pitch, recording.velocity, recording.seconds / 1, recording.exact}}
  end

  defp render(synth, recording) do
    seconds = recording.seconds + 0.3
    vel = recording.velocity / 127
    sound = Mxs.render_note(synth, [note: recording.note, vel: vel], seconds, nil, [])
    {rendered, packing} = Signal.packed(sound)
    {rendered, packing, Mxs.render_rate() / 1}
  end

  defp own_check(recording) do
    path = own_path(recording)

    case File.read(path) do
      {:ok, binary} ->
        :erlang.binary_to_term(binary)

      {:error, _reason} ->
        check =
          recording
          |> struck(raws([recording]))
          |> Native.check_fit_struck()
          |> Map.merge(Map.take(recording, [:note, :velocity, :kept]))

        File.mkdir_p!(Path.dirname(path))
        File.write!(path, :erlang.term_to_binary(check))
        check
    end
  end

  # A check is named after the recording, the part of it fitted, its file's size and time of change, and the build of mxs that fitted it.
  defp own_path(recording) do
    built = :mx |> :code.priv_dir() |> Path.join("native/*mxs_nif*") |> Path.wildcard()
    files = Enum.map([recording.path | built], &{Path.expand(&1), stamp(&1)})
    fitted = Map.take(recording, [:span, :pitch, :velocity, :seconds, :exact])
    key = :erlang.phash2({files, fitted}, 4_294_967_296)
    Path.join([System.tmp_dir!(), "mx-fit-struck", "#{key}.term"])
  end

  defp stamp(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{size: size, mtime: mtime}} -> {size, mtime}
      {:error, _reason} -> nil
    end
  end

  defp share([], _keep), do: nil
  defp share(partials, keep), do: Enum.count(partials, keep) / length(partials)
end
