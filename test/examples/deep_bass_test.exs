defmodule Mx.Examples.DeepBassTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/deep_bass.exs"

  test "the solo plays only the deep bass" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["deep_bass"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the ballad walks its roots down a bar each, to the low D" do
    assert print(0) =~
             ~r/\nbeat 0 +play 36 vel: 0.5, sustain: 3.9\nbeat 4 +play 35 vel: 0.5, sustain: 3.9\n/

    assert print(1) =~ ~r/\nbeat 8 +play 26 vel: 0.5, sustain: 3.9\n/
  end

  test "the groove holds the root and answers with its octave off the beat, harder the second time" do
    assert print(2) =~
             ~r/\nbeat 0 +play 33 vel: 0.75, sustain: 1.4\nbeat 1.5 +play 45 vel: 0.55, sustain: 0.4\n/

    assert print(3) =~ ~r/\nbeat 0 +play 33 vel: 0.9, sustain: 1.4\n/
  end

  test "the high phrase reaches D sharp, and the ending holds the low E" do
    assert print(4) =~ ~r/\nbeat 4 +play 63 vel: 0.8, sustain: 1.5\n/
    assert print(5) =~ ~r/\nbeat 9 +play 28 vel: 1.0, sustain: 6.5\n/
  end

  test "the guides name the synth and its solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/instruments.md") =~ "- `deep_bass` is a darker bass"
    assert File.read!("documentation/examples.md") =~ "examples/solo/deep_bass.exs"
    assert File.read!("LICENSE-designs.md") =~ "The deep bass is measured"
  end

  @tag :engine
  @tag :tmp_dir
  test "a minute of the solo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")
    capture_io(fn -> assert :ok = Mx.Render.render(@song, out, seconds: 60) end)

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end
end
