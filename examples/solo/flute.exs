import Mx

# A solo for the flute written for mx: a lyrical melody in D major with vibrato, fast runs in sixteenths, the melody again in its low register, softly, and a last phrase high in its range, loud, up to A6.

defmodule Flute do
  import Mx

  # The melody's notes as beat, note and beats held.
  def melody do
    [
      {0, 74, 1.5},
      {1.5, 76, 0.5},
      {2, 78, 1},
      {3, 81, 1},
      {4, 79, 2},
      {6, 78, 1},
      {7, 76, 1},
      {8, 74, 1.5},
      {9.5, 73, 0.5},
      {10, 71, 1},
      {11, 73, 1},
      {12, 74, 4}
    ]
  end

  # The melody with vibrato, each note held to just before the next.
  def strokes(:lyrical, _pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note, 0.6, sustain: held - 0.15, release: 0.2, vibrato: 0.25}
  end

  # The D major scale in sixteenths, up two octaves from D4 and back, louder on the beat and without vibrato; the second time from A4.
  def strokes(:runs, pass) do
    scale = Enum.filter(62..93, &(rem(&1 - 62, 12) in [0, 2, 4, 5, 7, 9, 11]))
    from = Enum.find_index(scale, &(&1 == if(pass == 1, do: 62, else: 69)))
    up = Enum.slice(scale, from, 15)
    notes = up ++ Enum.drop(Enum.reverse(up), 1) ++ [hd(up)]

    for {note, index} <- Enum.with_index(notes) do
      {index / 4, note, if(rem(index, 4) == 0, do: 0.75, else: 0.6),
       sustain: 0.15, release: 0.05, vibrato: 0}
    end
  end

  # The melody an octave lower, down to its low B and C sharp, played softly.
  def strokes(:low, _pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note - 12, 0.35, sustain: held - 0.15, release: 0.2, vibrato: 0.25}
  end

  # The melody's opening an octave higher and loud, climbing to A6 and held.
  def strokes(:high, _pass) do
    for {beat, note, held} <- Enum.take(melody(), 3) ++ [{3, 81, 6}],
        do: {beat, note + 12, 0.9, sustain: held - 0.15, release: 0.4, vibrato: 0.25}
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  def flute(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [lyrical: 1, runs: 2, low: 1, high: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:flute, flute(section, pass), synth: :flute)
    end)
  end
end

song(tempo: 76, music: repeat(seq(Flute.form())))
