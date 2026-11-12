import Mx

# A piece for the cuíca alone written for mx: its part in a samba batucada, in 2/4, two beats to the bar.
# Strokes fall on sixteenths with accents off the beat; the thumb pressing the head raises the accented strokes a fourth; longer phrases run strokes close together and swell.
defmodule Cuica do
  import Mx

  @low 49.79
  @high @low + 5

  # One bar's strokes as {sixteenth, accented?}: on the beat, then off it on the second and fourth sixteenths of the second beat.
  @figure [{0, false}, {2, true}, {3, false}, {5, true}, {6, false}]

  def figure(raised) do
    for {sixteenth, accented} <- @figure do
      note = if accented and raised, do: @high, else: @low
      {sixteenth / 4, hit(note: note, vel: if(accented, do: 0.85, else: 0.5))}
    end
  end

  # Eight bars of the figure, the accents raised a fourth when `raised`.
  def groove(raised) do
    at(for(bar <- 0..7, {beat, stroke} <- figure(raised), do: {2 * bar + beat, stroke}), 16)
  end

  # A bar of the figure, then a run of seven sixteenths that swells from soft to an accent raised a fourth, four times over.
  def phrases do
    run =
      for i <- 0..6 do
        {2 + i / 4,
         hit(note: if(i == 6, do: @high, else: @low), vel: Float.round(0.4 + 0.08 * i, 2))}
      end

    strokes =
      for start <- [0, 4, 8, 12],
          {beat, stroke} <- figure(false) ++ run,
          do: {start + beat, stroke}

    at(strokes, 16)
  end

  def form do
    seq([
      part(:cuica, groove(false), synth: :cuica),
      part(:cuica, groove(true), synth: :cuica),
      part(:cuica, phrases(), synth: :cuica),
      part(:cuica, groove(true), synth: :cuica)
    ])
  end
end

song(tempo: 100, music: repeat(Cuica.form()))
