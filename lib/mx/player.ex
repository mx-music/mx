defmodule Mx.Player do
  @moduledoc """
  Plays a song file until Enter is pressed or its music ends, and plays each saved version of it, for `mix mx.play` and the `mx` command.
  """

  alias Mx.{Session, Song}

  @switches [
    record: :string,
    render: :string,
    seconds: :float,
    force: :boolean,
    share: :float,
    ring_out: :boolean,
    mute: :keep,
    solo: :keep,
    part: :keep,
    tempo: :string,
    grid: :string,
    tune: :integer,
    output: :string,
    input: :string,
    rate: :integer,
    buffer: :integer
  ]

  @import [:part, :tempo, :grid, :tune]

  @devices [:output, :input, :rate, :buffer]

  @doc "The options `play/2` takes, parsed from command line arguments, and the arguments left."
  def parse(args) when is_list(args), do: OptionParser.parse!(args, strict: @switches)

  @doc "Plays a song file with `record:` and `force:`, or renders it offline with `render:`, `seconds:`, `ring_out:` and `force:`, either at `share:` of its tempo, and returns `:ok` once it stops, or `{:error, message}`."
  def play(path, opts) when is_binary(path) and is_list(opts) do
    with :ok <- Mx.Band.check_share(Keyword.get(opts, :share, 1)),
         :ok <- check_import(path, opts) do
      play_or_render(path, opts)
    end
  end

  defp check_import(path, opts) do
    if Mx.Import.score?(path) or Keyword.take(opts, @import) == [],
      do: :ok,
      else:
        {:error, "--part, --tempo, --grid and --tune go with a score, a MIDI file or an ABC tune"}
  end

  defp play_or_render(path, opts) do
    cond do
      opts[:render] && opts[:record] ->
        {:error,
         "--render and --record cannot go together: a render writes its file without playing"}

      out = opts[:render] ->
        say_unused(opts)

        Mx.Render.render(
          path,
          out,
          Keyword.take(opts, [:seconds, :force, :share, :ring_out | @import]) ++
            [mute: Keyword.get_values(opts, :mute), solo: Keyword.get_values(opts, :solo)]
        )

      Keyword.has_key?(opts, :ring_out) ->
        {:error, "--ring-out goes with --render"}

      Keyword.has_key?(opts, :mute) or Keyword.has_key?(opts, :solo) ->
        {:error, "--mute and --solo go with --render"}

      true ->
        play_aloud(path, opts)
    end
  end

  defp say_unused(opts) do
    case Enum.filter([:rate, :buffer], &Keyword.has_key?(opts, &1)) do
      [] ->
        :ok

      unused ->
        names = Enum.map_join(unused, " and ", &"--#{&1}")
        verb = if length(unused) == 1, do: "does", else: "do"
        IO.puts("#{names} #{verb} not apply to a render, which runs at 48000 Hz")
    end
  end

  # A device setting given to the task overrides the project's config for mx.
  defp devices(opts) do
    for key <- @devices,
        value = Keyword.get(opts, key, Application.get_env(:mx, key)),
        value != nil,
        do: {key, value}
  end

  defp play_aloud(path, opts) do
    record = opts[:record]

    with :ok <- check_record(record, Keyword.get(opts, :force, false)),
         {:ok, _apps} <- Application.ensure_all_started(:mx),
         {:ok, song, session_opts} <- load(path, opts) do
      Process.flag(:trap_exit, true)
      player = self()
      on_end = fn -> send(player, :song_ended) end

      session_opts =
        session_opts ++
          [song: song, on_end: on_end, devices: devices(opts)] ++
          Keyword.take(opts, [:record, :share])

      case Session.start_link(session_opts) do
        {:ok, session} ->
          parts = describe(song.loops, "part") ++ describe(song.live, "live audio")
          playing = Enum.join(parts, " and ")
          IO.puts("Playing #{playing} from #{path} at #{song.tempo} bpm.")

          if session_opts[:watch] == false,
            do: IO.puts("Press Enter to stop."),
            else: IO.puts("Save the file to change it, and press Enter to stop.")

          wait_for_end()
          Supervisor.stop(session)
          if record, do: Enum.each(Mx.Recording.report(record), &IO.puts/1)
          :ok

        {:error, {:shutdown, {:failed_to_start_child, _, message}}} when is_binary(message) ->
          {:error, message}
      end
    end
  end

  # A score plays as the song mx import would write from it, which is not written, and so not
  # watched.
  defp load(path, opts) do
    if Mx.Import.score?(path) do
      with {:ok, song, imported} <- Mx.Import.load(path, Keyword.take(opts, @import)) do
        Enum.each(imported.parts ++ imported.left_out, &IO.puts/1)
        {:ok, song, [path: imported.out, source: imported.source, watch: false]}
      end
    else
      with {:ok, song} <- Song.load(path), do: {:ok, song, [path: path]}
    end
  end

  defp check_record(nil, _force), do: :ok
  defp check_record(record, force), do: Mx.Recording.check(record, force)

  # Enter stops the song, and so does the end of a song whose music ends.
  defp wait_for_end do
    player = self()
    spawn_link(fn -> send(player, {:entered, IO.gets("")}) end)

    receive do
      {:entered, _line} -> :ok
      :song_ended -> IO.puts("The song ended.")
    end
  end

  defp describe([], _kind), do: []

  defp describe(items, kind) do
    names = Enum.map_join(items, ", ", &to_string(&1.name))
    kind = if length(items) == 1 or kind == "live audio", do: kind, else: kind <> "s"
    ["#{kind} #{names}"]
  end
end
