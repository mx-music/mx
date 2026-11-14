defmodule Mx.Examples.TamborimTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/tamborim/solo.exs"

  test "the solo plays only the tamborim, starting with the teleco-teco's sixteenths off the beat" do
    output = print()
    assert Regex.scan(~r/^(\w+), 64 beats/m, output, capture: :all_but_first) == [["tamborim"]]
    refute output =~ "sample "
    assert output =~ ~r/^beat 0 +play note: 72.03, vel: 0.85$/m
    assert output =~ ~r/^beat 1.25 +play note: 72.03, vel: 0.7$/m
    refute output =~ ~r/^beat 0.25 /m
  end

  test "the carreteiro strikes every sixteenth, accenting the teleco-teco's, and the virada swells in thirty-seconds" do
    output = print()
    assert output =~ ~r/^beat 16.25 +play note: 72.03, vel: 0.4$/m
    assert output =~ ~r/^beat 16.5 +play note: 72.03, vel: 0.8$/m
    assert output =~ ~r/^beat 46.125 +play note: 72.03, vel: 0.33$/m
    assert output =~ ~r/^beat 47.875 +play note: 72.03, vel: 0.75$/m
  end

  test "the examples guide points to the solo and lists the tamborim, and the synth designs license names its recording" do
    assert File.read!("documentation/examples.md") =~ "examples/tamborim/solo.exs"

    assert File.read!("documentation/instruments.md") =~
             "- `tamborim` is the small high drum of samba"

    notes = File.read!("LICENSE-designs.md")
    assert notes =~ "uploaded to Wikimedia Commons by Samba-x in 2014 under CC BY-SA 3.0"
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
