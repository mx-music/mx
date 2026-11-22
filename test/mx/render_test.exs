defmodule Mx.RenderTest do
  # The clock and the engine a render drives are the application's own, so renders run one at a
  # time.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.{Player, Recording, Render}

  @moduletag :tmp_dir

  defp write(dir, name, body) do
    path = Path.join(dir, name)
    File.write!(path, "import Mx\n" <> body)
    path
  end

  defp render(path, out, opts \\ []), do: with_io(fn -> Render.render(path, out, opts) end)

  # The seconds from the first sound of a recording to the start of its last.
  defp clicks(out) do
    {:ok, %{samples: samples, rate: rate}} = Mx.Audio.read(out)
    sounding = for {sample, frame} <- Enum.with_index(samples), abs(sample) > 0.001, do: frame

    starts =
      sounding
      |> Enum.zip([nil] ++ sounding)
      |> Enum.filter(fn {frame, before} -> before == nil or frame - before > 4800 end)
      |> Enum.map(&elem(&1, 0))

    (List.last(starts) - hd(starts)) / rate
  end

  test "a render at a share of 0.5 of the tempo lasts twice as long as at 1, and a share of 5 is refused",
       %{tmp_dir: dir} do
    path =
      write(
        dir,
        "song.exs",
        "song(tempo: 120, music: part(:a, repeat(seq([note(:c4, 0.25, release: 0.05), rest(0.75)]), 8)))\n"
      )

    half = Path.join(dir, "half.wav")
    whole = Path.join(dir, "whole.wav")

    assert {:ok, _} = render(path, whole)
    assert {:ok, _} = render(path, half, share: 0.5)

    assert render(path, Path.join(dir, "five.wav"), share: 5) ==
             {{:error, "a tempo share takes 0.25 to 4, not 5"}, ""}

    # From the first click to the last, seven beats.
    assert_in_delta clicks(half), 7.0, 0.001
    assert_in_delta clicks(whole), 3.5, 0.001
  end

  test "a render leaves out the parts muted and hears only those soloed, and refuses a part the song does not have",
       %{tmp_dir: dir} do
    both =
      write(dir, "both.exs", """
      song(tempo: 120, music: together([
        part(:low, seq(c3: 2, g3: 2), synth: :fm),
        part(:high, seq(e5: 1, g5: 3), synth: :fm)
      ]))
      """)

    low =
      write(
        dir,
        "low.exs",
        "song(tempo: 120, music: part(:low, seq(c3: 2, g3: 2), synth: :fm))\n"
      )

    out = &Path.join(dir, &1)

    assert {:ok, _} = render(low, out.("low.wav"))
    assert {:ok, _} = render(both, out.("soloed.wav"), solo: ["low"])
    assert {:ok, _} = render(both, out.("muted.wav"), mute: ["high"])
    assert File.read!(out.("soloed.wav")) == File.read!(out.("low.wav"))
    assert File.read!(out.("muted.wav")) == File.read!(out.("low.wav"))

    assert {:ok, _} = render(both, out.("silent.wav"), mute: ["low", "high"])
    {:ok, %{samples: samples}} = Mx.Audio.read(out.("silent.wav"))
    assert Enum.all?(samples, &(&1 == 0.0))

    assert render(both, out.("drums.wav"), mute: ["drums"]) ==
             {{:error, "the song has no part named drums"}, ""}

    assert {_opts, [_path]} =
             Player.parse(["both.exs", "--render", "o.wav", "--mute", "low", "--solo", "high"])

    assert with_io(fn -> Player.play(both, mute: ["low"]) end) ==
             {{:error, "--mute and --solo go with --render"}, ""}
  end

  test "writes a song to a stereo WAV file faster than it plays, and reports it", %{tmp_dir: dir} do
    path =
      write(
        dir,
        "song.exs",
        "song(tempo: 120, music: part(:a, seq(c4: 2, e4: 2, g4: 4), synth: :fm))\n"
      )

    out = Path.join(dir, "song.wav")

    {micros, {result, output}} = :timer.tc(fn -> render(path, out) end)

    assert result == :ok
    assert %{channels: 2, rate: 48_000} = Recording.read_wav(out)
    seconds = Recording.seconds(out)
    assert seconds >= 4 and seconds <= 8
    assert micros / 1_000_000 < seconds

    assert output =~
             ~r/^Recorded #{seconds} seconds to #{Regex.escape(out)}, peaking at -?\d+\.\d dB\.$/m
  end

  test "rendering a song twice writes the same file", %{tmp_dir: dir} do
    path =
      write(dir, "song.exs", """
      song(tempo: 140, music: together([
        part(:bass, repeat(seq(a2: 1, e2: 1), 4), synth: :fm, fx: [echo: [phase: 0.75, mix: 0.3]]),
        part(:lead, repeat(seq(a4: 0.5, c5: 0.5, e5: 1), 4), synth: :fm, fx: [reverb: [decay_seconds: 2.3]]),
        part(:pad, repeat(seq(a3: 4), 2), synth: :fm, fx: [ping_pong: [phase: 0.5], reverb: []])
      ]))
      """)

    first = Path.join(dir, "first.wav")
    second = Path.join(dir, "second.wav")
    assert {:ok, _} = render(path, first)
    assert {:ok, _} = render(path, second)
    assert File.read!(first) == File.read!(second)
  end

  test "music that plays until mx stops needs --seconds, and renders that long plus the fade", %{
    tmp_dir: dir
  } do
    path =
      write(dir, "song.exs", """
      verse = part(:a, seq(c4: 2, e4: 2), synth: :fm)
      chorus = part(:a, seq(g4: 2, c5: 2), synth: :fm)
      song(tempo: 120, music: repeat(seq([verse, chorus])))
      """)

    out = Path.join(dir, "song.wav")

    assert {{:error,
             "the song's music plays until mx stops it; give --seconds to say how long to render"},
            ""} =
             render(path, out)

    refute File.exists?(out)
    assert {:ok, output} = render(path, out, seconds: 30)
    seconds = Recording.seconds(out)
    assert seconds >= 30 and seconds <= 34
    assert List.last(progress(output)) == {30.0, 30.0}
  end

  defp progress(output) do
    for [rendered, total] <-
          Regex.scan(~r/^rendered (\d+\.\d) of (\d+\.\d) seconds$/m, output,
            capture: :all_but_first
          ),
        do: {String.to_float(rendered), String.to_float(total)}
  end

  test "rendering choro once through prints its progress about four times a second, rising to 148 of 148, then the report",
       %{tmp_dir: dir} do
    out = Path.join(dir, "choro.wav")

    {micros, {result, output}} =
      :timer.tc(fn -> render("examples/choro.exs", out, seconds: 148) end)

    assert result == :ok
    lines = progress(output)
    rendered = Enum.map(lines, &elem(&1, 0))

    assert List.last(lines) == {148.0, 148.0}
    assert Enum.all?(lines, &(elem(&1, 1) == 148.0))
    assert rendered == Enum.sort(rendered)
    assert_in_delta length(lines), micros / 250_000, micros / 1_000_000 + 2

    assert output =~
             ~r/^rendered 148\.0 of 148\.0 seconds\nthe render ends as the last notes fade, cutting short the reverb of part flute, which rings 1\.3 seconds on; --ring-out keeps it\nRecorded \d+\.\d seconds to /m
  end

  test "a song that ends renders as many seconds as its music, at its share of the tempo",
       %{tmp_dir: dir} do
    path =
      write(
        dir,
        "song.exs",
        "song(tempo: 120, music: part(:a, seq(c4: 2, e4: 2, g4: 4), synth: :fm))\n"
      )

    {:ok, output} = render(path, Path.join(dir, "whole.wav"))
    assert progress(output) == [{4.0, 4.0}]

    {:ok, output} = render(path, Path.join(dir, "half.wav"), share: 0.5)
    assert progress(output) == [{8.0, 8.0}]

    {:ok, output} = render(path, Path.join(dir, "short.wav"), seconds: 1.5)
    assert progress(output) == [{1.5, 1.5}]
  end

  test "a render with the ring out left out ends where the music ends, and one that keeps it rings on",
       %{tmp_dir: dir} do
    path =
      write(dir, "song.exs", """
      song(tempo: 120, music: part(:a, seq(c4: 2, e4: 2, g4: 4), synth: :fm, fx: [reverb: [decay_seconds: 5.5]]))
      """)

    left_out = Path.join(dir, "left_out.wav")
    {:ok, _output} = render(path, left_out, ring_out: false)
    assert_in_delta Recording.seconds(left_out), 4.0, 0.001

    as_ever = Path.join(dir, "as_ever.wav")
    {:ok, output} = render(path, as_ever)
    assert Recording.seconds(as_ever) > 4.25

    assert output =~
             "the render ends as the last notes fade, cutting short the reverb of part a, which rings 5.5 seconds on; --ring-out keeps it\n"

    kept = Path.join(dir, "kept.wav")
    {:ok, output} = render(path, kept, ring_out: true)
    assert_in_delta Recording.seconds(kept), Recording.seconds(as_ever) + 5.5, 0.011
    refute output =~ "cutting short"

    assert {{:error, "--ring-out takes true or false, not 1"}, ""} =
             render(path, Path.join(dir, "bad.wav"), ring_out: 1)

    {opts, [^path]} = Player.parse([path, "--render", left_out, "--no-ring-out", "--force"])
    {:ok, _output} = with_io(fn -> Player.play(path, opts) end)
    assert_in_delta Recording.seconds(left_out), 4.0, 0.001

    assert Player.play(path, ring_out: false) == {:error, "--ring-out goes with --render"}
  end

  test "says how long choro's effects ring once its notes have faded, and which part's effect rings longest" do
    {:ok, song} = Mx.Song.load("examples/choro.exs")

    assert Render.ring_out(song, seconds: 148) ==
             {:ok, %{seconds: 1.3, part: :flute, effect: :reverb}}
  end

  test "an echo given in beats rings for those beats at the tempo the music ends at, and a song with no effects rings for none",
       %{tmp_dir: dir} do
    path =
      write(dir, "song.exs", """
      song(tempo: 120, music: part(:a, seq(c4: 4), synth: :fm, fx: [echo: [decay: 4]]))
      """)

    {:ok, song} = Mx.Song.load(path)
    assert Render.ring_out(song) == {:ok, %{seconds: 2.0, part: :a, effect: :echo}}
    assert Render.ring_out(song, share: 0.5) == {:ok, %{seconds: 4.0, part: :a, effect: :echo}}

    path = write(dir, "dry.exs", "song(tempo: 120, music: part(:a, seq(c4: 4), synth: :fm))\n")
    {:ok, song} = Mx.Song.load(path)
    assert Render.ring_out(song) == {:ok, nil}
  end

  test "a file that exists is refused unless forced", %{tmp_dir: dir} do
    path = write(dir, "song.exs", "song(tempo: 120, music: part(:a, seq(c4: 1), synth: :fm))\n")
    out = Path.join(dir, "song.wav")
    File.write!(out, "keep")

    assert {{:error, "#{out} already exists; give --force to record over it"}, ""} ==
             render(path, out)

    assert File.read!(out) == "keep"
    assert {:ok, _} = render(path, out, force: true)
    assert %{channels: 2} = Recording.read_wav(out)
  end

  test "--render with --record is refused", %{tmp_dir: dir} do
    path = write(dir, "song.exs", "song(tempo: 120, music: part(:a, seq(c4: 1), synth: :fm))\n")
    out = Path.join(dir, "song.wav")

    assert Player.play(path, render: out, record: Path.join(dir, "session.wav")) ==
             {:error,
              "--render and --record cannot go together: a render writes its file without playing"}

    refute File.exists?(out)
  end

  test "a song with live_audio is refused", %{tmp_dir: dir} do
    path =
      write(
        dir,
        "song.exs",
        "song(tempo: 120, live_audio: [mic: []], music: part(:a, seq(c4: 1), synth: :fm))\n"
      )

    out = Path.join(dir, "song.wav")

    assert {{:error, "a song with live_audio cannot render, as it plays the sound card's input"},
            ""} =
             render(path, out)

    refute File.exists?(out)
  end

  test "a part that sends MIDI is named once and the other parts play", %{tmp_dir: dir} do
    path =
      write(dir, "song.exs", """
      song(tempo: 120, music: together([
        part(:keys, seq([midi(60, 1), midi(64, 1), midi(67, 2)])),
        part(:lead, seq(c4: 2, e4: 2), synth: :fm)
      ]))
      """)

    out = Path.join(dir, "song.wav")
    assert {:ok, output} = render(path, out)

    assert output
           |> String.split("\n")
           |> Enum.count(&(&1 == "part keys sends MIDI, which a render leaves out")) == 1

    assert %{peak: peak} = Recording.level(out)
    assert peak > -40
  end

  test "a part that waits for input is named and plays nothing", %{tmp_dir: dir} do
    path =
      write(dir, "song.exs", """
      song(tempo: 120, music: together([
        part(:pads, loop(fn _trigger, _inputs -> seq(c3: 1) end, on: :midi_note), synth: :fm),
        part(:lead, seq(c4: 2), synth: :fm)
      ]))
      """)

    out = Path.join(dir, "song.wav")
    assert {:ok, output} = render(path, out)

    assert output =~
             "part pads waits for MIDI or OSC input, which a render does not have, so it plays nothing\n"
  end

  test "the README names --render, and the playing guide describes it" do
    assert File.read!("README.md") =~ "`--render song.wav`"

    assert File.read!("documentation/playing.md") =~ "mx play song.exs --render song.wav"
  end

  @tag :timing
  @tag timeout: 600_000
  test "a render of dubwise holds what a recording of it holds", %{tmp_dir: dir} do
    samples = Application.get_env(:mx, :samples_dir)
    Application.put_env(:mx, :samples_dir, Mx.Samples.default_dir())
    on_exit(fn -> Application.put_env(:mx, :samples_dir, samples) end)
    recorded = Path.join(dir, "recorded.wav")
    rendered = Path.join(dir, "rendered.wav")

    # The song ends by itself, so Enter is never pressed: what the player prints is taken, and its
    # wait for a line is never answered.
    silent = spawn(&quiet/0)
    leader = Process.group_leader()
    Process.group_leader(self(), silent)

    try do
      :ok = Player.play("examples/dubwise.exs", record: recorded)
    after
      Process.group_leader(self(), leader)
    end

    assert {:ok, _} = render("examples/dubwise.exs", rendered)

    # A recording starts as the engine does, before the song has loaded its samples, so both are
    # compared from their first sound.
    assert_in_delta seconds(recorded), seconds(rendered), 0.25

    for {recorded_level, rendered_level} <- Enum.zip(levels(recorded), levels(rendered)),
        recorded_level > -60 or rendered_level > -60 do
      assert_in_delta recorded_level, rendered_level, 1
    end
  end

  defp quiet do
    receive do
      {:io_request, from, ref, {:put_chars, _, _}} -> send(from, {:io_reply, ref, :ok})
      {:io_request, from, ref, {:put_chars, _, _, _, _}} -> send(from, {:io_reply, ref, :ok})
      _ -> :ok
    end

    quiet()
  end

  # The seconds of a 32-bit float WAV file from its first sound on.
  defp seconds(path) do
    {samples, second} = sounding(path)
    length(samples) / second
  end

  # The level of each second of a 32-bit float WAV file in dB, from its first sound on.
  defp levels(path) do
    {samples, second} = sounding(path)

    for chunk <- Enum.chunk_every(samples, second, second, :discard) do
      mean = Enum.sum(Enum.map(chunk, &(&1 * &1))) / second
      10 * :math.log10(max(mean, 1.0e-12))
    end
  end

  # The samples from the first sound on, and how many make a second; a recording is at the sound
  # card's rate, a render at 48 kHz.
  defp sounding(path) do
    %{channels: channels, rate: rate} = Recording.read_wav(path)
    wav = File.read!(path)
    {at, _} = :binary.match(wav, "data")
    data = binary_part(wav, at + 8, byte_size(wav) - at - 8)
    samples = for <<x::little-float-32 <- data>>, do: x
    {Enum.drop_while(samples, &(abs(&1) < 1.0e-4)), rate * channels}
  end

  test "a render sends the same messages, in its own time", %{tmp_dir: dir} do
    path = Path.join(dir, "moving.exs")

    music =
      "part(:a, seq([note(60, 2), tempo(60, over: 4), note(62, 4), tempo(90), note(64, 2)]))"

    File.write!(path, "import Mx\nsong(tempo: 120, music: #{music})\n")
    out = Path.join(dir, "moving.wav")

    capture_io(fn -> assert :ok = Mx.Render.render(path, out, follow: self()) end)

    assert_received {:mx_beat, %{beat: 0, tempo: 120, heard_us: 0}}
    assert_received {:mx_beat, %{beat: 2, tempo: {:ramp, 120, 60, 4}, heard_us: 1_000_000}}
    assert_received {:mx_beat, %{beat: 6, tempo: 90, heard_us: six}}
    assert six == 1_000_000 + round(4 * :math.log(2) * 1_000_000)
    assert_received {:mx_beat, :stopped}
    refute_received {:mx_beat, _}
  end
end
