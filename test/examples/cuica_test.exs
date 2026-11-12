defmodule Mx.Examples.CuicaTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/cuica/solo.exs"

  test "the solo plays only the cuíca, a stroke every sixteenth, high on the beats and low between" do
    output = print()
    assert Regex.scan(~r/^(\w+), 64 beats/m, output, capture: :all_but_first) == [["cuica"]]
    refute output =~ "sample "
    assert output =~ ~r/^beat 0 +play note: 79, vel: 0.8$/m
    assert output =~ ~r/^beat 0.25 +play note: 65, vel: 0.55$/m
  end

  test "the high strokes cross the beat, and the phrases climb from the low note to the high one" do
    output = print()
    assert output =~ ~r/^beat 16.75 +play note: 79, vel: 0.8$/m
    assert output =~ ~r/^beat 32 +play note: 65, vel: 0.45$/m
    assert output =~ ~r/^beat 33 +play note: 73, vel: 0.65$/m
    assert output =~ ~r/^beat 33.75 +play note: 79, vel: 0.8$/m
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
