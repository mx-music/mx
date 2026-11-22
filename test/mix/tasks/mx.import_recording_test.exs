defmodule Mix.Tasks.Mx.ImportRecordingTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Import

  @moduletag :engine
  @moduletag :tmp_dir

  @aria "examples/erbarme_dich/bwv244.39.mxl"
  @parts ["--part", "Violin=violin", "--part", "Alto=oboe", "--part", "Organo a canne=organ"]

  # The aria's first bars rendered at `tempo`, for `seconds`, as a recording of them.
  defp recording(dir, tempo, seconds) do
    out = Path.join(dir, "at#{tempo}.exs")
    parts = ["Violin=violin", "Alto=oboe", "Organo a canne=organ"]
    {:ok, imported} = Mx.Import.song(@aria, tempo: tempo, part: parts, out: out)
    File.write!(out, imported.source)
    wav = Path.join(dir, "at#{tempo}.wav")
    :ok = Mx.Render.render(out, wav, seconds: seconds, force: true)
    wav
  end

  # The second bar `number` of the aria starts at, at `tempo`: an upbeat of half a beat, then bars
  # of 6.
  defp written(number, tempo), do: (0.5 + (number - 1) * 6) * 60 / tempo

  defp import!(args), do: capture_io(fn -> Import.run(args) end)

  test "a recording of the aria's first six bars at 40 beats a minute gives a song at 40, each bar starting where it plays",
       %{tmp_dir: dir} do
    wav = recording(dir, 40, written(7, 40))
    song = Path.join(dir, "played.exs")
    output = import!([@aria, "--recording", wav, "--bars", "0-6", "--out", song | @parts])

    assert File.read!(song) =~ "use Mx.Song, tempo: 40"
    assert File.read!(song) =~ ~r/with the timing and loudness of the\s+recording at40.wav/
    assert File.read!(song) =~ "defp order, do: Enum.concat([0..6])"

    for number <- 1..6 do
      [_, second] = Regex.run(~r/^bar #{number} starts at ([\d.]+) s in the recording$/m, output)
      assert_in_delta String.to_float(second), written(number, 40), 0.15
    end
  end

  test "the notes the score writes together start together, and each plays at the recording's loudness",
       %{tmp_dir: dir} do
    wav = recording(dir, 40, written(7, 40))
    {:ok, score} = Mx.Score.read(@aria)
    {:ok, performance} = Mx.Performance.retime(score, wav, bars: 0..6)

    firsts = fn score, name ->
      part = Enum.find(score.parts, &(&1.name == name))

      Map.new(part.bars, fn bar ->
        group = bar.voices |> hd() |> Enum.find(&(&1.notes != []))
        {bar.number, group && group.onset}
      end)
    end

    {written_violin, written_organ} = {firsts.(score, "Violin"), firsts.(score, "Organo a canne")}

    {violin, organ} =
      {firsts.(performance.score, "Violin"), firsts.(performance.score, "Organo a canne")}

    for number <- 0..6, written_violin[number] == written_organ[number] do
      assert violin[number] == organ[number], "bar #{number}"
    end

    vels =
      for part <- performance.score.parts,
          bar <- part.bars,
          voice <- bar.voices,
          group <- voice,
          note <- group.notes,
          not note.continues,
          do: note.vel

    assert Enum.min(vels) == 0.3
    assert Enum.max(vels) == 1.0
  end

  test "a bar the recording plays slower lasts more beats in the song than one it plays faster",
       %{tmp_dir: dir} do
    {:ok, fast} = Mx.Audio.read(recording(dir, 48, written(4, 48)))
    {:ok, slow} = Mx.Audio.read(recording(dir, 32, written(7, 32)))
    rate = fast.rate
    slow_bars = Enum.drop(slow.samples, round(written(4, 32) * rate))
    wav = Path.join(dir, "fast_then_slow.wav")
    :ok = Mx.Audio.write(wav, fast.samples ++ slow_bars, rate)

    {:ok, score} = Mx.Score.read(@aria)
    {:ok, performance} = Mx.Performance.retime(score, wav, bars: 0..6)
    violin = Enum.find(performance.score.parts, &(&1.name == "Violin"))

    length = fn number ->
      violin.bars
      |> Enum.find(&(&1.number == number))
      |> Map.fetch!(:voices)
      |> hd()
      |> Enum.map(& &1.length)
      |> Enum.sum()
    end

    assert length.(5) > length.(2) * 1.3
    assert performance.tempo in 36..42
  end

  test "a recording that plays on after the bars given is refused, naming the last bar and when the two part ways",
       %{tmp_dir: dir} do
    wav = recording(dir, 40, written(7, 40))
    song = Path.join(dir, "played.exs")

    assert_raise Mix.Error,
                 ~r/^the recording and the score part ways after bar 3, at 0:2\d in the recording$/,
                 fn ->
                   import!([@aria, "--recording", wav, "--bars", "0-3", "--out", song | @parts])
                 end

    refute File.exists?(song)
  end

  # Marian Anderson's 1953 recording of the aria with the Robert Shaw Chorale and Orchestra,
  # marked with the Public Domain Mark 1.0, from
  # https://taju.uniarts.fi/bitstreams/30ed028d-ca86-4ac6-afa2-8f734936008d/download, as a WAV
  # file at the path MX_ANDERSON names.
  describe "Marian Anderson's recording of the aria" do
    @describetag :anderson
    @describetag :ffmpeg

    setup do
      %{
        anderson:
          System.get_env("MX_ANDERSON") ||
            flunk("set MX_ANDERSON to the WAV file of the recording")
      }
    end

    test "is refused where it goes back to the opening after the score's last bar, and cut there gives the song",
         %{
           tmp_dir: dir,
           anderson: anderson
         } do
      song = Path.join(dir, "aria_anderson.exs")

      %Mix.Error{message: message} =
        assert_raise Mix.Error, fn ->
          import!([@aria, "--recording", anderson, "--out", song | @parts])
        end

      [_, bar, minutes, seconds] =
        Regex.run(
          ~r/^the recording and the score part ways after bar (\d+), at (\d+):(\d\d) in the recording$/,
          message
        )

      assert String.to_integer(bar) in 44..46
      assert (String.to_integer(minutes) * 60 + String.to_integer(seconds)) in 360..400
      refute File.exists?(song)

      cut = Path.join(dir, "anderson.wav")

      {_, 0} =
        System.cmd("ffmpeg", [
          "-loglevel",
          "error",
          "-y",
          "-i",
          anderson,
          "-t",
          "#{minutes}:#{seconds}",
          cut
        ])

      output = import!([@aria, "--recording", cut, "--bars", "0-#{bar}", "--out", song | @parts])
      source = File.read!(song)

      [_, tempo] = Regex.run(~r/use Mx.Song, tempo: (\d+)/, source)
      assert String.to_integer(tempo) in 40..46
      assert source =~ ~r/recording\s+anderson.wav/

      for number <- 0..String.to_integer(bar), part <- ["violin", "alto", "organo_a_canne"] do
        assert source =~ ~r/defp bar\(:#{part}, #{number}\)/
      end

      starts =
        for [number, second] <-
              Regex.scan(~r/^bar (\d+) starts at ([\d.]+) s in the recording$/m, output,
                capture: :all_but_first
              ),
            do: {String.to_integer(number), String.to_float(second)}

      assert length(starts) == String.to_integer(bar) + 1
    end

    test "gives the violin vel from 0.3 to 1, and the bars it plays slower more beats", %{
      tmp_dir: dir,
      anderson: anderson
    } do
      cut = Path.join(dir, "anderson.wav")

      {_, 0} =
        System.cmd("ffmpeg", ["-loglevel", "error", "-y", "-i", anderson, "-t", "6:28", cut])

      {:ok, score} = Mx.Score.read(@aria)
      {:ok, performance} = Mx.Performance.retime(score, cut, bars: 0..46)
      violin = Enum.find(performance.score.parts, &(&1.name == "Violin"))

      vels =
        for bar <- violin.bars,
            voice <- bar.voices,
            group <- voice,
            note <- group.notes,
            not note.continues,
            do: note.vel

      assert Enum.min(vels) >= 0.3 and Enum.max(vels) <= 1.0
      assert Enum.max(vels) - Enum.min(vels) > 0.5

      seconds =
        performance.bars
        |> Enum.chunk_every(2, 1, :discard)
        |> Map.new(fn [{number, at}, {_, next}] -> {number, next - at} end)

      length = fn number ->
        violin.bars
        |> Enum.find(&(&1.number == number))
        |> Map.fetch!(:voices)
        |> hd()
        |> Enum.map(& &1.length)
        |> Enum.sum()
      end

      {slowest, _} = seconds |> Map.delete(0) |> Enum.max_by(&elem(&1, 1))
      {fastest, _} = seconds |> Map.delete(0) |> Enum.min_by(&elem(&1, 1))
      assert length.(slowest) > length.(fastest)
    end
  end
end
