import Mx

# A piece for the cuíca alone written for mx: its part in a samba batucada, in 2/4, two beats to the bar.
# Every sixteenth is a stroke of the stick, push or pull; the finger pressing the head raises a stroke from the low note to the high one, on the beats or across them, and some phrases climb from one to the other.
defmodule Cuica do
  import Mx

  @low 65
  @high 79

  # One bar's eight strokes, high on the sixteenths given and low between.
  def bar(highs) do
    for sixteenth <- 0..7 do
      if sixteenth in highs,
        do: {sixteenth / 4, hit(note: @high, vel: 0.8)},
        else: {sixteenth / 4, hit(note: @low, vel: 0.55)}
    end
  end

  # Eight bars, high on the beats, or across them on the first, fourth and seventh sixteenths.
  def groove(highs) do
    strokes = for bar <- 0..7, {beat, stroke} <- bar(highs), do: {2 * bar + beat, stroke}
    at(strokes, 16)
  end

  # A bar climbing from the low note to the high one, swelling as it goes, then a bar high on the beats, four times over.
  def phrases do
    climb =
      for step <- 0..7,
          do: {step / 4, hit(note: @low + 2 * step, vel: Float.round(0.45 + 0.05 * step, 2))}

    answer = for {beat, stroke} <- bar([0, 4]), do: {2 + beat, stroke}

    strokes =
      for start <- [0, 4, 8, 12], {beat, stroke} <- climb ++ answer, do: {start + beat, stroke}

    at(strokes, 16)
  end

  def form do
    seq([
      part(:cuica, groove([0, 4]), synth: :cuica),
      part(:cuica, groove([0, 3, 6]), synth: :cuica),
      part(:cuica, phrases(), synth: :cuica),
      part(:cuica, groove([0, 3, 6]), synth: :cuica)
    ])
  end
end

song(tempo: 62, music: repeat(Cuica.form()))
