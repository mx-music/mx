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

  test "a song in 3 writes a score, a MIDI file and an ABC tune in 3/4 unless --time is given",
       %{tmp_dir: dir} do
    song = Path.join(dir, "waltz.exs")

    File.write!(
      song,
      "import Mx\nsong(meter: 3, music: part(:waltz, seq(c4: 1, e4: 1, g4: 1), synth: :piano))\n"
    )

    for {file, args} <- [
          {"waltz.musicxml", []},
          {"waltz.mid", []},
          {"waltz.abc", []},
          {"common.musicxml", ["--time", "4/4"]}
        ] do
      capture_io(fn -> Export.run([song, "--out", Path.join(dir, file) | args]) end)
    end

    assert File.read!(Path.join(dir, "waltz.musicxml")) =~
             "<time><beats>3</beats><beat-type>4</beat-type></time>"

    assert File.read!(Path.join(dir, "common.musicxml")) =~
             "<time><beats>4</beats><beat-type>4</beat-type></time>"

    assert File.read!(Path.join(dir, "waltz.abc")) =~ "\nM:3/4\n"
    {:ok, midi} = Mx.MIDI.parse(File.read!(Path.join(dir, "waltz.mid")), "waltz.mid")
    signatures = for {_, {:meta, 0x58, time}} <- hd(midi.tracks), do: time
    assert [<<3, 2, 24, 8>>] = signatures
  end

  test "a song in E minor writes a score, a MIDI file and an ABC tune in E minor unless --key is given",
       %{tmp_dir: dir} do
    song = Path.join(dir, "minor.exs")

    File.write!(
      song,
      "import Mx\nsong(key: :em, music: part(:tune, seq(e4: 1, fs4: 1, g4: 1), synth: :piano))\n"
    )

    for {file, args} <- [
          {"minor.musicxml", []},
          {"minor.mid", []},
          {"minor.abc", []},
          {"major.musicxml", ["--key", "d"]}
        ] do
      capture_io(fn -> Export.run([song, "--out", Path.join(dir, file) | args]) end)
    end

    assert File.read!(Path.join(dir, "minor.musicxml")) =~
             "<key><fifths>1</fifths><mode>minor</mode></key>"

    assert File.read!(Path.join(dir, "major.musicxml")) =~
             "<key><fifths>2</fifths><mode>major</mode></key>"

    assert File.read!(Path.join(dir, "minor.abc")) =~ "\nK:Em"
    {:ok, midi} = Mx.MIDI.parse(File.read!(Path.join(dir, "minor.mid")), "minor.mid")
    keys = for {_, {:meta, 0x59, key}} <- hd(midi.tracks), do: key
    assert [<<1, 1>>] = keys
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

  # Each note that starts in a bar, by part, as its bar's number, where in the bar it starts, and
  # its pitch.
  defp places(path) do
    {:ok, score} = Score.read(path)

    for part <- score.parts do
      places =
        for bar <- part.bars,
            voice <- bar.voices,
            {piece, at} <- starts(voice),
            note <- piece.notes || [],
            not note.continues,
            do: {bar.number, Float.round(at * 1.0, 3), note.midi}

      Enum.sort(places)
    end
  end

  defp starts(voice) do
    {starts, _end} =
      Enum.map_reduce(voice, 0, fn piece, at -> {{piece, at}, at + piece.length} end)

    starts
  end

  defp bars(path) do
    {:ok, score} = Score.read(path)

    for bar <- hd(score.parts).bars,
        do: {bar.number, bar.voices |> hd() |> Enum.map(& &1.length) |> Enum.sum()}
  end

  test "--pickup 0.5 writes the aria's first eighth as bar 0, and every note in the bar and place the score has it",
       %{tmp_dir: dir} do
    score = Path.join(dir, "pickup_aria.mxl")
    File.cp!(@aria, score)
    song = Path.join(dir, "pickup_aria.exs")
    out = Path.join(dir, "pickup_aria.musicxml")
    capture_io(fn -> Import.run([score]) end)

    capture_io(fn ->
      Export.run([song, "--time", "12/8", "--key", "bm", "--pickup", "0.5", "--out", out])
    end)

    assert File.read!(out) =~ ~s(<measure number="0" implicit="yes">)
    assert [{0, 0.5}, {1, 6.0} | _] = bars(out)

    [violin | _] = places(out)
    assert [{0, +0.0, _}] = Enum.filter(violin, &(elem(&1, 0) == 0))
    assert {1, +0.0, 74} = Enum.find(violin, &(elem(&1, 0) == 1))

    assert places(out) == places(score)
  end

  defp quarters(dir) do
    song = Path.join(dir, "quarters.exs")
    notes = Enum.map_join(1..9, ", ", fn _ -> "c4: 1" end)
    File.write!(song, "import Mx\nsong(music: part(:melody, seq(#{notes}), synth: :piano))\n")
    song
  end

  test "nine quarter notes in 4/4 with --pickup 1 make a bar 0 of one quarter and two full bars, and without it three bars",
       %{tmp_dir: dir} do
    song = quarters(dir)
    out = Path.join(dir, "pickup.musicxml")
    capture_io(fn -> Export.run([song, "--pickup", "1", "--out", out]) end)

    assert bars(out) == [{0, 1.0}, {1, 4.0}, {2, 4.0}]

    out = Path.join(dir, "no_pickup.musicxml")
    capture_io(fn -> Export.run([song, "--out", out]) end)

    assert bars(out) == [{1, 4.0}, {2, 4.0}, {3, 4.0}]
    assert [{3, +0.0, 60}] = out |> places() |> hd() |> Enum.filter(&(elem(&1, 0) == 3))
  end

  test "--pickup 0, 4 and -1 in 4/4 are refused, naming a bar of 4 beats", %{tmp_dir: dir} do
    song = quarters(dir)

    for pickup <- ["0", "4", "-1"] do
      message =
        "--pickup takes a number of beats shorter than a bar of 4 beats, such as 0.5, not #{pickup}"

      assert_raise Mix.Error, message, fn ->
        Export.run([song, "--pickup", pickup, "--out", Path.join(dir, "refused.musicxml")])
      end
    end
  end

  # Each note that starts in a bar of the first part, as its pitch, its staff, where it starts in
  # the song and how long it lasts.
  defp staves(path) do
    {:ok, score} = Score.read(path)
    bars = hd(score.parts).bars

    {notes, _end} =
      Enum.flat_map_reduce(bars, 0, fn bar, from ->
        notes =
          for voice <- bar.voices,
              {piece, at} <- starts(voice),
              note <- piece.notes || [],
              not note.continues,
              do: {note.midi, note.staff, from + at, piece.length}

        {notes, from + (bar.voices |> hd() |> Enum.map(& &1.length) |> Enum.sum())}
      end)

    Enum.sort(notes)
  end

  defp export_part(dir, name, music) do
    song = Path.join(dir, "#{name}.exs")
    File.write!(song, "import Mx\nsong(music: part(:#{name}, #{music}, synth: :piano))\n")
    out = Path.join(dir, "#{name}.musicxml")
    capture_io(fn -> Export.run([song, "--out", out]) end)
    out
  end

  test "the aria's organ is written on a grand staff, and the violin and the alto on one staff each",
       %{tmp_dir: dir} do
    score = Path.join(dir, "staves_aria.mxl")
    File.cp!(@aria, score)
    capture_io(fn -> Import.run([score]) end)
    out = Path.join(dir, "staves_aria.musicxml")
    capture_io(fn -> Export.run([Path.join(dir, "staves_aria.exs"), "--out", out]) end)

    [violin, alto, organ] = String.split(File.read!(out), ~r/<part id=/) |> tl()
    refute violin =~ "<staves>"
    refute alto =~ "<staves>"
    assert organ =~ "<staves>2</staves>"
    assert organ =~ ~s(<clef number="1"><sign>G</sign><line>2</line></clef>)
    assert organ =~ ~s(<clef number="2"><sign>F</sign><line>4</line></clef>)
  end

  test "C2, E3, G4 and C6 go on a grand staff, the two below middle C on the bass staff", %{
    tmp_dir: dir
  } do
    out = export_part(dir, "wide", "seq(c2: 1, e3: 1, g4: 1, c6: 1)")

    assert staves(out) == [
             {36, 2, +0.0, 1.0},
             {52, 2, 1.0, 1.0},
             {67, 1, 2.0, 1.0},
             {84, 1, 3.0, 1.0}
           ]
  end

  test "a chord across middle C is split between the staves, each half keeping its start and length",
       %{tmp_dir: dir} do
    out =
      export_part(
        dir,
        "split",
        "seq([note(:c2, 1), note([:c3, :g3, :e4, :c5], 2), note(:c6, 1)])"
      )

    assert staves(out) == [
             {36, 2, +0.0, 1.0},
             {48, 2, 1.0, 2.0},
             {55, 2, 1.0, 2.0},
             {64, 1, 1.0, 2.0},
             {72, 1, 1.0, 2.0},
             {84, 1, 3.0, 1.0}
           ]
  end

  test "a cello part from C2 to A4 is written on one bass staff", %{tmp_dir: dir} do
    out = export_part(dir, "cello", "seq(c2: 1, g2: 1, d3: 1, a4: 1)")
    xml = File.read!(out)

    refute xml =~ "<staves>"
    assert xml =~ "<clef><sign>F</sign><line>4</line></clef>"
  end
end
