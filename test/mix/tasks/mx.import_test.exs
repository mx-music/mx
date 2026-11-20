defmodule Mix.Tasks.Mx.ImportTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.{Import, Print}

  @chorale "examples/wachet_auf/bwv140.7.mxl"

  setup %{tmp_dir: dir} do
    score = Path.join(dir, "bwv140.7.mxl")
    File.cp!(@chorale, score)
    %{score: score, song: Path.join(dir, "bwv140.7.exs")}
  end

  @moduletag :tmp_dir

  test "writes the chorale beside the score with a part for each part of the score on tri", ctx do
    import!([ctx.score, "--tempo", "100"])
    song = File.read!(ctx.song)

    assert String.starts_with?(song, "defmodule Bwv1407 do\n")
    assert song =~ "\n  A score, imported from bwv140.7.mxl by mix mx.import.\n"
    assert song =~ "\n  \"\"\"\n\n  use Mx.Song, tempo: 100\n"

    assert Regex.scan(~r/^  part :(\w+), synth: :tri$/m, song, capture: :all_but_first) ==
             [["soprano"], ["alto"], ["tenor"], ["bass"]]
  end

  test "the soprano starts on eb4 and g4 as quarter notes and bb4 as a dotted quarter", ctx do
    import!([ctx.score, "--tempo", "100"])

    assert File.read!(ctx.song) =~
             "\n  defp bar(:soprano, 1), do: seq(eb4: 1, g4: 1, bb4: 1.5, bb4: 0.5)\n"

    soprano = print(ctx.song, "soprano")
    assert soprano =~ ~r/^beat 0 +play 63 sustain: 1$/m
    assert soprano =~ ~r/^beat 1 +play 67 sustain: 1$/m
    assert soprano =~ ~r/^beat 2 +play 70 sustain: 1.5$/m
  end

  test "--part plays a part on a synth, and the parts without one on tri", ctx do
    output =
      import!([ctx.score, "--tempo", "100", "--part", "Soprano=oboe", "--part", "Bass=cello"])

    song = File.read!(ctx.song)

    assert song =~ "\n  part :soprano, synth: :oboe\n"
    assert song =~ "\n  part :alto, synth: :tri\n"
    assert song =~ "\n  part :tenor, synth: :tri\n"
    assert song =~ "\n  part :bass, synth: :cello\n"
    assert song =~ "\n      part(:soprano, seq(Enum.map(order(), &bar(:soprano, &1)))),\n"

    assert print(ctx.song, "soprano") =~ ~r/^beat 0 +play 63 sustain: 1$/m
    assert output =~ "Soprano on oboe: 62 notes from :eb4 to :g5\n"
  end

  test "prints each part with its synth, its notes, and its lowest and highest", ctx do
    output = import!([ctx.score, "--tempo", "100", "--part", "Bass=cello"])

    assert output =~ "Wrote #{ctx.song}\n"
    assert output =~ "Soprano on tri: 62 notes from :eb4 to :g5\n"
    assert output =~ "Alto on tri: 66 notes from :bb3 to :c5\n"
    assert output =~ "Tenor on tri: 67 notes from :g3 to :f4\n"
    assert output =~ "Bass on cello: 81 notes from :eb2 to :eb4\n"
  end

  test "the first 8 bars play twice and bars 9 to 18 once, 99 beats, and the song ends", ctx do
    import!([ctx.score, "--tempo", "100"])

    assert File.read!(ctx.song) =~ "\n  defp order, do: Enum.concat([1..8, 1..8, 9..18])\n"
    assert print(ctx.song, "soprano") =~ "soprano, 99 beats at 100 bpm\n"

    # Bar 8 has 3 beats, so the repeat starts again on beat 31, and bar 9's pickup takes 1.
    soprano = print(ctx.song, "soprano")
    assert soprano =~ ~r/^beat 31 +play 63 sustain: 1$/m
    assert soprano =~ ~r/^beat 62 +play 70 sustain: 1$/m

    assert {:ok, song} = Mx.Song.load(ctx.song)
    assert Enum.all?(song.loops, &(&1.passes == 1))
  end

  test "the chorale's two ties each play as one note", ctx do
    import!([ctx.score, "--tempo", "100"])
    song = File.read!(ctx.song)

    assert song =~
             "\n  defp bar(:bass, 1) do\n    seq([\n      note(:eb3, 2, sustain: 2.5),\n      rest(0.5),\n      note(:g3, 0.5),\n      note(:bb3, 0.5),\n      note(:ab3, 0.5)\n    ])\n  end\n"

    assert length(Regex.scan(~r/, sustain: /, song)) == 2

    bass = print(ctx.song, "bass")
    assert bass =~ ~r/^beat 0 +play 51 sustain: 2.5$/m
    refute bass =~ ~r/^beat 2 /m
  end

  test "a tie from one voice into another plays as one note, and a later note of its name plays",
       %{tmp_dir: dir} do
    bar =
      attributes(1) <>
        note("B", 4, 1, ~s(<tie type="start"/><voice>1</voice>)) <>
        "<note><rest/><duration>1</duration><voice>1</voice></note>" <>
        note("B", 4, 2, "<voice>1</voice>") <>
        "<backup><duration>4</duration></backup>" <>
        "<note><rest/><duration>1</duration><voice>2</voice></note>" <>
        note("B", 4, 1, ~s(<tie type="stop"/><voice>2</voice>)) <>
        "<note><rest/><duration>2</duration><voice>2</voice></note>"

    path = score!(dir, "across.musicxml", [{"Organ", [bar]}])
    import!([path, "--tempo", "60"])
    organ = print(Path.join(dir, "across.exs"), "organ")

    assert organ =~ ~r/^beat 0 +play 71 sustain: 2$/m
    refute organ =~ ~r/^beat 1 /m
    assert organ =~ ~r/^beat 2 +play 71 sustain: 2$/m
  end

  test "a tie within one voice joins its own voice's note, beside the same note in another voice",
       %{tmp_dir: dir} do
    bar =
      attributes(1) <>
        note("C", 5, 2, ~s(<tie type="start"/><voice>1</voice>)) <>
        note("C", 5, 2, ~s(<tie type="stop"/><voice>1</voice>)) <>
        "<backup><duration>4</duration></backup>" <>
        "<note><rest/><duration>2</duration><voice>2</voice></note>" <>
        note("C", 5, 2, "<voice>2</voice>")

    path = score!(dir, "within.musicxml", [{"Organ", [bar]}])
    import!([path, "--tempo", "60"])
    organ = print(Path.join(dir, "within.exs"), "organ")

    assert organ =~ ~r/^beat 0 +play 72 sustain: 4$/m
    assert length(Regex.scan(~r/^beat 2 +play 72 sustain: 2$/m, organ)) == 1
  end

  test "the aria's notes play as the score writes them, its tie between voices too", %{
    tmp_dir: dir
  } do
    score = Path.join(dir, "bwv244.39.mxl")
    File.cp!("examples/erbarme_dich/bwv244.39.mxl", score)
    import!([score])
    song = Path.join(dir, "bwv244.39.exs")

    organ = print(song, "organo_a_canne")
    assert organ =~ ~r/^beat 166\.5 +play 71 vel: 0\.3, sustain: 1\.5$/m
    refute organ =~ ~r/^beat 167 +play 71 /m
    assert organ =~ ~r/^beat 168\.5 +play 71 vel: 0\.3, sustain: 3\.75$/m

    {:ok, original} = Mx.Score.read(score)
    assert Mx.ScoreNotes.played(song) == Mx.ScoreNotes.written(original)
  end

  test "the aria's import counts the text, slurs, trills and fermatas it leaves out, after the parts",
       %{tmp_dir: dir} do
    score = Path.join(dir, "bwv244.39.mxl")
    File.cp!("examples/erbarme_dich/bwv244.39.mxl", score)

    output = import!([score])

    assert output =~
             ~r/Organo a canne on tri: .*\n151 syllables of text are left out\n275 slurs are left out\n3 trills are left out\n3 fermatas are left out\n84 grace notes are left out\n22 articulations, such as staccato, are left out\n/
  end

  test "a score of notes only says nothing is left out", %{tmp_dir: dir} do
    path = score!(dir, "plain.musicxml", [{"Flute", [attributes(1) <> note("C", 4, 4)]}])

    refute import!([path, "--tempo", "60"]) =~ "left out"
  end

  test "the chorale's notes play as the score writes them", ctx do
    import!([ctx.score, "--tempo", "100"])

    {:ok, original} = Mx.Score.read(ctx.score)
    assert Mx.ScoreNotes.played(ctx.song) == Mx.ScoreNotes.written(original)
  end

  test "writes a long order of bars in full", %{tmp_dir: dir} do
    first =
      attributes(1) <>
        repeat("left", "forward") <> note("C", 4, 4, ~s(<tie type="stop"/>))

    middle = for _ <- 2..33, do: note("D", 4, 4)
    last = note("C", 4, 4, ~s(<tie type="start"/>)) <> repeat("right", "backward")

    path = score!(dir, "long.musicxml", [{"Flute", [first | middle] ++ [last]}])
    import!([path, "--tempo", "60"])
    song = Path.join(dir, "long.exs")

    refute File.read!(song) =~ "..."
    assert {:ok, %{loops: [%{passes: 1}]}} = Mx.Song.load(song)
    assert print(song, "flute") =~ "flute, 272 beats at 60 bpm\n"
  end

  test "writes one line per bar, each with its number", ctx do
    import!([ctx.score, "--tempo", "100"])

    song = File.read!(ctx.song)
    numbers = Regex.scan(~r/^  defp bar\(:soprano, (\d+)\), do: /m, song, capture: :all_but_first)

    assert numbers == Enum.map(1..18, &[Integer.to_string(&1)])
    assert song =~ "\n  defp bar(:soprano, 9), do: seq(bb4: 1)\n"
  end

  test "a score without a tempo is refused unless --tempo gives one", ctx do
    assert_raise Mix.Error, "give the score's tempo with --tempo", fn -> import!([ctx.score]) end
    refute File.exists?(ctx.song)
  end

  test "takes the tempo from the score's metronome mark", %{tmp_dir: dir} do
    mark =
      ~s(<direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit>) <>
        "<per-minute>72</per-minute></metronome></direction-type></direction>"

    path = score!(dir, "marked.musicxml", [{"Flute", [attributes(4) <> mark <> note("C", 5, 4)]}])
    import!([path])

    assert File.read!(Path.join(dir, "marked.exs")) =~ "use Mx.Song, tempo: 72\n"
  end

  test "a dotted quarter in 6/8 lasts 1.5 beats", %{tmp_dir: dir} do
    bar =
      attributes(2, "<time><beats>6</beats><beat-type>8</beat-type></time>") <>
        note("G", 4, 3, "<dot/>") <> note("A", 4, 3, "<dot/>")

    path = score!(dir, "six.musicxml", [{"Oboe", [bar]}])
    import!([path, "--tempo", "60"])
    song = Path.join(dir, "six.exs")

    assert File.read!(song) =~ "\n  defp bar(:oboe, 1), do: seq(g4: 1.5, a4: 1.5)\n"
    assert print(song, "oboe") =~ ~r/^beat 1.5 +play 69 sustain: 1.5$/m
  end

  test "a clarinet in Bb plays at the pitch it sounds", %{tmp_dir: dir} do
    transpose = "<transpose><diatonic>-1</diatonic><chromatic>-2</chromatic></transpose>"

    path =
      score!(dir, "transposed.musicxml", [
        {"Clarinet in Bb", [attributes(1, transpose) <> note("D", 5, 4)]}
      ])

    output = import!([path, "--tempo", "60"])
    song = Path.join(dir, "transposed.exs")

    assert File.read!(song) =~ "\n  defp bar(:clarinet_in_bb, 1), do: seq(c5: 4)\n"
    assert output =~ "Clarinet in Bb on tri: 1 notes from :c5 to :c5\n"
    assert print(song, "clarinet_in_bb") =~ ~r/^beat 0 +play 72 sustain: 4$/m
  end

  test "two voices on one staff and a chord of three notes all play", %{tmp_dir: dir} do
    bar =
      attributes(1) <>
        note("C", 5, 2, "<voice>1</voice>") <>
        note("E", 4, 2, "<voice>1</voice>", chord: true) <>
        note("G", 4, 2, "<voice>1</voice>", chord: true) <>
        note("D", 5, 2, "<voice>1</voice>") <>
        "<backup><duration>4</duration></backup>" <>
        note("C", 3, 4, "<voice>2</voice>")

    path = score!(dir, "voices.musicxml", [{"Piano", [bar]}])
    import!([path, "--tempo", "60"])
    song = Path.join(dir, "voices.exs")

    assert File.read!(song) =~
             "\n  defp bar(:piano, 1), do: together([seq([note([:c5, :e4, :g4], 2), note(:d5, 2)]), seq(c3: 4)])\n"

    piano = print(song, "piano")

    for {beat, note} <- [{0, 72}, {0, 64}, {0, 67}, {2, 74}, {0, 48}] do
      assert piano =~ ~r/^beat #{beat} +play #{note} /m
    end
  end

  test "a grace note is kept with the note it leads into, and takes no time", %{tmp_dir: dir} do
    grace = fn step, slash ->
      "<note><grace#{slash}/><pitch><step>#{step}</step><octave>5</octave></pitch><voice>1</voice></note>"
    end

    bar =
      attributes(1) <>
        grace.("D", ~s( slash="yes")) <>
        note("C", 5, 2, "<voice>1</voice>") <>
        grace.("F", "") <>
        grace.("G", "") <>
        note("E", 5, 2, "<voice>1</voice>")

    path = score!(dir, "graces.musicxml", [{"Piano", [bar]}])
    {:ok, score} = Mx.Score.read(path)
    [%{bars: [%{voices: [voice]}]}] = score.parts

    assert [
             %{
               onset: +0.0,
               length: 2.0,
               notes: [%{midi: 72}],
               graces: [%{midi: 74, slash: true}]
             },
             %{
               onset: 2.0,
               length: 2.0,
               notes: [%{midi: 76}],
               graces: [%{midi: 77, slash: false}, %{midi: 79, slash: false}]
             }
           ] = voice
  end

  test "dynamic marks set the vel of the notes after them", %{tmp_dir: dir} do
    bars = [
      attributes(1) <> dynamic("p") <> note("C", 4, 2) <> note("D", 4, 2),
      note("E", 4, 2) <> dynamic("f") <> note("F", 4, 2)
    ]

    path =
      score!(dir, "loud.musicxml", [
        {"Violin", bars},
        {"Viola", [attributes(1) <> note("C", 4, 4), note("C", 4, 4)]}
      ])

    import!([path, "--tempo", "60", "--part", "Violin=violin", "--part", "Viola=viola"])
    song = Path.join(dir, "loud.exs")

    assert File.read!(song) =~
             "\n  defp bar(:violin, 1), do: seq([note(:c4, 2, vel: 0.45), note(:d4, 2, vel: 0.45)])\n  defp bar(:violin, 2), do: seq([note(:e4, 2, vel: 0.45), note(:f4, 2, vel: 0.8)])\n"

    violin = print(song, "violin")
    assert violin =~ ~r/^beat 0 +play 60 vel: 0.45, sustain: 2$/m
    assert violin =~ ~r/^beat 4 +play 64 vel: 0.45, sustain: 2$/m
    assert violin =~ ~r/^beat 6 +play 65 vel: 0.8, sustain: 2$/m
    assert print(song, "viola") =~ ~r/^beat 4 +play 60 sustain: 4$/m
  end

  test "first and second endings play on their time through", %{tmp_dir: dir} do
    bars = [
      attributes(1) <> repeat("left", "forward") <> note("C", 4, 4),
      barline("left", ending("1", "start")) <>
        note("D", 4, 4) <> repeat("right", "backward", ending("1", "stop")),
      barline("left", ending("2", "start")) <>
        note("E", 4, 4) <> barline("right", ending("2", "discontinue")),
      note("F", 4, 4)
    ]

    path = score!(dir, "endings.musicxml", [{"Flute", bars}])
    import!([path, "--tempo", "60"])
    song = Path.join(dir, "endings.exs")

    assert File.read!(song) =~ "\n  defp order, do: Enum.concat([1..1, 2..2, 1..1, 3..3, 4..4])\n"

    notes =
      Regex.scan(~r/^beat (\d+) +play (\d+)/m, print(song, "flute"), capture: :all_but_first)

    assert notes == [~w(0 60), ~w(4 62), ~w(8 60), ~w(12 64), ~w(16 65)]
  end

  test "the song loads and prints like a song written by hand", ctx do
    import!([ctx.score, "--tempo", "100", "--part", "Soprano=oboe", "--part", "Bass=cello"])

    assert {:ok, song} = Mx.Song.load(ctx.song)
    assert Enum.map(song.loops, & &1.synth) == [:oboe, :tri, :tri, :cello]

    output = capture_io(fn -> Print.run([ctx.song]) end)
    assert output =~ "soprano, 99 beats at 100 bpm\n"
    assert output =~ "bass, 99 beats at 100 bpm\n"
  end

  test "the chorale saved uncompressed gives the same song", %{tmp_dir: dir} = ctx do
    {:ok, files} = :zip.unzip(String.to_charlist(@chorale), [:memory])
    {_, xml} = Enum.find(files, fn {name, _} -> to_string(name) == "bwv140.7.xml" end)
    plain = Path.join([dir, "plain", "bwv140.7.musicxml"])
    File.mkdir_p!(Path.dirname(plain))
    File.write!(plain, xml)

    import!([ctx.score, "--tempo", "100"])
    import!([plain, "--tempo", "100"])
    song = plain |> Path.rootname() |> Kernel.<>(".exs") |> File.read!()

    assert String.replace(song, "bwv140.7.musicxml", "bwv140.7.mxl") == File.read!(ctx.song)
  end

  test "refuses to write over a song unless --force is given", ctx do
    File.write!(ctx.song, "old")

    assert_raise Mix.Error, "#{ctx.song} already exists; give --force to write over it", fn ->
      import!([ctx.score, "--tempo", "100"])
    end

    assert File.read!(ctx.song) == "old"

    import!([ctx.score, "--tempo", "100", "--force"])
    assert File.read!(ctx.song) =~ "use Mx.Song, tempo: 100\n"
  end

  test "--out names another path for the song", %{tmp_dir: dir} = ctx do
    out = Path.join(dir, "chorale.exs")
    import!([ctx.score, "--tempo", "100", "--out", out])

    assert File.exists?(out)
    refute File.exists?(ctx.song)
  end

  test "refuses what it cannot read, files that are not scores, unknown synths and parts",
       %{tmp_dir: dir} = ctx do
    missing = Path.join(dir, "missing.mxl")

    assert_raise Mix.Error, "cannot read #{missing}", fn ->
      import!([missing, "--tempo", "100"])
    end

    text = Path.join(dir, "notes.xml")
    File.write!(text, "just some notes")

    assert_raise Mix.Error, "#{text} is not a MusicXML score", fn ->
      import!([text, "--tempo", "100"])
    end

    assert_raise Mix.Error, "unknown synth nosuch", fn ->
      import!([ctx.score, "--tempo", "100", "--part", "Soprano=nosuch"])
    end

    assert_raise Mix.Error,
                 "no part named Violin in bwv140.7.mxl; its parts are Soprano, Alto, Tenor and Bass",
                 fn -> import!([ctx.score, "--tempo", "100", "--part", "Violin=oboe"]) end
  end

  test "the scores guide describes importing a score with the chorale" do
    guide = File.read!("documentation/scores.md")

    assert guide =~ "mx import examples/wachet_auf/bwv140.7.mxl --tempo 72"
  end

  describe "with a recording" do
    test "a recording that is not a WAV file is refused, naming it", %{tmp_dir: dir} do
      mp3 = Path.join(dir, "anderson.mp3")

      assert_raise Mix.Error, "give the recording as a WAV file, not #{mp3}", fn ->
        import!([
          "examples/erbarme_dich/bwv244.39.mxl",
          "--recording",
          mp3,
          "--out",
          Path.join(dir, "aria.exs")
        ])
      end
    end

    test "--tempo is refused with --recording, and --bars without it", %{tmp_dir: dir} do
      out = Path.join(dir, "aria.exs")

      assert_raise Mix.Error,
                   "--tempo and --recording both set the tempo; give one of them",
                   fn ->
                     import!([
                       "examples/erbarme_dich/bwv244.39.mxl",
                       "--recording",
                       "a.wav",
                       "--tempo",
                       "40",
                       "--out",
                       out
                     ])
                   end

      assert_raise Mix.Error, ~r/^--bars lines a recording up/, fn ->
        import!(["examples/erbarme_dich/bwv244.39.mxl", "--bars", "0-12", "--out", out])
      end
    end

    test "the aria imported without a recording is the song in its examples", %{tmp_dir: dir} do
      out = Path.join(dir, "aria.exs")

      import!([
        "examples/erbarme_dich/bwv244.39.mxl",
        "--part",
        "Violin=violin",
        "--part",
        "Alto=oboe",
        "--part",
        "Organo a canne=organ",
        "--out",
        out
      ])

      assert File.read!(out) == File.read!("examples/erbarme_dich/aria.exs")
    end
  end

  defp import!(args), do: capture_io(fn -> Import.run(args) end)

  defp print(song, loop) do
    output = capture_io(fn -> Print.run([song]) end)
    [_, section] = Regex.run(~r/(?:^|\n)(#{loop}, \d.*?)(?:\n\n|\z)/s, output)
    section
  end

  defp score!(dir, name, parts) do
    list =
      parts
      |> Enum.with_index(1)
      |> Enum.map_join(fn {{part, _}, i} ->
        ~s(<score-part id="P#{i}"><part-name>#{part}</part-name></score-part>)
      end)

    body =
      parts
      |> Enum.with_index(1)
      |> Enum.map_join(fn {{_, bars}, i} ->
        measures =
          bars
          |> Enum.with_index(1)
          |> Enum.map_join(fn {bar, number} ->
            ~s(<measure number="#{number}">#{bar}</measure>)
          end)

        ~s(<part id="P#{i}">#{measures}</part>)
      end)

    path = Path.join(dir, name)

    File.write!(path, """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
    <score-partwise version="4.0"><part-list>#{list}</part-list>#{body}</score-partwise>
    """)

    path
  end

  defp attributes(divisions, extra \\ "") do
    "<attributes><divisions>#{divisions}</divisions><key><fifths>0</fifths></key>#{extra}</attributes>"
  end

  defp note(step, octave, duration, extra \\ "", opts \\ []) do
    chord = if opts[:chord], do: "<chord/>", else: ""

    "<note>#{chord}<pitch><step>#{step}</step><octave>#{octave}</octave></pitch><duration>#{duration}</duration>#{extra}</note>"
  end

  defp dynamic(mark) do
    "<direction><direction-type><dynamics><#{mark}/></dynamics></direction-type></direction>"
  end

  defp repeat(location, direction, extra \\ "") do
    ~s(<barline location="#{location}">#{extra}<repeat direction="#{direction}"/></barline>)
  end

  defp barline(location, content), do: ~s(<barline location="#{location}">#{content}</barline>)

  defp ending(number, type), do: ~s(<ending number="#{number}" type="#{type}"/>)
end
