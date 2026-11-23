defmodule Mx.Examples.VibraphoneTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/vibraphone.exs"

  test "the solo plays only the vibraphone" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["vibraphone"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the chords ring with the pedal, and then again with the motor turning" do
    assert print(0) =~ ~r/\nbeat 0 +play 53 vel: 0.5, motor: 0, release: 0.1, sustain: 1.9\n/
    assert print(1) =~ ~r/\nbeat 0 +play 53 vel: 0.5, motor: 2, release: 0.1, sustain: 1.9\n/
  end

  test "the line is of short damped notes over a held note" do
    assert print(2) =~
             ~r/\nbeat 0 +play 53 vel: 0.4, motor: 0, release: 0.1, sustain: 1.9\nbeat 0 +play 69 vel: 0.6, motor: 0, release: 0.05, sustain: 0.2\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/vibraphone.exs"
    assert File.read!("LICENSE-designs.md") =~ "The vibraphone is measured"
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
