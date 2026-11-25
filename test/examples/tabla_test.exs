defmodule Mx.Examples.TablaTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/tabla.exs"
  @synths ~w(tabla_ghe tabla_ke tabla_na tabla_te tabla_tun)

  test "the solo plays the tabla alone" do
    for pass <- 0..6 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert loops |> List.flatten() |> Enum.sort() == @synths
    end

    refute print(0) =~ "sample "
  end

  test "the theka plays no ghe in its khali, beats 9 to 12" do
    for pass <- [0, 1, 4, 5, 6] do
      [ghe] = Regex.run(~r/tabla_ghe, pass .*?\n\n/s, print(pass) <> "\n\n")
      beats = Regex.scan(~r/^beat (\d+)\s+play/m, ghe, capture: :all_but_first)
      beats = beats |> List.flatten() |> Enum.map(&String.to_integer/1)
      assert beats != []
      refute Enum.any?(beats, &(&1 in 8..11)), "pass #{pass} plays ghe on #{inspect(beats)}"
    end
  end

  test "the variation splits the theka's beats in two, and the bends slide the bayan up" do
    assert print(2) =~ ~r/tabla_te, pass 2.*\nbeat 0.5 +play vel: 0.45\n/s
    assert print(2) =~ ~r/tabla_ke, pass 2.*\nbeat 8.5 +play vel: 0.5\n/s
    assert print(4) =~ ~r/^beat 1 +play vel: 0.65, note_slide: 0.5\nbeat 1 +control note: 44.25$/m
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/tabla.exs"
    assert File.read!("LICENSE-designs.md") =~ "tabla bols"
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
