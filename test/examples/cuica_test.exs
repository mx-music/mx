defmodule Mx.Examples.CuicaTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/cuica/solo.exs"

  test "the solo plays only the cuíca, four swung strokes to the beat, two low and two high" do
    output = print()
    assert Regex.scan(~r/^(\w+), 64 beats/m, output, capture: :all_but_first) == [["cuica"]]
    refute output =~ "sample "
    assert output =~ ~r/^beat 8 +play note: 64.15, vel: 0.95, scoop: 0.8, sustain: 0.3$/m
    assert output =~ ~r/^beat 8.3 +play note: 64.45, vel: 0.6, scoop: 0.3, sustain: 0.32$/m
    assert output =~ ~r/^beat 8.62 +play note: 76.8, vel: 0.7, scoop: 1.0, sustain: 0.19$/m
    assert output =~ ~r/^beat 8.81 +play note: 75.7, vel: 0.9, scoop: -1.1, sustain: 0.19$/m
  end

  test "every fourth beat stays low, a soft stroke leads into a high one, and the break slows to single strokes" do
    output = print()
    assert output =~ ~r/^beat 11.62 +play note: 64.25, vel: 0.9, scoop: 0.3, sustain: 0.19$/m
    assert output =~ ~r/^beat 21.62 +play note: 72.8, vel: 0.4, scoop: 1.0, sustain: 0.19$/m
    assert output =~ ~r/^beat 40 +play vel: 0.8, sustain: 0.42, scoop: 3.3$/m
    assert output =~ ~r/^beat 44 +play note: 80.5, vel: 0.9, sustain: 0.3$/m
    refute output =~ ~r/^beat 43.5 /m
  end

  test "the README points to the solo and lists the cuíca, and the synth designs license names its recordings" do
    readme = File.read!("README.md")
    assert readme =~ "examples/cuica/solo.exs"
    assert readme =~ "- `cuica` is the friction drum of samba"
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
