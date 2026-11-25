defmodule Mx.ScoreTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "each note of a piano score carries the staff it is written on", %{tmp_dir: dir} do
    path =
      score!(dir, [
        attributes() <>
          note("E", 5, 4, "<voice>1</voice><staff>1</staff>") <>
          "<backup><duration>4</duration></backup>" <>
          note("C", 3, 4, "<voice>5</voice><staff>2</staff>") <>
          note("G", 3, 4, "<voice>5</voice><staff>2</staff>", chord: true)
      ])

    assert staves(path) == [{76, 1}, {48, 2}, {55, 2}]
  end

  test "a voice written across both staves gives each note its own staff", %{tmp_dir: dir} do
    path =
      score!(dir, [
        attributes() <>
          note("G", 4, 1, "<voice>1</voice><staff>1</staff>") <>
          note("E", 4, 1, "<voice>1</voice><staff>1</staff>") <>
          note("C", 4, 1, "<voice>1</voice><staff>2</staff>") <>
          note("A", 3, 1, "<voice>1</voice><staff>2</staff>")
      ])

    assert staves(path) == [{67, 1}, {64, 1}, {60, 2}, {57, 2}]
  end

  test "the notes of a chord each carry their own staff", %{tmp_dir: dir} do
    path =
      score!(dir, [
        attributes() <>
          note("C", 5, 4, "<voice>1</voice><staff>1</staff>") <>
          note("C", 3, 4, "<voice>1</voice><staff>2</staff>", chord: true)
      ])

    assert staves(path) == [{72, 1}, {48, 2}]
  end

  test "a note in a score with no staff marked carries staff 1", %{tmp_dir: dir} do
    path =
      score!(dir, [
        "<attributes><divisions>1</divisions><key><fifths>0</fifths></key></attributes>" <>
          note("C", 4, 2) <> note("D", 4, 2)
      ])

    assert staves(path) == [{60, 1}, {62, 1}]
  end

  test "every note of the chorale, one staff to a part, carries staff 1" do
    {:ok, score} = Mx.Score.read("examples/wachet_auf/bwv140.7.mxl")

    staves =
      for part <- score.parts,
          bar <- part.bars,
          voice <- bar.voices,
          group <- voice,
          note <- group.notes,
          into: MapSet.new(),
          do: note.staff

    assert staves == MapSet.new([1])
  end

  test "the aria says what it holds besides its notes: meter, key, tempo marking, upbeat, staves and marks" do
    assert {:ok, about} = Mx.Score.about("examples/erbarme_dich/bwv244.39.mxl")

    assert about.meter == "12/8"
    assert about.fifths == 2
    assert about.tempo == 48
    assert about.marking == "Grave"
    assert about.upbeat
    assert about.bars == 46
    assert about.staves == [{"Violin", 1}, {"Alto", 1}, {"Organo a canne", 2}]
    assert about.marks == [{1, "segno"}, {8, "Fine"}, {46, "D.S. al Fine"}]
  end

  test "saying what the aria holds leaves the song an import writes of it as it was" do
    {:ok, imported} = Mx.Import.song("examples/erbarme_dich/bwv244.39.mxl")

    assert Base.encode16(:crypto.hash(:sha256, imported.source), case: :lower) ==
             "f3d418223a9130350e0b128c09159196066fd3371d7fd594bf1364e391295aa2"
  end

  test "a file that is not a score says so when asked what it holds", %{tmp_dir: dir} do
    path = Path.join(dir, "notes.musicxml")
    File.write!(path, "Houston")
    assert Mx.Score.about(path) == {:error, "#{path} is not a MusicXML score"}
  end

  test "the aria read without writing a song counts what a song of it leaves out" do
    {:ok, score} = Mx.Score.read("examples/erbarme_dich/bwv244.39.mxl")

    assert score.left_out_counts == [
             {nil, :syllables, 151},
             {nil, :slurs, 275},
             {nil, :trills, 3},
             {nil, :fermatas, 3},
             {nil, :grace_notes, 84},
             {nil, :articulations, 22}
           ]
  end

  test "a note tied into keeps the staff of the note the tie starts on", %{tmp_dir: dir} do
    path =
      score!(dir, [
        attributes() <>
          note("C", 4, 4, ~s(<tie type="start"/><voice>1</voice><staff>1</staff>)),
        note("C", 4, 4, ~s(<tie type="stop"/><voice>1</voice><staff>2</staff>))
      ])

    assert staves(path) == [{60, 1}, {60, 1}]
  end

  defp staves(path) do
    {:ok, score} = Mx.Score.read(path)

    for part <- score.parts,
        bar <- part.bars,
        voice <- bar.voices,
        group <- voice,
        note <- group.notes,
        do: {note.midi, note.staff}
  end

  defp score!(dir, bars) do
    measures =
      bars
      |> Enum.with_index(1)
      |> Enum.map_join(fn {bar, number} -> ~s(<measure number="#{number}">#{bar}</measure>) end)

    path = Path.join(dir, "piano.musicxml")

    File.write!(path, """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list><part id="P1">#{measures}</part></score-partwise>
    """)

    path
  end

  defp attributes do
    "<attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves></attributes>"
  end

  defp note(step, octave, duration, extra \\ "", opts \\ []) do
    chord = if opts[:chord], do: "<chord/>", else: ""

    "<note>#{chord}<pitch><step>#{step}</step><octave>#{octave}</octave></pitch><duration>#{duration}</duration>#{extra}</note>"
  end
end
