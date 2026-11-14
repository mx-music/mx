defmodule Mx.Examples.CuicaTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/solo/cuica.exs"

  test "the solo plays only the cuíca, the fundamental on each beat and three medium strokes after it" do
    output = print()
    assert Regex.scan(~r/^(\w+), 64 beats/m, output, capture: :all_but_first) == [["cuica"]]
    refute output =~ "sample "
    assert output =~ ~r/^beat 0 +play note: 64.15, vel: 0.95, scoop: 0.8, sustain: 0.25$/m
    assert output =~ ~r/^beat 0.25 +play note: 75.7, vel: 0.85, scoop: -1.1, sustain: 0.21$/m
    assert output =~ ~r/^beat 0.46 +play note: 76.8, vel: 0.7, scoop: 1.0, sustain: 0.25$/m
    assert output =~ ~r/^beat 0.71 +play note: 75.7, vel: 0.85, scoop: -1.1, sustain: 0.29$/m
  end

  test "the roda's pattern holds a high stroke over the barline and comes back down through three fundamental ones" do
    output = print()
    assert output =~ ~r/^beat 9 +play note: 64.15, vel: 0.95, scoop: 0.8, sustain: 0.46$/m
    assert output =~ ~r/^beat 9.46 +play note: 78.4, vel: 0.9, sustain: 0.79$/m
    refute output =~ ~r/^beat 10 /m
    assert output =~ ~r/^beat 10.25 +play note: 64.25, vel: 0.85, scoop: 0.3, sustain: 0.46$/m
    assert output =~ ~r/^beat 10.71 +play note: 64.25, vel: 0.85, scoop: 0.3, sustain: 0.29$/m
    assert output =~ ~r/^beat 11 +play note: 64.15, vel: 0.95, scoop: 0.8, sustain: 0.25$/m
  end

  test "the variation rests on the beat, answers with three high strokes and goes on in syncopated medium ones" do
    output = print()
    refute output =~ ~r/^beat 24 /m
    assert output =~ ~r/^beat 24.25 +play note: 80.5, vel: 0.9, sustain: 0.21$/m
    assert output =~ ~r/^beat 24.71 +play note: 80.5, vel: 0.9, sustain: 0.29$/m
    assert output =~ ~r/^beat 25.46 +play note: 76.8, vel: 0.7, scoop: 1.0, sustain: 0.54$/m
    assert output =~ ~r/^beat 26 +play note: 76.8, vel: 0.7, scoop: 1.0, sustain: 0.71$/m
    refute output =~ ~r/^beat 27 /m
    assert output =~ ~r/^beat 27.25 +play note: 75.7, vel: 0.85, scoop: -1.1, sustain: 0.46$/m
  end

  test "the examples guide points to the solo and lists the cuíca, and the synth designs license names its recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/cuica.exs"
    assert File.read!("documentation/instruments.md") =~ "- `cuica` is the friction drum of samba"
    notes = File.read!("LICENSE-designs.md")
    assert notes =~ "reinsamba's pack \"Cuica\" on Freesound"
    refute notes =~ "Cuica01.ogg"
  end

  @tag :tmp_dir
  @tag timeout: 300_000
  test "a minute of the solo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")

    capture_io(:stderr, fn ->
      capture_io(fn -> assert :ok = Mx.Render.render(@song, out, seconds: 60) end)
    end)

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -1
    assert Mx.Recording.seconds(out) >= 60
  end

  defp print, do: capture_io(fn -> Mix.Tasks.Mx.Print.run([@song]) end)
end
