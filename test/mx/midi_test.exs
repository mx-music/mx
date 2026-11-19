defmodule Mx.MIDITest do
  use ExUnit.Case, async: true

  import Bitwise
  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.{Export, Import}
  alias Mx.ScoreNotes

  @moduletag :tmp_dir

  # A Standard MIDI File of format 1 at 480 ticks a beat, each track a list of {tick, bytes}.
  defp smf(tracks) do
    chunks =
      for events <- tracks do
        last = events |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 0 end)

        {body, _tick} =
          (events ++ [{last, <<0xFF, 0x2F, 0>>}])
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.map_reduce(0, fn {tick, bytes}, previous ->
            {[vlq(tick - previous), bytes], tick}
          end)

        body = IO.iodata_to_binary(body)
        <<"MTrk", byte_size(body)::32, body::binary>>
      end

    IO.iodata_to_binary([<<"MThd", 6::32, 1::16, length(tracks)::16, 480::16>> | chunks])
  end

  defp vlq(value) when value < 0x80, do: <<value>>
  defp vlq(value), do: high(value >>> 7) <> <<value &&& 0x7F>>
  defp high(0), do: <<>>
  defp high(value), do: high(value >>> 7) <> <<(value &&& 0x7F) ||| 0x80>>

  defp name(text), do: {0, <<0xFF, 0x03, byte_size(text)>> <> text}
  defp tempo(bpm, tick \\ 0), do: {tick, <<0xFF, 0x51, 3, round(60_000_000 / bpm)::24>>}
  defp meter(beats, power), do: {0, <<0xFF, 0x58, 4, beats, power, 24, 8>>}

  defp note(channel, key, from, to, velocity \\ 80) do
    [{from, <<0x90 + channel, key, velocity>>}, {to, <<0x80 + channel, key, 0>>}]
  end

  defp write(dir, file, tracks) do
    path = Path.join(dir, file)
    File.write!(path, smf(tracks))
    path
  end

  defp import!(path, args \\ []) do
    output = capture_io(fn -> Import.run([path | args]) end)
    {Path.rootname(path) <> ".exs", output}
  end

  test "a file of four tracks, two with notes, says so with its ticks to a quarter note", %{
    tmp_dir: dir
  } do
    path =
      write(dir, "four.mid", [
        [tempo(48), meter(4, 2)],
        [name("Right") | note(0, 72, 0, 480)],
        [name("Words")],
        [name("Left") | note(1, 48, 0, 1920)]
      ])

    assert {:ok, about} = Mx.Score.about(path)
    assert about.tracks == 4
    assert about.tracks_with_notes == 2
    assert about.ticks == 480
    assert about.meter == "4/4"
  end

  test "a file's tempo changes are given with the bar and the beat each falls on", %{tmp_dir: dir} do
    path =
      write(dir, "slowing.mid", [
        [tempo(48), meter(4, 2), tempo(46, 3 * 4 * 480)],
        note(0, 60, 0, 5 * 4 * 480)
      ])

    assert {:ok, about} = Mx.Score.about(path)

    assert about.tempos == [
             %{bar: 1, beat: 0.0, tempo: 48},
             %{bar: 4, beat: 12.0, tempo: 46}
           ]
  end

  test "a file cut short inside a track says what is wrong when asked what it holds", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "take_3.mid")
    data = smf([[tempo(100)], note(0, 60, 0, 480)])
    File.write!(path, binary_part(data, 0, byte_size(data) - 6))
    assert Mx.Score.about(path) == {:error, "#{path} is cut short inside a track"}
  end

  test "gives a note as it was played, its beat and length unmoved by any grid", %{tmp_dir: dir} do
    path = write(dir, "late.mid", [[tempo(100) | note(0, 60, 490, 720, 127)]])

    assert {:ok, %{ticks: 480, parts: [%{name: "track 1", notes: [played]}]}} =
             Mx.MIDI.played(path)

    assert played.midi == 60 and played.vel == 1.0
    assert_in_delta played.beat, 1.0208333, 1.0e-6
    assert_in_delta played.length, 0.4791667, 1.0e-6
  end

  test "gives the parts as played named as reading the file names them, and leaves drums out", %{
    tmp_dir: dir
  } do
    right = [name("Right") | note(0, 72, 5, 480) ++ note(9, 36, 0, 120)]
    path = write(dir, "hands.mid", [[tempo(100)], right, [name("Left") | note(1, 48, 0, 960)]])

    {:ok, score} = Mx.Score.read(path)
    {:ok, played} = Mx.MIDI.played(path)
    assert Enum.map(played.parts, & &1.name) == Enum.map(score.parts, & &1.name)
    assert Enum.map(played.parts, fn part -> Enum.map(part.notes, & &1.midi) end) == [[72], [48]]
  end

  test "a file cut short inside a track says so when asked for its notes as played", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "take_4.mid")
    data = smf([[tempo(100)], note(0, 60, 0, 480)])
    File.write!(path, binary_part(data, 0, byte_size(data) - 6))
    assert Mx.MIDI.played(path) == {:error, "#{path} is cut short inside a track"}
  end

  test "a file of two tracks named Right and Left imports as parts right and left that play its pitches",
       %{tmp_dir: dir} do
    right = Enum.concat([note(0, 72, 0, 480), note(0, 74, 480, 960), note(0, 76, 960, 1440)])
    pedal = [{0, <<0xB0, 64, 127>>}, {1440, <<0xB0, 64, 0>>}]
    left = note(1, 48, 0, 1920)

    path =
      write(dir, "two_hands.mid", [
        [tempo(100)],
        [name("Right") | right ++ pedal],
        [name("Left") | left]
      ])

    {song, output} = import!(path)

    assert output =~ "Right on tri: 3 notes from :c5 to :e5\n"
    assert output =~ "Left on tri: 1 notes from :c3 to :c3\n"
    assert output =~ "Right: 1 press of the sustain pedal is left out\n"
    assert File.read!(song) =~ "use Mx.Song, tempo: 100"
    assert File.read!(song) =~ "part :right, synth: :tri"

    assert ScoreNotes.played(song) == [
             [{0.0, 72, 1.0}, {1.0, 74, 1.0}, {2.0, 76, 1.0}],
             [{0.0, 48, 4.0}]
           ]
  end

  test "a note struck at velocity 64 imports with vel 0.5", %{tmp_dir: dir} do
    path =
      write(dir, "velocity.mid", [
        [name("Right") | note(0, 72, 0, 480, 64) ++ note(0, 74, 480, 960, 127)]
      ])

    {song, _output} = import!(path, ["--part", "Right=piano"])

    assert File.read!(song) =~ "note(:c5, 1, vel: 0.5)"
    assert File.read!(song) =~ "note(:d5, 1, vel: 1.0)"
  end

  test "a note off the beat moves to the nearest sixteenth note, and --grid 1/12 keeps triplets",
       %{tmp_dir: dir} do
    late = round(0.020 * 2 * 480)

    path =
      write(dir, "late.mid", [
        [tempo(120)],
        [name("Melody") | note(0, 60, 0, 480) ++ note(0, 62, 480 + late, 960)]
      ])

    {song, _output} = import!(path)
    assert ScoreNotes.played(song) == [[{0.0, 60, 1.0}, {1.0, 62, 1.0}]]

    triplets = Enum.concat([note(0, 60, 0, 160), note(0, 62, 160, 320), note(0, 64, 320, 480)])
    path = write(dir, "triplets.mid", [[tempo(120)], [name("Melody") | triplets]])

    {song, _output} = import!(path, ["--grid", "1/12"])

    assert ScoreNotes.played(song) == [
             [{0.0, 60, 0.333333}, {0.333333, 62, 0.333333}, {0.666667, 64, 0.333333}]
           ]

    assert File.read!(song) =~ "c4: 1 / 3, d4: 1 / 3, e4: 1 / 3"
  end

  test "drums on channel 10 are left out, and the task says so", %{tmp_dir: dir} do
    path =
      write(dir, "with_drums.mid", [
        [tempo(90)],
        [name("Kit") | note(9, 36, 0, 120) ++ note(9, 38, 480, 600)],
        [name("Bass") | note(0, 40, 0, 960) ++ note(9, 42, 0, 60)]
      ])

    {song, output} = import!(path)

    assert output =~
             "Kit is left out: its 2 notes are on channel 10, which General MIDI keeps for drums\n"

    assert output =~
             "Bass: 1 note on channel 10, which General MIDI keeps for drums, is left out\n"

    assert ScoreNotes.played(song) == [[{0.0, 40, 2.0}]]
  end

  test "the import counts the drum notes, the presses of the pedal and the controller messages it leaves out, and names the tempo",
       %{tmp_dir: dir} do
    drums = Enum.flat_map(0..15, &note(9, 36, &1 * 480, &1 * 480 + 60))

    presses =
      Enum.flat_map(0..7, fn press ->
        [
          {press * 960, <<0xB0, 64, 127>>},
          {press * 960 + 120, <<0xB0, 64, 100>>},
          {press * 960 + 480, <<0xB0, 64, 0>>}
        ]
      end)

    modulation = for step <- 0..4, do: {step * 100, <<0xB0, 1, step * 20>>}
    right = Enum.flat_map(0..15, &note(0, 72, &1 * 480, &1 * 480 + 480))

    path =
      write(dir, "counted.mid", [
        [tempo(90), tempo(46, 3 * 1920)],
        [name("Kit") | note(0, 40, 0, 480) ++ drums],
        [name("Right") | right ++ presses ++ modulation]
      ])

    {_song, output} = import!(path, ["--tempo", "90"])

    assert output =~
             "Kit: 16 notes on channel 10, which General MIDI keeps for drums, are left out\n"

    assert output =~ "Right: 8 presses of the sustain pedal are left out\n"
    assert output =~ "Right: 5 other controller messages are left out\n"
    assert output =~ "the tempo 46 from bar 4 is left out\n"

    {:ok, score} = Mx.Score.read(path)

    assert score.left_out_counts == [
             {"Kit", :drum_notes, 16},
             {"Right", :pedal_presses, 8},
             {"Right", :other_controls, 5}
           ]
  end

  test "a single track with a melody on channel 1 and chords on channel 2 imports as two parts",
       %{tmp_dir: dir} do
    melody = Enum.concat([note(0, 76, 0, 480), note(0, 77, 480, 960)])
    chords = Enum.concat([note(1, 48, 0, 960), note(1, 52, 0, 960), note(1, 55, 0, 960)])
    path = write(dir, "one_track.mid", [[tempo(80), name("Piano") | melody ++ chords]])

    {song, output} = import!(path)

    assert output =~ "channel 1 on tri: 2 notes from :e5 to :f5\n"
    assert output =~ "channel 2 on tri: 3 notes from :c3 to :g3\n"
    assert File.read!(song) =~ "note([:c3, :e3, :g3], 2)"

    assert ScoreNotes.played(song) == [
             [{0.0, 76, 1.0}, {1.0, 77, 1.0}],
             [{0.0, 48, 2.0}, {0.0, 52, 2.0}, {0.0, 55, 2.0}]
           ]
  end

  # Four bars of 12/8, a dotted quarter note at a time, at 48 and then 46 from bar 4.
  defp slowing(dir) do
    notes = Enum.flat_map(0..15, &note(0, 60 + rem(&1, 8), &1 * 720, &1 * 720 + 720))

    write(dir, "slowing.mid", [
      [meter(12, 3), tempo(48), tempo(46, 3 * 2880)],
      [name("Melody") | notes]
    ])
  end

  defp followed(song) do
    out = Path.rootname(song) <> ".wav"
    capture_io(fn -> assert :ok = Mx.Render.render(song, out, follow: self(), force: true) end)

    Stream.repeatedly(fn -> receive do: ({:mx_beat, %{} = beat} -> beat), after: (0 -> nil) end)
    |> Enum.take_while(& &1)
  end

  test "a file that slows from 48 to 46 at bar 4 imports to a song that plays bars 1 to 3 at 48 and bar 4 at 46, as long as the file plays",
       %{tmp_dir: dir} do
    {song, output} = import!(slowing(dir))

    refute output =~ "the tempo"
    assert File.read!(song) =~ "use Mx.Song, tempo: 48"

    assert [%{beat: 0, tempo: 48, heard_us: 0}, %{beat: 18, tempo: 46, heard_us: bar_4}] =
             followed(song)

    assert bar_4 == 22_500_000
    ends_us = bar_4 + 6 * 60_000_000 / 46
    file_us = 18 * 60_000_000 / 48 + 6 * 60_000_000 / 46
    assert abs(ends_us - file_us) < 0.25 * 60_000_000 / 46
  end

  test "a file that slows from 48 to 46 plays unwritten as the song an import writes, and with a tempo given names the later one as left out",
       %{tmp_dir: dir} do
    path = slowing(dir)
    {:ok, song, imported} = Mx.Import.load(path)
    assert song.tempo == 48
    assert imported.left_out == []
    assert Path.wildcard(Path.join(dir, "*")) == [path]

    {:ok, song, imported} = Mx.Import.load(path, tempo: "48")
    assert song.tempo == 48
    assert song.tempos == nil
    assert imported.left_out == ["the tempo 46 from bar 4 is left out"]
  end

  test "a file played unwritten keeps its notes on the grid it is given", %{tmp_dir: dir} do
    notes = Enum.concat([note(0, 60, 0, 180), note(0, 62, 180, 240), note(0, 64, 240, 480)])
    path = write(dir, "fast.mid", [[tempo(120)], [name("Melody") | notes]])

    starts = fn grid ->
      {:ok, song, _imported} = Mx.Import.load(path, grid: grid)
      {:ok, %{events: events}} = Mx.Pass.events(hd(song.loops), 0)
      events |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
    end

    assert starts.("1/16") == [0, 0.5]
    assert starts.("1/32") == [0, 0.375, 0.5]
    assert Path.wildcard(Path.join(dir, "*")) == [path]
  end

  test "a tempo change inside a bar is written at its beat on the grid", %{tmp_dir: dir} do
    notes = Enum.flat_map(0..7, &note(0, 60, &1 * 480, &1 * 480 + 480))

    path =
      write(dir, "inside.mid", [[tempo(100), tempo(80, 6 * 480 + 10)], [name("Melody") | notes]])

    {song, _output} = import!(path)

    assert File.read!(song) =~ "at([{6, tempo(80)}], 8)"
    assert [%{beat: 0, tempo: 100}, %{beat: 6, tempo: 80}] = followed(song)

    {_song, output} = import!(path, ["--tempo", "100", "--force"])
    assert output =~ "the tempo 80 from beat 3 of bar 2 is left out\n"
  end

  test "with --tempo 60 the song plays at 60 throughout and the import names the tempo 46 as left out",
       %{tmp_dir: dir} do
    {song, output} = import!(slowing(dir), ["--tempo", "60"])

    assert output =~ "the tempo 46 from bar 4 is left out\n"
    assert File.read!(song) =~ "use Mx.Song, tempo: 60"
    refute File.read!(song) =~ "tempo("
    assert [%{beat: 0, tempo: 60}] = followed(song)
  end

  test "a file with one tempo imports with no tempo change in its song", %{tmp_dir: dir} do
    path =
      write(dir, "steady.mid", [
        [tempo(100), tempo(100, 960)],
        [name("Melody") | note(0, 60, 0, 1920)]
      ])

    {song, output} = import!(path)

    refute output =~ "the tempo"
    refute File.read!(song) =~ "tempo("
  end

  test "a file that slows at bar 4, imported, exported and imported again, gives the same song",
       %{tmp_dir: dir} do
    {song, _output} = import!(slowing(dir))
    out = Path.join(dir, "again.mid")
    capture_io(fn -> Export.run([song, "--out", out, "--time", "12/8"]) end)
    [conductor | _parts] = tracks(out)

    assert metas(conductor, 0x51) == [
             <<round(60_000_000 / 48)::24>>,
             <<round(60_000_000 / 46)::24>>
           ]

    assert [{8640, _}] = for({tick, {:meta, 0x51, _}} = event <- conductor, tick > 0, do: event)

    {again, _output} = import!(out)
    # The export titles the file after the song, so only the song's first line differs.
    module = &String.replace(&1, ~r/\A.*\n.*\n.*\n/, "")
    assert module.(File.read!(again)) == module.(File.read!(song))
  end

  test "a file that is not a MIDI file is refused", %{tmp_dir: dir} do
    path = Path.join(dir, "noise.mid")
    File.write!(path, "not a midi file")

    assert_raise Mix.Error, "#{path} is not a MIDI file", fn -> Import.run([path]) end
  end

  defp tracks(path) do
    {:ok, midi} = Mx.MIDI.parse(File.read!(path), path)
    midi.tracks
  end

  defp metas(track, type) do
    for {_tick, {:meta, ^type, payload}} <- track, do: payload
  end

  test "a song exports as one track per part that plays notes, named after the part, at the song's tempo, leaving drums out",
       %{tmp_dir: dir} do
    song = Path.join(dir, "trio.exs")

    File.write!(song, """
    import Mx
    song(tempo: 90, music: together([
      part(:melody, seq(e4: 1, g4: 1), synth: :piano),
      part(:kick, steps("x...", 1), synth: :kick),
      part(:bass, note(:c2, 2, vel: 0.8), synth: :piano)
    ]))
    """)

    out = Path.join(dir, "trio.mid")
    output = capture_io(fn -> Export.run([song, "--out", out]) end)

    assert output =~ "Wrote #{out}\n"
    assert output =~ "melody: 2 notes from e4 to g4\n"
    assert output =~ "kick is left out: it plays no notes with a pitch\n"

    assert <<"MThd", 6::32, 1::16, 3::16, 480::16, _::binary>> = File.read!(out)
    [conductor, melody, bass] = tracks(out)

    assert metas(conductor, 0x51) == [<<round(60_000_000 / 90)::24>>]
    assert metas(melody, 0x03) == ["melody"]
    assert metas(bass, 0x03) == ["bass"]

    ons = for {tick, {:on, _, key, velocity}} <- bass, do: {tick, key, velocity}
    offs = for {tick, {:off, _, key}} <- bass, do: {tick, key}
    assert ons == [{0, 36, 102}]
    assert offs == [{960, 36}]
  end

  test "a song exported and imported again plays the same notes", %{tmp_dir: dir} do
    song = Path.join(dir, "round.exs")

    File.write!(song, """
    import Mx
    song(tempo: 110, music: together([
      part(:lead, seq([note(:c4, 0.25), note(:d4, 0.75), note(:e4, 1.5), note(:f4, 3.5), note(:g4, 0.5)]), synth: :piano),
      part(:pads, seq([note([:c3, :e3, :g3], 2), rest(1), note([:f3, :a3], 3.25)]), synth: :piano)
    ]))
    """)

    out = Path.join(dir, "round_trip.mid")
    capture_io(fn -> Export.run([song, "--out", out]) end)
    {again, _output} = import!(out)

    assert ScoreNotes.played(again) == ScoreNotes.played(song)
  end

  test "a tempo change over some beats exports as a change at once where it starts, and the export says so",
       %{tmp_dir: dir} do
    song = Path.join(dir, "easing.exs")

    File.write!(song, """
    import Mx
    song(tempo: 90, music: together([
      part(:melody, seq(c4: 4, d4: 4), synth: :piano),
      at([{2, tempo(60, over: 4)}], 8)
    ]))
    """)

    out = Path.join(dir, "easing.mid")
    output = capture_io(fn -> Export.run([song, "--out", out]) end)

    assert output =~
             "the tempo's move to 60 over 4 beats from beat 2 is written as a change at once\n"

    [conductor | _parts] = tracks(out)
    tempos = for {tick, {:meta, 0x51, <<us::24>>}} <- conductor, do: {tick, us}
    assert tempos == [{0, round(60_000_000 / 90)}, {960, 1_000_000}]
  end

  test "the README's Gymnopédie exports with the time signature and key given", %{tmp_dir: dir} do
    [_, code] = Regex.run(~r/```elixir\n(.*?)```/s, File.read!("README.md"))
    song = Path.join(dir, "gymnopedie.exs")
    File.write!(song, code)
    out = Path.join(dir, "gymnopedie.mid")

    capture_io(fn -> Export.run([song, "--out", out, "--time", "3/4", "--key", "d"]) end)
    [conductor | _parts] = tracks(out)

    assert metas(conductor, 0x58) == [<<3, 2, 24, 8>>]
    assert metas(conductor, 0x59) == [<<2, 0>>]
    assert metas(conductor, 0x51) == [<<round(60_000_000 / 72)::24>>]
  end
end
