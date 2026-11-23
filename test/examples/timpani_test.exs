defmodule Mx.Examples.TimpaniTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/timpani.exs"

  test "the solo plays only the timpani" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["timpani"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the roll is quick repeated strokes that swell from soft to loud and fade" do
    swell = print(0)

    assert swell =~
             ~r/\nbeat 0 +play 45 vel: 0.3, amp: 0.5\nbeat 0.167 +play 45 vel: 0.31, amp: 0.5\n/

    assert swell =~ ~r/\nbeat 7.833 +play 45 vel: 1.0, amp: 0.5\n/
    assert swell =~ ~r/\nbeat 13.833 +play 45 vel: 0.3, amp: 0.5\n/
  end

  test "the melody goes over the five drums, and comes back at its softest" do
    melody = print(2)

    for note <- [45, 47, 50, 52, 54] do
      assert melody =~ ~r/play #{note} vel: 0.65, amp: 0.5\n/
    end

    assert print(3) =~ ~r/\nbeat 4 +play 54 vel: 0.3, amp: 0.5\n/
  end

  test "the ending rolls on D3 and ends on a loud stroke" do
    assert print(4) =~ ~r/\nbeat 8 +play 50 vel: 1, amp: 0.5\n$/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/timpani.exs"
    assert File.read!("LICENSE-designs.md") =~ "The timpani is measured"
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
