defmodule Mx.SongLoadTest do
  # Not async, as it captures stderr, which every test shares.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Song

  @moduletag :tmp_dir

  test "a song file loaded several times at once, defining its module again each time, warns of no redefined module",
       ctx do
    path =
      write(ctx.tmp_dir, """
      defmodule Mx.SongLoadTest.Kick do
        use Mx.Song, tempo: 92
        part :kick, synth: :kick
        def song, do: part(:kick, note(:c4, 1))
      end
      """)

    warnings =
      capture_io(:stderr, fn ->
        1..40
        |> Task.async_stream(fn _ -> Song.load(path) end, max_concurrency: 4, timeout: 60_000)
        |> Enum.each(&assert(match?({:ok, {:ok, _}}, &1)))
      end)

    assert warnings == ""
  end

  defp write(dir, body) do
    path = Path.join(dir, "song.exs")
    File.write!(path, body)
    path
  end
end
