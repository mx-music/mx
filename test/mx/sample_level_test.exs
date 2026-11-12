defmodule Mx.SampleLevelTest do
  # Renders drive the application's own clock and engine.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Song

  @moduletag :tmp_dir

  # A 32-bit float WAV at 48 kHz of `frames`, each a list of one value per channel.
  defp wav(path, frames) do
    channels = length(hd(frames))
    data = for frame <- frames, x <- frame, into: <<>>, do: <<x::little-float-32>>
    size = byte_size(data)

    File.write!(
      path,
      "RIFF" <>
        <<36 + size::little-32>> <>
        "WAVEfmt " <>
        <<16::little-32, 3::little-16, channels::little-16, 48_000::little-32,
          48_000 * 4 * channels::little-32, 4 * channels::little-16, 32::little-16>> <>
        "data" <> <<size::little-32>> <> data
    )

    path
  end

  # Half a second of a 440 Hz sine at `level`, in `channels`.
  defp tone(path, level, channels \\ 2) do
    frames =
      for i <- 0..23_999,
          do: List.duplicate(level * :math.sin(2 * :math.pi() * 440 * i / 48_000), channels)

    wav(path, frames)
  end

  defp song(dir, body) do
    path = Path.join(dir, "song.exs")
    File.write!(path, "import Mx\nsong(tempo: 60, music: part(:s, #{body}))\n")
    path
  end

  # The peak of a song's render in dB below full scale, or :silent.
  defp rendered_peak(path) do
    out = Path.join(Path.dirname(path), "out.wav")
    File.rm(out)

    capture_io(:stderr, fn ->
      capture_io(fn -> assert :ok = Mx.Render.render(path, out, []) end)
    end)

    case Mx.Recording.level(out).peak do
      nil -> :silent
      peak -> peak
    end
  end

  defp load_warnings(path), do: capture_io(:stderr, fn -> assert {:ok, _} = Song.load(path) end)

  test "normalize raises a sample so its loudest moment reaches full scale, before amp", %{
    tmp_dir: dir
  } do
    quiet = tone(Path.join(dir, "quiet.wav"), 0.005)

    assert_in_delta rendered_peak(song(dir, "sample(#{inspect(quiet)}, 1, normalize: true)")),
                    0,
                    0.1

    assert_in_delta rendered_peak(
                      song(dir, "sample(#{inspect(quiet)}, 1, normalize: true, amp: 0.5)")
                    ),
                    -6.02,
                    0.1
  end

  test "a mono file normalized reaches full scale in both channels at the centre", %{tmp_dir: dir} do
    mono = tone(Path.join(dir, "mono.wav"), 0.3, 1)

    assert_in_delta rendered_peak(
                      song(dir, "sample(#{inspect(mono)}, 1, normalize: true, amp: 0.5)")
                    ),
                    -6.02,
                    0.1
  end

  test "a cut is scaled by the loudest moment of the whole file", %{tmp_dir: dir} do
    frames =
      for i <- 0..47_999,
          do:
            [if(i < 24_000, do: 0.1, else: 0.5) * :math.sin(2 * :math.pi() * 440 * i / 48_000)]
            |> then(&(&1 ++ &1))

    path = wav(Path.join(dir, "steps.wav"), frames)

    assert_in_delta rendered_peak(
                      song(
                        dir,
                        "sample(#{inspect(path)}, 1, from: 0.0, to: 0.5, normalize: true)"
                      )
                    ),
                    -13.98,
                    0.1
  end

  test "a sample more than 40 dB below full scale, played without normalize, is named once when the song loads",
       %{tmp_dir: dir} do
    quiet = tone(Path.join(dir, "quiet.wav"), 0.005)

    assert load_warnings(
             song(dir, "seq([sample(#{inspect(quiet)}, 1), sample(#{inspect(quiet)}, 1)])")
           ) ==
             "sample #{quiet} peaks 46.0 dB below full scale; normalize: true plays it at full scale\n"

    assert load_warnings(song(dir, "sample(#{inspect(quiet)}, 1, normalize: true)")) == ""
  end

  test "a sample 21 dB below full scale is not named", %{tmp_dir: dir} do
    tone = tone(Path.join(dir, "tone.wav"), 0.0891)
    assert load_warnings(song(dir, "sample(#{inspect(tone)}, 1)")) == ""
  end

  test "a silent file plays silence, normalized or not, and is named as silent", %{tmp_dir: dir} do
    silence = wav(Path.join(dir, "silence.wav"), List.duplicate([0.0, 0.0], 4800))
    path = song(dir, "sample(#{inspect(silence)}, 1, normalize: true)")
    assert load_warnings(path) == "sample #{silence} is silent\n"
    assert rendered_peak(path) == :silent
  end

  test "a sample without normalize plays at its own level", %{tmp_dir: dir} do
    tone = tone(Path.join(dir, "tone.wav"), 0.5)
    assert_in_delta rendered_peak(song(dir, "sample(#{inspect(tone)}, 1)")), -6.02, 0.01
  end

  test "mix mx.print shows normalize as written", %{tmp_dir: dir} do
    tone = tone(Path.join(dir, "tone.wav"), 0.5)
    path = song(dir, "sample(#{inspect(tone)}, 1, normalize: true)")

    assert capture_io(fn -> Mix.Tasks.Mx.Print.run([path]) end) =~
             "sample #{tone} normalize: true\n"
  end

  test "the README describes normalize" do
    assert File.read!("README.md") =~ "`normalize: true`"
  end

  # Versilian Studios' Versilian Community Sample Library, from https://github.com/sgossner/VCSL, in the folder MX_VCSL names.
  describe "VCSL" do
    @describetag :vcsl

    setup do
      {:ok, vcsl: System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")}
    end

    test "the ocean drum normalized peaks at full scale, and without normalize is named 41 dB below it",
         %{
           tmp_dir: dir,
           vcsl: vcsl
         } do
      drum =
        Path.join(vcsl, "Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_1_Mid.wav")

      assert_in_delta rendered_peak(
                        song(dir, "sample(#{inspect(drum)}, 40, normalize: true, amp: 1)")
                      ),
                      0,
                      0.1

      warning = load_warnings(song(dir, "sample(#{inspect(drum)}, 40)"))
      assert warning =~ "OceanDrum_Sus_1_Mid.wav peaks 41.0 dB below full scale"
    end

    test "the mbira's E3 key, 21 dB below full scale, is not named", %{tmp_dir: dir, vcsl: vcsl} do
      e3 =
        Path.join(
          vcsl,
          "Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B/MBira4_pluck_Main_E3_9_50_100_rr4.wav"
        )

      assert load_warnings(song(dir, "sample(#{inspect(e3)}, 4)")) == ""
    end
  end

  # NASA's recording of the Apollo 11 landing, from https://nssdc.gsfc.nasa.gov/planetary/lunar/a11landing.aiff, in the folder MX_NASA names.
  describe "AIFF" do
    @describetag :nasa

    setup do
      {:ok,
       nasa: System.get_env("MX_NASA") || flunk("set MX_NASA to the folder of a11landing.aiff")}
    end

    test "the Apollo 11 landing normalized at amp 0.5 peaks 6 dB below full scale", %{
      tmp_dir: dir,
      nasa: nasa
    } do
      landing = Path.join(nasa, "a11landing.aiff")

      assert_in_delta rendered_peak(
                        song(dir, "sample(#{inspect(landing)}, 4, normalize: true, amp: 0.5)")
                      ),
                      -6.02,
                      0.1
    end
  end
end
