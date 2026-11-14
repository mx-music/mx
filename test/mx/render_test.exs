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
        part(:lead, repeat(seq(a4: 0.5, c5: 0.5, e5: 1), 4), synth: :fm, fx: [reverb: [room: 0.7]]),
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
    assert {:ok, _} = render(path, out, seconds: 30)
    seconds = Recording.seconds(out)
    assert seconds >= 30 and seconds <= 34
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

  test "the README describes --render" do
    assert File.read!("README.md") =~ "mix mx.play song.exs --render song.wav"
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
end
