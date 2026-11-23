defmodule Mx.Examples.HarmoniumTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/harmonium.exs"

  test "the solo plays the harmonium alone, a melody over a held Sa" do
    for pass <- 0..4 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ["melody", "sa"]
      assert print(pass) =~ ~r/sa, pass .*\nbeat 0 +play 43 vel: 0.5, sustain: 15.5/s
    end

    refute print(0) =~ "sample "
  end

  test "the solo climbs and falls through Bhairav, tuned with cents, low and high" do
    ascent = print(0)
    assert ascent =~ ~r/^beat 1 +play 56.12 /m
    assert ascent =~ ~r/^beat 7 +play 67.0 vel: 0.6, sustain: 1.8/m
    assert print(2) =~ ~r/^beat 11 +play 51.14 /m
    assert print(3) =~ ~r/^beat 6 +play 71.98 /m
    assert print(2) =~ ~r/^beat 0.5 +play 56.12 vel: 0.5, sustain: 0.45/m
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/harmonium.exs"
    assert File.read!("LICENSE-designs.md") =~ "cabled_mess"
    assert File.read!("LICENSE-designs.md") =~ "donyaquick"
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
