defmodule Mx.Page do
  @moduledoc """
  Writes a song as one HTML page that plays it and shows each part's notes on a timeline, for `mix mx.page`.

  The page holds the song's offline render, which ffmpeg encodes as MP3, so a browser plays what mx plays and works out no sound itself.
  Each part's notes are the ones `Mx.Pass` works out, pass by pass, at the seconds `Mx.Tempo` gives their beats.
  A note with no `sustain:` shows half a beat long, and a note a control step moves to another pitch shows as one mark for each pitch.
  A sample shows as a hit, and so does a note of a sampled instrument, as its pass names the file it plays and not the key.
  A hit lasts as long as its sample file plays at its rate, cut short by a sustain it is given, or as long as the attack, decay, sustain and release given to its synth; a synth hit given none of them lasts 0 seconds, as its synth alone knows how long it rings.
  A part that waits for input is left out, as a render leaves it out.

  Each part's `synth` names its sound: the synth it plays notes on, such as `flute`; a sampled instrument by its folder and collection, such as `sampled instrument Samples/kickmic/kick of virtuosity_drums`, a list of files by the folder they share or else by the first file and the count of the others; and a part that plays only samples by its sample, such as `vinyl_hiss`, or by the first it plays and the count of the others, such as `kick and 1 other`.
  """

  alias Mx.{Pass, Recording, Render, Samples, Song, Synths, Tempo}

  @unheld_beats 0.5

  @doc "Writes the song at `path` to the HTML file `out`, with `seconds:`, `force:` and `title:`, and returns `:ok` once written, or `{:error, message}`."
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    id = System.unique_integer([:positive])
    wav_path = Path.join(System.tmp_dir!(), "mx-page-#{id}.wav")
    mp3_path = Path.rootname(wav_path) <> ".mp3"

    try do
      with {:ok, ffmpeg} <- ffmpeg(),
           :ok <- check(out, Keyword.get(opts, :force, false)),
           :ok <- Render.render(path, wav_path, seconds: opts[:seconds]),
           :ok <- encode(ffmpeg, wav_path, mp3_path),
           {:ok, song} <- Song.load(path),
           {:ok, data} <- data(song, path, Recording.seconds(wav_path)) do
        title = Keyword.get_lazy(opts, :title, fn -> title(path) end)
        audio = mp3_path |> File.read!() |> Base.encode64()
        File.write!(out, html(Map.merge(data, %{title: title, audio: audio})))
      end
    after
      File.rm(wav_path)
      File.rm(mp3_path)
    end
  end

  @doc "What the page shows of a loaded song that renders to `seconds` of sound: its sections, the seconds of each beat, and each part's notes and hits in seconds; `source` is the file's text, read from `path` when not given."
  def data(%Song{} = song, path, seconds, source \\ nil)
      when is_binary(path) and is_number(seconds) do
    loops = Enum.filter(song.loops, &(&1.on == nil))

    with {:ok, played} <- map_ok(loops, &passes(&1, song, seconds)) do
      [{timeline, _, _, _} | _] = longest = Enum.max_by(played, &length/1)
      beats = longest |> Enum.map(fn {_, start, _, beats} -> start + beats end) |> Enum.max()
      files = files(played)

      {:ok,
       %{
         file: Path.basename(path),
         source: source || File.read!(path),
         tempo: song.tempo,
         meter: song.meter,
         seconds: seconds,
         beats: Enum.map(0..ceil(beats), &seconds_at(timeline, &1)),
         sections:
           for {_, start, _, beats} <- Enum.reverse(longest) do
             [seconds_at(timeline, start), beats]
           end,
         parts: Enum.zip_with(loops, played, &part(&1, &2, files))
       }}
    end
  end

  @whole_seconds 36_000

  @doc "What `data/4` gives of a loaded song without a render to measure: all of a song that ends, and one time through its sections of a song that plays until stopped, with `:ends` saying which; `source` is the file's text, read from `path` when nil."
  def whole(%Song{} = song, path, source \\ nil) when is_binary(path) do
    ends? = Enum.all?(song.loops, &(&1.passes != nil or &1.on != nil))
    first = if ends?, do: @whole_seconds, else: 0.001

    with {:ok, data} <- data(song, path, first, source),
         {:ok, data} <- through(song, path, data),
         {:ok, data} <- data(song, path, List.last(data.beats), data.source) do
      {:ok, Map.put(data, :ends, ends?)}
    end
  end

  # A part with more sections than the passes shown so far is shown a pass further.
  defp through(song, path, data) do
    sections =
      song.loops
      |> Enum.filter(&(&1.on == nil))
      |> Enum.map(&tuple_size(&1.music.sections))
      |> Enum.max(fn -> 1 end)

    if length(data.sections) >= sections do
      {:ok, data}
    else
      seconds = List.last(data.beats) + 0.001

      case data(song, path, seconds, data.source) do
        {:ok, more} when length(more.sections) > length(data.sections) ->
          through(song, path, more)

        {:ok, _same} ->
          {:ok, data}

        error ->
          error
      end
    end
  end

  # Each pass that starts before the sound ends, the last first, as its timeline, the beat it
  # starts on, its events and its length.
  defp passes(loop, song, seconds) do
    sections = loop.music.sections
    window = elem(sections, tuple_size(sections) - 1).beats

    played =
      0
      |> Stream.iterate(&(&1 + 1))
      |> Stream.take_while(&(loop.passes == nil or &1 < loop.passes))
      |> Enum.reduce_while({:ok, [], 0}, fn pass, {:ok, played, start} ->
        {timeline, _} = Tempo.through(song.tempos, song.tempo, pass, window)

        with true <- seconds_at(timeline, start) < seconds,
             {:ok, %{events: events, beats: beats}} <- Pass.events(loop, pass) do
          {:cont, {:ok, [{timeline, start, events, beats} | played], start + beats}}
        else
          false -> {:halt, {:ok, played, start}}
          {:error, message} -> {:halt, {:error, message}}
        end
      end)

    case played do
      {:ok, played, _start} -> {:ok, played}
      error -> error
    end
  end

  defp files(played) do
    paths =
      for passes <- played,
          {_, _, events, _} <- passes,
          {_, {:sample, _, path}, _} <- events,
          uniq: true,
          do: path

    Map.new(paths, &{&1, Samples.seconds(&1)})
  end

  defp part(loop, played, files) do
    marks = played |> Enum.reverse() |> Enum.flat_map(&marks(&1, loop.synth, files))
    notes = for {:note, note} <- marks, do: note
    hits = for {:hit, hit} <- marks, do: hit

    %{
      name: loop.name,
      synth: sound(loop.synth, played),
      fx: Enum.map(loop.fx, fn {effect, _opts} -> effect end),
      notes: Enum.sort(notes),
      hits: Enum.sort(hits)
    }
  end

  # A part that gives no sampled instrument and plays only samples is named by the samples it plays.
  defp sound(synth, played) do
    steps = for {_, _, events, _} <- Enum.reverse(played), {_, step, _} <- events, do: step
    samples = for {:sample, ref, _path} <- steps, uniq: true, do: sample_name(ref)

    if is_atom(synth) and samples != [] and not Enum.any?(steps, &played_note?/1) do
      first = hd(samples)
      others = Mx.Sampled.others(length(samples) - 1)
      "#{first}#{others}"
    else
      to_string(synth)
    end
  end

  defp played_note?(step),
    do: is_number(step) or step == :own_note or match?({:midi_note, _}, step)

  defp sample_name({_collection, name}) when is_atom(name), do: Atom.to_string(name)
  defp sample_name({_collection, path}) when is_binary(path), do: sample_name(path)
  defp sample_name(name) when is_atom(name), do: Atom.to_string(name)
  defp sample_name(path) when is_binary(path), do: path |> Path.basename() |> Path.rootname()

  # A control step names the notes it changes by their place among the pass's events.
  defp marks({timeline, start, events, _beats}, synth, files) do
    moves =
      for {beat, {:control, {:sounds, indexes}, _synth}, opts} <- events,
          pitch = opts[:note],
          index <- indexes,
          reduce: %{} do
        moves -> Map.update(moves, index, [{beat, pitch}], &(&1 ++ [{beat, pitch}]))
      end

    at = &seconds_at(timeline, start + &1)

    events
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {{beat, pitch, opts}, index} when is_number(pitch) ->
        until = beat + (opts[:sustain] || @unheld_beats)
        held = [{beat, pitch} | Enum.filter(Map.get(moves, index, []), &(elem(&1, 0) < until))]
        strength = strength(opts)

        held
        |> Enum.zip(Enum.map(tl(held), &elem(&1, 0)) ++ [until])
        |> Enum.with_index(fn {{from, pitch}, to}, turn ->
          tied = if turn > 0, do: 1, else: 0
          {:note, [at.(from), Float.round(at.(to) - at.(from), 3), pitch, strength, tied]}
        end)

      {{beat, {:midi_note, pitch}, opts}, _index} ->
        seconds = Float.round(at.(beat + opts[:length]) - at.(beat), 3)
        [{:note, [at.(beat), seconds, pitch, Float.round(opts[:velocity] / 127, 2), 0]}]

      {{beat, step, opts}, _index} when step == :own_note or elem(step, 0) == :sample ->
        lasts = &Float.round(at.(beat + &1) - at.(beat), 3)
        [{:hit, [at.(beat), strength(opts), sounds(step, opts, synth, files, lasts)]}]

      _other ->
        []
    end)
  end

  defp sounds({:sample, _, path}, opts, _synth, files, lasts) do
    span = abs(Keyword.get(opts, :finish, 1) - Keyword.get(opts, :start, 0))
    whole = Float.round(files[path] * span / abs(Keyword.get(opts, :rate, 1)), 3)

    case opts[:sustain] do
      sustain when is_number(sustain) and sustain >= 0 ->
        min(
          whole,
          lasts.(Keyword.get(opts, :attack, 0) + sustain + Keyword.get(opts, :release, 0))
        )

      _until_the_end ->
        whole
    end
  end

  defp sounds(:own_note, opts, synth, _files, lasts) do
    envelope =
      for key <- [:attack, :decay, :sustain, :release],
          is_atom(synth),
          Synths.option?(synth, key),
          beats = opts[key],
          do: beats

    if envelope == [], do: 0.0, else: lasts.(Enum.sum(envelope))
  end

  defp strength(opts) do
    strength = opts[:vel] || opts[:amp] || 1
    strength |> max(0) |> min(1) |> Kernel./(1) |> Float.round(2)
  end

  defp seconds_at(timeline, beat), do: Float.round(Tempo.time_at(timeline, beat) / 1_000_000, 3)

  defp map_ok(items, fun) do
    mapped =
      items
      |> Enum.reduce_while({:ok, []}, fn item, {:ok, done} ->
        case fun.(item) do
          {:ok, value} -> {:cont, {:ok, [value | done]}}
          error -> {:halt, error}
        end
      end)

    case mapped do
      {:ok, done} -> {:ok, Enum.reverse(done)}
      error -> error
    end
  end

  @doc "Checks a file can be written to `out`: `:ok`, or `{:error, message}` when it exists without `force` or its folder does not."
  def check(out, force) when is_binary(out) and is_boolean(force) do
    cond do
      File.exists?(out) and not force ->
        {:error, "#{out} already exists; give --force to write over it"}

      not File.dir?(Path.dirname(out)) ->
        {:error, "cannot write #{out}: its folder does not exist"}

      true ->
        :ok
    end
  end

  defp ffmpeg do
    case System.find_executable("ffmpeg") do
      nil -> {:error, "a page needs ffmpeg to encode the song's sound, and it is not installed"}
      program -> {:ok, program}
    end
  end

  defp encode(ffmpeg, wav_path, mp3_path) do
    args = ~w(-v error -y -i #{wav_path} -codec:a libmp3lame -b:a 160k #{mp3_path})

    case System.cmd(ffmpeg, args, stderr_to_stdout: true) do
      {_log, 0} -> :ok
      {log, _status} -> {:error, "ffmpeg could not encode the song's sound: #{String.trim(log)}"}
    end
  end

  defp title(path) do
    path |> Path.basename() |> Path.rootname() |> String.replace("_", " ") |> String.capitalize()
  end

  # The song goes into a script element as JSON, where only a closing tag could end it early.
  defp html(data) do
    title = data.title |> String.replace("&", "&amp;") |> String.replace("<", "&lt;")
    song = data |> JSON.encode!() |> String.replace("</", "<\\/")

    Application.app_dir(:mx, "priv/page.html")
    |> File.read!()
    |> String.replace("{{title}}", title)
    |> String.replace("{{song}}", song)
  end
end
