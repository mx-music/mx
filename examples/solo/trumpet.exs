import Mx

# A solo for the trumpet written for mx: a fanfare call in Bb major, tongued short and answered, a lyrical phrase with vibrato, the call at its loudest with a soft echo, and a last climb to a held Bb5.

defmodule Trumpet do
  import Mx

  # The call as beat, note and beats held: up the Bb major chord in short tongued notes to a held F5.
  def call do
    [
      {0, 65, 0.5},
      {0.75, 65, 0.25},
      {1, 70, 1},
      {2, 70, 0.5},
      {2.75, 74, 0.25},
      {3, 77, 1.5},
      {4.5, 74, 0.5},
      {5, 70, 0.5},
      {5.5, 74, 0.5},
      {6, 77, 2}
    ]
  end

  # Its answer, stepping down to the tonic.
  def answer do
    [
      {8, 77, 0.5},
      {8.75, 77, 0.25},
      {9, 74, 0.5},
      {9.5, 70, 0.5},
      {10, 72, 1},
      {11, 69, 1},
      {12, 70, 0.5},
      {12.5, 65, 0.5},
      {13, 62, 0.5},
      {13.5, 65, 0.5},
      {14, 70, 2}
    ]
  end

  # A slow phrase in half and whole notes, as beat, note and beats held.
  def phrase do
    [
      {0, 62, 2},
      {2, 65, 1},
      {3, 67, 1},
      {4, 69, 3},
      {7, 67, 1},
      {8, 65, 2},
      {10, 62, 2},
      {12, 60, 4}
    ]
  end

  # The call and its answer, the second time a fourth higher; notes under a beat are tongued short.
  def strokes(:fanfare, pass) do
    for {beat, note, held} <- call() ++ answer() do
      if held < 1 do
        {beat, note + pass * 5, 0.8, sustain: 0.15, release: 0.05}
      else
        {beat, note + pass * 5, 0.75, sustain: held - 0.2, release: 0.1}
      end
    end
  end

  # The slow phrase with vibrato, each note held to just before the next.
  def strokes(:lyrical, _pass) do
    for {beat, note, held} <- phrase(),
        do: {beat, note, 0.5, sustain: held - 0.15, release: 0.25, vibrato: 0.1}
  end

  # The call at its loudest, then again at its softest as an echo.
  def strokes(:echo, _pass) do
    for {vel, from} <- [{1, 0}, {0.2, 8}],
        {beat, note, held} <- call() do
      {from + beat, note, vel, sustain: max(held - 0.2, 0.15), release: 0.1}
    end
  end

  # A climb up the Bb major chord in eighths from Bb3 to a held Bb5.
  def strokes(:ending, _pass) do
    run = [58, 62, 65, 70, 74, 77]

    Enum.with_index(run, fn note, i -> {i / 2, note, 0.8, sustain: 0.3, release: 0.05} end) ++
      [
        {length(run) / 2, 82, 0.9,
         sustain: 16 - length(run) / 2 - 0.5, release: 0.4, vibrato: 0.1}
      ]
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  def trumpet(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [fanfare: 2, lyrical: 1, echo: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:trumpet, trumpet(section, pass), synth: :trumpet)
    end)
  end
end

song(tempo: 104, music: repeat(seq(Trumpet.form())))
