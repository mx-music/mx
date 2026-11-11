defmodule Mix.Tasks.Mx.HumTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mx.{Audio, Hum, Voice}
  alias Mx.Engine.Rust

  @moduletag :tmp_dir

  @twinkle [{0, 48, 1}, {1, 48, 1}, {2, 55, 1}, {3, 55, 1}, {4, 57, 1}, {5, 57, 1}, {6, 55, 2}]

  describe "mx's own synths" do
    @describetag :engine

    test "a flute's quarter notes and half note come out as they were played", ctx do
      wav = write_wav(ctx, "flute.wav", flute(ctx, vibrato: 0.25), Rust.render_rate())

      assert song(wav, 90) =~ "seq(e4: 1, g4: 1, a4: 1, b4: 2, r: 3)"
    end

    test "a flute's notes held with vibrato are still those four notes", ctx do
      wav = write_wav(ctx, "flute.wav", flute(ctx, vibrato: 0.5), Rust.render_rate())

      assert song(wav, 90) =~ "seq(e4: 1, g4: 1, a4: 1, b4: 2, r: 3)"
    end

    test "a quick slide is the note it starts on and the note it lands on", ctx do
      beat = 60 / 90
      slide = [{beat, [note: 64]}]
      opts = [note: 60, sustain: 2 * beat, release: 0.05, note_slide: beat / 10]
      samples = Rust.render_note(:saw, opts, 2.2 * beat, ctx.tmp_dir, slide)
      %{notes: notes} = Hum.transcribe(samples, Rust.render_rate(), 90)

      assert [{+0.0, 60, 1.0}, {1.0, 64, _}] = notes
    end
  end

  test "two notes at one pitch with a break between them are two notes" do
    beat = 60 / 90
    first = {:note, 0, 0.18 * beat, 69, scoop: 0}
    second = {:note, 0.25 * beat, 0.7 * beat, 69, scoop: 0}

    assert {[{+0.0, 69, 0.25}, {0.25, 69, 0.75}], 4} =
             transcribe([first, second], 1.0, 48_000, 90)
  end

  test "a note hummed 30 cents sharp is the semitone below" do
    assert {[{+0.0, 55, 1.0}], 4} = transcribe([{:note, 0, 0.6, 55, cents: 30}], 0.8, 48_000, 100)
  end

  test "a melody lasts until the end of the bar its last note ends in" do
    notes = [{:note, 0, 2.9, 60, []}, {:note, 3, 1.9, 62, []}]

    assert {[{+0.0, 60, 3.0}, {3.0, 62, 2.0}], 8} = transcribe(notes, 5.2, 48_000, 60)
  end

  test "silence and a breath before the first note leave it on beat 0" do
    events = [{:breath, 0.5, 0.4}, {:note, 1.1, 0.55, 64, []}, {:note, 1.7, 0.55, 67, []}]

    assert {[{+0.0, 64, 1.0}, {1.0, 67, 1.0}], 4} = transcribe(events, 2.5, 48_000, 100)
  end

  test "a hum of Twinkle Twinkle Little Star against a click is its notes, in its octave", ctx do
    wav = write_wav(ctx, "twinkle.wav", twinkle(48_000), 48_000)

    assert song(wav, 100) =~ "seq(c3: 1, c3: 1, g3: 1, g3: 1, a3: 1, a3: 1, g3: 2)"
  end

  test "the written song loads, and prints its notes on their beats", ctx do
    wav = write_wav(ctx, "twinkle.wav", twinkle(48_000), 48_000)
    song(wav, 100)
    path = Path.join(ctx.tmp_dir, "twinkle.exs")

    assert {:ok, %Mx.Song{tempo: 100}} = Mx.Song.load(path)
    printed = capture_io(fn -> Mix.Tasks.Mx.Print.run([path]) end)

    assert printed =~ "hum, 8 beats at 100 bpm, played again and again"

    for {beat, note, held} <- @twinkle do
      assert printed =~ ~r/^beat #{beat} +play #{note} sustain: #{held}$/m
    end
  end

  test "a stereo AIFF at 44.1 kHz and a mono WAV at 48 kHz of one hum give one song", ctx do
    wav = write_wav(ctx, "mono.wav", twinkle(48_000), 48_000)
    aiff = write_stereo_aiff(ctx, "stereo.aiff", twinkle(44_100), 44_100)

    assert song(wav, 100) == song(aiff, 100)
  end

  test "prints where it wrote the song, how many notes it found, and their lowest and highest",
       ctx do
    wav = write_wav(ctx, "twinkle.wav", twinkle(48_000), 48_000)
    out = Path.join(ctx.tmp_dir, "tune.exs")

    printed = capture_io(fn -> Mix.Tasks.Mx.Hum.run([wav, "--tempo", "100", "--out", out]) end)

    assert printed == "Wrote #{out}: 7 notes, from c3 to a3.\n"
    assert File.exists?(out)
  end

  test "refuses a hum without its tempo, and a song that exists unless forced", ctx do
    wav = write_wav(ctx, "hum.wav", twinkle(48_000), 48_000)

    assert_raise Mix.Error, "give the hum's tempo with --tempo", fn ->
      Mix.Tasks.Mx.Hum.run([wav])
    end

    out = Path.join(ctx.tmp_dir, "hum.exs")
    File.write!(out, "old")

    assert_raise Mix.Error, "#{out} already exists; give --force to write over it", fn ->
      Mix.Tasks.Mx.Hum.run([wav, "--tempo", "100"])
    end

    assert File.read!(out) == "old"
    capture_io(fn -> Mix.Tasks.Mx.Hum.run([wav, "--tempo", "100", "--force"]) end)
    assert File.read!(out) =~ "seq(c3: 1"
  end

  test "with --record, refuses before any click a hum without its tempo or a recording that exists",
       ctx do
    wav = Path.join(ctx.tmp_dir, "hum.wav")

    assert_raise Mix.Error, "give the hum's tempo with --tempo", fn ->
      Mix.Tasks.Mx.Hum.run(["--record", wav])
    end

    File.write!(wav, "old")

    assert_raise Mix.Error, "#{wav} already exists; give --force to record over it", fn ->
      capture_io(fn -> Mix.Tasks.Mx.Hum.run(["--record", wav, "--tempo", "90"]) end)
    end

    assert_raise Mix.Error, "give one recording, such as mix mx.hum hum.wav --tempo 90", fn ->
      Mix.Tasks.Mx.Hum.run(["--record", wav, wav, "--tempo", "90"])
    end
  end

  test "refuses a file it cannot read, and a file with no pitched sound", ctx do
    missing = Path.join(ctx.tmp_dir, "missing.wav")

    assert_raise Mix.Error, "cannot read #{missing}", fn ->
      Mix.Tasks.Mx.Hum.run([missing, "--tempo", "100"])
    end

    silent = write_wav(ctx, "silent.wav", List.duplicate(0.0, 48_000), 48_000)

    assert_raise Mix.Error, "found no notes in #{silent}", fn ->
      Mix.Tasks.Mx.Hum.run([silent, "--tempo", "100"])
    end

    noise = Voice.render([{:breath, 0.1, 0.8}, {:click, 0.95}], 1.0, 48_000)
    noisy = write_wav(ctx, "breath.wav", noise, 48_000)

    assert_raise Mix.Error, "found no notes in #{noisy}", fn ->
      Mix.Tasks.Mx.Hum.run([noisy, "--tempo", "100"])
    end
  end

  # A count-in of four clicks, then the hum a little off the beat, each note ending before the next, as a voice does.
  defp twinkle(rate) do
    beat = 60 / 100
    start = 4 * beat
    late = [0.02, -0.03, 0.01, 0.03, -0.02, 0.0, 0.02]
    clicks = for count <- 0..11, do: {:click, count * beat}

    notes =
      for {{at, note, held}, off} <- Enum.zip(@twinkle, late) do
        {:note, start + at * beat + off, held * beat - 0.12, note, []}
      end

    Voice.render([{:breath, start - 0.5, 0.35} | clicks ++ notes], start + 8.5 * beat, rate)
  end

  defp flute(ctx, opts) do
    beat = 60 / 90

    [{64, 1}, {67, 1}, {69, 1}, {71, 2}]
    |> Enum.flat_map(fn {note, beats} ->
      note_opts = [note: note, sustain: beats * beat - 0.2, release: 0.1, vel: 0.6] ++ opts
      Rust.render_note(:flute, note_opts, beats * beat, ctx.tmp_dir, [])
    end)
  end

  defp transcribe(events, seconds, rate, tempo) do
    %{notes: notes, beats: beats} =
      events |> Voice.render(seconds, rate) |> Hum.transcribe(rate, tempo)

    {notes, beats}
  end

  defp song(path, tempo) do
    out = Path.rootname(path) <> ".exs"
    args = [path, "--tempo", "#{tempo}", "--out", out, "--force"]
    capture_io(fn -> Mix.Tasks.Mx.Hum.run(args) end)
    File.read!(out)
  end

  defp write_wav(ctx, name, samples, rate) do
    path = Path.join(ctx.tmp_dir, name)
    Audio.write(path, samples, rate)
    path
  end

  # AIFF: 16-bit big-endian samples, the same in both channels, and the rate as an 80-bit extended float.
  defp write_stereo_aiff(ctx, name, samples, rate) do
    path = Path.join(ctx.tmp_dir, name)

    data =
      for sample <- samples,
          into: <<>>,
          do: <<round(sample * 32_767)::signed-16, round(sample * 32_767)::signed-16>>

    exponent = floor(:math.log2(rate))
    mantissa = round(rate * 2 ** (63 - exponent))
    common = <<2::16, length(samples)::32, 16::16, 16_383 + exponent::16, mantissa::64>>
    sound = <<0::32, 0::32>> <> data
    body = "AIFF" <> "COMM" <> <<18::32>> <> common <> "SSND" <> <<byte_size(sound)::32>> <> sound
    File.write!(path, "FORM" <> <<byte_size(body)::32>> <> body)
    path
  end
end
