defmodule Mx.Watcher do
  @moduledoc """
  Loads a song file again whenever its content changes, and hands each
  version that loads to `on_song`. A version that does not load prints its
  error, and the playing version stays.

  It compares the content rather than the modification time, since that
  time has a resolution of one second and two quick saves would look like one.

  A save is loaded once, here, and a program that wants the loaded version asks for its
  description with `subscribe/1` or `description/1` instead of loading the file again.
  The description is what `Mx.Page.whole/3` gives of the version handed to `on_song`, as
  `{:ok, data}` or `{:error, message}`, worked out from the file's text as it was loaded.
  The versions are numbered: the song the watcher starts with is 0, and each save that loads is
  the next number.
  A subscriber is sent `{:mx_loaded, number, description}` for each save that loads, and
  `{:mx_load_failed, message}` for each save that does not.
  Two saves while the first still loads are loaded as one, the later.
  """

  use GenServer

  alias Mx.Song

  @doc "Starts watching the song file at `:path`, handing each version that loads to `:on_song`; `:song` is the version already loaded from it, if any, and `:source` its text; with `watch: false` it never reads the file, and only describes `:song`."
  def start_link(opts) when is_list(opts), do: GenServer.start_link(__MODULE__, opts)

  @doc "Subscribes the calling process to the saves the watcher loads, and returns the version loaded now, as `description/1` does."
  def subscribe(watcher) when is_pid(watcher), do: GenServer.call(watcher, :subscribe, 30_000)

  @doc "The version loaded now, as `{number, description}`, without reading the file; the description is nil when the watcher was started without `:song`."
  def description(watcher) when is_pid(watcher), do: GenServer.call(watcher, :description, 30_000)

  @impl true
  def init(opts) when is_list(opts) do
    path = Keyword.fetch!(opts, :path)
    watch = Keyword.get(opts, :watch, true)
    source = opts[:source] || if(watch, do: read(path))

    state = %{
      path: path,
      on_song: Keyword.fetch!(opts, :on_song),
      interval_ms: Keyword.get(opts, :interval_ms, 10),
      digest: digest(source),
      number: 0,
      song: opts[:song],
      source: source,
      description: nil,
      subscribers: %{}
    }

    if watch, do: schedule(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:subscribe, {pid, _tag}, state) do
    state = describe(state)
    subscribers = Map.put_new_lazy(state.subscribers, pid, fn -> Process.monitor(pid) end)
    {:reply, {state.number, state.description}, %{state | subscribers: subscribers}}
  end

  def handle_call(:description, _from, state) do
    state = describe(state)
    {:reply, {state.number, state.description}, state}
  end

  @impl true
  def handle_info(:check, %{} = state) do
    source = read(state.path)
    digest = digest(source)
    changed? = digest != state.digest and digest != nil
    state = if changed?, do: load(state, source), else: state
    schedule(state)
    {:noreply, %{state | digest: digest || state.digest}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, pid)}}
  end

  defp load(state, source) do
    case Song.load(state.path) do
      {:ok, song} ->
        IO.puts("Loaded #{state.path}, each loop takes over at the end of its current pass.")
        state.on_song.(song)
        state = %{state | number: state.number + 1, song: song, source: source, description: nil}
        state = if state.subscribers == %{}, do: state, else: describe(state)
        tell(state, {:mx_loaded, state.number, state.description})
        state

      {:error, message} ->
        IO.puts(:stderr, message <> "\nThe previous version keeps playing.")
        tell(state, {:mx_load_failed, message})
        state
    end
  end

  defp describe(%{description: nil, song: %Song{} = song} = state) do
    %{state | description: Mx.Page.whole(song, state.path, state.source)}
  end

  defp describe(state), do: state

  defp tell(state, message), do: state.subscribers |> Map.keys() |> Enum.each(&send(&1, message))

  defp read(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> nil
    end
  end

  defp digest(nil), do: nil
  defp digest(content), do: :erlang.md5(content)

  defp schedule(state), do: Process.send_after(self(), :check, state.interval_ms)
end
