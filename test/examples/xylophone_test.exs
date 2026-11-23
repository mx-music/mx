defmodule Mx.Examples.XylophoneTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/xylophone.exs"

  test "the solo plays only the xylophone" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["xylophone"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the runs go up two octaves in sixteenths and back, the second a fifth higher" do
    assert print(0) =~
             ~r/\nbeat 0 +play 72 vel: 0.8\nbeat 0.25 +play 74 vel: 0.6\n.*\nbeat 3.5 +play 96 vel: 0.6\n/s

    assert print(1) =~ ~r/\nbeat 0 +play 79 vel: 0.8\n.*\nbeat 3.5 +play 103 vel: 0.6\n/s
  end

  test "one note is struck every sixteenth while a melody moves under it" do
    repeats = print(2)
    assert length(Regex.scan(~r/play 79 /, repeats)) == 32

    assert repeats =~
             ~r/\nbeat 0 +play 79 vel: 0.75\nbeat 0 +play 76 vel: 0.7\nbeat 0.25 +play 79 vel: 0.5\n/
  end

  test "the ending runs up to C8, the top bar" do
    assert print(4) =~ ~r/\nbeat 1.75 +play 108 vel: 0.9\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/xylophone.exs"
    assert File.read!("LICENSE-designs.md") =~ "The xylophone is measured"
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
