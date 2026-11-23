defmodule Mx.Examples.OboeTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/oboe.exs"

  test "the solo plays only the oboe" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["oboe"]]
    end

    refute print(0) =~ "sample "
  end

  test "the melody holds each note to just before the next" do
    assert print(0) =~ ~r/\nbeat 4 +play 70 vel: 0.55, sustain: 1.4, release: 0.15\n/
  end

  test "the dance is short and detached, the second time a fourth higher" do
    assert print(1) =~ ~r/\nbeat 0.75 +play 70 vel: 0.55, sustain: 0.08, release: 0.04\n/
    assert print(2) =~ ~r/\nbeat 0 +play 77 vel: 0.7, sustain: 0.08, release: 0.04\n/
  end

  test "the climb starts on the low B flat and holds F6, and the melody ends an octave up" do
    assert print(3) =~ ~r/\nbeat 0 +play 58 vel: 0.6, sustain: 0.4, release: 0.1\n/
    assert print(3) =~ ~r/\nbeat 9 +play 89 vel: 0.7, sustain: 2.9, release: 0.15\n/
    assert print(4) =~ ~r/\nbeat 12 +play 77 vel: 0.75, sustain: 3.9, release: 0.8\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/oboe.exs"
    assert File.read!("LICENSE-designs.md") =~ "The oboe is measured"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the solo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")
    args = [@song, "--render", out, "--seconds", "60"]
    report = capture_io(fn -> Mix.Tasks.Mx.Play.run(args) end)
    assert report =~ "Recorded "

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end
end
