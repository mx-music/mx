defmodule Mx.Examples.SitarTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/sitar.exs"

  test "the solo plays the sitar alone" do
    for pass <- 0..7 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert List.flatten(loops) == ["sitar"]
    end

    refute print(0) =~ "sample "
  end

  test "the alap glides between notes on one pluck, and the gat runs in sixteenths" do
    assert print(0) =~
             ~r/^beat 2.5 +play 51.04 .*note_slide: 0.6.*\nbeat 3.5 +control note: 52.86$/m

    assert print(5) =~ ~r/^beat 0.25 +play 51.04 vel: 0.5, sustain: 0.225/m
    assert print(4) =~ ~r/^beat 8.5 +play 63.04 /m
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/sitar.exs"
    assert File.read!("LICENSE-designs.md") =~ "sitar01.flac"
    assert File.read!("LICENSE-designs.md") =~ "sitar j"
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
