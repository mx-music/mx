defmodule Mx.Examples.ElectricBassTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/electric_bass.exs"

  test "the solo plays only the electric bass" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["electric_bass"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the funk line lands hard on the low E and answers with its octave off the beat" do
    assert print(0) =~ ~r/\nbeat 0 +play 28 vel: 0.95, sustain: 0.4\n/
    assert print(0) =~ ~r/\nbeat 1.5 +play 40 vel: 0.8, sustain: 0.15\n/
    assert print(1) =~ ~r/\nbeat 7.75 +play 39 vel: 0.8, sustain: 0.15\n/
  end

  test "the walking line plays quarters, harder on the one, up and then down" do
    assert print(2) =~
             ~r/\nbeat 0 +play 38 vel: 0.8, sustain: 0.9\nbeat 1 +play 41 vel: 0.6, sustain: 0.9\n/

    assert print(3) =~ ~r/\nbeat 1 +play 36 vel: 0.6, sustain: 0.9\n/
  end

  test "the ballad holds its roots a bar each, and the ending holds the low E" do
    assert print(4) =~
             ~r/\nbeat 0 +play 36 vel: 0.5, sustain: 3.9\nbeat 4 +play 33 vel: 0.5, sustain: 3.9\n/

    assert print(5) =~ ~r/\nbeat 8 +play 28 vel: 1.0, sustain: 7.5\n/
  end

  test "the guides name the synth and its solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/instruments.md") =~ "- `electric_bass` is an electric bass"
    assert File.read!("documentation/examples.md") =~ "examples/solo/electric_bass.exs"
    assert File.read!("LICENSE-designs.md") =~ "The electric bass is measured"
    assert File.read!("LICENSE-designs.md") =~ "Creative Commons Attribution 4.0"
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
