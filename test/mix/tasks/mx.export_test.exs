defmodule Mix.Tasks.Mx.ExportTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.{Export, Import}
  alias Mx.{Pass, Score, Song}

  @aria "examples/erbarme_dich/bwv244.39.mxl"

  @moduletag :tmp_dir

  test "the aria imported and exported again has the notes the imported song plays", %{
    tmp_dir: dir
  } do
    score = Path.join(dir, "bwv244.39.mxl")
    File.cp!(@aria, score)
    song = Path.join(dir, "bwv244.39.exs")
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

    for {played, again} <- Enum.zip(played(song), notes(exported)) do
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

  # Each part's notes as {beat, note, beats} as the song plays them, through the whole of its music once.
  defp played(path) do
    {:ok, song} = Song.load(path)

    for loop <- song.loops do
      {notes, _} =
        Enum.flat_map_reduce(0..(tuple_size(loop.music.sections) - 1), 0, fn pass, start ->
          {:ok, %{notes: notes, beats: beats}} = Pass.events(loop, pass)

          {for({beat, note, held} <- notes, do: {round6(start + beat), note, round6(held)}),
           start + beats}
        end)

      Enum.sort(notes)
    end
  end

  # Each part's notes as {beat, note, beats} from the start of the score, in the order the score
  # plays its bars, a tied note as one note lasting the whole tie.
  defp notes(score) do
    for part <- score.parts do
      bars = Map.new(part.bars, &{&1.number, &1})

      {notes, _} =
        Enum.flat_map_reduce(score.order, 0, fn number, start ->
          bar = Map.fetch!(bars, number)

          notes =
            for voice <- bar.voices,
                group <- voice,
                note <- group.notes,
                do: {start + group.onset, note.midi, group.length, note.tie, note.continues}

          {notes, start + bar_length(bar)}
        end)

      notes
      |> Enum.sort()
      |> Enum.reduce([], &join_tie/2)
      |> Enum.map(fn {beat, note, beats, _tie} -> {round6(beat), note, round6(beats)} end)
      |> Enum.sort()
    end
  end

  # A note tied into joins the note of its pitch that ties out where it starts.
  defp join_tie({beat, note, beats, tie, true}, notes) do
    index =
      Enum.find_index(notes, fn {at, held, length, out} ->
        out and held == note and abs(at + length - beat) < 1.0e-6
      end)

    List.update_at(notes, index, fn {at, held, length, _out} ->
      {at, held, length + beats, tie}
    end)
  end

  defp join_tie({beat, note, beats, tie, false}, notes), do: [{beat, note, beats, tie} | notes]

  defp bar_length(bar), do: bar.voices |> hd() |> Enum.map(& &1.length) |> Enum.sum()

  defp round6(number), do: Float.round(number * 1.0, 6)
end
