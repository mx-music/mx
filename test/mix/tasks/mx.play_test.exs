defmodule Mix.Tasks.Mx.PlayTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Play
  alias Mx.Engine.Mxs

  # At -80 dB the notes are not heard, but a recording holds them.
  @song "import Mx\nsong(tempo: 240, music: part(:a, loop(1, fn _, _ -> seq([note(72, 0, amp: 0.0001, release: 0.05), rest(1)]) end)))\n"

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
    :ok = Mxs.levels(self())
    assert_receive {:mx_levels, %{peak: {+0.0, +0.0}, parts: parts}}, 500
    assert %{"bass" => %{peak: {+0.0, +0.0}}, "lead" => %{peak: {+0.0, +0.0}}} = parts
    assert map_size(parts) == 2
    Process.sleep(500)
    Supervisor.stop(session)

    assert [line] = Mx.Recording.report(out)
    assert line =~ ~r/peaking at -inf dB\.$/
  end

  @tag :engine
  test "a song plays on, every note at its beat, while mx is held up for less than the two beats the engine holds",
       ctx do
    path = Path.join(ctx.tmp_dir, "held.exs")
    out = Path.join(ctx.tmp_dir, "held.wav")

    # At -80 dB the notes are not heard, but the recording holds them.
    File.write!(
      path,
      "import Mx\nsong(tempo: 60, music: part(:a, loop(4, fn _, _ -> seq(for _ <- 1..4, do: seq([note(72, 0.25, amp: 0.0001, release: 0.05), rest(0.75)])) end), synth: :saw))\n"
    )

    {:ok, song} = Mx.Song.load(path)
    {:ok, session} = Mx.Session.start_link(path: path, song: song, record: out)
    [{0, start_us, 60}] = Mx.Band.timeline(Mx.Band)

    # The pass from beat 8 is handed over at beat 6, and mx is held up from beat 6.5 to beat 8.3.
    Process.sleep(div(start_us + 6_500_000 - System.os_time(:microsecond), 1000))
    held = [Mx.Band | Mx.Band.loops(Mx.Band)]
    Enum.each(held, &:sys.suspend/1)
    Process.sleep(1800)
    Enum.each(held, &:sys.resume/1)
    Process.sleep(2500)
    Supervisor.stop(session)

    {:ok, %{samples: samples, rate: rate}} = Mx.Audio.read(out)
    [first | _] = starts = note_starts(samples)
    beats = Enum.map(starts, &((&1 - first) / rate))

    assert length(beats) == 11

    for {beat, at} <- Enum.with_index(beats) do
      assert_in_delta beat, at, 2 / rate
    end
  end

  @tag :engine
  test "a share of 0.5 set by hand puts the clicks a second apart within 200 ms, and two parts stay together",
       ctx do
    path = Path.join(ctx.tmp_dir, "share.exs")
    out = Path.join(ctx.tmp_dir, "share.wav")
    click = "seq([note(72, 0.25, amp: 0.0001, release: 0.05, pan: PAN), rest(0.75)])"
    left = String.replace(click, "PAN", "-1")
    right = String.replace(click, "PAN", "1")

    # At -80 dB the clicks are not heard, but the recording holds them.
    File.write!(
      path,
      "import Mx\nsong(tempo: 120, music: together([part(:left, loop(1, fn _, _ -> #{left} end), synth: :saw), part(:right, loop(1, fn _, _ -> #{right} end), synth: :saw)]))\n"
    )

    {:ok, song} = Mx.Song.load(path)
    {:ok, session} = Mx.Session.start_link(path: path, song: song, record: out)
    Process.sleep(2200)
    asked_us = System.os_time(:microsecond)
    assert Mx.Session.scale_tempo(session, 0.5) == :ok
    [{_beat, changed_us, 60.0} | _] = Mx.Band.timeline(Mx.Band)
    [{0, start_us, 120} | _] = Enum.reverse(Mx.Band.timeline(Mx.Band))
    Process.sleep(4500)
    Supervisor.stop(session)

    assert changed_us - asked_us < 200_000
    {:ok, %{rate: rate, channels: 2, bits: 32}, data} = Mx.Audio.raw(out)
    lefts = note_starts(for <<l::float-32-little, _r::float-32-little <- data>>, do: l)
    rights = note_starts(for <<_l::float-32-little, r::float-32-little <- data>>, do: r)

    assert length(lefts) == length(rights)
    for {left, right} <- Enum.zip(lefts, rights), do: assert(abs(left - right) <= 1)

    # Beat 0 is the first click, so the change falls this far into the recording.
    changed = hd(lefts) + (changed_us - start_us) * rate / 1_000_000
    after_change = Enum.filter(lefts, &(&1 > changed))
    assert length(after_change) >= 4

    for {earlier, later} <- Enum.zip(after_change, tl(after_change)),
        do: assert_in_delta(later - earlier, rate, 2)
  end

  # The frames of a recording at which a sound starts after a tenth of a second of silence.
  defp note_starts(samples) do
    sounding =
      for {sample, frame} <- Enum.with_index(samples), abs(sample) > 1.0e-6, do: frame

    sounding
    |> Enum.zip([nil] ++ sounding)
    |> Enum.filter(fn {frame, before} -> before == nil or frame - before > 4800 end)
    |> Enum.map(&elem(&1, 0))
  end

  # A session that records a song whose lead is heard and whose bass is silent, subscribed to its
  # saves.
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

    # Rendered rather than played, so a level test is not heard.
    capture_io(fn -> assert Mx.Render.render(song_path, out, seconds: 2.5) == :ok end)
    {Mx.Recording.report(out), out}
  end

  # The seconds into a recording of its first sample above a thousandth of full scale.
  defp sound_start(path) do
    {:ok, %{samples: samples, rate: rate}} = Mx.Audio.read(path)
    Enum.find_index(samples, &(abs(&1) > 0.001)) / rate
  end

  @tag :engine
  test "a session plays a recording on a part through its echo, stops it, refuses a part, a range or a file that cannot play, and leaves the file as it is",
       ctx do
    path = Path.join(ctx.tmp_dir, "echoes.exs")
    out = Path.join(ctx.tmp_dir, "echoes.wav")
    burst = Path.join(ctx.tmp_dir, "burst.wav")
    step = "examples/tranquility_base/a11step.aiff"

    song =
      "import Mx\nsong(tempo: 120, music: part(:voice, loop(4, fn _, _ -> rest(4) end), fx: [echo: [phase: 1, decay: 8, mix: 1]]))\n"

    File.write!(path, song)
    samples = for sample <- 0..959, do: :math.sin(sample / 3)
    write_wav(burst, samples)
    {:ok, loaded} = Mx.Song.load(path)
    {:ok, session} = Mx.Session.start_link(path: path, song: loaded, record: out)
    {:ok, device} = StringIO.open("")

    for {_id, pid, _type, _modules} <- Supervisor.which_children(session),
        do: Process.group_leader(pid, device)

    Process.sleep(500)

    # At -74 dB the burst and its echoes are not heard, but the recording holds them.
    asked_us = System.os_time(:microsecond)
    assert {:ok, beat} = Mx.Session.play_recording(session, :voice, burst, amp: 0.0002)
    [{0, start_us, 120}] = Mx.Band.timeline(Mx.Band)
    assert start_us + beat * 500_000 - asked_us < 2_000_000
    Process.sleep(3000)
    assert :ok = Mx.Session.stop_recording(session, :voice)

    assert Mx.Session.play_recording(session, :no_such_part, step, from: 2.447, to: 3.4) ==
             {:error, "the song has no part named no_such_part"}

    assert Mx.Session.play_recording(session, :voice, step, from: 6.0, to: 9.0) ==
             {:error, "sample #{step} lasts 7.155 seconds, so to: 9.0 is outside it"}

    broken = Path.join(ctx.tmp_dir, "broken.wav")
    File.write!(broken, "not a sound")

    assert Mx.Session.play_recording(session, :voice, broken, []) ==
             {:error, "sample file #{broken} cannot play: it is not a FLAC, WAV or AIFF file"}

    Supervisor.stop(session)
    assert File.read!(path) == song

    {:ok, %{samples: samples, rate: rate}} = Mx.Audio.read(out)
    [first | _] = starts = note_starts(samples)
    gaps = Enum.map(starts, &((&1 - first) / rate))
    assert length(gaps) >= 3

    for {gap, repeat} <- Enum.with_index(Enum.take(gaps, 3)) do
      assert_in_delta gap, repeat * 0.5, 0.005
    end
  end

  @tag :engine
  test "a recording plays alone with no song, and stops", ctx do
    burst = Path.join(ctx.tmp_dir, "burst.wav")
    samples = for sample <- 0..959, do: 0.0001 * :math.sin(sample / 3)
    write_wav(burst, samples)
    {:ok, _engine} = Mxs.start_link([])
    assert {:ok, id} = Mxs.play_recording(burst, from: 0.0, to: 0.01)
    assert :ok = Mxs.stop_sounds([id])

    assert Mxs.play_recording(burst, from: 0.0, to: 1.0) ==
             {:error, "sample #{burst} lasts 0.020 seconds, so to: 1.0 is outside it"}

    GenServer.stop(Mxs)
  end

  @tag :engine
  test "an engine plays through the output named, at the rate and buffer size given" do
    name = default_device(true)
    rate = other_rate()
    {:ok, _engine} = Mxs.start_link(devices: [output: name, rate: rate, buffer: 64])
    assert %{device: ^name, rate: output_rate} = Mxs.output(self())
    assert output_rate == rate
    Mxs.buffer_load()
    Process.sleep(1000)
    %{buffers: buffers} = Mxs.buffer_load()
    assert_in_delta buffers, rate / 64, 70
    GenServer.stop(Mxs)
  end

  @tag :engine
  test "an engine refuses an output, a rate or a buffer size the device cannot take, naming what it takes" do
    Process.flag(:trap_exit, true)
    name = default_device(true)

    assert {:error, "no output device named Studio; the outputs are " <> outputs} =
             Mxs.start_link(devices: [output: "Studio"])

    assert outputs =~ name
    assert {:error, message} = Mxs.start_link(devices: [rate: 7])
    assert message =~ ~r/^#{Regex.escape(name)} runs at [0-9, or]+ Hz, not 7$/
    assert {:error, message} = Mxs.start_link(devices: [buffer: 7])
    assert message =~ ~r/^#{Regex.escape(name)} takes buffers of \d+ to \d+ frames, not 7$/
  end

  @tag :engine
  test "--output, --rate and --buffer stop the play before any sound when the device cannot take them",
       ctx do
    assert_raise Mix.Error, ~r/^no output device named Studio; the outputs are /, fn ->
      Play.run([ctx.song, "--output", "Studio"])
    end

    assert_raise Mix.Error, ~r/ runs at .* Hz, not 7$/, fn ->
      Play.run([ctx.song, "--rate", "7"])
    end

    assert_raise Mix.Error, ~r/ takes buffers of \d+ to \d+ frames, not 7$/, fn ->
      Play.run([ctx.song, "--buffer", "7"])
    end
  end

  @tag :engine
  test "the project's config names the output, and --output overrides it", ctx do
    Application.put_env(:mx, :output, "Studio")
    on_exit(fn -> Application.delete_env(:mx, :output) end)

    assert_raise Mix.Error, ~r/^no output device named Studio;/, fn ->
      Play.run([ctx.song])
    end

    assert_raise Mix.Error, ~r/^no output device named Booth;/, fn ->
      Play.run([ctx.song, "--output", "Booth"])
    end
  end

  @tag :engine
  test "--input names the input a song with live audio reads", ctx do
    path = Path.join(ctx.tmp_dir, "live.exs")

    File.write!(
      path,
      "import Mx\nsong(tempo: 60, music: rest(4), live_audio: [mic: [amp: 0.8]])\n"
    )

    assert_raise Mix.Error, ~r/^no input device named Nope; the inputs are /, fn ->
      Play.run([path, "--input", "Nope"])
    end
  end

  @tag :engine
  test "a play recorded at a rate is written at that rate", ctx do
    out = Path.join(ctx.tmp_dir, "rate.wav")
    {:ok, song} = Mx.Song.load(ctx.song)

    rate = other_rate()

    {:ok, session} =
      Mx.Session.start_link(path: ctx.song, song: song, record: out, devices: [rate: rate])

    Process.sleep(500)
    Supervisor.stop(session)
    assert {:ok, %{rate: ^rate}} = Mx.Audio.read(out)
  end

  @tag :engine
  test "a render says --rate and --buffer do not apply to it, and renders at 48000 Hz", ctx do
    out = Path.join(ctx.tmp_dir, "render.wav")

    said =
      capture_io(fn ->
        Play.run([
          ctx.song,
          "--render",
          out,
          "--seconds",
          "1",
          "--rate",
          "44100",
          "--buffer",
          "64"
        ])
      end)

    assert said =~ "--rate and --buffer do not apply to a render, which runs at 48000 Hz\n"
    assert {:ok, %{rate: 48_000}} = Mx.Audio.read(out)
  end

  # A rate the default output takes other than the 48000 Hz a render runs at, 44100 where it can.
  defp other_rate do
    {:ok, devices} = Mxs.Native.devices()
    {_, true, true, _, ranges, _} = Enum.find(devices, &match?({_, true, true, _, _, _}, &1))
    rates = for {low, high} <- ranges, rate <- [low, high], rate != 48_000, do: rate

    if Enum.any?(ranges, fn {low, high} -> low <= 44_100 and 44_100 <= high end) do
      44_100
    else
      Enum.max(rates)
    end
  end

  defp default_device(output?) do
    {:ok, devices} = Mxs.Native.devices()

    {name, ^output?, true, _, _, _} =
      Enum.find(devices, &match?({_, ^output?, true, _, _, _}, &1))

    name
  end

  defp write_wav(path, samples) do
    data = for sample <- samples, into: <<>>, do: <<sample::float-little-32>>

    fmt =
      <<3::little-16, 1::little-16, 48_000::little-32, 192_000::little-32, 4::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
  end
end
