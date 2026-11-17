defmodule Mx.Examples.ElectricGuitarTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/electric_guitar.exs"

  test "the solo plays only the electric guitar" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["electric_guitar"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "a chord is strummed down, a string every twentieth of a beat, and left to ring" do
    assert print(0) =~
             ~r/\nbeat 0 +play 45 vel: 0.8, sustain: 3.9\nbeat 0.05 +play 52 vel: 0.8, sustain: 3.85\n/
  end

  test "the line is picked in eighths over the open A held low" do
    assert print(2) =~ ~r/\nbeat 0 +play 45 vel: 0.6, sustain: 7.9\n/
    assert print(2) =~ ~r/\nbeat 0.5 +play 72 vel: 0.55, sustain: 0.45\n/
  end

  test "the muted notes are short, and the last pass climbs to the high D and rings the low E" do
    assert print(4) =~ ~r/\nbeat 0.25 +play 40 vel: 0.5, sustain: 0.12\n/
    assert print(5) =~ ~r/\nbeat 4 +play 86 vel: 0.95, sustain: 3.5\n/
    assert print(5) =~ ~r/\nbeat 8 +play 40 vel: 0.9, sustain: 7.5\n/
  end

  test "the guides name the synth and its solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/instruments.md") =~ "- `electric_guitar` is a solid-body"
    assert File.read!("documentation/examples.md") =~ "examples/solo/electric_guitar.exs"
    assert File.read!("LICENSE-designs.md") =~ "The electric guitar is measured"
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
