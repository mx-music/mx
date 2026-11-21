defmodule Vibraphone do
  @moduledoc """
  A solo for the vibraphone written for mx: chords left to ring with the pedal, the same chords
  with the motor turning, a line of short damped notes, and a last chord.
  """

  use Mx.Song, tempo: 72

  part :vibraphone, synth: :vibraphone

  def song do
    repeat(
      form([chords: 1, motor: 1, damped: 2, ending: 1], fn section, %{pass: pass} ->
        part(:vibraphone, vibraphone(section, pass))
      end)
    )
  end

  # A pass of vibraphone, as 8 beats.
  defp vibraphone(section, _pass) do
    notes =
      for {beat, note, vel, motor, sustain, release} <- strokes(section),
          do: {beat, note(note, sustain, vel: vel, motor: motor, release: release)}

    at(notes, 8)
  end

  # Each chord rings for its two beats, and the pedal damps it as the next one is struck.
  defp strokes(section) when section in [:chords, :motor] do
    motor = if section == :motor, do: 2, else: 0

    for {chord, index} <- Enum.with_index(chords()),
        note <- chord,
        do: {index * 2, note, 0.5, motor, 1.9, 0.1}
  end

  # A line in eighths, each note damped at once, over each chord's lowest note held for its two
  # beats.
  defp strokes(:damped) do
    line = [69, 72, 76, 74, 72, 69, 67, 65, 71, 74, 79, 76, 73, 70, 67, 64]

    held =
      for {chord, index} <- Enum.with_index(chords()),
          do: {index * 2, hd(chord), 0.4, 0, 1.9, 0.1}

    short = for {note, index} <- Enum.with_index(line), do: {index * 0.5, note, 0.6, 0, 0.2, 0.05}
    held ++ short
  end

  defp strokes(:ending) do
    for note <- [48, 55, 59, 62, 64, 71], do: {0, note, 0.55, 2, 6, 1}
  end

  # D minor nine, G thirteen, C major nine and A seven, two beats each.
  defp chords, do: [[53, 57, 60, 64], [53, 57, 59, 64], [52, 55, 59, 62], [55, 58, 61, 64]]
end
