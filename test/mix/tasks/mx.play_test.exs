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
  # fm with no depth is a sine at 0.6, and a centred pan sends amp / √2 to each channel, so amp 0.5 peaks at -13.5 dB.
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
    <<"RIFF", _::32, "WAVE", chunks::binary>> = File.read!(path)
    [_, data] = :binary.split(chunks, "data")
    <<_size::32, samples::binary>> = data
    frames = for <<left::little-signed-24, _right::little-signed-24 <- samples>>, do: left
    Enum.find_index(frames, &(abs(&1) > 8388)) / 48_000
  end
end
