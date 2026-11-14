defmodule Mx.WatcherTest do
  use ExUnit.Case, async: true, group: :stderr

  import ExUnit.CaptureIO

  alias Mx.{Song, Watcher}

  @song "import Mx\nsong(music: part(:melody, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end)))\n"

  setup %{tmp_dir: dir} do
    path = Path.join(dir, "song.exs")
    File.write!(path, @song)
    test = self()
    %{path: path, on_song: fn song -> send(test, {:song, song}) end}
  end

  @tag :tmp_dir
  test "loads the file again when it is saved", %{path: path, on_song: on_song} do
    watcher = start_supervised!({Watcher, path: path, on_song: on_song, interval_ms: 10})
    silence_stdout(watcher)

    File.write!(path, String.replace(@song, "60", "62"))

    assert_receive {:song, %Song{loops: [loop]}}, 1000
    assert {:ok, %{events: [{0, 62, []}]}} = Mx.Pass.events(loop, 0)
  end

  @tag :tmp_dir
  test "prints the error of a save that does not load, and loads the next good save", ctx do
    watcher = start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})
    silence_stdout(watcher)

    output =
      capture_io(:stderr, fn ->
        File.write!(ctx.path, "import Mx\nsong(music: part(:melody, note(:h4, 1)))\n")
        Process.sleep(100)
      end)

    assert output =~ "song.exs:2: unknown note h4"
    refute_received {:song, _}

    File.write!(ctx.path, @song)
    assert_receive {:song, %Song{}}, 1000
  end

  @tag :tmp_dir
  test "prints the error of a song written as music that does not load, with its line", ctx do
    File.write!(ctx.path, "import Mx\nsong(music: part(:lead, seq(c4: 1)))\n")
    watcher = start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})
    silence_stdout(watcher)

    output =
      capture_io(:stderr, fn ->
        File.write!(ctx.path, "import Mx\nsong(music: part(:lead, seq(c4: 1))\n")
        Process.sleep(100)
      end)

    assert output =~ "song.exs:2:36"
    assert output =~ "The previous version keeps playing."
    refute_received {:song, _}
  end

  @tag :tmp_dir
  test "refuses a save that names a part twice, and keeps the previous version", ctx do
    start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})

    output =
      capture_io(:stderr, fn ->
        File.write!(
          ctx.path,
          "import Mx\nsong(music: together([part(:melody, seq(c4: 1)), part(:melody, seq(e4: 1))]))\n"
        )

        Process.sleep(100)
      end)

    assert output =~ "two parts named melody play together"
    assert output =~ "The previous version keeps playing."
    refute_received {:song, _}
  end

  @tag :tmp_dir
  test "refuses a save with an effect mx does not have, and keeps the previous version", ctx do
    start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})

    output =
      capture_io(:stderr, fn ->
        File.write!(ctx.path, String.replace(@song, "end)))", "end), fx: :reverbb))"))
        Process.sleep(100)
      end)

    assert output =~ "part melody: mx has no effect reverbb"
    assert output =~ "The previous version keeps playing."
    refute_received {:song, _}
  end

  # The watcher inherits the test supervisor's group leader, so capture_io in the test does not
  # reach it.
  defp silence_stdout(pid) do
    {:ok, device} = StringIO.open("")
    Process.group_leader(pid, device)
  end
end
