defmodule Mx.Examples.FluteTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/flute.exs"

  test "the solo plays only the flute" do
    assert Regex.scan(~r/^(\w+), /m, print(0), capture: :all_but_first) == [["flute"]]
    refute print(0) =~ "sample "
  end

  test "Syrinx opens on one breath from B flat 5 through the fermata, its later notes moving the held note" do
    assert print(0) =~ ~r/\nbeat 0 +play 82 vel: 0.5, sustain: 7.4, release: 0.3\n/
    assert print(0) =~ ~r/\nbeat 0.75 +control note: 81, note_slide: 0\n/
    assert print(0) =~ ~r/\nbeat 7.5 +play 82 vel: 0.5, sustain: 4.4, release: 0.3\n/
  end

  test "a note starting a slur is tongued, dipping the breath to a quarter and bringing it back" do
    assert print(0) =~ ~r/\nbeat 0.975 +control vel: 0.125, vel_slide: 0.02\n/
    assert print(0) =~ ~r/\nbeat 1 +control note: 80, note_slide: 0, vel: 0.5, vel_slide: 0.025\n/
  end

  test "the last breath slows to the end and holds the low D flat" do
    assert print(0) =~ ~r/\nbeat 101.31 +play 71 vel: 0.35, sustain: 14.7, release: 0.3\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/flute.exs"
    assert File.read!("LICENSE-designs.md") =~ "The flute is measured"
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
