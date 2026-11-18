defmodule Mx.Examples.ElectricPianoTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/electric_piano.exs"

  test "the solo plays only the electric piano" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["electric_piano"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the chords are struck softly and left to ring a bar each" do
    assert print(0) =~ ~r/\nbeat 0 +play 50 vel: 0.3, sustain: 3.9\n/
    assert print(0) =~ ~r/\nbeat 4 +play 43 vel: 0.3, sustain: 3.9\n/
  end

  test "the melody is struck harder than the chords under it" do
    assert print(2) =~ ~r/\nbeat 0 +play 50 vel: 0.25, sustain: 3.9\n/
    assert print(2) =~ ~r/\nbeat 0 +play 76 vel: 0.75, sustain: 1\n/
  end

  test "the low pass reaches the low E, and the last pass climbs to the top E" do
    assert print(4) =~ ~r/\nbeat 12 +play 28 vel: 0.85, sustain: 3.9\n/
    assert print(5) =~ ~r/\nbeat 6 +play 88 vel: 0.85, sustain: 2\n/
  end

  test "the guides name the synth and its solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/instruments.md") =~ "- `electric_piano` is an electric piano"
    assert File.read!("documentation/examples.md") =~ "examples/solo/electric_piano.exs"
    assert File.read!("LICENSE-designs.md") =~ "The electric piano is measured"
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
