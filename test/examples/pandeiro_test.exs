defmodule Mx.Examples.PandeiroTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/pandeiro.exs"
  @virtuoso "examples/pandeiro/virtuoso.exs"

  test "the solo plays only the pandeiro, a strain of 32 beats to each pass" do
    for pass <- 0..7 do
      loops = Regex.scan(~r/^(\w+), pass \d, 32 beats/m, print(pass), capture: :all_but_first)

      assert Enum.sort(List.flatten(loops)) ==
               ["pandeiro_heel", "pandeiro_jingles", "pandeiro_slap", "pandeiro_thumb"]
    end

    refute print(0) =~ "sample "
  end

  test "strain A mutes the thumb's bass on each bar's first beat and opens it on its second" do
    thumb = strokes(print(0), "pandeiro_thumb")
    assert [{first, 1}, {second, 0}, {third, 1}, {fourth, 0} | _] = thumb

    for {beat, want} <- [{first, 0}, {second, 1}, {third, 2}, {fourth, 3}],
        do: assert_in_delta(beat, want, 0.02)
  end

  test "the strains play in the order A A B B A C C A" do
    slaps = fn pass -> pass |> print() |> strokes("pandeiro_slap") |> length() end
    counts = Enum.map(0..7, slaps)
    [first, second, trio] = [Enum.at(counts, 0), Enum.at(counts, 2), Enum.at(counts, 5)]
    assert length(Enum.uniq([first, second, trio])) == 3
    assert counts == [first, first, second, second, first, trio, trio, first]
  end

  test "strain B slaps a sixteenth before the second beat of its first bar" do
    assert [{beat, 1} | _] = strokes(print(2), "pandeiro_slap")
    assert_in_delta beat, 0.75, 0.04
  end

  test "strain C strikes an accented open bass on its second bar, and a slap after it" do
    strain = print(5)
    thumb = strokes(strain, "pandeiro_thumb")
    assert Enum.any?(thumb, fn {beat, muted} -> abs(beat - 2) < 0.02 and muted == 0 end)
    assert strain =~ ~r/pandeiro_thumb, pass 5.*\nbeat 2\.\d+ +play vel: 0\.[89]\d*, muted: 0/s
    assert [{beat, 1} | _] = strokes(strain, "pandeiro_slap")
    assert_in_delta beat, 2.75, 0.04
  end

  test "a strain ends on a roll of sixteen soft strokes on the jingles over its last beat" do
    roll = for {beat, 1} <- strokes(print(0), "pandeiro_jingles"), beat >= 30.99, do: beat
    assert length(roll) == 16
  end

  test "the virtuoso solo starts on a coco groove and splits sixteenths into ruffs" do
    assert print(0, @virtuoso) =~
             ~r/pandeiro_slap, pass 0.*\nbeat 1.25 +play vel: 0.8\nbeat 2.75 +play vel: 0.8\n/s

    assert print(2, @virtuoso) =~
             ~r/pandeiro_heel, pass 2.*\nbeat 0.5 +play vel: 0.5\nbeat 0.875 +play /s
  end

  test "the virtuoso solo's accents every three sixteenths cross the bar line, pass after pass" do
    first = print(4, @virtuoso)
    assert first =~ ~r/pandeiro_thumb, pass 4.*\nbeat 0 +play vel: 0.9\n/s

    assert first =~
             ~r/pandeiro_slap, pass 4.*\nbeat 0.75 +play vel: 0.85\nbeat 2.25 +play vel: 0.85\nbeat 3.75 /s

    assert print(5, @virtuoso) =~ ~r/pandeiro_heel, pass 5.*\nbeat 0.5 +play vel: 0.85\n/s
    assert print(7, @virtuoso) =~ ~r/pandeiro_thumb, pass 7.*\nbeat 0 +play vel: 0.9\n/s
  end

  test "the virtuoso solo accents every fourth sextuplet" do
    assert print(15, @virtuoso) =~
             ~r/pandeiro_heel, pass 15.*\nbeat 0.333 +play vel: 0.5\nbeat 0.667 +play vel: 0.85\nbeat 1.333 +play vel: 0.85\n/s
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/pandeiro.exs"
    assert File.read!("documentation/examples.md") =~ "examples/pandeiro/virtuoso.exs"
    assert File.read!("LICENSE-designs.md") =~ "MeanRaccoon"
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

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the virtuoso solo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "virtuoso.wav")
    args = [@virtuoso, "--render", out, "--seconds", "60"]
    report = capture_io(fn -> Mix.Tasks.Mx.Play.run(args) end)
    assert report =~ "Recorded "

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  # The strokes a part plays in a printed pass, as {beat, muted}.
  defp strokes(printed, part) do
    [_before, after_heading] = String.split(printed, ~r/^#{part}, pass [^\n]*\n/m, parts: 2)
    [rows | _] = String.split(after_heading, ~r/^pandeiro_\w+, pass /m, parts: 2)

    for [beat, muted] <-
          Regex.scan(~r/^beat ([\d.]+) +play .*muted: (\d)/m, rows, capture: :all_but_first) do
      {String.to_float(if(beat =~ ".", do: beat, else: beat <> ".0")), String.to_integer(muted)}
    end
  end

  defp print(pass, song \\ @song) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([song, "--pass", pass]) end)
  end
end
