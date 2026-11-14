defmodule Mx.Examples.CaxixiTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/solo/caxixi.exs"

  test "the solo plays only the caxixi, leaning on angola's open note" do
    output = print()
    assert Regex.scan(~r/^(\w+), 64 beats/m, output, capture: :all_but_first) == [["caxixi"]]
    refute output =~ "sample "
    assert output =~ ~r/^beat 0 +play vel: 0.5$/m
    assert output =~ ~r/^beat 0.5 +play vel: 0.5$/m
    assert output =~ ~r/^beat 1 +play vel: 0.85$/m
    refute output =~ ~r/^beat 1.5 /m
  end

  test "in são bento grande the accents move to the first buzz of each pair and the closing open note" do
    output = print()
    assert output =~ ~r/^beat 32 +play vel: 0.8$/m
    assert output =~ ~r/^beat 33 +play vel: 0.45$/m
    assert output =~ ~r/^beat 34 +play vel: 0.8$/m
    assert output =~ ~r/^beat 35.5 +play vel: 0.8$/m
  end

  test "the examples guide points to the solo and lists the caxixi, and the synth designs license names its recording" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/caxixi.exs"
    assert File.read!("documentation/instruments.md") =~ "- `caxixi` is the woven basket shaker"
    notes = File.read!("LICENSE-designs.md")
    assert notes =~ "by Freddythehat, who released it into the public domain"
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
