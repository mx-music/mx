defmodule Mx.Hum.RecorderTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Mx.{Audio, Voice}
  alias Mx.Engine.Mxs
  alias Mx.Hum.Recorder

  @moduletag :tmp_dir

  describe "recording against a click" do
    @describetag :engine

    test "clicks a bar of 4 beats before beat 0, then every beat, the first of each bar louder",
         ctx do
      clicks = Path.join(ctx.tmp_dir, "clicks.wav")
      record(ctx, [], 6, 120, synth: [record: clicks])

      %{samples: samples, rate: rate} = read!(clicks)
      peaks = peaks(samples, rate)
      times = Enum.map(peaks, &elem(&1, 0))
      levels = Enum.map(peaks, &elem(&1, 1))

      assert length(peaks) >= 10

      for gap <- Enum.zip_with(times, tl(times), &(&2 - &1)) do
        assert_in_delta gap, 0.5, 0.005
      end

      [first, second, third, fourth, fifth | _] = levels
      assert Enum.min([first, fifth]) > Enum.max([second, third, fourth]) * 1.4
    end

    test "places the hum on the click's beats, and leaves the recording and the song", ctx do
      hum = [{:note, 1, 0.9, 64, []}, {:note, 2, 0.9, 67, []}]
      {result, printed} = record(ctx, hum, 4, 90)

      assert result == :ok
      wav = Path.join(ctx.tmp_dir, "hum.wav")
      song = Path.join(ctx.tmp_dir, "hum.exs")
      assert File.read!(song) =~ "seq(r: 1, e4: 1, g4: 1, r: 1)"

      assert printed =~ ~r/^Recorded #{wav}: \d+\.\d seconds\.$/m
      assert printed =~ ~r/^Wrote #{song}: 2 notes, from e4 to g4\.$/m
    end

    test "leaves out a note hummed during the count-in, and says so", ctx do
      hum = [{:note, -2, 0.9, 69, []}, {:note, 0, 0.9, 64, []}]
      {result, printed} = record(ctx, hum, 4, 90)

      assert result == :ok
      assert printed =~ "Left out 1 note hummed during the count-in.\n"
      assert File.read!(Path.join(ctx.tmp_dir, "hum.exs")) =~ "seq(e4: 1, r: 3)"
    end

    test "a click the microphone picks up is not a note", ctx do
      beat = 60 / 120

      bleed =
        Enum.flat_map(0..11, fn _ ->
          Mxs.render_note(:closed_hihat, [vel: 1.0], beat, ctx.tmp_dir, [])
          |> Enum.map(&(&1 * 0.5))
        end)

      source = Path.join(ctx.tmp_dir, "bleed.wav")
      Audio.write(source, bleed, Mxs.render_rate())
      wav = Path.join(ctx.tmp_dir, "hum.wav")

      {result, _} =
        capture(fn ->
          Recorder.record(wav, tempo: 120, source: source, wait: wait(5.5))
        end)

      assert result == {:error, "found no notes in #{wav}"}
      assert File.exists?(wav)
    end

    test "with force, records over a recording and writes over its song", ctx do
      wav = Path.join(ctx.tmp_dir, "hum.wav")
      song = Path.join(ctx.tmp_dir, "hum.exs")
      File.write!(wav, "old")
      File.write!(song, "old")

      {result, _} = record(ctx, [{:note, 0, 0.9, 64, []}], 4, 90, force: true)

      assert result == :ok
      assert {:ok, _} = Audio.read(wav)
      assert File.read!(song) =~ "seq(e4: 1, r: 3)"
    end
  end

  test "refuses a recording or a song that exists before any click", ctx do
    wav = Path.join(ctx.tmp_dir, "hum.wav")
    song = Path.join(ctx.tmp_dir, "hum.exs")
    File.write!(wav, "old")

    assert {{:error, "#{wav} already exists; give --force to record over it"}, ""} ==
             capture(fn -> Recorder.record(wav, tempo: 90) end)

    File.rm!(wav)
    File.write!(song, "old")

    assert {{:error, "#{song} already exists; give --force to write over it"}, ""} ==
             capture(fn -> Recorder.record(wav, tempo: 90) end)
  end

  test "refuses a folder that does not exist before any click" do
    assert {{:error, "cannot record to /missing/hum.wav: its folder does not exist"}, ""} ==
             capture(fn -> Recorder.record("/missing/hum.wav", tempo: 90) end)
  end

  # Plays a hum given in beats from beat 0 in place of the input, and records it for the count-in and some beats more.
  defp record(ctx, hum, beats, tempo, opts \\ []) do
    beat = 60 / tempo
    seconds = (4 + beats) * beat

    events =
      for {:note, at, held, note, note_opts} <- hum,
          do: {:note, (4 + at) * beat, held * beat, note, note_opts}

    source = Path.join(ctx.tmp_dir, "source.wav")
    Audio.write(source, Voice.render(events, seconds, 48_000), 48_000)
    wav = Path.join(ctx.tmp_dir, "hum.wav")
    recorder_opts = [tempo: tempo, source: source, wait: wait(seconds)]
    capture(fn -> Recorder.record(wav, Keyword.merge(recorder_opts, opts)) end)
  end

  defp wait(seconds), do: fn -> Process.sleep(round(seconds * 1000) + 400) end

  defp capture(fun) do
    printed = capture_io(fn -> send(self(), {:result, fun.()}) end)
    assert_received {:result, result}
    {result, printed}
  end

  defp read!(path) do
    {:ok, recording} = Audio.read(path)
    recording
  end

  # Each click's time and peak: the first 5 ms block a tenth of the loudest or more, at least 0.2 s after the last.
  defp peaks(samples, rate) do
    block = div(rate, 200)

    levels =
      samples
      |> Enum.chunk_every(block)
      |> Enum.map(fn chunk -> chunk |> Enum.map(&abs/1) |> Enum.max() end)

    loudest = Enum.max(levels)
    indexed = Enum.with_index(levels)

    {peaks, _} =
      Enum.reduce(indexed, {[], -1000}, fn {level, index}, {peaks, last} ->
        if level >= loudest / 10 and index - last >= 40 do
          peak = levels |> Enum.slice(index, 10) |> Enum.max()
          {[{index * block / rate, peak} | peaks], index}
        else
          {peaks, last}
        end
      end)

    Enum.reverse(peaks)
  end
end
