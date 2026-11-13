import Mx

# A piece for the cuíca alone, built from the grooves and strokes of reinsamba's pack "Cuica" on Freesound, the recordings the synth is measured from.
# In 2/4, the stick rubs four strokes to the beat, push and pull, the first two long and the last two short, as "cuica (2).wav" and "cuica (12).wav" swing them.
# The groove answers two low strokes, the head free, with two high ones an octave up, a finger pressing the head: the first high stroke rises into its note and the second falls away from it.
# Every fourth beat stays low, and a soft stroke halfway up sometimes leads into a single high one.
# The break slows to the pack's single strokes: low ones that whoop up into their note, then high squeals.
defmodule Cuica do
  import Mx

  # Where the four strokes of a beat start, and so how long each lasts.
  @starts [0, 0.30, 0.62, 0.81, 1]

  # L and l are the low strokes on the beat and after it, the second softer and a little sharp, and k is the short low one; H rises into the high note and h falls from above it; m is the soft stroke halfway up.
  # The notes, scoops and levels are those of the recording's own strokes.
  def stroke("L"), do: [note: 64.15, vel: 0.95, scoop: 0.8]
  def stroke("l"), do: [note: 64.45, vel: 0.6, scoop: 0.3]
  def stroke("k"), do: [note: 64.25, vel: 0.9, scoop: 0.3]
  def stroke("H"), do: [note: 76.8, vel: 0.7, scoop: 1.0]
  def stroke("h"), do: [note: 75.7, vel: 0.9, scoop: -1.1]
  def stroke("m"), do: [note: 72.8, vel: 0.4, scoop: 1.0]

  def beat(:answer), do: ~w(L l H h)
  def beat(:low), do: ~w(L l k k)
  def beat(:lead), do: ~w(L l m h)

  # Beats of four swung strokes, each lasting until the next.
  def groove(beats) do
    strokes =
      for {name, index} <- Enum.with_index(beats),
          {cell, place} <- Enum.with_index(beat(name)) do
        from = Enum.at(@starts, place)
        length = Float.round(Enum.at(@starts, place + 1) - from, 2)
        {index + from, hit(stroke(cell) ++ [sustain: length])}
      end

    at(strokes, length(beats))
  end

  # Four bars of single strokes on the eighths: low ones that scoop up into their note as an isolated stroke does, then high squeals, the last of each bar left to ring.
  def break do
    whoops = for eighth <- 0..6, do: {eighth / 2, hit(vel: 0.8, sustain: 0.42, scoop: 3.3)}

    squeals =
      for eighth <- 0..6,
          do: {4 + eighth / 2, hit(note: 80.5, vel: 0.9, sustain: 0.3)}

    at(whoops ++ squeals, 8)
  end

  def form do
    turn = [:answer, :answer, :answer, :low]
    varied = [:answer, :lead, :answer, :low]

    seq([
      part(:cuica, groove(List.duplicate(:low, 8)), synth: :cuica),
      part(:cuica, groove(turn ++ turn ++ turn ++ varied), synth: :cuica),
      part(:cuica, groove(turn ++ varied ++ [:answer, :low, :answer, :low] ++ varied),
        synth: :cuica
      ),
      part(:cuica, Cuica.break(), synth: :cuica),
      part(:cuica, groove(turn ++ varied ++ turn ++ [:answer, :low, :low, :low]), synth: :cuica)
    ])
  end
end

song(tempo: 104, music: repeat(Cuica.form()))
