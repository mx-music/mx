defmodule Mx.MusicXMLTest do
  use ExUnit.Case, async: true

  alias Mx.{MusicXML, Score}

  @moduletag :tmp_dir

  defp export(dir, body, opts \\ []) do
    path = Path.join(dir, "a_song.exs")
    File.write!(path, "import Mx\n" <> body)
    out = Path.join(dir, Keyword.get(opts, :out, "a_song.musicxml"))
    assert {:ok, report} = MusicXML.write(path, out, Keyword.merge([force: true], opts))
    {File.read!(out), out, report}
  end

  defp xml(dir, body, opts \\ []), do: dir |> export(body, opts) |> elem(0)

  defp measure(xml, number) do
    [_, measure] = Regex.run(~r/<measure number="#{number}">(.*?)<\/measure>/s, xml)
    measure
  end

  defp types(measure), do: Regex.scan(~r/<type>(\w+)<\/type>/, measure, capture: :all_but_first)

  test "four quarter notes fill one bar of 4/4", %{tmp_dir: dir} do
    xml = xml(dir, "song(music: part(:lead, repeat(note(:c4, 1), 4), synth: :tri))")

    assert xml =~ "<time><beats>4</beats><beat-type>4</beat-type></time>"
    assert types(measure(xml, 1)) == List.duplicate(["quarter"], 4)
    refute xml =~ ~s(<measure number="2">)
  end

  test "a note sustained half its beats is an eighth note and an eighth rest", %{tmp_dir: dir} do
    xml =
      xml(
        dir,
        "song(music: part(:lead, seq([note(:c4, 1, sustain: 0.5), rest(3)]), synth: :tri))"
      )

    assert [first, second | _] = Regex.scan(~r/<note>.*?<\/note>/, measure(xml, 1))
    assert hd(first) =~ "<step>C</step>"
    assert hd(first) =~ "<type>eighth</type>"
    assert hd(second) =~ "<rest/>"
    assert hd(second) =~ "<type>eighth</type>"
  end

  test "starts snap to a 24th of a beat, so 1.01 is the beat and 1.33 a triplet", %{tmp_dir: dir} do
    xml =
      xml(dir, """
      song(music: part(:lead, at([{1.01, note(:c4, 0.32)}, {1.33, note(:d4, 0.34)}, {1.67, note(:e4, 0.33)}], 4), synth: :tri))
      """)

    {:ok, score} = Score.read(write_tmp(dir, xml))
    [%{voices: [voice]}] = hd(score.parts).bars
    notes = for group <- voice, group.notes != [], do: {group.onset, group.length}
    assert notes == [{1.0, 1 / 3}, {4 / 3, 1 / 3}, {5 / 3, 1 / 3}]
    assert xml =~ "<time-modification><actual-notes>3</actual-notes>"
  end

  test "a note of 3 beats from beat 3 is a quarter tied over the bar line to a half", %{
    tmp_dir: dir
  } do
    xml = xml(dir, "song(music: part(:lead, seq([rest(3), note(:c4, 3), rest(2)]), synth: :tri))")

    assert measure(xml, 1) =~
             ~s(<step>C</step><octave>4</octave></pitch><duration>24</duration><tie type="start"/><voice>1</voice><type>quarter</type>)

    assert measure(xml, 2) =~
             ~s(<duration>48</duration><tie type="stop"/><voice>1</voice><type>half</type>)
  end

  test "a chord lasting as long is one chord in one voice", %{tmp_dir: dir} do
    xml =
      xml(dir, "song(music: part(:keys, seq([note([:c4, :e4, :g4], 2), rest(2)]), synth: :tri))")

    assert length(Regex.scan(~r/<chord\/>/, xml)) == 2
    refute xml =~ "<voice>2</voice>"
    refute xml =~ "<backup>"
  end

  test "a held note under moving quarters is a second voice", %{tmp_dir: dir} do
    xml =
      xml(dir, """
      song(music: part(:keys, together([seq(e4: 1, f4: 1, g4: 1, a4: 1), note(:c4, 4)]), synth: :tri))
      """)

    measure = measure(xml, 1)
    assert measure =~ "<backup><duration>96</duration></backup>"
    assert [voice_one, voice_two] = String.split(measure, "<backup>")
    assert length(Regex.scan(~r/<voice>1<\/voice>/, voice_one)) == 4
    assert voice_two =~ "<step>C</step><octave>4</octave></pitch><duration>96</duration>"
    assert voice_two =~ "<voice>2</voice><type>whole</type>"
  end

  test "a voice after the first is left out of bars it has no note in", %{tmp_dir: dir} do
    xml =
      xml(dir, """
      song(music: part(:keys, seq([together([note(:e4, 4), note(:c4, 4, sustain: 2)]), note(:d4, 4)]), synth: :tri))
      """)

    assert measure(xml, 1) =~ "<voice>2</voice>"
    refute measure(xml, 2) =~ "<voice>2</voice>"
  end

  test "pitches are spelled in the key", %{tmp_dir: dir} do
    flat = xml(dir, "song(music: part(:lead, note(70, 4), synth: :tri))", key: "f")
    assert flat =~ "<step>B</step><alter>-1</alter><octave>4</octave>"
    assert flat =~ "<key><fifths>-1</fifths><mode>major</mode></key>"

    sharp = xml(dir, "song(music: part(:lead, note(70, 4), synth: :tri))", key: "e")
    assert sharp =~ "<step>A</step><alter>1</alter><octave>4</octave>"

    minor = xml(dir, "song(music: part(:lead, note(70, 4), synth: :tri))", key: "bm")
    assert minor =~ "<key><fifths>2</fifths><mode>minor</mode></key>"
  end

  test "writes a note between semitones at the nearest one", %{tmp_dir: dir} do
    xml = xml(dir, "song(music: part(:lead, seq([note(60.4, 2), note(63.86, 2)]), synth: :tri))")

    assert xml =~ "<step>C</step><octave>4</octave>"
    assert xml =~ "<step>E</step><octave>4</octave>"
  end

  test "spells notes the key alters with the key's letters", _ctx do
    assert MusicXML.spell(65, 6) == {"E", 1, 4}
    assert MusicXML.spell(71, -6) == {"C", -1, 5}
    assert MusicXML.spell(60, 0) == {"C", 0, 4}
    assert MusicXML.spell(61, 0) == {"C", 1, 4}
    assert MusicXML.spell(61, -1) == {"D", -1, 4}
  end

  test "refuses a key or a time signature it cannot write", _ctx do
    assert MusicXML.key("h") == {:error, "--key takes a key such as d, bm or fsm, not h"}

    assert {:error, "--time takes a time signature such as 4/4 or 12/8, not 4"} =
             MusicXML.time("4")

    assert {:ok, {12, 8}} = MusicXML.time("12/8")
  end

  test "writes the song's tempo as a metronome mark", %{tmp_dir: dir} do
    xml = xml(dir, "song(tempo: 92, music: part(:lead, note(:c4, 4), synth: :tri))")

    assert xml =~
             "<metronome><beat-unit>quarter</beat-unit><per-minute>92</per-minute></metronome>"

    {:ok, score} = Score.read(write_tmp(dir, xml))
    assert score.tempo == 92
  end

  test "is titled after the song's file unless given a title", %{tmp_dir: dir} do
    assert xml(dir, "song(music: part(:lead, note(:c4, 4), synth: :tri))") =~
             "<work-title>A song</work-title>"

    assert xml(dir, "song(music: part(:lead, note(:c4, 4), synth: :tri))", title: "Q & A") =~
             "<work-title>Q &amp; A</work-title>"
  end

  test "leaves out a part that plays no pitched notes, and says why", %{tmp_dir: dir} do
    {xml, _out, report} =
      export(dir, """
      song(music: together([part(:kick, steps("x...", 1), synth: :kick), part(:bass, note(:c2, 4), synth: :tri)]))
      """)

    assert [%{name: "bass", notes: 1, low: "c2", high: "c2"}] = report.parts
    assert report.left_out == [{"kick", "it plays no notes with a pitch"}]
    assert xml =~ "<part-name>bass</part-name>"
    refute xml =~ "kick"
    assert xml =~ "<clef><sign>F</sign><line>4</line></clef>"
  end

  test "refuses a song with no part that plays notes with a pitch", %{tmp_dir: dir} do
    path = Path.join(dir, "drums.exs")
    File.write!(path, "import Mx\nsong(music: part(:kick, steps(\"x...\", 1), synth: :kick))")
    out = Path.join(dir, "drums.musicxml")

    assert MusicXML.write(path, out) ==
             {:error, "#{path} has no part that plays notes with a pitch"}

    refute File.exists?(out)
  end

  test "refuses to write over a file unless forced", %{tmp_dir: dir} do
    path = Path.join(dir, "a_song.exs")
    File.write!(path, "import Mx\nsong(music: part(:lead, note(:c4, 4), synth: :tri))")
    out = Path.join(dir, "a_song.musicxml")
    File.write!(out, "")

    assert {:error, message} = MusicXML.write(path, out)
    assert message == "#{out} already exists; give --force to write over it"
    assert {:ok, _} = MusicXML.write(path, out, force: true)
  end

  test "an .mxl path writes a compressed score that reads back", %{tmp_dir: dir} do
    {_zip, out, _report} =
      export(dir, "song(music: part(:lead, seq(c4: 1, e4: 3), synth: :tri))", out: "a_song.mxl")

    assert {:ok, score} = Score.read(out)
    [%{voices: [voice]}] = hd(score.parts).bars

    played = for group <- voice, note <- group.notes, do: {group.onset, note.midi}
    assert played == [{0.0, 60}, {1.0, 64}]
  end

  defp write_tmp(dir, xml) do
    path = Path.join(dir, "read_back.musicxml")
    File.write!(path, xml)
    path
  end
end
