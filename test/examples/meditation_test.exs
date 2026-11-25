defmodule Mx.Examples.MeditationTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/meditation.exs"

  test "the meditation plays only mx's measured synths, and no samples" do
    output = Enum.map_join(0..17, &print/1)

    for loop <- ~w(flute tanpura shruti bells chikari dayan bayan ganza sam) do
      assert output =~ ~r/^#{loop}, pass \d+, 16 beats/m
    end

    refute output =~ "sample "
  end

  test "the flute plays only raga Bhupali's notes, tuned to Sa D as just intervals" do
    notes =
      for pass <- 0..17,
          [_, note] <-
            Regex.scan(~r/(?:play|control note:) ([\d.]+)/, loop_part(print(pass), "flute")) do
        String.to_float(note)
      end

    steps = MapSet.new(notes, &Float.round(:math.fmod(&1 - 50, 12), 2))
    assert MapSet.subset?(steps, MapSet.new([0.0, 2.04, 3.86, 7.02, 8.84]))
    assert MapSet.size(steps) == 5
  end

  test "the alap glides from note to note, and the tabla waits for the gat" do
    assert loop_part(print(0), "flute") =~ "control note: 62.0"

    for pass <- [0, 4, 16] do
      assert loop_part(print(pass), "dayan") == ""
      assert loop_part(print(pass), "bayan") == ""
    end

    refute loop_part(print(8), "dayan") == ""
  end

  test "the bayan rests through the khali, beats 9 to 13 of teentaal" do
    bayan = loop_part(print(8), "bayan")
    beats = for [_, beat] <- Regex.scan(~r/^beat (\d+)/m, bayan), do: String.to_integer(beat)
    assert beats == [0, 1, 2, 3, 4, 5, 6, 7, 13, 14, 15]
  end

  test "the gat ends with a tihai whose last Sa lands on the sam of shanti" do
    tihai = loop_part(print(15), "flute")
    matches = Regex.scan(~r/play 62\.0 /, tihai)
    assert length(matches) == 2
    assert loop_part(print(16), "flute") =~ ~r/\Abeat 0 +play 62\.0 /
  end

  test "the examples guide points to the meditation" do
    assert File.read!("documentation/examples.md") =~ "examples/meditation.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the meditation renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "meditation.wav")
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

  defp loop_part(output, loop) do
    [part | _] = output |> String.split(~r/^#{loop}, pass \d+[^\n]*\n/m) |> tl()
    ("\n" <> part) |> String.split("\n\n") |> hd() |> String.trim()
  end
end
