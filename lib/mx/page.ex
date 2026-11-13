defmodule Mx.Page do
  @moduledoc """
  Writes a song as one HTML page that plays it and shows each part's notes on a timeline, for `mix mx.page`.

  The page holds the song's offline render, which ffmpeg encodes as MP3, so a browser plays what mx plays and works out no sound itself.
  Each part's notes are the ones `Mx.Pass` works out, pass by pass, at the seconds `Mx.Tempo` gives their beats.
  A note with no `sustain:` shows half a beat long, and a note a control step moves to another pitch shows as one mark for each pitch.
  A sample shows as a hit, and so does a note of a sampled instrument, as its pass names the file it plays and not the key.
  A part that waits for input is left out, as a render leaves it out.
  """

  alias Mx.{Pass, Recording, Render, Song, Tempo}

  @unheld_beats 0.5

  @doc "Writes the song at `path` to the HTML file `out`, with `seconds:`, `force:` and `title:`, and returns `:ok` once written, or `{:error, message}`."
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    id = System.unique_integer([:positive])
    wav = Path.join(System.tmp_dir!(), "mx-page-#{id}.wav")
    mp3 = Path.rootname(wav) <> ".mp3"

    try do
      with {:ok, ffmpeg} <- ffmpeg(),
           :ok <- check(out, Keyword.get(opts, :force, false)),
           :ok <- Render.render(path, wav, seconds: opts[:seconds]),
           :ok <- encode(ffmpeg, wav, mp3),
           {:ok, song} <- Song.load(path),
           {:ok, data} <- data(song, path, Recording.seconds(wav)) do
        title = Keyword.get_lazy(opts, :title, fn -> title(path) end)
        audio = mp3 |> File.read!() |> Base.encode64()
        File.write!(out, html(Map.merge(data, %{title: title, audio: audio})))
      end
    after
      File.rm(wav)
      File.rm(mp3)
    end
  end

  @doc "What the page shows of a loaded song that renders to `seconds` of sound: its sections, the seconds of each beat, and each part's notes and hits in seconds."
  def data(%Song{} = song, path, seconds) when is_binary(path) and is_number(seconds) do
    loops = Enum.filter(song.loops, &(&1.on == nil))

    with {:ok, played} <- map_ok(loops, &passes(&1, song, seconds)) do
      [{timeline, _, _, _} | _] = longest = Enum.max_by(played, &length/1)
      beats = longest |> Enum.map(fn {_, start, _, beats} -> start + beats end) |> Enum.max()

      {:ok,
       %{
         file: Path.basename(path),
         source: File.read!(path),
         tempo: song.tempo,
         seconds: seconds,
         beats: for(beat <- 0..ceil(beats), do: seconds_at(timeline, beat)),
         sections:
           for {_, start, _, beats} <- Enum.reverse(longest) do
             [seconds_at(timeline, start), beats]
           end,
         parts: Enum.zip_with(loops, played, &part/2)
       }}
    end
  end

  # Each pass that starts before the sound ends, the last first, as its timeline, the beat it starts on, its events and its length.
  defp passes(loop, song, seconds) do
    sections = loop.music.sections
    window = elem(sections, tuple_size(sections) - 1).beats

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
    |> case do
      {:ok, played, _start} -> {:ok, played}
      error -> error
    end
  end

  defp part(loop, played) do
    marks = played |> Enum.reverse() |> Enum.flat_map(&marks/1)

    %{
      name: loop.name,
      synth: to_string(loop.synth),
      fx: Enum.map(loop.fx, fn {effect, _opts} -> effect end),
      notes: for({:note, note} <- marks, do: note) |> Enum.sort(),
      hits: for({:hit, hit} <- marks, do: hit) |> Enum.sort()
    }
  end

  # A control step names the notes it changes by their place among the pass's events.
  defp marks({timeline, start, events, _beats}) do
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
        [{:hit, [at.(beat), strength(opts)]}]

      _other ->
        []
    end)
  end

  defp strength(opts) do
    strength = opts[:vel] || opts[:amp] || 1
    strength |> max(0) |> min(1) |> Kernel./(1) |> Float.round(2)
  end

  defp seconds_at(timeline, beat), do: Float.round(Tempo.time_at(timeline, beat) / 1_000_000, 3)

  defp map_ok(items, fun) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, done} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, [value | done]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, done} -> {:ok, Enum.reverse(done)}
      error -> error
    end
  end

  defp check(out, force) do
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

  defp encode(ffmpeg, wav, mp3) do
    args = ~w(-v error -y -i #{wav} -codec:a libmp3lame -b:a 160k #{mp3})

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
