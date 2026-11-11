defmodule Mx.Watcher do
  @moduledoc """
  Loads a song file again whenever its content changes, and hands each
  version that loads to `on_song`. A version that does not load prints its
  error, and the playing version stays.

  It compares the content rather than the modification time, since that
  time has a resolution of one second and two quick saves would look like one.
  """

  use GenServer

  alias Mx.Song

  @doc "Starts watching the song file at `:path`, handing each version that loads to `:on_song`."
  def start_link(opts) when is_list(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) when is_list(opts) do
    path = Keyword.fetch!(opts, :path)

    state = %{
      path: path,
      on_song: Keyword.fetch!(opts, :on_song),
      interval_ms: Keyword.get(opts, :interval_ms, 100),
      digest: digest(path)
    }

    schedule(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:check, %{} = state) do
    digest = digest(state.path)

    if digest != state.digest and digest != nil do
      load(state)
    end

    schedule(state)
    {:noreply, %{state | digest: digest || state.digest}}
  end

  defp load(state) do
    case Song.load(state.path) do
      {:ok, song} ->
        IO.puts("Loaded #{state.path}, each loop takes over at the end of its current pass.")
        state.on_song.(song)

      {:error, message} ->
        IO.puts(:stderr, message <> "\nThe previous version keeps playing.")
    end
  end

  defp digest(path) do
    case File.read(path) do
      {:ok, content} -> :erlang.md5(content)
      {:error, _} -> nil
    end
  end

  defp schedule(state), do: Process.send_after(self(), :check, state.interval_ms)
end
