import Mx

# A solo for the tenor saxophone written for mx: a choro melody in F major with its runs in sixteenths, a slow phrase with vibrato, the same phrase at its softest and then its loudest, and a last run down to its low A flat.

defmodule TenorSax do
  import Mx

  # Each bar of the choro as beat and note, a run of sixteenths up to a held note and down; the second pass answers the first a fourth lower.
  def choro(0) do
    [
      {0, 65},
      {0.25, 67},
      {0.5, 69},
      {0.75, 70},
      {1, 72},
      {2, 69},
      {2.25, 70},
      {2.5, 72},
      {2.75, 74},
      {3, 72},
      {3.5, 69},
      {4, 70},
      {4.25, 69},
      {4.5, 67},
      {4.75, 65},
      {5, 64},
      {6, 67},
      {6.25, 65},
      {6.5, 64},
      {6.75, 62},
      {7, 60}
    ]
  end

  def choro(1) do
    for {beat, note} <- choro(0), do: {beat, note - 5}
  end

  # A slow phrase in half and whole notes, as beat, note and beats held.
  def phrase do
    [{0, 60, 2}, {2, 65, 2}, {4, 64, 1}, {5, 62, 1}, {6, 60, 2}, {8, 57, 4}, {12, 53, 4}]
  end

  # The choro twice through, short notes in the runs and the notes on the beat held, louder on the beat.
  def strokes(:choro, pass) do
    bar = choro(pass)
    ends = Enum.map(Enum.drop(bar, 1), &elem(&1, 0)) ++ [8]

    for half <- [0, 8],
        {{beat, note}, next} <- Enum.zip(bar, ends) do
      {half + beat, note, if(beat == trunc(beat), do: 0.7, else: 0.55),
       sustain: (next - beat) * 0.8, release: 0.05}
    end
  end

  # The slow phrase with full vibrato, each note held to just before the next.
  def strokes(:slow, _pass) do
    for {beat, note, held} <- phrase(),
        do: {beat, note, 0.6, sustain: held - 0.15, release: 0.2, vibrato: 1}
  end

  # The phrase's first half at its softest, then its second half at its loudest.
  def strokes(:extremes, _pass) do
    for {beat, note, held} <- phrase(),
        do:
          {beat, note, if(beat < 8, do: 0.2, else: 1),
           sustain: held - 0.15, release: 0.2, vibrato: 0.5}
  end

  # A run down the F major scale in sixteenths from E5 to its low A flat, held.
  def strokes(:ending, _pass) do
    run = Enum.filter(76..45//-1, &(rem(&1, 12) in [0, 2, 4, 5, 7, 9, 10]))

    Enum.with_index(run, fn note, i -> {i / 4, note, 0.65, sustain: 0.2, release: 0.05} end) ++
      [{length(run) / 4, 44, 0.8, sustain: 16 - length(run) / 4 - 0.5, release: 0.4, vibrato: 1}]
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  def tenor_sax(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [choro: 2, slow: 1, extremes: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:tenor_sax, tenor_sax(section, pass), synth: :tenor_sax)
    end)
  end
end

song(tempo: 88, music: repeat(seq(TenorSax.form())))
