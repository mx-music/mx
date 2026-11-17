defmodule Mix.Tasks.Mx.ExportTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.{Export, Import}
  alias Mx.{Score, ScoreNotes}

  @aria "examples/erbarme_dich/bwv244.39.mxl"

  @moduletag :tmp_dir

  test "the aria imported and exported again has the notes the imported song plays", %{
    tmp_dir: dir
  } do
    # Named apart from the import tests' copy, whose song defines the module Bwv24439.
    score = Path.join(dir, "exported_aria.mxl")
    File.cp!(@aria, score)
    song = Path.join(dir, "exported_aria.exs")
    out = Path.join(dir, "aria.musicxml")
    capture_io(fn -> Import.run([score]) end)

    output =
      capture_io(fn -> Export.run([song, "--time", "12/8", "--key", "bm", "--out", out]) end)

    assert output =~ "Wrote #{out}\n"
    assert output =~ ~r/^violin: \d+ notes from \w+ to \w+$/m

    {:ok, original} = Score.read(score)
    {:ok, exported} = Score.read(out)

    assert exported.tempo == original.tempo
    assert length(exported.parts) == length(original.parts)

    for {played, again} <- Enum.zip(ScoreNotes.played(song), ScoreNotes.written(exported)) do
      assert again == played
    end
  end

  test "names the parts it leaves out", %{tmp_dir: dir} do
    song = Path.join(dir, "beat.exs")

    File.write!(song, """
    import Mx
    song(music: together([part(:kick, steps("x...", 1), synth: :kick), part(:bass, note(:c2, 4), synth: :tri)]))
    """)

    out = Path.join(dir, "beat.musicxml")
    output = capture_io(fn -> Export.run([song]) end)

    assert output =~ "Wrote #{out}\n"
    assert output =~ "bass: 1 notes from c2 to c2\n"
    assert output =~ "kick is left out: it plays no notes with a pitch\n"
  end
end
