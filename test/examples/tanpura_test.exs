defmodule Mx.Examples.TanpuraTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/tanpura.exs"

  test "the solo plays only the tanpura" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["tanpura"]]
    end

    refute print(0) =~ "sample "
  end

  test "the solo holds drones on two different Sa, plucked slowly and quickly, short and long" do
    drones =
      for pass <- 0..4 do
        [sa, gap, held] =
          Regex.run(
            ~r/^beat 0 +play (\d+) vel: 0.6, gap: ([\d.]+), sustain: (\d+), amp: 0.5$/m,
            print(pass),
            capture: :all_but_first
          )

        {gap, ""} = Float.parse(gap)
        {String.to_integer(sa), gap, String.to_integer(held)}
      end

    assert drones |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 2
    assert drones |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() >= 2
    assert drones |> Enum.map(&elem(&1, 2)) |> Enum.min() <= 12
    assert drones |> Enum.map(&elem(&1, 2)) |> Enum.max() >= 60
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/tanpura.exs"

    assert File.read!("LICENSE-designs.md") =~
             ~s(The tanpura is measured from the recording "Tanpura 10")

    assert File.read!("LICENSE-designs.md") =~ ~s("Tanpura in E")
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
