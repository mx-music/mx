defmodule Mx.Examples.TriangleTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/triangle.exs"

  test "the solo plays only the triangle" do
    for pass <- 0..7 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["triangle"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "single strokes ring from soft to loud, and damped strokes stop at once" do
    assert print(0) =~ ~r/\nbeat 0 +play vel: 0.4, amp: 0.5\nbeat 2 +play vel: 0.4, amp: 0.5\n/
    assert print(1) =~ ~r/\nbeat 0 +play vel: 0.7, amp: 0.5\n/
    assert print(2) =~ ~r/\nbeat 0 +play vel: 0.7, sustain: 0.1, release: 0.05, amp: 0.5\n/
  end

  test "the roll grows from soft into a stroke left to ring" do
    roll = print(3)
    assert roll =~ ~r/\nbeat 0 +play vel: 0.3, amp: 0.5\nbeat 0.125 +play vel: 0.33, amp: 0.5\n/
    assert roll =~ ~r/\nbeat 3 +play vel: 1, amp: 0.5\n/
  end

  test "the baião is four sixteenths to a beat, open on the third and closed on the others" do
    assert print(4) =~
             ~r/\nbeat 0 +play vel: 0.5, sustain: 0.02, release: 0.15, amp: 0.5\nbeat 0.25 +play vel: 0.5, sustain: 0.02, release: 0.15, amp: 0.5\nbeat 0.5 +play vel: 0.75, sustain: 0.2, release: 0.1, amp: 0.5\nbeat 0.75 +play vel: 0.5, sustain: 0.02/

    assert print(6) =~ ~r/\nbeat 3.75 +play vel: 0.75, sustain: 0.2, release: 0.1, amp: 0.5\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/triangle.exs"
    assert File.read!("LICENSE-designs.md") =~ "triangle recordings"
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
