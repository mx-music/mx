defmodule Clarinet do
  @moduledoc """
  A solo for the clarinet written for mx: a dark melody in G minor low in its range, fast
  arpeggios through its registers, the melody again an octave and a fifth up, and a last phrase
  high in its range, up to G6.
  """

  use Mx.Song, tempo: 84

  part :clarinet, synth: :clarinet

  def song do
    repeat(
      form([low: 1, arpeggios: 2, melody: 1, high: 1], fn section, %{pass: pass} ->
        part(:clarinet, clarinet(section, pass))
      end)
    )
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  defp clarinet(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The melody in its low register, softly, each note held to just before the next.
  defp strokes(:low, _pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note, 0.4, sustain: held - 0.1, release: 0.15}
  end

  # G minor, E flat, C minor and D, each chord's notes up two octaves and a third in sixteenths
  # and back, with a breath before the next, louder on the beat; the second time an octave up.
  defp strokes(:arpeggios, pass) do
    shift = if pass == 1, do: 0, else: 12

    for {chord, bar} <- Enum.with_index([[55, 58, 62], [51, 55, 58], [51, 55, 60], [50, 54, 57]]),
        up =
          0..2
          |> Enum.flat_map(fn octave -> Enum.map(chord, &(&1 + 12 * octave + shift)) end)
          |> Enum.take(8),
        {note, index} <- Enum.with_index(up ++ Enum.drop(Enum.reverse(up), 1)) do
      {bar * 4 + index / 4, note, if(rem(index, 4) == 0, do: 0.75, else: 0.6),
       sustain: 0.15, release: 0.05}
    end
  end

  # The melody an octave and a fifth up, in its clear middle register.
  defp strokes(:melody, _pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note + 19, 0.65, sustain: held - 0.1, release: 0.2}
  end

  # The melody's opening two octaves up and loud, climbing to G6 and held.
  defp strokes(:high, _pass) do
    for {beat, note, held} <- Enum.take(melody(), 3) ++ [{3, 67, 6}],
        do: {beat, note + 24, 0.85, sustain: held - 0.1, release: 0.4}
  end

  # The melody's notes as beat, note and beats held, starting on its low G.
  defp melody do
    [
      {0, 55, 1.5},
      {1.5, 58, 0.5},
      {2, 62, 1},
      {3, 60, 1},
      {4, 58, 2},
      {6, 57, 1},
      {7, 55, 1},
      {8, 53, 1.5},
      {9.5, 55, 0.5},
      {10, 57, 1},
      {11, 50, 1},
      {12, 55, 4}
    ]
  end
end
