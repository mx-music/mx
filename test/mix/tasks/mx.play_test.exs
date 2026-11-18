defmodule Mix.Tasks.Mx.PlayTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Play

  @song "import Mx\nsong(tempo: 240, music: part(:a, loop(1, fn _, _ -> seq([note(72, 0, release: 0.05), rest(1)]) end)))\n"

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    path = Path.join(dir, "song.exs")
    File.write!(path, @song)
    %{song: path}
  end

  test "refuses to record over an existing file before playing, naming it", ctx do
    out = Path.join(ctx.tmp_dir, "out.wav")
    File.write!(out, "keep")

    assert_raise Mix.Error, "#{out} already exists; give --force to record over it", fn ->
      Play.run([ctx.song, "--record", out])
    end

    assert File.read!(out) == "keep"
  end

  test "refuses to record into a folder that does not exist, naming the path", ctx do
    assert_raise Mix.Error, "cannot record to /missing/out.wav: its folder does not exist", fn ->
      Play.run([ctx.song, "--record", "/missing/out.wav"])
    end
  end

  @tag :engine
  test "records over an existing file with --force, and prints its parts, where, how long and how loud",
       ctx do
    out = Path.join(ctx.tmp_dir, "out.wav")
    File.write!(out, "old")

    output =
      capture_io([input: ""], fn ->
        Play.run([ctx.song, "--record", out, "--force"])
      end)

    assert output =~ "Playing part a from #{ctx.song} at 240 bpm.\n"

    assert output =~
             ~r/Recorded \d+\.\d seconds to #{Regex.escape(out)}, peaking at [-\d.inf]+ dB\./

    assert %{channels: 2} = Mx.Recording.read_wav(out)
  end

  @tag :engine
  # fm with no depth is a sine at 0.6, and a centred pan sends amp / √2 to each channel, so amp
  # 0.5 peaks at -13.5 dB.
  test "a recording of one sine at amp 0.5 peaks at -13.5 dB, with no warning", ctx do
    [line] =
      record(ctx, "seq([note(72, 0, amp: 0.5, depth: 0, sustain: 0.5), rest(8)])", synth: :fm)

    [_, peak] = Regex.run(~r/peaking at (-[\d.]+) dB\.$/, line)
    assert_in_delta String.to_float(peak), -13.5, 0.3
  end

  @tag :engine
  test "a recording of a chord of eight notes at amp 1 warns that it clipped, within the note's first second",
       ctx do
    {lines, out} =
      record_to(
        ctx,
        "seq([note([60, 64, 67, 72, 76, 79, 84, 88], 0, amp: 1, sustain: 1), rest(8)])"
      )

    assert [_, warning] = lines

    [_, count, first] =
      Regex.run(
        ~r/^The recording clipped (\d+) times?, first at ([\d.]+) seconds\. Lower the amp of the loudest loops to record it cleanly\.$/,
        warning
      )

    assert String.to_integer(count) >= 1
    first = String.to_float(first)
    start = sound_start(out)
    assert first >= start - 0.05 and first < start + 1
  end

  @tag :engine
  test "a recording of nothing peaks at -inf dB, with no warning", ctx do
    assert [line] = record(ctx, "rest(8)")
    assert line =~ ~r/peaking at -inf dB\.$/
  end

  @tag :engine
  test "a session sends a subscriber the description of each save it loads", ctx do
    path = Path.join(ctx.tmp_dir, "quiet.exs")

    song =
      "import Mx\nsong(music: part(:a, loop(8, fn _, _ -> seq([note(60, 1, amp: 0)]) end)))\n"

    File.write!(path, song)
    {:ok, loaded} = Mx.Song.load(path)
    {:ok, session} = Mx.Session.start_link(path: path, song: loaded)

    {:ok, device} = StringIO.open("")

    for {_id, pid, _type, _modules} <- Supervisor.which_children(session),
        do: Process.group_leader(pid, device)

    assert {0, {:ok, %{source: ^song}}} = Mx.Session.subscribe(session)
    saved = String.replace(song, "60", "62")
    File.write!(path, saved)
    assert_receive {:mx_loaded, 1, {:ok, %{source: ^saved}}}, 2000
    assert {1, {:ok, %{source: ^saved}}} = Mx.Session.description(session)
    Supervisor.stop(session)
  end

  @tag :engine
  test "a session sends a follower where the beat is once, and again only when it stops", ctx do
    path = Path.join(ctx.tmp_dir, "quiet.exs")

    song =
      "import Mx\nsong(tempo: 120, music: part(:a, loop(8, fn _, _ -> seq([note(60, 1, amp: 0)]) end)))\n"

    File.write!(path, song)
    {:ok, loaded} = Mx.Song.load(path)
    {:ok, session} = Mx.Session.start_link(path: path, song: loaded)
    {:ok, device} = StringIO.open("")

    for {_id, pid, _type, _modules} <- Supervisor.which_children(session),
        do: Process.group_leader(pid, device)

    :ok = Mx.Session.follow_beat(session)
    assert_receive {:mx_beat, %{beat: 0, tempo: 120, heard_us: heard_us} = message}
    [{0, start_us, 120}] = Mx.Band.timeline(Mx.Band)
    delay_us = heard_us - start_us
    assert delay_us >= 0 and delay_us < 500_000

    File.write!(path, String.replace(song, "60", "62"))
    refute_receive {:mx_beat, _}, 3000
    now = System.os_time(:microsecond)
    asked = Mx.Band.beat_at(Mx.Band.timeline(Mx.Band), now - delay_us)
    assert_in_delta Mx.Beat.at(message, now), asked, 1.0e-6

    Supervisor.stop(session)
    assert_receive {:mx_beat, :stopped}
  end

  @tag :engine
  test "a part muted in a session stays silent through a save that changes the tempo, and the file is left as saved",
       ctx do
    {session, path, song, out} = lead_and_silent_bass(ctx)

    assert Mx.Session.mute(session, :lead) == :ok

    assert Mx.Session.mute(session, :no_such_part) ==
             {:error, "the song has no part named no_such_part"}

    Process.sleep(1000)
    assert File.read!(path) == song
    saved = String.replace(song, "tempo: 120", "tempo: 90")
    File.write!(path, saved)
    assert_receive {:mx_loaded, 1, {:ok, _}}, 2000
    Process.sleep(2500)
    Supervisor.stop(session)

    assert File.read!(path) == saved
    assert [line] = Mx.Recording.report(out)
    assert line =~ ~r/^Recorded [4-9]\.\d seconds .* peaking at -inf dB\.$/
  end

  @tag :engine
  test "with another part soloed in a session, a part is not heard, and the levels name both parts",
       ctx do
    {session, _path, _song, out} = lead_and_silent_bass(ctx)

    assert Mx.Session.solo(session, ["bass"]) == :ok
    assert Mx.Session.solo(session, [:bass, :nope]) == {:error, "the song has no part named nope"}
    Process.sleep(2000)
    :ok = Mx.Engine.Mxs.levels(self())
    assert_receive {:mx_levels, %{peak: {+0.0, +0.0}, parts: parts}}, 500
    assert %{"bass" => %{peak: {+0.0, +0.0}}, "lead" => %{peak: {+0.0, +0.0}}} = parts
    assert map_size(parts) == 2
    Process.sleep(500)
    Supervisor.stop(session)

    assert [line] = Mx.Recording.report(out)
    assert line =~ ~r/peaking at -inf dB\.$/
  end

  # A session that records a song whose lead is heard and whose bass is silent, subscribed to its saves.
  defp lead_and_silent_bass(ctx) do
    path = Path.join(ctx.tmp_dir, "parts.exs")
    out = Path.join(ctx.tmp_dir, "parts.wav")

    song =
      "import Mx\nsong(tempo: 120, music: together([part(:lead, loop(1, fn _, _ -> seq([note(72, 1)]) end), synth: :saw, fx: [echo: [phase: 0.5]]), part(:bass, loop(1, fn _, _ -> seq([note(40, 1, amp: 0)]) end))]))\n"

    File.write!(path, song)
    {:ok, loaded} = Mx.Song.load(path)
    {:ok, session} = Mx.Session.start_link(path: path, song: loaded, record: out)
    {:ok, device} = StringIO.open("")

    for {_id, pid, _type, _modules} <- Supervisor.which_children(session),
        do: Process.group_leader(pid, device)

    Mx.Session.subscribe(session)
    {session, path, song, out}
  end

  defp record(ctx, music, opts \\ []), do: ctx |> record_to(music, opts) |> elem(0)

  defp record_to(ctx, music, opts \\ []) do
    song_path = Path.join(ctx.tmp_dir, "level.exs")
    out = Path.join(ctx.tmp_dir, "level.wav")
    part_opts = Enum.map_join(opts, fn {key, value} -> ", #{key}: #{inspect(value)}" end)

    File.write!(
      song_path,
      "import Mx\nsong(music: part(:a, loop(8, fn _, _ -> #{music} end)#{part_opts}))\n"
    )

    {:ok, song} = Mx.Song.load(song_path)
    {:ok, session} = Mx.Session.start_link(path: song_path, song: song, record: out)
    Process.sleep(2500)
    Supervisor.stop(session)
    {Mx.Recording.report(out), out}
  end

  # The seconds into a recording of its first sample above a thousandth of full scale.
  defp sound_start(path) do
    {:ok, %{samples: samples, rate: rate}} = Mx.Audio.read(path)
    Enum.find_index(samples, &(abs(&1) > 0.001)) / rate
  end
end
