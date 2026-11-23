defmodule Mx.Examples.ClavesTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/claves.exs"

  test "the solo plays only the clave" do
    for pass <- 0..9 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["clave"]]
    end

    refute print(0) =~ "sample "
  end

  test "it plays son clave 3-2 and 2-3, rumba clave, and the bossa nova clave" do
    assert beats(0) == [0, 1.5, 3, 5, 6]
    assert beats(2) == [1, 2, 4, 5.5, 7]
    assert beats(3) == [0, 1.5, 3.5, 5, 6]
    assert beats(5) == [0, 1.5, 3, 5, 6.5]
  end

  test "the 6/8 bell plays seven strokes in triplets twice, and the last son clave ends on its hardest stroke" do
    assert beats(7) == [
             0,
             0.667,
             1.333,
             1.667,
             2.333,
             3,
             3.667,
             4,
             4.667,
             5.333,
             5.667,
             6.333,
             7,
             7.667
           ]

    assert print(9) =~ ~r/\nbeat 6 +play vel: 1, amp: 0.5\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/claves.exs"
    assert File.read!("LICENSE-designs.md") =~ "claves recordings"
  end

  defp beats(pass) do
    for [beat] <- Regex.scan(~r/^beat ([\d.]+)/m, print(pass), capture: :all_but_first) do
      {number, _} = Float.parse(beat)
      if number == trunc(number), do: trunc(number), else: number
    end
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
