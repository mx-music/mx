defmodule Mx.ABCTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Import
  alias Mx.{Score, ScoreNotes}

  @moduletag :tmp_dir

  @reel """
  X:1
  T:The Test Reel
  R:reel
  M:4/4
  L:1/8
  K:D
  A|:dAFA dAFA|B2 cd (3efe dB|~A3 F DFAF|1 GBAG FDD2:|2 GBAG FDDe||
  |:f2 af ~g3 e|fdec d2 cd|e2 ce fedc|1 dBAG FDDe:|2 dBAG FDD2|]
  """

  defp write(dir, file, text) do
    path = Path.join(dir, file)
    File.write!(path, text)
    path
  end

  defp import!(path, args \\ []) do
    output = capture_io(fn -> Import.run([path | args]) end)
    {Path.rootname(path) <> ".exs", output}
  end

  test "a reel in D plays its notes in D major, each of its two parts repeated with its endings",
       %{tmp_dir: dir} do
    path = write(dir, "reel.abc", @reel)
    {:ok, score} = Score.read(path)

    assert score.title == "The Test Reel"
    assert score.order == [1, 2, 3, 4, 5, 2, 3, 4, 6, 7, 8, 9, 10, 7, 8, 9, 11]
    assert score.left_out == ["2 decorations are left out"]

    {song, output} = import!(path)

    assert output =~ "The Test Reel on tri: "
    assert output =~ "2 decorations are left out\n"
    assert File.read!(song) =~ "use Mx.Song, tempo: 120"

    [notes] = ScoreNotes.played(song)

    assert Enum.take(notes, 5) == [
             {0.0, 69, 0.5},
             {0.5, 74, 0.5},
             {1.0, 69, 0.5},
             {1.5, 66, 0.5},
             {2.0, 69, 0.5}
           ]

    pitches = notes |> Enum.map(&elem(&1, 1)) |> MapSet.new()
    assert 66 in pitches and 73 in pitches
    refute 65 in pitches or 72 in pitches
  end

  test "the first ending plays the first time through and the second the second", %{
    tmp_dir: dir
  } do
    path =
      write(dir, "endings.abc", """
      X:1
      T:Endings
      M:2/4
      L:1/4
      K:C
      |:C D|1 E F:|2 G A|]
      """)

    {song, _output} = import!(path)
    [notes] = ScoreNotes.played(song)

    assert Enum.map(notes, &elem(&1, 1)) == [60, 62, 64, 65, 60, 62, 67, 69]
  end

  test "a file of three tunes imports the one --tune names, the first without it, and lists them",
       %{tmp_dir: dir} do
    tune = fn number, title, note ->
      "X:#{number}\nT:#{title}\nM:4/4\nL:1/4\nK:C\n#{note}4|]\n"
    end

    path =
      write(
        dir,
        "three.abc",
        Enum.join([tune.(1, "First", "C"), tune.(2, "Second", "D"), tune.(3, "Third", "E")], "\n")
      )

    {song, output} = import!(path, ["--tune", "2"])

    assert output =~ "Second on tri: 1 notes from :d4 to :d4\n"

    assert output =~
             "three.abc holds 3 tunes, and --tune picks one:\n  X:1 First\n  X:2 Second\n  X:3 Third\n"

    assert ScoreNotes.played(song) == [[{0.0, 62, 4.0}]]

    {song, output} = import!(path, ["--force"])
    assert output =~ "First on tri: 1 notes from :c4 to :c4\n"
    assert ScoreNotes.played(song) == [[{0.0, 60, 4.0}]]

    assert_raise Mix.Error, ~r/has no tune X:5; its tunes are 1, 2, 3$/, fn ->
      Import.run([path, "--tune", "5", "--force"])
    end
  end

  test "Q:1/4=90 gives the tempo, and --tempo overrides it", %{tmp_dir: dir} do
    path = write(dir, "slow.abc", "X:1\nT:Slow\nM:3/4\nQ:1/4=90\nK:G\nG3|]\n")

    {song, _output} = import!(path)
    assert File.read!(song) =~ "use Mx.Song, tempo: 90"

    {song, _output} = import!(path, ["--tempo", "120", "--force"])
    assert File.read!(song) =~ "use Mx.Song, tempo: 120"
  end

  test "a tune with voices V:1 and V:2 imports as two parts", %{tmp_dir: dir} do
    path =
      write(dir, "duet.abc", """
      X:1
      T:Duet
      M:4/4
      L:1/4
      K:C
      V:1
      c d e f|g4|]
      V:2
      C,4|G,,4|]
      """)

    {song, output} = import!(path)

    assert output =~ "1 on tri: 5 notes from :c5 to :g5\n"
    assert output =~ "2 on tri: 2 notes from :g2 to :c3\n"

    assert ScoreNotes.played(song) == [
             [{0.0, 72, 1.0}, {1.0, 74, 1.0}, {2.0, 76, 1.0}, {3.0, 77, 1.0}, {4.0, 79, 4.0}],
             [{0.0, 48, 4.0}, {4.0, 43, 4.0}]
           ]
  end

  test "(3abc plays as three eighth-note triplets, and a>b as a dotted eighth and a sixteenth",
       %{tmp_dir: dir} do
    path = write(dir, "rhythms.abc", "X:1\nT:Rhythms\nM:2/4\nL:1/8\nK:C\n(3abc a>b|]\n")

    {song, _output} = import!(path)

    assert ScoreNotes.played(song) == [
             [
               {0.0, 81, 0.333333},
               {0.333333, 83, 0.333333},
               {0.666667, 72, 0.333333},
               {1.0, 81, 0.75},
               {1.75, 83, 0.25}
             ]
           ]
  end

  test "chord symbols are left out, and the task says how many", %{tmp_dir: dir} do
    path = write(dir, "chords.abc", ~s(X:1\nT:Chords\nM:4/4\nL:1/4\nK:C\n"C"C E "G"G B|]\n))

    {song, output} = import!(path)

    assert output =~ "2 chord symbols are left out\n"

    assert ScoreNotes.played(song) == [
             [{0.0, 60, 1.0}, {1.0, 64, 1.0}, {2.0, 67, 1.0}, {3.0, 71, 1.0}]
           ]
  end

  test "a line it cannot read stops the import, naming the line", %{tmp_dir: dir} do
    path = write(dir, "overlay.abc", "X:1\nT:Overlay\nM:4/4\nL:1/4\nK:C\nC D E F|\nG A & B c|]\n")

    assert_raise Mix.Error, ~s(#{path}: line 7: cannot read "&"), fn -> Import.run([path]) end
  end
end
