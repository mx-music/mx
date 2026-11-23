defmodule Mx.Examples.CajonTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/cajon.exs"

  test "the solo plays only the cajón" do
    for pass <- 0..17 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["cajon"]]
    end

    refute print(0) =~ "sample "
  end

  test "the festejo is in 12/8, with the bass tone on the first and third beats and a slap on the others" do
    festejo = print(0)

    assert festejo =~
             ~r/\nbeat 0 +play slap: 0, vel: 0.8\nbeat 0.667 +play slap: 1, vel: 0.35\nbeat 1 +play slap: 1, vel: 0.9\n/

    assert festejo =~ ~r/\nbeat 2 +play slap: 0, vel: 0.8\n/
    assert length(strokes(print(2))) == 12
  end

  test "the rumba plays the bass tone on the first beat and the eighth after the second, and the slap on two and four" do
    rumba = strokes(print(4))
    assert rumba == [{0.0, 0, 0.8}, {1.0, 1, 0.9}, {1.5, 0, 0.8}, {3.0, 1, 0.9}]

    filled = strokes(print(6))
    tones = for {beat, 0, _vel} <- filled, do: beat
    slaps = for {beat, 1, 0.9} <- filled, do: beat
    assert tones == [0.0, 1.5]
    assert slaps == [1.0, 3.0]
  end

  test "the bulerías accents 12, 3, 6, 8 and 10, then 12, 3, 7, 8 and 10, and the last cycle closes on 10" do
    accents = fn pass ->
      for {beat, _slap, vel} <- strokes(print(pass)), vel > 0.7, do: beat * 2
    end

    assert print(8) =~ ~r/cajon, pass 8, 6 beats/
    assert accents.(8) == [0.0, 3.0, 6.0, 8.0, 10.0]
    assert accents.(9) == [0.0, 3.0, 6.0, 8.0, 10.0]
    assert accents.(10) == [0.0, 3.0, 7.0, 8.0, 10.0]
    assert List.last(strokes(print(11))) == {5.0, 0, 0.95}
  end

  test "the rock beat adds soft slaps until every sixteenth is played, and the roll grows into the bass tone" do
    assert strokes(print(12)) ==
             [{0.0, 0, 0.8}, {1.0, 1, 0.9}, {2.0, 0, 0.8}, {2.5, 0, 0.8}, {3.0, 1, 0.9}]

    assert length(strokes(print(13))) == 8
    assert length(strokes(print(14))) == 16

    roll = strokes(print(16))
    assert Enum.take(roll, 2) == [{0.0, 1, 0.35}, {0.125, 1, 0.35}]
    assert List.last(roll) == {3.0, 0, 0.95}
    assert strokes(print(17)) == [{0.0, 0, 0.95}]
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/cajon.exs"
    assert File.read!("LICENSE-designs.md") =~ "cajón recordings"
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

  # The strokes of a printed pass, as {beat, slap, vel}.
  defp strokes(printed) do
    for [beat, slap, vel] <-
          Regex.scan(~r/^beat (\S+) +play slap: (\d), vel: (\S+)$/m, printed,
            capture: :all_but_first
          ) do
      {number(beat), String.to_integer(slap), number(vel)}
    end
  end

  defp number(text) do
    {value, ""} = Float.parse(text)
    value
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end
end
