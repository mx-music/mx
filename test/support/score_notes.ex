defmodule Mx.ScoreNotes do
  @moduledoc """
  Each part's notes as `{beat, note, beats}` from the start, sorted, so a score and a song made
  from it can be compared note for note.
  Beats are rounded to six decimals.
  """

  alias Mx.{Pass, Song}

  @doc "Each part's notes as the song at `path` plays them, through the whole of its music once."
  def played(path) do
    {:ok, song} = Song.load(path)

    for loop <- song.loops do
      {notes, _} =
        Enum.flat_map_reduce(0..(tuple_size(loop.music.sections) - 1), 0, fn pass, start ->
          {:ok, %{notes: notes, beats: beats}} = Pass.events(loop, pass)

          notes = for {beat, note, held} <- notes, do: {round6(start + beat), note, round6(held)}
          {notes, start + beats}
        end)

      Enum.sort(notes)
    end
  end

  @doc """
  Each part's notes as the score read by `Mx.Score` writes them, in the order it plays its bars, a
  tied note as one note lasting the whole tie.
  """
  def written(%Mx.Score{} = score) do
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

  defp bar_length(bar), do: Enum.sum_by(hd(bar.voices), & &1.length)

  defp round6(number), do: Float.round(number * 1.0, 6)
end
