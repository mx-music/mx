defmodule Mx.LoudnessTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  alias Mx.Loudness

  @moduletag :tmp_dir
  @rate 48_000

  # A stereo WAV of 32-bit floats: on each side a sine of the Hz and peak in dB given, for the seconds given.
  defp sine(ctx, name, seconds, sides) do
    frames = round(seconds * @rate)

    data =
      for frame <- 0..(frames - 1)//1, {hz, db} <- sides, into: <<>> do
        level = if db, do: :math.pow(10, db / 20), else: 0.0
        <<level * :math.sin(2 * :math.pi() * hz * frame / @rate)::little-float-32>>
      end

    fmt =
      <<3::little-16, 2::little-16, @rate::little-32, @rate * 8::little-32, 8::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    path = Path.join(ctx.tmp_dir, name)
    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
    path
  end

  # A song of one sine near 1000 Hz for 10 seconds that peaks at the dB given on both sides.
  defp song(ctx, db, seconds \\ 10) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    amp = :math.pow(10, db / 20) * :math.sqrt(2) / 0.6

    part =
      "part(:a, note(83.2, #{seconds}, amp: #{amp}, depth: 0, attack: 0, release: 0), synth: :fm)"

    File.write!(path, "import Mx\nsong(tempo: 60, music: #{part})\n")
    path
  end

  defp render(ctx, song, opts) do
    out = Path.join(ctx.tmp_dir, "song.wav")
    opts = [force: true, ring_out: false] ++ opts
    output = capture_io(fn -> send(self(), {:result, Mx.Render.render(song, out, opts)}) end)
    assert_received {:result, result}
    {result, output, out}
  end

  test "a 1000 Hz sine at -20 dB on both sides measures -20 LUFS, and on one side 3 dB less",
       ctx do
    assert_in_delta Loudness.measure(sine(ctx, "both.wav", 10, [{1000, -20}, {1000, -20}])),
                    -20,
                    0.1

    assert_in_delta Loudness.measure(sine(ctx, "one.wav", 10, [{1000, -20}, {1000, nil}])),
                    -23,
                    0.1

    assert_in_delta Loudness.measure(sine(ctx, "full.wav", 5, [{997, 0}, {997, 0}])), 0, 0.1
  end

  # Beside 1000 Hz, the two filters of BS.1770 pass 100 Hz 1.9 dB lower and 10 kHz 3.3 dB higher.
  test "the lows count for less and the highs for more, as the weighting of BS.1770 has them",
       ctx do
    assert_in_delta Loudness.measure(sine(ctx, "low.wav", 5, [{100, -20}, {100, -20}])),
                    -21.8,
                    0.3

    assert_in_delta Loudness.measure(sine(ctx, "high.wav", 5, [{10_000, -20}, {10_000, -20}])),
                    -16.7,
                    0.3
  end

  test "a long silence beside the music does not lower its loudness", ctx do
    loud = sine(ctx, "loud.wav", 5, [{1000, -20}, {1000, -20}])
    frames = 5 * @rate * 8
    <<head::binary-size(44), data::binary>> = File.read!(loud)
    gap = Path.join(ctx.tmp_dir, "gap.wav")

    body =
      binary_part(head, 8, 32) <>
        <<byte_size(data) + frames::little-32>> <> data <> <<0::size(frames * 8)>>

    File.write!(gap, "RIFF" <> <<byte_size(body)::little-32>> <> body)

    # The blocks that hold the music's end are part silence and pass the gates; ungated it would be -23.
    assert_in_delta Loudness.measure(gap), -20, 0.2
  end

  test "a file too short or too quiet has no loudness", ctx do
    assert Loudness.measure(sine(ctx, "short.wav", 0.2, [{1000, -20}, {1000, -20}])) == nil
    assert Loudness.measure(sine(ctx, "quiet.wav", 2, [{1000, -90}, {1000, -90}])) == nil
    assert Loudness.measure(sine(ctx, "silent.wav", 2, [{1000, nil}, {1000, nil}])) == nil
  end

  @tag :engine
  test "a render prints its loudness beside its peak", ctx do
    {:ok, output, out} = render(ctx, song(ctx, -20), [])

    assert [_, peak, loudness] =
             Regex.run(
               ~r/^Recorded 10\.0 seconds to #{Regex.escape(out)}, peaking at (-\d+\.\d) dB, loudness (-\d+\.\d) LUFS\.$/m,
               output
             )

    assert_in_delta String.to_float(peak), -20, 0.2
    assert_in_delta String.to_float(loudness), -20, 0.2
  end

  @tag :engine
  test "a render with loudness: -23 writes a file that measures -23 LUFS, and without it the same samples as before",
       ctx do
    {:ok, _, out} = render(ctx, song(ctx, -20), [])
    plain = File.read!(out)
    {:ok, _, out} = render(ctx, song(ctx, -20), [])
    assert File.read!(out) == plain

    {:ok, output, out} = render(ctx, song(ctx, -20), loudness: -23)
    assert_in_delta Loudness.measure(out), -23, 0.2
    assert output =~ ~r/peaking at -23\.\d dB, loudness -23\.0 LUFS\.$/m
    assert byte_size(File.read!(out)) == byte_size(plain)
    assert %{channels: 2, rate: 48_000} = Mx.Recording.read_wav(out)

    {:ok, output, out} = render(ctx, song(ctx, -20), loudness: -12)
    assert_in_delta Loudness.measure(out), -12, 0.2
    refute output =~ "limiter"
  end

  @tag :engine
  test "a render is raised only as far as a peak of -1 dB, and says what it reached and names the limiter",
       ctx do
    {:ok, output, out} = render(ctx, song(ctx, -7), loudness: -0.5)
    assert_in_delta Mx.Recording.level(out).peak, -1, 0.05
    assert_in_delta Loudness.measure(out), -1, 0.2

    assert output =~
             ~r/^The loudness reached -1\.\d LUFS, not -0\.5: more would push the peak past -1 dB\. A limiter on the song, fx: \[limiter: \[\]\], allows more\.$/m

    assert output =~ ~r/peaking at -1\.0 dB, loudness -1\.\d LUFS\.$/m

    {:ok, output, out} = render(ctx, song(ctx, -1), loudness: 0)
    assert_in_delta Mx.Recording.level(out).peak, -1, 0.05
    assert output =~ ~r/^The loudness reached -1\.\d LUFS, not 0: /m
  end

  test "a loudness that is not a number below 0 or at it is refused", ctx do
    for target <- [3, 0.5, :loud] do
      assert {{:error,
               "--loudness takes the loudness to bring the file to in LUFS, a number at or below 0, such as -14"},
              _, _} =
               render(ctx, song(ctx, -20), loudness: target)
    end
  end

  @tag :engine
  test "a render of 0.2 seconds prints its length and peak with no loudness, with or without a target",
       ctx do
    for opts <- [[], [loudness: -14]] do
      {:ok, output, out} = render(ctx, song(ctx, -20, 0.2), opts)

      assert output =~
               ~r/^Recorded 0\.2 seconds to #{Regex.escape(out)}, peaking at -20\.\d dB\.$/m
    end
  end

  test "mx play takes --loudness with --render only", ctx do
    assert {[render: "out.wav", loudness: -14.0], ["song.exs"]} =
             Mx.Player.parse(["song.exs", "--render", "out.wav", "--loudness", "-14"])

    assert Mx.Player.play(song(ctx, -20), loudness: -14.0) ==
             {:error, "--loudness goes with --render"}
  end
end
