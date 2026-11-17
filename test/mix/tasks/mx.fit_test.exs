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
      assert times == 27
    end

    test "refuses a folder with no recordings named by note and velocity, and asks for --out or --check",
         ctx do
      assert_raise Mix.Error, ~r/found no recordings named like name-064-025.wav in/, fn ->
        Mix.Tasks.Mx.Fit.run(["electric_piano", "--struck", ctx.tmp_dir, "--check"])
      end

      assert_raise Mix.Error, "give --out with a file to write the figures to, or --check", fn ->
        Mix.Tasks.Mx.Fit.run(["electric_piano", "--struck", ctx.tmp_dir])
      end
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
