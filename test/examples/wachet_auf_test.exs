defmodule Mx.Examples.WachetAufTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/wachet_auf/chorale.exs"

  @tag :tmp_dir
  test "the chorale is the song mix mx.import writes from the score, as the README gives it", %{
    tmp_dir: dir
  } do
    out = Path.join(dir, "chorale.exs")

    [command] =
      Regex.run(
        ~r/^mix mx\.import examples\/wachet_auf\/bwv140\.7\.mxl .*$/m,
        File.read!("README.md")
      )

    args =
      command
      |> OptionParser.split()
      |> Enum.drop(2)
      |> Enum.map(&if(&1 == @song, do: out, else: &1))

    capture_io(fn -> Mix.Tasks.Mx.Import.run(args) end)

    assert File.read!(out) == File.read!(@song)
  end

  test "the chorale plays soprano, alto, tenor and bass on oboe, clarinet, viola and bassoon" do
    assert {:ok, song} = Mx.Song.load(@song)

    assert Enum.map(song.loops, &{&1.name, &1.synth}) ==
             [soprano: :oboe, alto: :clarinet, tenor: :viola, bass: :bassoon]
  end

  test "the score's license is kept beside it" do
    assert File.read!("examples/wachet_auf/LICENSE.md") =~
             "Redistribution and use in source and binary forms"
  end
end
