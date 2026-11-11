import Mx

# A solo for the French horn written for mx: a broad melody in Eb major, then again an octave lower, hunting calls answered a fourth lower, a long note at its softest and then its loudest, and a run down to a held low Eb2.

defmodule Horn do
  import Mx

  # The melody as beat, note and beats held.
  def melody do
    [
      {0, 63, 2},
      {2, 65, 1},
      {3, 67, 1},
      {4, 70, 3},
      {7, 68, 1},
      {8, 67, 2},
      {10, 65, 1},
      {11, 63, 1},
      {12, 62, 2},
      {14, 63, 2}
    ]
  end

  # A call up the Eb major chord, as beat, note and beats held.
  def call do
    [{0, 58, 0.5}, {0.75, 63, 0.25}, {1, 67, 1}, {2, 70, 0.5}, {2.75, 67, 0.25}, {3, 63, 1}]
  end

  # The melody with a little vibrato, each note held to just before the next, the second time an octave lower.
  def strokes(:melody, pass) do
    for {beat, note, held} <- melody(),
        do: {beat, note - pass * 12, 0.55, sustain: held - 0.15, release: 0.3, vibrato: 0.05}
  end

  # The call, then its answer a fourth lower, twice; notes under a beat are tongued short.
  def strokes(:calls, _pass) do
    for {from, down} <- [{0, 0}, {4, 5}, {8, 0}, {12, 5}], {beat, note, held} <- call() do
      if held < 1 do
        {from + beat, note - down, 0.75, sustain: 0.15, release: 0.05}
      else
        {from + beat, note - down, 0.7, sustain: held - 0.2, release: 0.15}
      end
    end
  end

  # Eb4 then G4 held at its softest, then the same at its loudest.
  def strokes(:extremes, _pass) do
    for {vel, from} <- [{0.2, 0}, {1, 8}],
        {beat, note} <- [{0, 63}, {4, 67}],
        do: {from + beat, note, vel, sustain: 3.6, release: 0.3}
  end

  # A run down the Eb major chord in eighths from Eb5 to a held low Eb2.
  def strokes(:ending, _pass) do
    run = [75, 70, 67, 63, 58, 55, 51, 46, 43]

    Enum.with_index(run, fn note, i -> {i / 2, note, 0.75, sustain: 0.3, release: 0.05} end) ++
      [{length(run) / 2, 39, 0.85, sustain: 16 - length(run) / 2 - 0.5, release: 0.5}]
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  def horn(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [melody: 2, calls: 1, extremes: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:horn, horn(section, pass), synth: :horn)
    end)
  end
end

song(tempo: 72, music: repeat(seq(Horn.form())))
