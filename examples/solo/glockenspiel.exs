defmodule Glockenspiel do
  @moduledoc """
  A solo for the glockenspiel written for mx: a melody high in its range, damped as it goes, then
  notes struck once and left to ring, and a last arpeggio up to its top bar.
  """

  use Mx.Song, tempo: 92

  part :glockenspiel, synth: :glockenspiel

  def song do
    repeat(form())
  end

  # The form, each of its passes a section.
  defp form do
    form([melody: 2, ring: 1, ending: 1], fn section, %{pass: pass} ->
      part(:glockenspiel, glockenspiel(section, pass))
    end)
  end

  # A pass of glockenspiel, as 8 beats.
  defp glockenspiel(section, pass) do
    notes =
      for {beat, note, vel, sustain, release} <- strokes(section, pass),
          do: {beat, note(note, sustain, vel: vel, release: release)}

    at(notes, 8)
  end

  # Each note of the melody is damped when the next one comes, as a player stops a bar with a
  # finger.
  defp strokes(:melody, pass) do
    for {beat, note, held} <- phrase(pass), do: {beat, note, 0.6, held - 0.1, 0.1}
  end

  # A C major chord one bar at a time, every bar left to ring under the ones after it.
  defp strokes(:ring, _pass) do
    for {note, index} <- Enum.with_index([72, 76, 79, 84]), do: {index * 2, note, 0.7, 1000, 0.3}
  end

  # An arpeggio in eighths from C6 up to E8, the top bar, left to ring.
  defp strokes(:ending, _pass) do
    for {note, index} <- Enum.with_index([84, 88, 91, 96, 100, 103, 108, 112]),
        do: {index / 2, note, 0.65, 1000, 0.3}
  end

  # Each phrase's notes as beat, note and beats held; the second ends on the tonic.
  defp phrase(0) do
    [{0, 88, 1}, {1, 91, 1}, {2, 96, 1.5}, {3.5, 95, 0.5}, {4, 93, 1}, {5, 91, 1}, {6, 88, 2}]
  end

  defp phrase(1) do
    [{0, 89, 1}, {1, 93, 1}, {2, 98, 1.5}, {3.5, 96, 0.5}, {4, 95, 1}, {5, 91, 1}, {6, 96, 2}]
  end
end
