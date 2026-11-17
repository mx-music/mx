defmodule Mix.Tasks.Mx.MeasureTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs
  alias Mx.Measure
  alias Mx.Measure.{Held, Hits}

  @moduletag :tmp_dir

  describe "--known" do
    setup do
      {micros, output} =
        :timer.tc(fn -> capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--known"]) end) end)

      %{output: output, seconds: micros / 1_000_000}
    end

    test "measures six kinds of note at C2, C4 and C7, with each partial's errors, in under 30 seconds",
         %{output: output, seconds: seconds} do
      notes = Regex.scan(~r/^(C2|C4|C7) (\w+): strike [+-][\d.]+ ms$/m, output)
      assert length(notes) == 18

      assert notes |> Enum.map(&Enum.at(&1, 2)) |> Enum.uniq() ==
               ~w(slow short beating building noisy early)

      assert output =~
               ~r/^  261\.6 Hz: first 20 ms [+-][\d.]+ dB, average [\d.]+ dB, [+-][\d.]+ cents$/m

      assert seconds < 30
    end

    test "marks every figure beyond 2 dB and no figure within it", %{output: output} do
      figures =
        Regex.scan(~r/(?:first 20 ms|average) \+?(-?[\d.]+) dB( \(beyond 2 dB\))?/, output)

      assert length(figures) > 60

      for [_, value | mark] <- figures do
        assert abs(String.to_float(value)) > 2 == (mark != []),
               "#{value} dB is marked #{inspect(mark)}"
      end
    end

    test "ends with a line for each kind saying at which pitches it is followed within 2 dB",
         %{output: output} do
      lines = output |> String.split("\n", trim: true) |> Enum.take(-6)

      for {kind, line} <- Enum.zip(~w(slow short beating building noisy early), lines) do
        assert line =~ ~r/^#{kind}: (not )?followed within 2 dB at /
      end

      assert List.first(lines) == "slow: followed within 2 dB at C4, C7, not at C2"
    end
  end

  test "prints the notes found in each file, and each band's fade and level", ctx do
    path = write_wav(ctx, "run.wav", Enum.flat_map(0..2, &tone(110 * 2 ** (&1 / 12), 3)))
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["#{path}:A2"]) end)

    assert output =~ "run.wav: 3 notes, a2 as2 b2"
    assert output =~ ~r/80-160 Hz +3\.\d\d s +\+0\.\d dB/
    assert output =~ ~r/160-250 Hz +3\.\d\d s +-[56]\.\d dB/
  end

  test "refuses a file it cannot read, a file with no notes, and a file with no note", ctx do
    missing = Path.join(ctx.tmp_dir, "missing.wav")

    assert_raise Mix.Error, "cannot read #{missing}", fn ->
      Mix.Tasks.Mx.Measure.run(["#{missing}:A2"])
    end

    silent = write_wav(ctx, "silent.wav", List.duplicate(0.0, 48_000))

    assert_raise Mix.Error, "found no notes in #{silent}", fn ->
      Mix.Tasks.Mx.Measure.run(["#{silent}:A2"])
    end

    assert_raise Mix.Error,
                 "give each file with the note it starts on, such as Guitar.mf.sulA.A2B2.aif:A2",
                 fn ->
                   Mix.Tasks.Mx.Measure.run([silent])
                 end

    assert_raise Mix.Error, "unknown note H2", fn ->
      Mix.Tasks.Mx.Measure.run(["#{silent}:H2"])
    end
  end

  @tag :engine
  test "with --synth, prints the synth beside the recordings for every band, with the difference",
       ctx do
    path = write_wav(ctx, "run.wav", Enum.flat_map(0..1, &tone(110 * 2 ** (&1 / 12), 3)))

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Measure.run(["#{path}:A2", "--synth", "guitar", "--vel", "0.6"])
      end)

    assert output =~ "guitar at vel 0.6"

    for band <- ["80-160", "160-250", "250-400", "400-630"] do
      assert output =~
               ~r/#{band} Hz +[\d.]+ s +[-+][\d.]+ dB +[\d.]+ s +[-+][\d.]+ dB +[-+]\d+% +[-+][\d.]+ dB/
    end
  end

  @tag :engine
  test "a design test and mix mx.measure give the same figures for the same rendered sound",
       ctx do
    sound = Mxs.render_note(:guitar, [note: 45, vel: 0.6], 4.4, ctx.tmp_dir, [])
    path = write_wav(ctx, "guitar.wav", sound)
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["#{path}:A2"]) end)

    for band <- Measure.bands([Measure.note(sound, Mxs.render_rate(), 45)]) do
      {low, high} = band.band
      fade = :erlang.float_to_binary(band.fade, decimals: 2)
      level = :erlang.float_to_binary(band.level, decimals: 1)
      level = if band.level >= 0, do: "+" <> level, else: level
      figures = Regex.escape("#{fade} s") <> " +" <> Regex.escape("#{level} dB")
      assert output =~ ~r/#{low}-#{high} Hz +#{figures}/
    end
  end

  test "with --held, prints each note's attack and vibrato, and each band's level and noise",
       ctx do
    silence = List.duplicate(0.0, 24_000)

    path =
      write_wav(
        ctx,
        "held.wav",
        Enum.flat_map(0..1, &(held(220 * 2 ** (&1 / 12), 2.5) ++ silence))
      )

    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--held", "#{path}:A3"]) end)

    assert output =~ "held.wav: 2 notes, a3 as3"
    assert output =~ ~r/  a3 at 2[12]\d\.\d Hz, attack 0\.\d\d s, no vibrato/
    assert output =~ ~r/^attack +0\.\d\d s$/m
    assert output =~ ~r/^vibrato +none$/m
    assert output =~ ~r/^400-630 Hz +-6\.\d dB +-[\d.]+ dB$/m
  end

  test "with --hits, prints each hit's peaks, and each band's level and fade, with no note given",
       ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path]) end)

    assert output =~ "hit.wav: 1 hit"
    assert output =~ ~r/  hit 1: peaks at 1\.00, 3\.9\d/
    assert output =~ ~r/^250-400 Hz +1\.\d\d s +\+0\.0 dB$/m
  end

  @tag :engine
  test "with --hits and --synth, keeps a space between a long synth heading and the difference",
       ctx do
    path = write_wav(ctx, "hit.wav", hit(1047, 1.0))

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "low_agogo", "--vel", "0.6"])
      end)

    assert output =~ "low_agogo at vel 0.6 difference"
  end

  test "with --hits and --partials, prints each hit's strongest partials with Hz, ratio, level and ring",
       ctx do
    path =
      write_wav(ctx, "partials.wav", partials_hit(200, [{1, 1}, {3.9, 0.5}, {9.2, 0.316}], 1.0))

    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path, "--partials", "3"]) end)

    assert output =~ ~r/^ +200\.\d Hz +1\.00 +[-+]0\.0 dB +(0\.9\d|1\.0\d) s$/m
    assert output =~ ~r/^ +7[78]\d\.\d Hz +3\.9\d +-[56]\.\d dB +(0\.9\d|1\.0\d) s$/m
    assert output =~ ~r/^ +18[34]\d\.\d Hz +9\.[12]\d +-(9|10)\.\d dB +(0\.9\d|1\.0\d) s$/m

    two = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path, "--partials", "2"]) end)
    assert length(Regex.scan(~r/^ +\d+\.\d Hz/m, two)) == 2
  end

  test "with --hits, prints each band's level at 0, 50, 100 and 200 ms after the loudest moment",
       ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path]) end)

    assert output =~ "levels in dB at 0, 50, 100 and 200 ms after the loudest moment"
    assert output =~ ~r/^250-400 Hz +\+0 +-3 +-6 +-12$/m
  end

  test "with --hits, a moment after the recording ends prints as -", ctx do
    path = write_wav(ctx, "short.wav", hit(300, 0.125))
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path]) end)
    [_bands, moments] = String.split(output, "after the loudest moment")
    rows = Regex.scan(~r/^\d+-\d+ Hz .*$/m, moments)

    assert rows != []
    for [row] <- rows, do: assert(row =~ ~r/ -$/)
  end

  @tag :engine
  test "with --hits and --synth, prints the synth's levels over time beside the recordings'",
       ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))

    output =
      capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "cowbell"]) end)

    [_bands, moments] = String.split(output, "after the loudest moment")
    assert moments =~ ~r/^band +recordings +cowbell at vel 0\.6 +difference$/m
    assert moments =~ ~r/^250-400 Hz +\+0 +-3 +-6 +-12( +([-+]\d+|-)){8}$/m
  end

  @tag :engine
  test "--compare writes the recorded hits nearest the median, then the synth's, at one peak, fading out",
       ctx do
    silence = List.duplicate(0.0, 24_000)

    path =
      write_wav(
        ctx,
        "hits.wav",
        Enum.concat([
          hit(300, 3.0),
          silence,
          hit(300, 3.0),
          silence,
          hit(300, 3.0),
          silence,
          hit(300, 3.0)
        ])
      )

    out = Path.join(ctx.tmp_dir, "ab.wav")

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "cowbell", "--compare", out])
      end)

    assert output =~
             ~r/^wrote .*ab\.wav: hits\.wav at \d+\.\d\d s, hits\.wav at \d+\.\d\d s and hits\.wav at \d+\.\d\d s, then cowbell three times$/m

    {:ok, %{rate: 48_000, samples: samples}} = Mx.Audio.read(out)
    each = round(0.85 * 48_000)
    assert length(samples) == 6 * each

    for part <- Enum.chunk_every(samples, each) do
      assert_in_delta part |> Enum.map(&abs/1) |> Enum.max(), 0.5, 0.001
      ending = Enum.at(part, round(0.6 * 48_000) - 1)
      assert abs(ending) < 0.001, "each hit fades out, so a ringing synth ends without a click"
    end

    capture_io(fn -> Mix.Tasks.Mx.Spectrogram.run([out]) end)
    assert File.exists?(Path.rootname(out) <> ".png")
  end

  test "--compare needs --hits and --synth", ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))

    for args <- [["--hits", path], [path <> ":C4", "--synth", "cowbell"]] do
      assert_raise Mix.Error, "--compare needs --hits and --synth", fn ->
        Mix.Tasks.Mx.Measure.run(args ++ ["--compare", "ab.wav"])
      end
    end
  end

  test "--hits without --partials prints the bands, then the levels over time", ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path]) end)

    assert output == """
           hit.wav: 1 hit
             hit 1: peaks at 1.00, 3.90

           band                fade     level
           160-250 Hz      1.00 s  -41.0 dB
           250-400 Hz      1.00 s   +0.0 dB
           400-630 Hz      1.00 s  -56.7 dB
           1000-1600 Hz    1.00 s   -6.0 dB

           levels in dB at 0, 50, 100 and 200 ms after the loudest moment, against the loudest band then
           band              0   50  100  200
           250-400 Hz       +0   -3   -6  -12
           1000-1600 Hz     -6   -9  -12  -18
           """
  end

  @tag :engine
  test "with --option, renders the synth with that option, and names it in the heading", ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))

    down =
      capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "shaker"]) end)

    up =
      capture_io(fn ->
        Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "shaker", "--option", "up=1"])
      end)

    assert up =~ "shaker at vel 0.6, up 1 "
    refute down =~ "up 1"
    assert synth_rows(up) != synth_rows(down)
  end

  test "--option needs a name the synth takes and a number", ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))

    assert_raise Mix.Error, "shaker has no option rub", fn ->
      Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "shaker", "--option", "rub=1"])
    end

    for option <- ["up", "up=", "up=high"] do
      assert_raise Mix.Error, "give --option as a name and a number, such as --option up=1", fn ->
        Mix.Tasks.Mx.Measure.run(["--hits", path, "--synth", "shaker", "--option", option])
      end
    end

    assert_raise Mix.Error, "--option needs --synth", fn ->
      Mix.Tasks.Mx.Measure.run(["--hits", path, "--option", "up=1"])
    end
  end

  test "--partials needs --hits or plucked notes, and a count from 1 up", ctx do
    path = write_wav(ctx, "hit.wav", hit(300, 1.0))

    assert_raise Mix.Error, "--partials needs --hits or plucked notes", fn ->
      Mix.Tasks.Mx.Measure.run(["--held", "#{path}:D4", "--partials", "4"])
    end

    for count <- ["0", "-2", "two", "1.5"] do
      assert_raise Mix.Error, "--partials takes a count from 1 up, such as --partials 12", fn ->
        Mix.Tasks.Mx.Measure.run(["--hits", path, "--partials", count])
      end
    end
  end

  @tag :engine
  test "with --hits, --partials and --synth, prints the synth's partials under its name after the recordings'",
       ctx do
    path = write_wav(ctx, "hit.wav", partials_hit(1047, [{1, 1}, {2.98, 0.5}], 1.0))

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Measure.run(["--hits", path, "--partials", "4", "--synth", "low_agogo"])
      end)

    [_, synth] = String.split(output, ~r/^low_agogo at vel 0\.6: 1 hit$/m)
    assert synth =~ ~r/^  hit 1: peaks at .*\n +\d+\.\d Hz/m
    assert synth =~ ~r/^ +10[45]\d\.\d Hz/m
  end

  test "with --held and --drone, measures each file as one note, however often it is plucked again",
       ctx do
    plucked =
      held(220, 6)
      |> Enum.with_index(fn sample, index ->
        since = :math.fmod(index / 48_000, 1.5)
        sample * (0.05 + 0.95 * :math.exp(-since / 0.3))
      end)

    path = write_wav(ctx, "drone.wav", plucked)

    assert capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--held", "#{path}:A3"]) end) =~
             ~r/^drone.wav: [2-9] notes/m

    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--held", "--drone", "#{path}:A3"]) end)
    assert output =~ "drone.wav: 1 note, a3"
    assert output =~ ~r/^400-630 Hz +-6\.\d dB +-[\d.]+ dB$/m
  end

  test "--drone needs --held", ctx do
    path = write_wav(ctx, "held.wav", held(220, 2))

    assert_raise Mix.Error, "--drone needs --held", fn ->
      Mix.Tasks.Mx.Measure.run(["--drone", "#{path}:A3"])
    end
  end

  test "--held needs the note each file starts on, and --hits refuses a file with no hits", ctx do
    silent = write_wav(ctx, "silent.wav", List.duplicate(0.0, 48_000))

    assert_raise Mix.Error,
                 "give each file with the note it starts on, such as Guitar.mf.sulA.A2B2.aif:A2",
                 fn -> Mix.Tasks.Mx.Measure.run(["--held", silent]) end

    assert_raise Mix.Error, "found no hits in #{silent}", fn ->
      Mix.Tasks.Mx.Measure.run(["--hits", silent])
    end

    assert_raise Mix.Error, "give --held or --hits, not both", fn ->
      Mix.Tasks.Mx.Measure.run(["--held", "--hits", silent])
    end
  end

  @tag :engine
  test "with --held and --synth, prints the synth beside the recordings, with the difference",
       ctx do
    path = write_wav(ctx, "held.wav", held(440, 2.5))

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Measure.run(["--held", "#{path}:A4", "--synth", "flute", "--vel", "0.6"])
      end)

    assert output =~ "flute at vel 0.6"
    assert output =~ ~r/^attack +0\.\d\d s +0\.\d\d s +[-+]\d+%$/m

    assert output =~
             ~r/^400-630 Hz +\+0\.0 dB +-[\d.]+ dB +\+0\.0 dB +-[\d.]+ dB +\+0\.0 dB +[-+][\d.]+ dB$/m
  end

  @tag :engine
  test "a design test and mix mx.measure give the same figures for the same held note and hit",
       ctx do
    flute =
      Mxs.render_note(:flute, [note: 69, vel: 0.6, sustain: 2], 3, ctx.tmp_dir, [])

    path = write_wav(ctx, "flute.wav", flute)
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--held", "#{path}:A4"]) end)
    summary = Held.summary([Held.note(flute, Mxs.render_rate(), 69)])
    attack = :erlang.float_to_binary(summary.attack, decimals: 2)
    assert output =~ ~r/^attack +#{Regex.escape(attack)} s$/m

    # The WAV holds 32-bit samples, which can move a band far below the fundamental by a printed
    # tenth of a dB.
    for %{band: {low, high}, level: level} <- summary.bands, level != nil do
      [_, printed] = Regex.run(~r/^#{low}-#{high} Hz +([-+][\d.]+) dB/m, output)
      assert_in_delta String.to_float(printed), level, 0.15
    end

    cowbell = Mxs.render_note(:cowbell, [], 2, ctx.tmp_dir, [])
    path = write_wav(ctx, "cowbell.wav", cowbell)
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path]) end)

    for band <- Hits.summary([Hits.hit(cowbell, Mxs.render_rate(), nil)]),
        band.fade != nil do
      {low, high} = band.band
      fade = :erlang.float_to_binary(band.fade, decimals: 2)
      figures = Regex.escape("#{fade} s") <> " +" <> Regex.escape("#{signed(band.level)} dB")
      assert output =~ ~r/#{low}-#{high} Hz +#{figures}/
    end
  end

  test "with --strokes, prints each stroke, and with --tracks its pitch and levels at every step",
       ctx do
    silence = List.duplicate(0.0, 2400)
    path = write_wav(ctx, "rubs.wav", silence ++ rub(330) ++ rub(330) ++ silence)

    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--strokes", path]) end)
    assert output =~ "rubs.wav: 2 strokes"
    assert output =~ ~r/^ +0 +0\.0\d +1\d\d +64\.0\d +-\d+ +[-+]0\.\d$/m
    assert output =~ ~r/^ +1 +0\.2\d +1\d\d +64\.0\d/m

    args = ["--strokes", path, "--tracks", "1", "--ignore", "600-700"]
    output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(args) end)
    assert output =~ ~r/^stroke 1 of rubs\.wav: note 64\.0\d, scoop 0\.\d\d, \d+ steps of 8 ms$/m
    assert output =~ ~r/^cents: -\d+(, -?\d+)+$/m
    assert output =~ ~r/^\[(-1|0), -127, -[67], -127(, -?\d+){13}\],$/m
  end

  test "--strokes refuses silence and a stroke the file does not have, and --tracks needs it",
       ctx do
    silent = write_wav(ctx, "silent.wav", List.duplicate(0.0, 48_000))

    assert_raise Mix.Error, "found no strokes in #{silent}", fn ->
      Mix.Tasks.Mx.Measure.run(["--strokes", silent])
    end

    path = write_wav(ctx, "rub.wav", List.duplicate(0.0, 2400) ++ rub(330))

    assert_raise Mix.Error, "--tracks takes strokes from 0 to 0, such as --tracks 0,3", fn ->
      Mix.Tasks.Mx.Measure.run(["--strokes", path, "--tracks", "1"])
    end

    assert_raise Mix.Error,
                 "--ignore takes two frequencies in Hz, such as --ignore 8500-9100",
                 fn ->
                   Mix.Tasks.Mx.Measure.run(["--strokes", path, "--tracks", "0", "--ignore", "x"])
                 end

    assert_raise Mix.Error, "--tracks needs --strokes", fn ->
      Mix.Tasks.Mx.Measure.run([path, "--tracks", "0"])
    end
  end

  # The University of Iowa Electronic Music Studios' flute recordings, from
  # https://theremin.music.uiowa.edu/MISflute.html, in the folder MX_IOWA_FLUTE names.
  describe "the Iowa flute recordings" do
    @describetag :iowa

    setup do
      dir =
        System.get_env("MX_IOWA_FLUTE") ||
          flunk("set MX_IOWA_FLUTE to the folder of the Iowa flute recordings")

      %{dir: dir}
    end

    test "finds a vibrato of 4 to 7 a second in the notes played with vibrato, and none without",
         %{dir: dir} do
      vibrato =
        capture_io(fn ->
          Mix.Tasks.Mx.Measure.run(["--held", Path.join(dir, "Flute.vib.mf.B3B4.aiff") <> ":B3"])
        end)

      [_, rate] = Regex.run(~r/^vibrato +([\d.]+) Hz/m, vibrato)
      assert String.to_float(rate) >= 4 and String.to_float(rate) <= 7

      steady =
        capture_io(fn ->
          Mix.Tasks.Mx.Measure.run([
            "--held",
            Path.join(dir, "Flute.nonvib.mf.B3B4.aiff") <> ":B3"
          ])
        end)

      assert steady =~ ~r/^vibrato +none$/m
    end

    test "prints mx's flute beside the recordings, with the difference", %{dir: dir} do
      path = Path.join(dir, "Flute.vib.mf.C5B5.aiff")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Measure.run(["--held", "#{path}:C5", "--synth", "flute", "--vel", "0.6"])
        end)

      assert output =~ "flute at vel 0.6"

      assert output =~
               ~r/^vibrato +[\d.]+ Hz, \d+ cents +[\d.]+ Hz, \d+ cents +[-+][\d.]+ Hz, [-+]\d+ cents$/m
    end
  end

  # The VSCO 2 Community Edition percussion, from https://github.com/sgossner/VSCO-2-CE, in the
  # folder MX_VSCO_PERCUSSION names.
  describe "the VSCO 2 cowbell recordings" do
    @describetag :vsco

    setup do
      dir =
        System.get_env("MX_VSCO_PERCUSSION") ||
          flunk("set MX_VSCO_PERCUSSION to the folder of the VSCO 2 percussion")

      %{dir: dir}
    end

    test "finds one hit in each file, and prints each band's level and fade", %{dir: dir} do
      paths = Path.wildcard(Path.join(dir, "Cowbell1_Hit_*.wav"))
      assert length(paths) == 8
      output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits" | paths]) end)

      for path <- paths do
        name = Path.basename(path)
        assert output =~ "#{name}: 1 hit"
      end

      assert output =~ ~r/^630-1000 Hz +[\d.]+ s +[-+][\d.]+ dB$/m
    end
  end

  # Versilian Studios' Versilian Community Sample Library, from https://github.com/sgossner/VCSL,
  # in the folder MX_VCSL names.
  describe "the VCSL agogô recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Idiophones/Struck Idiophones/Agogo Bells")}
    end

    test "prints the low bell's partials at the ratios its peaks show", %{dir: dir} do
      path = Path.join(dir, "Agogo_Low_v1_rr1_Mid.wav")
      output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["--hits", path, "--partials", "6"]) end)

      ratios =
        for [ratio] <- Regex.scan(~r/^ +[\d.]+ Hz +([\d.]+) /m, output, capture: :all_but_first),
            do: String.to_float(ratio)

      for expected <- [1.05, 2.98, 3.40] do
        assert Enum.any?(ratios, &(abs(&1 / expected - 1) <= 0.03)), output
      end
    end

    test "prints each bell beside its recordings, within 6 dB and 30 percent from 630 Hz to 10 kHz",
         %{dir: dir} do
      for {bell, synth} <- [{"Low", "low_agogo"}, {"High", "high_agogo"}] do
        paths = Path.wildcard(Path.join(dir, "Agogo_#{bell}_v*_rr1_Mid.wav"))

        output =
          capture_io(fn ->
            Mix.Tasks.Mx.Measure.run(["--hits" | paths] ++ ["--synth", synth, "--vel", "0.6"])
          end)

        rows =
          Regex.scan(~r/^(\d+)-\d+ Hz .* ([-+]\d+)% +([-+][\d.]+) dB$/m, output,
            capture: :all_but_first
          )

        # From 10 kHz the bells hold the stick's strike over a quiet tail, which a fade's straight
        # line does not fit.
        # The design tests hold that band to its levels over time instead.
        rows =
          for [low, fade, level] <- rows,
              String.to_integer(low) in 630..9999,
              do: {fade, level}

        assert length(rows) >= 5, output

        for {fade, level} <- rows do
          assert abs(String.to_integer(fade)) <= 30, output
          assert abs(String.to_float(level)) <= 6, output
        end
      end
    end
  end

  # The small and the large shaker of the Versilian Community Sample Library, in the folder
  # MX_VCSL names.
  describe "the VCSL shaker recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Idiophones/Struck Idiophones")}
    end

    # One small up stroke, Mid_ShakerLowFaster_Up_rr2.wav, is too short to measure, so it is left
    # out.
    test "prints the ganza and the shaker beside their strokes, within 6 dB and 30 percent from 1 kHz up",
         %{dir: dir} do
      small = Path.join(dir, "Shaker, Small")
      large = Path.join(dir, "Shaker, Large")

      cases = [
        {"ganza", [], Path.wildcard(Path.join(small, "*_Down_*.wav"))},
        {"ganza", ["--option", "up=1"],
         Path.wildcard(Path.join(small, "*_Up_*.wav")) --
           [Path.join(small, "Mid_ShakerLowFaster_Up_rr2.wav")]},
        {"shaker", [], Path.wildcard(Path.join(large, "*Shake1D*.wav"))},
        {"shaker", ["--option", "up=1"], Path.wildcard(Path.join(large, "*Shake1U*.wav"))}
      ]

      for {synth, option, paths} <- cases do
        assert length(paths) >= 2

        output =
          capture_io(fn ->
            Mix.Tasks.Mx.Measure.run(["--hits" | paths] ++ ["--synth", synth | option])
          end)

        rows =
          for [low, fade, level] <-
                Regex.scan(~r/^(\d+)-\d+ Hz .* ([-+]\d+)% +([-+][\d.]+) dB$/m, output,
                  capture: :all_but_first
                ),
              String.to_integer(low) >= 1000,
              do: {fade, level}

        assert length(rows) >= 4, output

        for {fade, level} <- rows do
          assert abs(String.to_integer(fade)) <= 30, output
          assert abs(String.to_float(level)) <= 6, output
        end
      end
    end
  end

  # The University of Iowa Electronic Music Studios' guitar recordings, from
  # https://theremin.music.uiowa.edu/MISguitar.html, unzipped into the folder MX_IOWA_GUITAR
  # names.
  # The cabasa of the Versilian Community Sample Library, in the folder MX_VCSL names.
  describe "the VCSL cabasa recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Idiophones/Struck Idiophones/Cabasa")}
    end

    test "prints the cabasa beside its hits, within 6 dB and 30 percent from 1 kHz up", %{
      dir: dir
    } do
      paths = Path.wildcard(Path.join(dir, "Cabasa1_Hit_*.wav"))
      assert length(paths) == 2

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Measure.run(["--hits" | paths] ++ ["--synth", "cabasa"])
        end)

      rows =
        for [low, fade, level] <-
              Regex.scan(~r/^(\d+)-\d+ Hz .* ([-+]\d+)% +([-+][\d.]+) dB$/m, output,
                capture: :all_but_first
              ),
            String.to_integer(low) >= 1000,
            do: {fade, level}

      assert length(rows) == 6, output

      for {fade, level} <- rows do
        assert abs(String.to_integer(fade)) <= 30, output
        assert abs(String.to_float(level)) <= 6, output
      end
    end
  end

  # The cajón of the Versilian Community Sample Library, whose bass tone is the stroke named hit2
  # and slap hit1.
  describe "the VCSL cajón recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Idiophones/Struck Idiophones/Cajon")}
    end

    test "prints the cajón beside its bass tone and slap, within 6 dB and 30 percent up to 10 kHz",
         %{dir: dir} do
      for {stroke, slap} <- [{"hit2", "0"}, {"hit1", "1"}] do
        paths = Path.wildcard(Path.join(dir, "Cajon_#{stroke}_f_rr*.wav"))
        assert length(paths) == 2
        args = ["--hits" | paths] ++ ["--synth", "cajon", "--option", "slap=#{slap}"]
        output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(args) end)

        rows =
          for [low, fade, level] <-
                Regex.scan(~r/^(\d+)-\d+ Hz .* ([-+]\d+)% +([-+][\d.]+) dB$/m, output,
                  capture: :all_but_first
                ),
              String.to_integer(low) < 10_000,
              do: {fade, level}

        assert length(rows) == 10, output

        for {fade, level} <- rows do
          assert abs(String.to_integer(fade)) <= 30, output
          assert abs(String.to_float(level)) <= 6, output
        end
      end
    end
  end

  # The bongos of the Versilian Community Sample Library, open and muted, at their middle
  # strength.
  describe "the VCSL bongo recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Membranophones/Struck Membranophones/Bongos")}
    end

    test "prints each bongo beside its open and muted hits, within 6 dB and 30 percent up to 10 kHz",
         %{dir: dir} do
      strokes = [
        {"BongoL_Hit1", "low_bongo", "0"},
        {"BongoL_HitMuted2", "low_bongo", "1"},
        {"BongoH_Hit1", "high_bongo", "0"},
        {"BongoH_HitMuted1", "high_bongo", "1"}
      ]

      for {stroke, synth, muted} <- strokes do
        paths = Path.wildcard(Path.join(dir, "#{stroke}_v2_rr*.wav"))
        assert length(paths) == 2
        args = ["--hits" | paths] ++ ["--synth", synth, "--option", "muted=#{muted}"]
        output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(args) end)

        rows =
          for [low, fade, level] <-
                Regex.scan(~r/^(\d+)-\d+ Hz .* ([-+]\d+)% +([-+][\d.]+) dB$/m, output,
                  capture: :all_but_first
                ),
              String.to_integer(low) < 10_000,
              do: {fade, level}

        assert length(rows) == 10, output

        for {fade, level} <- rows do
          assert abs(String.to_integer(fade)) <= 30, output
          assert abs(String.to_float(level)) <= 6, output
        end
      end
    end
  end

  # The Steinway B grand of the Versilian Community Sample Library without the sustain pedal, at
  # its three strengths.
  describe "the VCSL Steinway recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Chordophones/Zithers/Grand Piano, Steinway B/NoSus")}
    end

    # The soft notes' harmonics above 1 kHz sit near the noise floor, which stretches their
    # measured fades, so those fades are left out.
    test "prints the piano beside every fourth semitone from C2 to C7, within 6 dB and 30 percent up to 4 kHz",
         %{dir: dir} do
      names = ~w(C Cs D Ds E F Fs G Gs A As B)

      for {layer, vel} <- [{2, "0.3"}, {3, "0.6"}, {4, "1"}] do
        files =
          for note <- 36..96//4 do
            name = "#{Enum.at(names, rem(note, 12))}#{div(note, 12) - 1}"
            file = String.replace(name, "s", "#")
            Path.join(dir, "JHPiano_NoSus_Close_#{file}_vl#{layer}_rr1.wav") <> ":" <> name
          end

        args = files ++ ["--synth", "piano", "--vel", vel, "--option", "sustain=60"]
        output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(args) end)

        rows =
          for [low, fade, level] <-
                Regex.scan(~r/^(\d+)-\d+ Hz .* ([-+]\d+)% +([-+][\d.]+) dB$/m, output,
                  capture: :all_but_first
                ),
              String.to_integer(low) < 4000,
              do: {String.to_integer(low), fade, level}

        assert length(rows) == 8, output

        for {low, fade, level} <- rows do
          assert abs(String.to_float(level)) <= 6, output
          assert (layer == 2 and low >= 1000) or abs(String.to_integer(fade)) <= 30, output
        end
      end
    end
  end

  describe "the Iowa guitar recordings" do
    @describetag :iowa

    setup do
      dir =
        System.get_env("MX_IOWA_GUITAR") ||
          flunk("set MX_IOWA_GUITAR to the folder of the Iowa guitar recordings")

      %{dir: dir}
    end

    test "finds 3 notes in the A string's A2 to B2", %{dir: dir} do
      path = Path.join(dir, "Guitar.mf.sulA.A2B2.aif")
      output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["#{path}:A2"]) end)
      assert output =~ "Guitar.mf.sulA.A2B2.aif: 3 notes, a2 as2 b2"
    end

    test "measures the fades mx's guitar was built on, over the 15 files played mf", %{dir: dir} do
      args =
        for path <- Path.wildcard(Path.join(dir, "Guitar.mf.*.aif")) do
          [_, first] = Regex.run(~r/\.([A-G]b?\d)[A-G]?b?\d*\.aif$/, path)
          "#{path}:#{first}"
        end

      assert length(args) == 15
      output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(args) end)
      [_, low] = Regex.run(~r/80-160 Hz +([\d.]+) s/, output)
      [_, middle] = Regex.run(~r/630-1000 Hz +([\d.]+) s/, output)
      assert_in_delta String.to_float(low) / 10.3, 1, 0.1
      assert_in_delta String.to_float(middle) / 2.45, 1, 0.1
    end
  end

  # Six harmonics at 1/number of the first, held at one level after a 20 ms rise.
  # The keyboard_electronic_098 instrument of the test set of Google's NSynth dataset, from
  # https://magenta.tensorflow.org/datasets/nsynth, in the folder MX_NSYNTH names, which holds
  # one folder an instrument.
  describe "the NSynth electric piano recordings" do
    @describetag :nsynth

    setup do
      dir =
        System.get_env("MX_NSYNTH") ||
          flunk("set MX_NSYNTH to the folder of the NSynth recordings")

      %{dir: Path.join(dir, "keyboard_electronic_098")}
    end

    test "--partials prints E4's bell partial at velocity 25 with how it falls", %{dir: dir} do
      path = Path.join(dir, "keyboard_electronic_098-064-025.wav")
      output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["#{path}:E4", "--partials", "12"]) end)

      assert [[ratio, fall]] =
               Regex.scan(
                 ~r/^ +[\d.]+ Hz +(7\.[0-6]\d\d)  between +-[\d.]+ dB  falls (\d+) dB\/s/m,
                 output, capture: :all_but_first)

      assert_in_delta String.to_float(ratio), 7.35, 0.05
      assert String.to_integer(fall) > 20
    end

    test "--partials names G#2's steady line near 4 kHz at velocity 127 as left out", %{dir: dir} do
      path = Path.join(dir, "keyboard_electronic_098-044-127.wav")
      output = capture_io(fn -> Mix.Tasks.Mx.Measure.run(["#{path}:Gs2", "--partials", "3"]) end)

      assert [[hz]] =
               Regex.scan(~r/left out, no strike or fall: +([\d.]+) Hz/, output,
                 capture: :all_but_first
               )

      assert_in_delta String.to_float(hz), 4108, 20
    end
  end

  defp held(f0, seconds) do
    for index <- 0..(round(seconds * 48_000) - 1) do
      time = index / 48_000
      level = min(time / 0.02, 1)

      0.1 * level *
        Enum.sum(for number <- 1..6, do: :math.sin(2 * :math.pi() * f0 * number * time) / number)
    end
  end

  # Partials at 1 and 3.9 times the lowest, fading 60 dB over `fade` seconds.
  defp hit(lowest, fade) do
    for index <- 0..(round(fade * 1.2 * 48_000) - 1) do
      time = index / 48_000

      partials =
        :math.sin(2 * :math.pi() * lowest * time) +
          0.5 * :math.sin(2 * :math.pi() * lowest * 3.9 * time)

      0.2 * partials * 10 ** (-3 * time / fade)
    end
  end

  defp synth_rows(output) do
    for [row] <- Regex.scan(~r/^\d+-\d+ Hz .* dB +[-+]\d+% .*$/m, output), do: row
  end

  # Partials at ratios of the lowest, each at its level, all fading 60 dB over `fade` seconds,
  # struck at once.
  defp partials_hit(lowest, partials, fade) do
    for index <- 0..(round(fade * 1.2 * 48_000) - 1) do
      time = index / 48_000

      sum =
        Enum.sum(
          for {ratio, level} <- partials,
              do: level * :math.sin(2 * :math.pi() * lowest * ratio * time)
        )

      0.2 * sum * 10 ** (-3 * time / fade)
    end
  end

  defp signed(value) do
    text = :erlang.float_to_binary(value / 1, decimals: 1)
    if value >= 0, do: "+" <> text, else: text
  end

  # Twelve harmonics at 1/number of the first, each fading 60 dB over 3 seconds.
  defp tone(f0, seconds) do
    for index <- 0..(round(seconds * 48_000) - 1) do
      time = index / 48_000

      0.1 *
        Enum.sum(for number <- 1..12, do: :math.sin(2 * :math.pi() * f0 * number * time) / number) *
        10 ** -time
    end
  end

  # A stroke of 150 ms whose level rises from 34 dB down and falls back, with harmonics at 1, 1
  # and 0.5, starting 100 cents flat for 40 ms.
  defp rub(hz) do
    count = round(0.15 * 48_000)

    {samples, _} =
      Enum.map_reduce(0..(count - 1), 0.0, fn index, phase ->
        bent = hz * 2 ** (-100 / 1200 * max(0.0, 1 - index / 48_000 / 0.04))
        level = 0.02 + 0.48 * :math.sin(:math.pi() * index / count) ** 2
        sample = :math.sin(phase) + :math.sin(2 * phase) + 0.5 * :math.sin(3 * phase)
        {level * sample / 2.5, phase + 2 * :math.pi() * bent / 48_000}
      end)

    samples
  end

  defp write_wav(ctx, name, samples) do
    path = Path.join(ctx.tmp_dir, name)
    data = for sample <- samples, into: <<>>, do: <<sample::float-little-32>>

    fmt =
      <<3::little-16, 1::little-16, 48_000::little-32, 192_000::little-32, 4::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
    path
  end
end
