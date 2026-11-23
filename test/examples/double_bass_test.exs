defmodule Mx.Examples.DoubleBassTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/double_bass.exs"

  test "the solo plays only the double bass" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["double_bass"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the walking line plucks the blues in quarters, harder on the beat" do
    assert print(0) =~ ~r/\nbeat 0 +play 29 vel: 0.8, pizz: 1, sustain: 0.9\n/
    assert print(0) =~ ~r/\nbeat 1 +play 33 vel: 0.6, pizz: 1, sustain: 0.9\n/
    assert print(2) =~ ~r/\nbeat 1 +play 34 vel: 0.6, pizz: 1, sustain: 0.9\n/
  end

  test "the slow melody is slurred in two swelled bows with vibrato, the second sliding down to the low C" do
    assert print(3) =~
             ~r/\nbeat 0 +play 41 vel: 0.65, sustain: 7.8, release: 0.4, vibrato: 0.08, amp: 0.6\nbeat 0 +control amp: 1, amp_slide: 4\nbeat 4 +control note: 45, note_slide: 0.01\n/

    assert print(3) =~ ~r/\nbeat 12 +control note: 36, note_slide: 0.15\n/
  end

  test "the ending holds the low F bowed, swelled" do
    assert print(4) =~
             ~r/\nbeat 8 +play 29 vel: 0.8, sustain: 6, release: 1, vibrato: 0.08, amp: 0.6\nbeat 8 +control amp: 1, amp_slide: 3\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/double_bass.exs"
    assert File.read!("LICENSE-designs.md") =~ "The double bass is measured"
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
