defmodule Bassoon do
  @moduledoc """
  A solo for the bassoon written for mx: a song-like melody in B flat in its tenor register, a
  walking bass line low in its range, a comic tune in short detached notes, and the melody again,
  closing on its low B flat.
  """

  use Mx.Song, tempo: 76

  part :bassoon, synth: :bassoon

  def song do
    repeat(
      form([tenor: 1, bass: 1, detached: 2, ending: 1], fn section, %{pass: pass} ->
        part(:bassoon, bassoon(section, pass))
      end)
    )
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  defp bassoon(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The melody with a little vibrato, each note held to just before the next.
  defp strokes(:tenor, _pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note, 0.6, sustain: held - 0.1, release: 0.15, vibrato: 0.1}
  end

  # B flat, E flat, F and B flat again, a walking bass line in quarters, each bar's root louder.
  defp strokes(:bass, _pass) do
    line = [34, 38, 41, 43, 39, 43, 46, 48, 41, 45, 48, 45, 46, 41, 38, 34]

    Enum.with_index(line, fn note, i ->
      {i, note, if(rem(i, 4) == 0, do: 0.7, else: 0.55), sustain: 0.8, release: 0.1}
    end)
  end

  # A comic tune in eighths and sixteenths, every note short and detached, louder on the first and
  # third beats; the second time an octave down.
  defp strokes(:detached, pass) do
    shift = if pass == 2, do: 0, else: -12

    bar = [
      {0, 65},
      {0.5, 62},
      {1, 58},
      {1.5, 62},
      {2, 65},
      {2.25, 67},
      {2.5, 69},
      {2.75, 70},
      {3, 65}
    ]

    for repeat <- 0..3,
        {beat, note} <- bar,
        do:
          {repeat * 4 + beat, note + shift, if(beat in [0, 2], do: 0.7, else: 0.55),
           sustain: 0.08, release: 0.04}
  end

  # The melody's first bars again, then down to its low B flat, held.
  defp strokes(:ending, _pass) do
    first =
      for {beat, note, held} <- melody(),
          beat < 8,
          do: {beat, note, 0.6, sustain: held - 0.1, release: 0.15, vibrato: 0.1}

    first ++
      [{8, 46, 0.6, sustain: 1.9, release: 0.15}, {10, 34, 0.75, sustain: 5.5, release: 0.6}]
  end

  # The melody's notes as beat, note and beats held, in its tenor register.
  defp melody do
    [
      {0, 58, 1},
      {1, 62, 1},
      {2, 65, 1.5},
      {3.5, 63, 0.5},
      {4, 62, 1},
      {5, 60, 1},
      {6, 58, 2},
      {8, 60, 1},
      {9, 62, 0.5},
      {9.5, 63, 0.5},
      {10, 65, 1},
      {11, 67, 1},
      {12, 65, 4}
    ]
  end
end
