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
  defp tempo(bpm), do: {0, <<0xFF, 0x51, 3, round(60_000_000 / bpm)::24>>}

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
    assert output =~ "Right: the sustain pedal is left out\n"
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
             "Kit is left out: it plays only on channel 10, which General MIDI keeps for drums\n"

    assert output =~
             "Bass: its notes on channel 10, which General MIDI keeps for drums, are left out\n"

    assert ScoreNotes.played(song) == [[{0.0, 40, 2.0}]]
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
