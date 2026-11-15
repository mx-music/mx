defmodule Mix.Tasks.Mx.VideoTest do
  # One test empties the path programs are found on.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Mx.Pictures, only: [frames: 3, pixel: 2]

  alias Mix.Tasks.Mx.Video
  alias Mx.Engine.Mxs.Native

  @moduletag :tmp_dir

  test "without ffmpeg on the path, says so in one line and writes nothing", ctx do
    path = write(ctx, "tone.wav", tone(1, fn _ -> 0.5 end))
    held = System.get_env("PATH")
    System.put_env("PATH", "")

    try do
      message = "a video needs ffmpeg to join the picture and the sound, and it is not installed"
      assert_raise Mix.Error, message, fn -> Video.run([path]) end
    after
      System.put_env("PATH", held)
    end

    assert File.ls!(ctx.tmp_dir) == ["tone.wav"]
  end

  test "warns that a video of 11 MB is over GitHub's limit, and not for one of 9 MB" do
    assert {"Wrote song.mp4, 62.5 seconds and 11.0 MB", warning} =
             Mx.Video.report("song.mp4", 62.5, 11_000_000)

    assert warning =~ "song.mp4 is over the 10 MB GitHub allows"

    assert Mx.Video.report("song.mp4", 62.5, 9_000_000) ==
             {"Wrote song.mp4, 62.5 seconds and 9.0 MB", nil}
  end

  @tag :ffmpeg
  test "over the waveform, every bar is grey in the first frame and amber in the last", ctx do
    path = write(ctx, "tone.wav", tone(2, fn _ -> 0.5 end))

    assert capture_io(fn -> Video.run([path]) end) =~
             ~r/^Wrote #{ctx.tmp_dir}\/tone.mp4, 2.0 seconds and 0.\d MB\n$/

    frames = frames(Path.join(ctx.tmp_dir, "tone.mp4"), 1500, 150)
    assert length(frames) == 60

    bars = fn frame ->
      for left <- 40..1456//3, {_red, green, _blue} = pixel(Enum.at(frame, 75), left) do
        if green > 130, do: :amber, else: :grey
      end
    end

    assert Enum.uniq(bars.(hd(frames))) == [:grey]
    assert Enum.uniq(bars.(List.last(frames))) == [:amber]
    assert Enum.uniq(bars.(Enum.at(frames, 30))) == [:amber, :grey]
  end

  @tag :ffmpeg
  test "over the spectrogram, a white line is at half the width at half the length, and no line marks a second",
       ctx do
    path = write(ctx, "tone.wav", tone(20, fn _ -> 0.5 end))
    capture_io(fn -> Video.run([path, "--picture", "spectrogram"]) end)

    frames = frames(Path.join(ctx.tmp_dir, "tone.mp4"), 1500, 480)
    top = frames |> Enum.at(div(length(frames), 2)) |> Enum.at(10)

    white =
      for left <- 0..1499,
          {red, green, blue} = pixel(top, left),
          min(red, min(green, blue)) > 150,
          do: left

    assert Enum.min(white) in 747..750
    assert Enum.max(white) in 749..752

    first = frames |> hd() |> Enum.at(10)
    for second <- 1..19, do: assert(pixel(first, second * 75) |> Tuple.sum() < 30)
  end

  @tag :ffmpeg
  test "the sound is the recording at one gain, peaking 1.5 dB below full scale", ctx do
    path = write(ctx, "louder.wav", tone(4, fn at -> 0.02 + 0.07 * at end))
    capture_io(fn -> Video.run([path]) end)

    video = Path.join(ctx.tmp_dir, "louder.mp4")
    {sound, 0} = System.cmd("ffmpeg", ~w(-v error -i #{video} -vn -ac 1 -f f32le -))
    {peak, played} = Native.levels(sound, {"float_little", 32, 1}, 40)

    {_peak, recorded} =
      Native.levels(
        File.read!(path) |> binary_part(44, 4 * 4 * 48_000),
        {"float_little", 32, 1},
        40
      )

    assert_in_delta 20 * :math.log10(peak), -1.5, 0.5
    gains = Enum.zip_with(played, recorded, &(20 * :math.log10(&1 / &2)))
    assert Enum.max(gains) - Enum.min(gains) < 0.5
    assert_in_delta hd(gains), -1.5 - 20 * :math.log10(0.3), 0.5
  end

  @tag :ffmpeg
  test "refuses to write over a file that exists, and writes over it with --force", ctx do
    path = write(ctx, "tone.wav", tone(1, fn _ -> 0.5 end))
    out = Path.join(ctx.tmp_dir, "tone.mp4")
    File.write!(out, "kept")

    assert_raise Mix.Error, "#{out} exists; give --force to write over it", fn ->
      Video.run([path])
    end

    assert File.read!(out) == "kept"
    capture_io(fn -> Video.run([path, "--force"]) end)
    assert byte_size(File.read!(out)) > 1000
  end

  defp tone(seconds, level) do
    for index <- 0..(seconds * 48_000 - 1) do
      at = index / 48_000
      level.(at) * :math.sin(2 * :math.pi() * 440 * at)
    end
  end

  defp write(ctx, name, samples) do
    path = Path.join(ctx.tmp_dir, name)
    Mx.Audio.write(path, samples, 48_000)
    path
  end
end
