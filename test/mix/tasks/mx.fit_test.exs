defmodule Mix.Tasks.Mx.FitTest do
  # Fitting keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs
  alias Mx.Fit

  @moduletag :tmp_dir

  test "a step adds and subtracts, or multiplies and divides when it is a ratio" do
    assert Fit.step(10.0, %{step: 2.0, ratio: false}, 1) == 12.0
    assert Fit.step(10.0, %{step: 2.0, ratio: false}, -1) == 8.0
    assert_in_delta Fit.step(0.25, %{step: 1.2, ratio: true}, 1), 0.3, 1.0e-9
    assert_in_delta Fit.step(0.25, %{step: 1.2, ratio: true}, -1), 0.2083, 1.0e-4
  end

  @tag :engine
  test "searches from the starting values, printing each change it keeps and the best values",
       ctx do
    files = recordings(ctx, "slow", attack: 0.4)

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Fit.run(
          ["clarinet", "--vel", "0.6"] ++ files ++ ["--control", "attack=0.05:x2"]
        )
      end)

    assert output =~ ~r/^vel 0.6: 3 notes, left out 0 quiet stretches and 0 below c4$/m
    [_, start] = Regex.run(~r/^start ([\d.]+)$/m, output)
    assert output =~ ~r/^round 3$/m
    assert output =~ ~r/^  attack [\d.]+: [\d.]+$/m
    [_, best] = Regex.run(~r/^best ([\d.]+): attack=[\d.]+$/m, output)
    assert String.to_float(best) < String.to_float(start)
  end

  @tag :engine
  test "--check prints each dynamic's attack and bands, marking those far off", ctx do
    files = recordings(ctx, "soft", vel: 0.3)

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Fit.run(
          ["clarinet", "--vel", "1"] ++ files ++ ["--control", "attack=0.05:x2", "--check"]
        )
      end)

    assert output =~ ~r/^vel 1 attack [-+]\d+%/m
    assert output =~ ~r/^vel 1 250-400 Hz recordings [-+][\d.]+ dB, off by [-+][\d.]+ dB/m

    assert output =~
             ~r/^vel 1 \d+-\d+ Hz recordings [-+][\d.]+ dB, off by \+([7-9]|\d\d)\.\d\d dB <--$/m

    assert output =~ ~r/^score [\d.]+$/m
    refute output =~ "start"
  end

  @tag :engine
  test "--check needs no control, and prints the noise between the harmonics of each band", ctx do
    files = recordings(ctx, "plain", [])

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Fit.run(["clarinet", "--vel", "0.6"] ++ files ++ ["--check"])
      end)

    assert output =~ ~r/^vel 0.6 250-400 Hz recordings [-+][\d.]+ dB, off by [-+][\d.]+ dB/m
    assert output =~ ~r/^vel 0.6 250-400 Hz noise recordings [-+][\d.]+ dB, off by [-+][\d.]+ dB/m
    assert output =~ ~r/^score [\d.]+$/m
  end

  # Notes held six seconds that swell in over three reach their held level only if the synth holds
  # as long.
  @tag :engine
  test "renders each note as long as the recordings hold theirs", ctx do
    files = recordings(ctx, "long", sustain: 6, attack: 3)

    output =
      capture_io(fn ->
        Mix.Tasks.Mx.Fit.run(
          ["clarinet", "--vel", "0.6"] ++ files ++ ["--control", "attack=3:x2", "--check"]
        )
      end)

    [_, attack] = Regex.run(~r/^vel 0.6 attack ([-+]\d+)%/m, output)
    assert abs(String.to_integer(attack)) <= 10, output
  end

  @tag :engine
  test "--drone measures each file as one note, held from its first sample to its last, with no attack",
       ctx do
    file = drone(ctx)
    args = ["clarinet", "--vel", "0.6", file, "--check"]

    [_, split] =
      Regex.run(~r/^vel 0.6: (\d+) notes/m, capture_io(fn -> Mix.Tasks.Mx.Fit.run(args) end))

    assert String.to_integer(split) > 1

    output = capture_io(fn -> Mix.Tasks.Mx.Fit.run(args ++ ["--drone"]) end)
    assert output =~ ~r/^vel 0.6: 1 notes, left out 0 quiet stretches and 0 below c4$/m
    assert output =~ ~r/^vel 0.6 attack -$/m
    assert output =~ ~r/^vel 0.6 250-400 Hz recordings [-+][\d.]+ dB, off by [-+][\d.]+ dB/m
  end

  @tag :engine
  test "measures the recordings once, and again once a file changes", ctx do
    files = recordings(ctx, "again", [])
    args = ["clarinet", "--vel", "0.6"] ++ files ++ ["--control", "attack=0.05:x2", "--check"]

    refute capture_io(fn -> Mix.Tasks.Mx.Fit.run(args) end) =~ "from an earlier run"

    assert capture_io(fn -> Mix.Tasks.Mx.Fit.run(args) end) =~
             "using the recordings' figures from an earlier run"

    [first | _] = files
    path = String.replace(first, ~r/:\w+$/, "")
    File.touch!(path, System.os_time(:second) + 10)
    refute capture_io(fn -> Mix.Tasks.Mx.Fit.run(args) end) =~ "from an earlier run"
  end

  test "refuses an unknown synth, a control the synth does not take, and a file it cannot read",
       ctx do
    missing = Path.join(ctx.tmp_dir, "missing.wav")

    assert_raise Mix.Error, "unknown synth nosuch", fn ->
      Mix.Tasks.Mx.Fit.run([
        "nosuch",
        "--vel",
        "0.6",
        "#{missing}:C4",
        "--control",
        "attack=0.05:2"
      ])
    end

    assert_raise Mix.Error, "clarinet takes no control k_odd", fn ->
      Mix.Tasks.Mx.Fit.run([
        "clarinet",
        "--vel",
        "0.6",
        "#{missing}:C4",
        "--control",
        "k_odd=-2:2"
      ])
    end

    assert_raise Mix.Error, "cannot read #{missing}", fn ->
      Mix.Tasks.Mx.Fit.run([
        "clarinet",
        "--vel",
        "0.6",
        "#{missing}:C4",
        "--control",
        "attack=0.05:2"
      ])
    end

    assert_raise Mix.Error, ~r/^give --vel before its files/, fn ->
      Mix.Tasks.Mx.Fit.run(["clarinet", "#{missing}:C4", "--control", "attack=0.05:2"])
    end

    assert_raise Mix.Error, ~r/^give --control as a name, a starting value and a step/, fn ->
      Mix.Tasks.Mx.Fit.run([
        "clarinet",
        "--vel",
        "0.6",
        "#{missing}:C4",
        "--control",
        "attack=0.05"
      ])
    end
  end

  describe "--struck" do
    test "writes the figures of each recording in a folder, those --notes keeps", ctx do
      dir = struck_recordings(ctx, [{60, 25}, {60, 127}, {64, 75}])
      out = Path.join(ctx.tmp_dir, "piano.mxf")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run([
            "electric_piano",
            "--struck",
            dir,
            "--notes",
            "C4:D4",
            "--out",
            out
          ])
        end)

      assert output =~ "wrote the figures of 2 recordings to #{out}"
      assert <<"MXF1", times::little-16, _rest::binary>> = File.read!(out)
      assert times == 37
    end

    test "refuses a folder with no recordings named by note and velocity, and asks for --out, --check or --tour",
         ctx do
      assert_raise Mix.Error, ~r/found no recordings named like name-064-025.wav in/, fn ->
        Mix.Tasks.Mx.Fit.run(["electric_piano", "--struck", ctx.tmp_dir, "--check"])
      end

      assert_raise Mix.Error,
                   "give --out with a file to write the figures to, --check, or --tour with a file to write a tour to",
                   fn -> Mix.Tasks.Mx.Fit.run(["electric_piano", "--struck", ctx.tmp_dir]) end
    end

    test "a list splits a run into its notes, names those it did not find, and fits the rest",
         ctx do
      write_wav(ctx.tmp_dir, "run.wav", run([60, 62, 64]))
      list = write_list(ctx, ["C4:E4 64 run.wav"])
      out = Path.join(ctx.tmp_dir, "run.mxf")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(["electric_piano", "--struck", list, "--out", out])
        end)

      assert output =~ "run.wav: c4 d4 e4\n  not found: cs4 ds4\n"
      assert output =~ "wrote the figures of 3 recordings"
      assert {_times, [%{note: 60}, %{note: 62}, %{note: 64}]} = figures(File.read!(out))
    end

    test "a list leaves out a note that sounds an octave from its name, and fits a drum given in Hz at the nearest note",
         ctx do
      write_wav(ctx.tmp_dir, "octave.wav", struck_note(60, 2, harmonics: [2, 4, 6]))
      write_wav(ctx.tmp_dir, "drum.wav", struck_note(125.6, 2, ratios: [1, 1.5, 1.99, 2.44]))
      list = write_list(ctx, ["C3 127 octave.wav", "125.6Hz 127 drum.wav"])
      out = Path.join(ctx.tmp_dir, "drum.mxf")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(["timpani", "--struck", list, "--out", out])
        end)

      assert output =~ "octave.wav: \n  left out c3 at 0.0 s: sounds an octave above it\n"
      assert output =~ "drum.wav: b2\n"
      assert {_times, [%{note: 47, partials: partials}]} = figures(File.read!(out))
      ratios = partials |> Enum.map(& &1.ratio) |> Enum.sort() |> Enum.take(4)
      expected = Enum.map([1, 1.5, 1.99, 2.44], &(&1 * 125.6 / Mx.Signal.hz(47)))
      for {ratio, want} <- Enum.zip(ratios, expected), do: assert_in_delta(ratio, want, 0.002)
    end

    test "a note is fitted over its whole ring, and falls on at its last slope after it", ctx do
      write_wav(ctx.tmp_dir, "long.wav", struck_note(60, 12, harmonics: [1], fade: 6))
      list = write_list(ctx, ["C4 100 long.wav"])
      out = Path.join(ctx.tmp_dir, "long.mxf")
      capture_io(fn -> Mix.Tasks.Mx.Fit.run(["piano", "--struck", list, "--out", out]) end)

      {times, [%{partials: partials}]} = figures(File.read!(out))
      %{levels: levels, tail: tail} = Enum.find(partials, &(&1.harmonic == 1))
      at = Map.new(Enum.zip(times, levels))
      assert_in_delta at[8.8] - at[1.1], -6 * 7.7, 1.5
      assert_in_delta tail, -6, 0.5
      assert_in_delta at[28.0] - at[11.0], tail * 17, 0.5
    end

    test "--check prints how far each velocity is under the loudest at its note, for recordings that keep their levels",
         ctx do
      write_wav(ctx.tmp_dir, "loud.wav", struck_note(60, 2))
      write_wav(ctx.tmp_dir, "soft.wav", struck_note(60, 2, gain: 0.02))
      write_wav(ctx.tmp_dir, "loud_d4.wav", struck_note(62, 2))
      write_wav(ctx.tmp_dir, "soft_d4.wav", struck_note(62, 2, gain: 0.02))

      list =
        write_list(ctx, [
          "C4 127 kept loud.wav",
          "C4 40 kept soft.wav",
          "D4 127 loud_d4.wav",
          "D4 40 soft_d4.wav"
        ])

      output =
        capture_io(fn -> Mix.Tasks.Mx.Fit.run(["piano", "--struck", list, "--check"]) end)

      [recordings] = captures(~r/c4 vel 40: recordings (-[\d.]+) dB, synth -[\d.]+ dB/, output)
      assert_in_delta recordings, -20, 0.2
      refute output =~ "d4 vel 40: recordings"
    end

    test "--check prints each figure for the synth followed by the fit's own", ctx do
      write_wav(ctx.tmp_dir, "c4.wav", struck_note(60, 2))
      write_wav(ctx.tmp_dir, "d4.wav", struck_note(62, 2, fade: 10))
      list = write_list(ctx, ["C4 127 kept c4.wav", "D4 127 kept d4.wav"])

      output =
        capture_io(fn -> Mix.Tasks.Mx.Fit.run(["piano", "--struck", list, "--check"]) end)

      assert output =~ "piano against 2 recordings"

      assert output =~
               ~r/^\d+ partials within 30 dB of the loudest: \d+% within 2 dB over the first 20 ms, the fit \d+%, \d+% within 2 dB on average, the fit \d+%$/m

      assert output =~
               ~r/^\d+ partials 30 to 60 dB down: (\d+%|-) within 4 dB on average, the fit (\d+%|-)$/m

      assert output =~
               ~r/^ERB bands: [\d.]+ dB at the median note, the fit [\d.]+; [\d.]+ dB at the worst, [cd]4 vel 127, the fit [\d.]+$/m

      assert output =~
               ~r/^  [cd]4 vel 127, [\d.]+ harmonic \d+, [\d.]+ dB down: first 20 ms [-+][\d.]+ dB, the fit [-+][\d.]+, mean [\d.]+ dB, the fit [\d.]+$/m

      assert output =~
               ~r/^  [cd]4 vel 127: [\d.]+ dB, the fit [\d.]+; \d+ of its partials within 30 dB of the loudest more than 2 dB off, the fit \d+$/m
    end

    test "--check --own prints the fit's figures alone, the same whichever synth is named, and twice as fast the second time",
         ctx do
      write_wav(ctx.tmp_dir, "c4.wav", struck_note(60, 2))
      write_wav(ctx.tmp_dir, "e4.wav", struck_note(64, 2, fade: 10))
      list = write_list(ctx, ["C4 127 kept c4.wav", "E4 40 kept e4.wav"])

      run =
        &capture_io(fn -> Mix.Tasks.Mx.Fit.run([&1, "--struck", list, "--check", "--own"]) end)

      {first, piano} = :timer.tc(fn -> run.("piano") end)
      {second, marimba} = :timer.tc(fn -> run.("marimba") end)

      assert piano =~ "the fit's own render against 2 recordings"

      assert piano =~
               ~r/^\d+ partials within 30 dB of the loudest: \d+% within 2 dB over the first 20 ms, \d+% within 2 dB on average$/m

      refute piano =~ "the fit "
      refute piano =~ "piano"
      assert marimba == piano
      assert second < first / 2
    end

    test "--check --note prints one recording frame by frame every 5 ms, and --csv writes the same figures",
         ctx do
      write_wav(ctx.tmp_dir, "c4.wav", struck_note(60, 2))
      write_wav(ctx.tmp_dir, "d4.wav", struck_note(62, 2))
      list = write_list(ctx, ["C4 127 kept c4.wav", "D4 127 kept d4.wav"])
      csv = Path.join(ctx.tmp_dir, "c4.csv")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(
            ~w(piano --struck #{list} --check --note C4 --vel 127 --csv #{csv})
          )
        end)

      assert output =~
               ~r/^c4 vel 127: 261\.\d\d Hz, -?\d+\.\d cents from c4, struck at 0\.2\d\d s in c4.wav$/m

      assert output =~ ~r/^ms +-5 +0 +5 .* 95 +100$/m
      refute output =~ "partials within 30 dB"
      [_, partial] = Regex.run(~r/^1\.000 harmonic 1\n((?:  .*\n){5})/m, output)

      names =
        Regex.scan(~r/^ +(recording|synth|the fit|sines|noise) /m, partial,
          capture: :all_but_first
        )

      assert names == [["recording"], ["synth"], ["the fit"], ["sines"], ["noise"]]
      assert length(String.split(hd(String.split(partial, "\n")))) == 23
      assert output =~ ~r/^ERB bands\n50-\d+ Hz\n  recording /m

      printed =
        for line <- String.split(output, "\n"),
            [_, row, figures] <- [
              Regex.run(~r/^ +(recording|synth|the fit|sines|noise) +(.*)$/, line)
            ],
            figure <- String.split(figures),
            do: {String.replace(row, "the ", ""), if(figure == "-", do: "", else: figure)}

      [header | lines] = csv |> File.read!() |> String.split("\n", trim: true)
      assert header == "kind,at,row,ms,db"

      assert Enum.map(
               lines,
               &(&1
                 |> String.split(",")
                 |> Enum.slice(2, 3)
                 |> then(fn [row, _ms, db] -> {row, db} end))
             ) == printed

      assert lines
             |> Enum.map(&(&1 |> String.split(",") |> Enum.at(3)))
             |> Enum.uniq()
             |> length() == 22
    end

    test "--check --note --until 1 --own prints 24 times to a second, no synth, the same whichever synth is named",
         ctx do
      write_wav(ctx.tmp_dir, "c4.wav", struck_note(60, 2))
      list = write_list(ctx, ["C4 127 kept c4.wav"])
      args = ~w(--struck #{list} --check --note C4 --vel 127 --until 1 --own)
      piano = capture_io(fn -> Mix.Tasks.Mx.Fit.run(["piano" | args]) end)

      [_, times] = Regex.run(~r/^ms +(.*)$/m, piano)
      times = String.split(times)
      assert length(times) == 24 and List.first(times) == "-5" and List.last(times) == "1000"
      refute piano =~ "synth"
      assert capture_io(fn -> Mix.Tasks.Mx.Fit.run(["marimba" | args]) end) == piano
    end

    test "--check --note refuses a note and velocity the list does not hold, naming the nearest",
         ctx do
      write_wav(ctx.tmp_dir, "c4.wav", struck_note(60, 2))
      write_wav(ctx.tmp_dir, "d4.wav", struck_note(62, 2))
      list = write_list(ctx, ["C4 127 kept c4.wav", "D4 100 kept d4.wav"])

      assert_raise Mix.Error, "no recording of c8 vel 100; the nearest is d4 vel 100", fn ->
        Mix.Tasks.Mx.Fit.run(~w(piano --struck #{list} --check --note C8 --vel 100))
      end

      assert_raise Mix.Error, "--note and --vel go together, with --check", fn ->
        Mix.Tasks.Mx.Fit.run(~w(piano --struck #{list} --check --note C4))
      end

      assert_raise Mix.Error, "--until and --csv need --note and --vel", fn ->
        Mix.Tasks.Mx.Fit.run(~w(piano --struck #{list} --check --until 1))
      end
    end

    test "refuses --own without --check", ctx do
      write_wav(ctx.tmp_dir, "c4.wav", struck_note(60, 2))
      list = write_list(ctx, ["C4 127 kept c4.wav"])

      assert_raise Mix.Error, "--own needs --check", fn ->
        Mix.Tasks.Mx.Fit.run(["piano", "--struck", list, "--out", "x.mxf", "--own"])
      end
    end

    test "refuses a list line it cannot read", ctx do
      list = write_list(ctx, ["# the loud C4", "C4 loud.wav"])

      assert_raise Mix.Error, "cannot read line 2: C4 loud.wav", fn ->
        Mix.Tasks.Mx.Fit.run(["piano", "--struck", list, "--check"])
      end
    end

    test "--tour writes each recording followed by the synth, each brought to the same level",
         ctx do
      dir = struck_recordings(ctx, [{60, 25}, {62, 75}, {64, 127}])
      tour = Path.join(ctx.tmp_dir, "tour.wav")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run([
            "electric_piano",
            "--struck",
            dir,
            "--tour",
            tour,
            "--count",
            "2"
          ])
        end)

      assert output =~ "wrote a tour of 2 recordings, each followed by electric_piano, to #{tour}"
      {:ok, %{rate: rate, samples: samples}} = Mx.Audio.read(tour)
      assert_in_delta length(samples) / rate, 2 * 2 * (2.9 + 1), 0.05

      [recording, synth] =
        for part <- [0, 1] do
          start = round(part * 3.9 * rate)
          half = Enum.slice(samples, start, round(0.55 * rate))
          10 * :math.log10(Enum.sum(Enum.map(half, &(&1 * &1))) / length(half))
        end

      assert_in_delta recording, synth, 0.5
    end
  end

  # The keyboard_electronic_098 and guitar_electronic_028 instruments of the test set of Google's
  # NSynth dataset, from https://magenta.tensorflow.org/datasets/nsynth, in the folder MX_NSYNTH
  # names, which holds one folder an instrument.
  describe "the NSynth recordings" do
    @describetag :nsynth

    setup do
      dir =
        System.get_env("MX_NSYNTH") ||
          flunk("set MX_NSYNTH to the folder of the NSynth recordings")

      %{dir: Path.join(dir, "keyboard_electronic_098"), nsynth: dir}
    end

    @tag timeout: 600_000
    test "--check finds electric_piano within 2 dB partial by partial and 1.5 dB in ERB bands from E1 to E6",
         %{dir: dir} do
      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(["electric_piano", "--struck", dir, "--notes", "E1:E6", "--check"])
        end)

      assert output =~ "electric_piano against 75 recordings"
      assert_close(output)
    end

    @tag timeout: 600_000
    test "--check finds electric_guitar within 2 dB partial by partial and 1.5 dB in ERB bands from E2 to D6",
         %{nsynth: nsynth} do
      dir = Path.join(nsynth, "guitar_electronic_028")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run([
            "electric_guitar",
            "--struck",
            dir,
            "--notes",
            "E2:D6",
            "--check"
          ])
        end)

      assert output =~ "electric_guitar against 46 recordings"
      assert_close(output)
    end

    test "C#5 at velocity 127 loses its 7th harmonic by 0.5 seconds and holds its fundamental at 2 seconds",
         %{dir: dir} do
      {:ok, recordings} = Mx.Fit.Struck.recordings(dir, [73])
      recording = Enum.find(recordings, &(&1.velocity == 127))
      [%{partials: partials}] = Mx.Fit.Struck.check(:electric_piano, [recording])

      %{floor: floor, levels: levels} = Enum.find(partials, &(&1.harmonic == 7))
      {0.5, _recorded, rendered} = List.keyfind(levels, 0.5, 0)
      assert rendered < floor + 10

      %{levels: levels} = Enum.find(partials, &(&1.harmonic == 1))
      {2.0, recorded, rendered} = List.keyfind(levels, 2.0, 0)
      assert_in_delta rendered, recorded, 3
    end

    @tag timeout: 600_000
    test "fits the recordings of two folders into one synth, bass_electronic_025's and bass_electronic_027's",
         %{nsynth: nsynth} = ctx do
      out = Path.join(ctx.tmp_dir, "deep_bass.mxf")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run([
            "deep_bass",
            "--struck",
            Path.join(nsynth, "bass_electronic_025"),
            "--struck",
            Path.join(nsynth, "bass_electronic_027"),
            "--out",
            out
          ])
        end)

      assert output =~ "wrote the figures of 110 recordings"
    end

    test "--tour writes eight recordings of keyboard_electronic_098, each followed by electric_piano",
         %{dir: dir} = ctx do
      tour = Path.join(ctx.tmp_dir, "tour.wav")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run([
            "electric_piano",
            "--struck",
            dir,
            "--tour",
            tour,
            "--count",
            "8"
          ])
        end)

      assert output =~ "wrote a tour of 8 recordings, each followed by electric_piano"
      {:ok, %{rate: rate, samples: samples}} = Mx.Audio.read(tour)
      assert_in_delta length(samples) / rate, 8 * 2 * (2.9 + 1), 0.05
    end
  end

  # The University of Iowa Electronic Music Studios' marimba, xylophone and vibraphone recordings,
  # from https://theremin.music.uiowa.edu/MISmarimba.html and the pages beside it, in the folders
  # MX_IOWA_MARIMBA, MX_IOWA_XYLOPHONE and MX_IOWA_VIBRAPHONE name.
  describe "the Iowa mallet recordings" do
    @describetag :iowa

    setup do
      folder = fn name ->
        System.get_env(name) || flunk("set #{name} to the folder of its Iowa recordings")
      end

      %{
        marimba: folder.("MX_IOWA_MARIMBA"),
        xylophone: folder.("MX_IOWA_XYLOPHONE"),
        vibraphone: folder.("MX_IOWA_VIBRAPHONE")
      }
    end

    @tag timeout: 600_000
    test "fits the 36 notes of the marimba from C4 to B4 at pp, mf and ff, quieter at pp by as much as the recordings",
         %{marimba: marimba} = ctx do
      list =
        write_list(ctx, [
          "C4:B4 40 kept #{marimba}/Marimba.yarn.pp.C4B4.aif",
          "C4:B4 80 kept #{marimba}/Marimba.yarn.mf.C4B4.aif",
          "C4:B4 127 kept #{marimba}/Marimba.yarn.ff.C4B4.aif"
        ])

      out = Path.join(ctx.tmp_dir, "marimba.mxf")

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(["marimba", "--struck", list, "--out", out, "--check"])
        end)

      assert output =~ "wrote the figures of 36 recordings"
      assert output =~ "marimba against 36 recordings"
      [recordings] = captures(~r/c4 vel 40: recordings (-[\d.]+) dB/, output)
      {times, fitted} = figures(File.read!(out))
      at = fn velocity -> Enum.find(fitted, &(&1.note == 60 and &1.velocity == velocity)) end
      assert_in_delta loudness(times, at.(40)) - loudness(times, at.(127)), recordings, 1.5
    end

    @tag timeout: 600_000
    test "--check --note C2 --vel 80 prints the mf C2's pitch, its fundamental and 4th partial frame by frame, with sines and noise adding up",
         %{marimba: marimba} = ctx do
      list = write_list(ctx, ["C2:B2 80 kept #{marimba}/Marimba.yarn.mf.C2B2.aif"])

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(~w(marimba --struck #{list} --check --note C2 --vel 80))
        end)

      assert output =~
               ~r/^c2 vel 80: 65\.\d\d Hz, -\d\.\d cents from c2, struck at \d\.\d{3} s in Marimba.yarn.mf.C2B2.aif$/m

      for partial <- ["1\\.000 harmonic 1", "(3\\.9|4\\.0)\\d\\d harmonic 4"] do
        assert output =~
                 ~r/^#{partial}\n  recording( +[-\d.]+){22}\n  synth( +[-\d.]+){22}\n  the fit( +[-\d.]+){22}\n/m
      end

      {:ok, recordings, _lines} = Mx.Fit.Struck.listed(list)
      recording = Enum.find(recordings, &(&1.note == 36))
      frames = Mx.Fit.Struck.frames(nil, recording, for(step <- 0..21, do: (5 * step - 5) / 1000))

      for rows <- frames.partials ++ frames.bands,
          [fit, sines, noise] =
            Enum.map(~w(fit sines noise), &elem(List.keyfind(rows.rows, &1, 0), 1)),
          {fit, sines, noise} <- Enum.zip([fit, sines, noise]),
          fit > rows.floor and abs(sines - noise) > 20 do
        assert_in_delta 10 * :math.log10(10 ** (sines / 10) + 10 ** (noise / 10)), fit, 1
      end
    end

    test "splits the xylophone's mf run from C6 to B6 into its twelve notes, and names the vibraphone's pp C#6 as not found",
         %{xylophone: xylophone, vibraphone: vibraphone} = ctx do
      list =
        write_list(ctx, [
          "C6:B6 80 #{xylophone}/xylophone.rosewood.mf.C6B6.aif",
          "C6:F6 40 #{vibraphone}/Vibraphone.sustain.pp.C6F6.aif"
        ])

      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(["xylophone", "--struck", list, "--check"])
        end)

      assert output =~
               "xylophone.rosewood.mf.C6B6.aif: c6 cs6 d6 ds6 e6 f6 fs6 g6 gs6 a6 as6 b6\n"

      assert output =~ "Vibraphone.sustain.pp.C6F6.aif: c6 d6 ds6 e6 f6\n  not found: cs6\n"
      assert output =~ "xylophone against 17 recordings"
    end
  end

  # The folk harp and the Steinway B of the Versilian Community Sample Library, in the folder MX_VCSL
  # names.
  describe "the VCSL harp and piano recordings" do
    @describetag :vcsl

    setup do
      dir = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      %{dir: Path.join(dir, "Chordophones")}
    end

    test "leaves out the folk harp's file named C3 as an octave above it, and fits it as C4",
         %{dir: dir} = ctx do
      path = Path.join(dir, "Composite Chordophones/Folk Harp/EWHarp_Normal_C3_v3_RR1.wav")
      list = write_list(ctx, ["C3 127 #{path}", "C4 127 #{path}"])
      out = Path.join(ctx.tmp_dir, "harp.mxf")

      output =
        capture_io(fn -> Mix.Tasks.Mx.Fit.run(["harp", "--struck", list, "--out", out]) end)

      assert output =~
               "EWHarp_Normal_C3_v3_RR1.wav: \n  left out c3 at 0.0 s: sounds an octave above it\n"

      assert output =~ "EWHarp_Normal_C3_v3_RR1.wav: c4\n"
      assert {_times, [%{note: 60}]} = figures(File.read!(out))
    end

    @tag timeout: 600_000
    test "follows the Steinway's C4 past 10 seconds, and checks the whole note",
         %{dir: dir} = ctx do
      path =
        Path.join(dir, "Zithers/Grand Piano, Steinway B/NoSus/JHPiano_NoSus_Close_C4_vl3_rr1.wav")

      list = write_list(ctx, ["C4 90 #{path}"])
      out = Path.join(ctx.tmp_dir, "piano.mxf")
      capture_io(fn -> Mix.Tasks.Mx.Fit.run(["piano", "--struck", list, "--out", out]) end)

      {:ok, [recording], _lines} = Mx.Fit.Struck.listed(list)
      [%{partials: partials}] = Mx.Fit.Struck.check(:piano, [recording])
      %{levels: checked} = Enum.find(partials, &(&1.harmonic == 1))
      assert {17.0, _recorded, _rendered} = List.keyfind(checked, 17.0, 0)

      {times, [%{partials: fitted}]} = figures(File.read!(out))
      %{levels: levels} = Enum.find(fitted, &(&1.harmonic == 1))

      for second <- [11.0, 14.0] do
        {^second, recorded, _rendered} = List.keyfind(checked, second, 0)
        {3.0, from, _rendered} = List.keyfind(checked, 3.0, 0)
        fell = level_at(times, levels, second) - level_at(times, levels, 3.0)
        assert_in_delta fell, recorded - from, 1.5
      end
    end
  end

  # The timpani of VSCO 2 Community Edition, from https://github.com/sgossner/VSCO-2-CE, in the
  # folder Timpani of the folder MX_VSCO_PERCUSSION names.
  describe "the VSCO 2 timpani recordings" do
    @describetag :vsco

    setup do
      dir =
        System.get_env("MX_VSCO_PERCUSSION") ||
          flunk("set MX_VSCO_PERCUSSION to the folder of the VSCO 2 percussion")

      %{dir: Path.join(dir, "Timpani")}
    end

    test "fits drum 3's hit at its lowest partial, 125.6 Hz, under B2", %{dir: dir} = ctx do
      list = write_list(ctx, ["125.6Hz 127 kept #{dir}/Timpani3_Hit_v4_rr1_Sum.wav"])
      out = Path.join(ctx.tmp_dir, "timpani.mxf")

      output =
        capture_io(fn -> Mix.Tasks.Mx.Fit.run(["timpani", "--struck", list, "--out", out]) end)

      assert output =~ "Timpani3_Hit_v4_rr1_Sum.wav: b2\n"
      assert {_times, [%{note: 47, partials: partials}]} = figures(File.read!(out))
      lowest = partials |> Enum.map(& &1.ratio) |> Enum.min()
      assert_in_delta lowest * Mx.Signal.hz(47), 125.6, 1
    end
  end

  # The University of Iowa Electronic Music Studios' Bb clarinet recordings, from
  # https://theremin.music.uiowa.edu/MISBbclarinet.html, in the folder MX_IOWA_CLARINET names.
  describe "the Iowa clarinet recordings" do
    @describetag :iowa

    setup do
      dir =
        System.get_env("MX_IOWA_CLARINET") ||
          flunk("set MX_IOWA_CLARINET to the folder of the Iowa Bb clarinet recordings")

      %{dir: dir}
    end

    test "leaves out the seven quiet stretches between notes at pp", %{dir: dir} do
      output =
        capture_io(fn ->
          Mix.Tasks.Mx.Fit.run(
            ["clarinet", "--vel", "0.3"] ++
              iowa(dir, "pp") ++ ["--from", "160", "--control", "attack=0.01:x2", "--check"]
          )
        end)

      assert output =~ "vel 0.3: 41 notes, left out 7 quiet stretches and 0 below d3"
      [_, level] = Regex.run(~r/^vel 0.3 250-400 Hz recordings \+([\d.]+) dB/m, output)
      assert_in_delta String.to_float(level), 8.9, 1
    end

    @tag timeout: 600_000
    test "searches over pp, mf and ff to a best score no higher than the start", %{dir: dir} do
      args =
        ["clarinet"] ++
          Enum.flat_map([{"0.3", "pp"}, {"0.6", "mf"}, {"1", "ff"}], fn {vel, dynamic} ->
            ["--vel", vel] ++ iowa(dir, dynamic)
          end) ++ ["--from", "160", "--control", "attack=0.01:x2"]

      output = capture_io(fn -> Mix.Tasks.Mx.Fit.run(args) end)
      [_, start] = Regex.run(~r/^start ([\d.]+)$/m, output)
      [_, best] = Regex.run(~r/^best ([\d.]+): attack=[\d.]+$/m, output)
      assert String.to_float(best) <= String.to_float(start)
    end
  end

  defp iowa(dir, dynamic, prefix \\ "BbClar") do
    for path <- Path.wildcard(Path.join(dir, "#{prefix}.#{dynamic}.*.aiff")) do
      [first] = Regex.run(~r/\.([A-G]b?\d)[A-G]?b?\d?\.aiff$/, path, capture: :all_but_first)
      "#{path}:#{first}"
    end
  end

  # The clarinet's own notes C4, C#4 and D4 at vel 0.6 unless given, each held two seconds unless
  # given, in a file of its own.
  defp recordings(ctx, name, opts) do
    dir = Path.join(ctx.tmp_dir, name)
    File.mkdir_p!(dir)

    for note <- 60..62 do
      given = Keyword.merge([note: note, vel: 0.6, sustain: 2], opts)
      sound = Mxs.render_note(:clarinet, given, given[:sustain] + 1, dir, [])
      path = write_wav(dir, "#{note}.wav", sound)
      "#{path}:#{note}"
    end
  end

  # The clarinet's C4 held eight seconds, jumping to its full level every 1.5 seconds and fading
  # 25 dB before the next, as a drone is plucked again and again.
  defp drone(ctx) do
    dir = Path.join(ctx.tmp_dir, "drone")
    File.mkdir_p!(dir)
    sound = Mxs.render_note(:clarinet, [note: 60, vel: 0.6, sustain: 8], 8, dir, [])
    rate = Mxs.render_rate()

    plucked =
      Enum.with_index(sound, fn sample, index ->
        since = :math.fmod(index / rate, 1.5)
        sample * (0.05 + 0.95 * :math.exp(-since / 0.3))
      end)

    path = write_wav(dir, "drone.wav", plucked)
    "#{path}:C4"
  end

  # Struck notes in a folder of their own, named as NSynth names its recordings: each note's first
  # four harmonics fading over two seconds.
  defp struck_recordings(ctx, notes) do
    dir = Path.join(ctx.tmp_dir, "struck")
    File.mkdir_p!(dir)
    rate = Mxs.render_rate()

    for {note, velocity} <- notes do
      hz = 440 * 2 ** ((note - 69) / 12)

      sound =
        for index <- 0..(3 * rate - 1) do
          time = index / rate
          wave = Enum.sum(for n <- 1..4, do: :math.sin(2 * :math.pi() * hz * n * time) / n)
          0.2 * wave * 10 ** (-1.5 * time)
        end

      name = :io_lib.format("piano-~3..0B-~3..0B.wav", [note, velocity]) |> to_string()
      write_wav(dir, name, sound)
    end

    dir
  end

  # The shares --check prints are within the criteria of mx-00162, and it names the ten partials
  # and the ten notes furthest off.
  defp assert_close(output) do
    [strike, mean] =
      captures(
        ~r/partials within 30 dB of the loudest: (\d+)% within 2 dB over the first 20 ms, the fit \d+%, (\d+)% within 2 dB on average, the fit \d+%/,
        output
      )

    assert strike >= 90 and mean >= 90
    [weaker] = captures(~r/partials 30 to 60 dB down: (\d+)% within 4 dB on average/, output)
    assert weaker >= 80

    [median, worst] =
      captures(
        ~r/ERB bands: ([\d.]+) dB at the median note, the fit [\d.]+; ([\d.]+) dB at the worst/,
        output
      )

    assert median <= 1.5 and worst <= 3

    [_, partials] = String.split(output, "the ten partials furthest off on average:\n")
    [partials, notes] = String.split(partials, "the ten notes furthest off in ERB bands:\n")

    assert length(
             Regex.scan(
               ~r/^  [a-g]s?\d vel \d+, [\d.]+ (harmonic \d+|between), [\d.]+ dB down: first 20 ms [-+][\d.]+ dB, the fit [-+][\d.]+, mean [\d.]+ dB, the fit [\d.]+$/m,
               partials
             )
           ) == 10

    assert length(
             Regex.scan(
               ~r/^  [a-g]s?\d vel \d+: [\d.]+ dB, the fit [\d.]+; \d+ of its partials/m,
               notes
             )
           ) ==
             10
  end

  # A struck note at a MIDI note or a frequency in Hz: its partials at whole multiples or at
  # `ratios`, each 1/n of the first, fading `fade` dB a second, after 0.2 seconds of silence.
  defp struck_note(note, seconds, opts \\ []) do
    rate = Mxs.render_rate()
    hz = if is_integer(note), do: Mx.Signal.hz(note), else: note
    ratios = opts[:ratios] || opts[:harmonics] || [1, 2, 3, 4]
    gain = Keyword.get(opts, :gain, 0.2)
    fade = Keyword.get(opts, :fade, 30)

    List.duplicate(0.0, round(0.2 * rate)) ++
      for index <- 0..round(seconds * rate - 1) do
        time = index / rate

        wave =
          ratios
          |> Enum.with_index(1)
          |> Enum.map(fn {ratio, n} -> :math.sin(2 * :math.pi() * hz * ratio * time) / n end)
          |> Enum.sum()

        gain * wave * 10 ** (-fade * time / 20) * min(time / 0.002, 1)
      end
  end

  # Notes one after another, each ringing 1.5 seconds.
  defp run(notes), do: Enum.flat_map(notes, &struck_note(&1, 1.5))

  defp write_list(ctx, lines) do
    path = Path.join(ctx.tmp_dir, "list.txt")
    File.write!(path, Enum.join(lines, "\n") <> "\n")
    path
  end

  # The times of figures as mxs reads them, and each recording's note, velocity and partials,
  # each partial with its ratio, harmonic, last slope and levels in dB.
  defp figures(<<"MXF1", count::little-16, rest::binary>>) do
    {time_bytes, level_bytes} = {count * 4, count * 2}
    <<times::binary-size(^time_bytes), bands::little-16, rest::binary>> = rest
    times = for <<time::float-little-32 <- times>>, do: Float.round(time, 4)
    {edge_bytes, noise_bytes} = {bands * 8, bands * (count + 1) * 2}
    <<_edges::binary-size(^edge_bytes), recordings::little-16, rest::binary>> = rest

    {recordings, <<>>} =
      Enum.map_reduce(1..recordings//1, rest, fn _, rest ->
        <<note, velocity, partials::little-16, rest::binary>> = rest

        {partials, rest} =
          Enum.map_reduce(1..partials//1, rest, fn _, rest ->
            <<ratio::float-little-32, harmonic::little-16, tail::little-signed-16,
              levels::binary-size(^level_bytes), rest::binary>> = rest

            levels = for <<level::little-signed-16 <- levels>>, do: level / 10
            {%{ratio: ratio, harmonic: harmonic, tail: tail / 10, levels: levels}, rest}
          end)

        <<_noise::binary-size(^noise_bytes), rest::binary>> = rest
        {%{note: note, velocity: velocity, partials: partials}, rest}
      end)

    {times, recordings}
  end

  # A level of figures between their times, in straight lines.
  defp level_at(times, levels, time) do
    {earlier, later} = times |> Enum.zip(levels) |> Enum.split_while(fn {t, _} -> t <= time end)
    {t0, l0} = List.last(earlier)
    {t1, l1} = List.first(later)
    l0 + (time - t0) / (t1 - t0) * (l1 - l0)
  end

  # The power of a recording's partials over its first half second, in dB, as the check sums it.
  defp loudness(times, %{partials: partials}) do
    total =
      for %{levels: levels} <- partials, step <- 0..199, reduce: 0 do
        sum -> sum + 10 ** (level_at(times, levels, step * 0.0025) / 10)
      end

    10 * :math.log10(total)
  end

  defp captures(pattern, output) do
    for value <- Regex.run(pattern, output, capture: :all_but_first) do
      if value =~ ".", do: String.to_float(value), else: String.to_integer(value)
    end
  end

  defp write_wav(dir, name, samples) do
    path = Path.join(dir, name)
    rate = Mxs.render_rate()
    data = for sample <- samples, into: <<>>, do: <<sample::float-little-32>>

    fmt =
      <<3::little-16, 1::little-16, rate::little-32, rate * 4::little-32, 4::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
    path
  end
end
