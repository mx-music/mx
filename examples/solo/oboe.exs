defmodule Oboe do
  @moduledoc """
  A solo for the oboe written for mx: a pastoral melody in F major, a dance in short detached
  notes, a climb through its range from its low B flat to F6 and back, and the melody again an
  octave up.
  """

  use Mx.Song, tempo: 72

  part :oboe, synth: :oboe

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [melody: 1, dance: 2, range: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:oboe, oboe(section, pass))
    end)
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  defp oboe(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The melody, each note held to just before the next.
  defp strokes(:melody, _pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note, 0.55, sustain: held - 0.1, release: 0.15}
  end

  # A dance in eighths and sixteenths, every note short and detached, louder on the first and
  # third beats; the second time a fourth higher.
  defp strokes(:dance, pass) do
    shift = if pass == 1, do: 0, else: 5

    bar = [
      {0, 72},
      {0.5, 69},
      {0.75, 70},
      {1, 72},
      {1.5, 65},
      {2, 67},
      {2.5, 69},
      {2.75, 70},
      {3, 69},
      {3.5, 67}
    ]

    for repeat <- 0..3,
        {beat, note} <- bar,
        do:
          {repeat * 4 + beat, note + shift, if(beat in [0, 2], do: 0.7, else: 0.55),
           sustain: 0.08, release: 0.04}
  end

  # The F major scale in eighths from its low B flat up to F6, held, and an F major arpeggio in
  # quarters back down to F4.
  defp strokes(:range, _pass) do
    scale = Enum.filter(58..89, &(rem(&1, 12) in [0, 2, 4, 5, 7, 9, 10]))
    {climb, [top]} = Enum.split(scale, -1)
    last = length(climb) / 2

    Enum.with_index(climb, fn note, index ->
      {index / 2, note, 0.6, sustain: 0.4, release: 0.1}
    end) ++
      [{last, top, 0.7, sustain: 12 - last - 0.1, release: 0.15}] ++
      for {note, index} <- Enum.with_index([81, 77, 72, 65]),
          do: {12 + index, note, 0.6, sustain: 0.85, release: 0.15}
  end

  # The melody an octave up and louder, its last note held.
  defp strokes(:ending, _pass) do
    for {beat, note, held} <- melody(),
        do:
          {beat, note + 12, 0.75,
           sustain: held - 0.1, release: if(beat == 12, do: 0.8, else: 0.15)}
  end

  # The melody's notes as beat, note and beats held.
  defp melody do
    [
      {0, 65, 1},
      {1, 69, 0.5},
      {1.5, 67, 0.5},
      {2, 65, 1},
      {3, 72, 1},
      {4, 70, 1.5},
      {5.5, 69, 0.5},
      {6, 67, 2},
      {8, 69, 1},
      {9, 70, 0.5},
      {9.5, 72, 0.5},
      {10, 74, 1},
      {11, 67, 1},
      {12, 65, 4}
    ]
  end
end
