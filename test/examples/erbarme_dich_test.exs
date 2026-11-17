defmodule Mx.Examples.ErbarmeDichTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/erbarme_dich/aria.exs"

  @tag :tmp_dir
  test "the aria is the song mix mx.import writes from the score, as the scores guide gives it",
       %{
         tmp_dir: dir
       } do
    out = Path.join(dir, "aria.exs")

    [command] =
      Regex.run(
        ~r/^mx import examples\/erbarme_dich\/bwv244\.39\.mxl .*$/m,
        File.read!("documentation/scores.md")
      )

    args =
      command
      |> OptionParser.split()
      |> Enum.drop(2)
      |> Enum.map(&if(&1 == @song, do: out, else: &1))

    capture_io(fn -> Mix.Tasks.Mx.Import.run(args) end)

    assert File.read!(out) == File.read!(@song)
  end

  test "the aria plays violin, alto and organ on violin, oboe and organ" do
    assert {:ok, song} = Mx.Song.load(@song)

    assert Enum.map(song.loops, &{&1.name, &1.synth}) ==
             [violin: :violin, alto: :oboe, organo_a_canne: :organ]
  end

  test "the score's license is kept beside it" do
    assert File.read!("examples/erbarme_dich/LICENSE.md") =~
             "https://creativecommons.org/licenses/by/4.0/"
  end
end
