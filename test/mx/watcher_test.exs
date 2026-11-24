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

    assert_receive {:song, %Song{loops: [loop]}}
    assert {:ok, %{events: [{0, 62, []}]}} = Mx.Pass.events(loop, 0)
  end

  @tag :tmp_dir
  test "prints the error of a save that does not load, and loads the next good save", ctx do
    watcher = start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})
    silence_stdout(watcher)
    Watcher.subscribe(watcher)

    output =
      capture_io(:stderr, fn ->
        File.write!(ctx.path, "import Mx\nsong(music: part(:melody, note(:h4, 1)))\n")
        assert_receive {:mx_load_failed, _message}
      end)

    assert output =~ "song.exs:2: unknown note h4"
    refute_received {:song, _}

    File.write!(ctx.path, @song)
    assert_receive {:song, %Song{}}
  end

  @tag :tmp_dir
  test "prints the error of a song written as music that does not load, with its line", ctx do
    File.write!(ctx.path, "import Mx\nsong(music: part(:lead, seq(c4: 1)))\n")
    watcher = start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})
    silence_stdout(watcher)
    Watcher.subscribe(watcher)

    output =
      capture_io(:stderr, fn ->
        File.write!(ctx.path, "import Mx\nsong(music: part(:lead, seq(c4: 1))\n")
        assert_receive {:mx_load_failed, _message}
      end)

    assert output =~ "song.exs:2:36"
    assert output =~ "The previous version keeps playing."
    refute_received {:song, _}
  end

  @tag :tmp_dir
  test "refuses a save that names a part twice, and keeps the previous version", ctx do
    watcher = start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})
    Watcher.subscribe(watcher)

    output =
      capture_io(:stderr, fn ->
        File.write!(
          ctx.path,
          "import Mx\nsong(music: together([part(:melody, seq(c4: 1)), part(:melody, seq(e4: 1))]))\n"
        )

        assert_receive {:mx_load_failed, _message}
      end)

    assert output =~ "two parts named melody play together"
    assert output =~ "The previous version keeps playing."
    refute_received {:song, _}
  end

  @tag :tmp_dir
  test "refuses a save with an effect mx does not have, and keeps the previous version", ctx do
    watcher = start_supervised!({Watcher, path: ctx.path, on_song: ctx.on_song, interval_ms: 10})
    Watcher.subscribe(watcher)

    output =
      capture_io(:stderr, fn ->
        File.write!(ctx.path, String.replace(@song, "end)))", "end), fx: :reverbb))"))
        assert_receive {:mx_load_failed, _message}
      end)

    assert output =~ "part melody: mx has no effect reverbb"
    assert output =~ "The previous version keeps playing."
    refute_received {:song, _}
  end

  describe "a subscriber" do
    setup ctx do
      name = :"watcher_test_#{System.unique_integer([:positive])}"
      Process.register(self(), name)
      telling = "send(#{inspect(name)}, {:evaluated, System.monotonic_time(:millisecond)})\n"
      File.write!(ctx.path, telling <> @song)
      {:ok, song} = Song.load(ctx.path)
      assert_receive {:evaluated, _}
      opts = [path: ctx.path, song: song, on_song: ctx.on_song]
      watcher = start_supervised!({Watcher, opts})
      silence_stdout(watcher)
      %{watcher: watcher, song: song, source: telling <> @song}
    end

    @tag :tmp_dir
    test "is given the version loaded now, numbered 0, and the same without subscribing", ctx do
      assert {0, {:ok, described}} = Watcher.subscribe(ctx.watcher)
      assert described.source == ctx.source
      assert [%{name: :melody, notes: [[+0.0, _held, 60 | _]]}] = described.parts
      assert Watcher.description(ctx.watcher) == {0, {:ok, described}}
    end

    @tag :tmp_dir
    test "is sent each save that loads, numbered, loaded once and within 20 ms", ctx do
      Watcher.subscribe(ctx.watcher)
      saved = String.replace(ctx.source, "60", "62")
      File.write!(ctx.path, saved)
      at = System.monotonic_time(:millisecond)

      assert_receive {:mx_loaded, 1, {:ok, %{source: ^saved} = described}}
      assert [%{name: :melody, notes: [[+0.0, _held, 62 | _]]}] = described.parts
      assert_received {:song, %Song{loops: [loop]}}
      assert {:ok, %{events: [{0, 62, []}]}} = Mx.Pass.events(loop, 0)
      assert_received {:evaluated, started}
      assert started - at <= 20
      refute_receive {:evaluated, _}
      refute_received {:mx_loaded, _, _}
      assert Watcher.description(ctx.watcher) == {1, {:ok, described}}

      File.write!(ctx.path, String.replace(ctx.source, "60", "64"))
      assert_receive {:mx_loaded, 2, {:ok, _described}}
    end

    @tag :tmp_dir
    test "is sent the error of a save that does not load, once, and the version stays", ctx do
      Watcher.subscribe(ctx.watcher)

      capture_io(:stderr, fn ->
        File.write!(
          ctx.path,
          String.duplicate("\n", 11) <> "song(music: part(:melody, seq(c4: 1))\n"
        )

        assert_receive {:mx_load_failed, message}
        assert message =~ "song.exs:12:"
        refute_receive {:mx_load_failed, _}
      end)

      refute_received {:song, _}
      assert {0, {:ok, %{source: source}}} = Watcher.description(ctx.watcher)
      assert source == ctx.source
    end

    @tag :tmp_dir
    test "asking for the loaded version reads no file", ctx do
      File.rm!(ctx.path)
      Process.sleep(50)
      assert {0, {:ok, %{source: source}}} = Watcher.description(ctx.watcher)
      assert source == ctx.source
    end

    @tag :tmp_dir
    test "two saves 10 ms apart end with the second loaded", ctx do
      Watcher.subscribe(ctx.watcher)
      File.write!(ctx.path, String.replace(ctx.source, "60", "62"))
      Process.sleep(10)
      second = String.replace(ctx.source, "60", "64")
      File.write!(ctx.path, second)
      assert_receive {:mx_loaded, number, {:ok, %{source: ^second}}}
      assert {^number, {:ok, %{source: ^second} = described}} = Watcher.description(ctx.watcher)
      assert number in [1, 2]
      assert [%{notes: [[+0.0, _held, 64 | _]]}] = described.parts
    end

    @tag :tmp_dir
    test "that ends is forgotten", ctx do
      test = self()
      subscriber = spawn(fn -> send(test, {:subscribed, Watcher.subscribe(ctx.watcher)}) end)
      assert_receive {:subscribed, {0, {:ok, _described}}}
      ref = Process.monitor(subscriber)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
      assert :sys.get_state(ctx.watcher).subscribers == %{}
    end
  end

  # The watcher inherits the test supervisor's group leader, so capture_io in the test does not
  # reach it.
  defp silence_stdout(pid) do
    {:ok, device} = StringIO.open("")
    Process.group_leader(pid, device)
  end
end
