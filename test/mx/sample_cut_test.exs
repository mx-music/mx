defmodule Mx.SampleCutTest do
  # Some tests render, and a render drives the application's own clock and engine.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs.Native
  alias Mx.{Pass, Samples, Song}

  @moduletag :tmp_dir

  @amen 1.753310657596372

  defp write(dir, body, tempo \\ 120) do
    path = Path.join(dir, "song.exs")
    File.write!(path, "import Mx\nsong(tempo: #{tempo}, music: part(:amen,\n#{body}))\n")
    path
  end

  defp load(dir, body, tempo \\ 120), do: dir |> write(body, tempo) |> Song.load()

  # The options the engine plays the song's first sample with.
  defp played(dir, body, tempo \\ 120) do
    {:ok, song} = load(dir, body, tempo)
    {:ok, %{events: [{_, {:sample, _, path}, opts} | _]}} = Pass.events(hd(song.loops), 0)
    Samples.cut(opts, Samples.seconds(path), tempo)
  end

  # How long a song's render sounds, to its last frame that is not silent.
  defp rendered_seconds(dir, body) do
    path = write(dir, body)
    out = Path.join(dir, "out.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, []) end)
    wav = File.read!(out)
    {at, _} = :binary.match(wav, "data")
    data = binary_part(wav, at + 8, byte_size(wav) - at - 8)

    frames =
      for <<left::little-float-32, right::little-float-32 <- data>>,
        do: max(abs(left), abs(right))

    sounding = frames |> Enum.reverse() |> Enum.drop_while(&(&1 < 1.0e-6)) |> length()
    sounding / 48_000
  end

  test "a sample reads its length from its file" do
    assert_in_delta Samples.seconds(Path.join(Samples.dir(), "loop_amen.flac")), @amen, 1.0e-9
  end

  test "beats fits a sample to that many beats at the tempo where it starts", %{tmp_dir: dir} do
    assert Float.round(played(dir, "sample({:sonic_pi, :loop_amen}, 4, beats: 4)")[:rate], 4) ==
             0.8767

    assert_in_delta played(dir, "sample({:sonic_pi, :loop_amen}, 4, beats: 4)", 136.9)[:rate],
                    1,
                    0.001

    assert_in_delta rendered_seconds(dir, "sample({:sonic_pi, :loop_amen}, 4, beats: 4)"), 2, 0.02
  end

  test "slices and slice play one of equal pieces, fitted to its share of beats", %{tmp_dir: dir} do
    opts = played(dir, "sample({:sonic_pi, :loop_amen}, 0.5, slices: 8, slice: 3, beats: 0.5)")
    assert_in_delta opts[:start] * @amen, 0.6575, 0.0001
    assert_in_delta opts[:finish] * @amen, 0.8767, 0.0001
    assert Float.round(opts[:rate], 4) == 0.8767

    assert_in_delta rendered_seconds(
                      dir,
                      "sample({:sonic_pi, :loop_amen}, 0.5, slices: 8, slice: 3, beats: 0.5)"
                    ),
                    0.25,
                    0.02
  end

  test "from and to cut a sample at seconds into its file", %{tmp_dir: dir} do
    opts = played(dir, "sample({:sonic_pi, :loop_amen}, 1, from: 0.5, to: 1.0)")
    assert_in_delta opts[:start] * @amen, 0.5, 1.0e-9
    assert_in_delta opts[:finish] * @amen, 1.0, 1.0e-9
    refute Keyword.has_key?(opts, :rate)

    assert_in_delta rendered_seconds(
                      dir,
                      "sample({:sonic_pi, :loop_amen}, 1, from: 0.5, to: 1.0)"
                    ),
                    0.5,
                    0.02
  end

  test "from and to name seconds of the recording, forwards and backwards", %{tmp_dir: dir} do
    ramp = ramp(Path.join(dir, "ramp.wav"))
    forwards = play(ramp, Samples.cut([from: 0.25, to: 0.5], 1, 120))
    backwards = play(ramp, Samples.cut([from: 0.25, to: 0.5, rate: -1], 1, 120))

    assert_in_delta length(forwards) / 48_000, 0.25, 0.001
    assert_in_delta length(backwards) / 48_000, 0.25, 0.001

    # A quarter and three quarters of the way through, the ramp reads 0.3125 and 0.4375 seconds
    # in.
    assert_in_delta quarters(forwards), 0.3125 / 0.4375, 0.01
    assert_in_delta quarters(backwards), 0.4375 / 0.3125, 0.01
  end

  test "a cut past the file, outside 0 to 1, or given two ways, is refused when the song loads, with its line",
       %{tmp_dir: dir} do
    file = Path.join(dir, "song.exs")

    for {body, message} <- [
          {"sample({:sonic_pi, :loop_amen}, 1, to: 2.0)",
           "sample loop_amen lasts 1.753 seconds, so to: 2.0 is outside it"},
          {"sample({:sonic_pi, :loop_amen}, 1, finish: 1.2)",
           "a sample's finish takes a fraction of the file from 0 to 1, not 1.2"},
          {"sample({:sonic_pi, :loop_amen}, 1, beats: 4, rate: 2)",
           "a sample takes beats or rate, not both"},
          {"sample({:sonic_pi, :loop_amen}, 4, beats: 4, rate: -1)",
           "a sample takes beats or rate, not both"},
          {"sample({:sonic_pi, :loop_amen}, 1, from: 0.5, start: 0.1)",
           "a sample takes start and finish, or from and to, not both"},
          {"sample({:sonic_pi, :loop_amen}, 1, slices: 8, slice: 8)",
           "a sample's slice takes a whole number from 0 to 7, not 8"},
          {"sample({:sonic_pi, :loop_amen}, 1, slice: 2)",
           "a sample takes slices and slice together"}
        ] do
      assert load(dir, body) == {:error, "#{file}:3: #{message}"}
    end
  end

  test "a cut in a loop's pass is refused with its line", %{tmp_dir: dir} do
    {:ok, song} = load(dir, "loop(1, fn _, _ -> sample({:sonic_pi, :loop_amen}, 1, to: 2.0) end)")
    assert {:error, message} = Pass.events(hd(song.loops), 0)

    assert message =~
             "song.exs:3: part amen: sample loop_amen lasts 1.753 seconds, so to: 2.0 is outside it"
  end

  test "mix mx.print shows the options as written and the rate beats works out", %{tmp_dir: dir} do
    path =
      write(
        dir,
        "seq([sample({:sonic_pi, :loop_amen}, 4, beats: 4), sample({:sonic_pi, :loop_amen}, 1, from: 0.5, to: 1.0)])"
      )

    assert capture_io(fn -> Mix.Tasks.Mx.Print.run([path]) end) == """
           amen, 5 beats at 120 bpm
           beat 0  sample loop_amen beats: 4, rate: 0.8767
           beat 4  sample loop_amen from: 0.5, to: 1.0
           """
  end

  test "the notation guide describes from, to, beats, slices and slice" do
    guide = File.read!("documentation/notation.md")

    for option <- ~w(from to beats slices slice) do
      assert guide =~ ~r/`[^`]*\b#{option}\b[^`]*`/
    end
  end

  defp quarters(sound) do
    count = length(sound)
    Enum.at(sound, div(count, 4)) / Enum.at(sound, div(3 * count, 4))
  end

  # A mono 16-bit WAV at 48 kHz rising from 0 to 0.9 over one second.
  defp ramp(path) do
    data =
      for frame <- 0..47_999,
          into: <<>>,
          do: <<round(frame / 48_000 * 0.9 * 32_767)::little-signed-16>>

    size = byte_size(data)

    File.write!(
      path,
      "RIFF" <>
        <<36 + size::little-32>> <>
        "WAVEfmt " <>
        <<16::little-32, 1::little-16, 1::little-16, 48_000::little-32, 96_000::little-32,
          2::little-16, 16::little-16>> <> "data" <> <<size::little-32>> <> data
    )

    path
  end

  # The left channel of a sample played with options from an offline engine, from its first sound
  # to its last.
  defp play(path, opts) do
    {:ok, engine} = Native.start(false, false)
    {:ok, {sample, _channels}} = Native.load_sample(engine, path)
    event = Mx.Engine.Mxs.event({:sample, nil, %{sample: sample, channels: 1}, opts, nil})
    :ok = Native.play(engine, [{0.0, event}])
    {:ok, {left, _right}} = Native.render(engine, 0.5)

    samples = for <<sample::float-32-native <- left>>, do: sample

    samples
    |> Enum.drop_while(&(&1 == 0.0))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == 0.0))
    |> Enum.reverse()
  end
end
