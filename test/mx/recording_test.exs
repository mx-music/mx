defmodule Mx.RecordingTest do
  use ExUnit.Case, async: true

  alias Mx.Recording

  @moduletag :tmp_dir

  test "accepts a new file in a folder that exists", %{tmp_dir: dir} do
    path = Path.join(dir, "out.wav")
    assert Recording.check(path, false) == :ok
    refute File.exists?(path)
  end

  test "refuses an existing file unless forced, naming it", %{tmp_dir: dir} do
    path = Path.join(dir, "out.wav")
    File.write!(path, "keep")

    assert Recording.check(path, false) ==
             {:error, "#{path} already exists; give --force to record over it"}

    assert Recording.check(path, true) == :ok
    assert File.read!(path) == "keep"
  end

  test "refuses a file in a folder that does not exist, naming it", %{tmp_dir: dir} do
    path = Path.join([dir, "missing", "out.wav"])

    assert Recording.check(path, false) ==
             {:error, "cannot record to #{path}: its folder does not exist"}
  end

  test "refuses a file that cannot be written, naming it", %{tmp_dir: dir} do
    locked = Path.join(dir, "locked")
    File.mkdir_p!(locked)
    File.chmod!(locked, 0o500)
    path = Path.join(locked, "out.wav")

    try do
      assert Recording.check(path, false) ==
               {:error, "cannot record to #{path}: permission denied"}
    after
      File.chmod!(locked, 0o700)
    end
  end

  test "reads the length of a WAV file in seconds", %{tmp_dir: dir} do
    path = Path.join(dir, "half.wav")
    File.write!(path, silent_wav(24_000, 48_000))

    assert Recording.read_wav(path) == %{channels: 2, rate: 48_000, frames: 24_000}
    assert Recording.seconds(path) == 0.5
  end

  test "reads the peak of a recording in dB below full scale, and no clips", %{tmp_dir: dir} do
    path = Path.join(dir, "half.wav")
    half = List.duplicate({4_194_304, -2_097_152}, 4800) ++ [{0, 0}]
    File.write!(path, wav(half))

    assert %{peak: peak, clips: 0, first_clip: nil} = Recording.level(path)
    assert_in_delta peak, -6.02, 0.01
  end

  test "counts one clip for a stretch of 100 samples at full scale, with the time it starts", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "clip.wav")
    quiet = List.duplicate({1000, 1000}, 24_000)
    clipped = List.duplicate({1000, 8_388_607}, 100)
    File.write!(path, wav(quiet ++ clipped ++ quiet))

    assert %{peak: peak, clips: 1, first_clip: 0.5} = Recording.level(path)
    assert_in_delta peak, 0, 0.001
  end

  test "counts each stretch at full scale, in either channel and at either end", %{tmp_dir: dir} do
    path = Path.join(dir, "clips.wav")
    quiet = List.duplicate({0, 0}, 480)
    high = List.duplicate({8_388_607, 0}, 10)
    low = List.duplicate({0, -8_388_608}, 10)
    File.write!(path, wav(quiet ++ high ++ quiet ++ low ++ low ++ quiet ++ high))

    assert %{clips: 3, first_clip: 0.01} = Recording.level(path)
  end

  test "a silent recording has no peak and no clips", %{tmp_dir: dir} do
    path = Path.join(dir, "silent.wav")
    File.write!(path, silent_wav(24_000, 48_000))
    assert Recording.level(path) == %{peak: nil, clips: 0, first_clip: nil}
  end

  test "the report gives the length and the peak, and warns of clips", %{tmp_dir: dir} do
    clean = Path.join(dir, "clean.wav")
    half = List.duplicate({4_194_304, 0}, 24_000)
    File.write!(clean, wav(half))
    assert Recording.report(clean) == ["Recorded 0.5 seconds to #{clean}, peaking at -6.0 dB."]

    clipped = Path.join(dir, "clipped.wav")
    quiet = List.duplicate({0, 0}, 4800)
    File.write!(clipped, wav(quiet ++ [{8_388_607, 0}] ++ quiet ++ [{8_388_607, 0}] ++ quiet))

    assert Recording.report(clipped) == [
             "Recorded 0.3 seconds to #{clipped}, peaking at -0.0 dB.",
             "The recording clipped 2 times, first at 0.1 seconds. Lower the amp of the loudest loops to record it cleanly."
           ]

    silent = Path.join(dir, "silent.wav")
    File.write!(silent, silent_wav(24_000, 48_000))
    assert Recording.report(silent) == ["Recorded 0.5 seconds to #{silent}, peaking at -inf dB."]
  end

  test "reads a 32-bit float recording, where a sample beyond full scale clips", %{tmp_dir: dir} do
    clean = Path.join(dir, "float.wav")
    half = List.duplicate({0.5, -0.25}, 24_000)
    File.write!(clean, float_wav(half))
    assert Recording.report(clean) == ["Recorded 0.5 seconds to #{clean}, peaking at -6.0 dB."]

    loud = Path.join(dir, "loud.wav")
    quiet = List.duplicate({0.0, 0.0}, 4800)
    File.write!(loud, float_wav(quiet ++ [{0.0, 1.5}, {1.0, 0.0}] ++ quiet ++ [{-2.0, 0.0}]))

    assert %{peak: peak, clips: 2, first_clip: 0.1} = Recording.level(loud)
    assert_in_delta peak, 0, 0.001
  end

  test "reading the level leaves the recording as it was", %{tmp_dir: dir} do
    path = Path.join(dir, "clip.wav")
    File.write!(path, wav([{8_388_607, -8_388_608}, {0, 0}]))
    before = File.read!(path)
    Recording.report(path)
    assert File.read!(path) == before
  end

  # A stereo 24-bit WAV at 48 kHz from {left, right} frames.
  defp wav(frames) do
    data =
      for {left, right} <- frames,
          into: <<>>,
          do: <<left::little-signed-24, right::little-signed-24>>

    size = byte_size(data)

    "RIFF" <>
      <<36 + size::little-32>> <>
      "WAVEfmt " <>
      <<16::little-32, 1::little-16, 2::little-16, 48_000::little-32, 288_000::little-32,
        6::little-16, 24::little-16>> <> "data" <> <<size::little-32>> <> data
  end

  # A stereo 32-bit float WAV at 48 kHz from {left, right} frames, as mxs writes it.
  defp float_wav(frames) do
    data =
      for {left, right} <- frames,
          into: <<>>,
          do: <<left::little-float-32, right::little-float-32>>

    size = byte_size(data)

    "RIFF" <>
      <<36 + size::little-32>> <>
      "WAVEfmt " <>
      <<16::little-32, 3::little-16, 2::little-16, 48_000::little-32, 384_000::little-32,
        8::little-16, 32::little-16>> <> "data" <> <<size::little-32>> <> data
  end

  defp silent_wav(frames, rate) do
    data = :binary.copy(<<0>>, frames * 6)
    size = byte_size(data)

    "RIFF" <>
      <<36 + size::little-32>> <>
      "WAVEfmt " <>
      <<16::little-32, 1::little-16, 2::little-16, rate::little-32, rate * 6::little-32,
        6::little-16, 24::little-16>> <> "data" <> <<size::little-32>> <> data
  end
end
