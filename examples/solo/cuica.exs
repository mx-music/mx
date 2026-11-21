defmodule Cuica do
  @moduledoc """
  A piece for the cuíca alone, playing its part in a roda de samba, in 2/4, as Luiz Guimarães
  notates it in "A percussão da roda de samba" (UNIRIO).
  The stick is rubbed back and forth on every sixteenth, and the other hand on the head gives
  three sounds: the fundamental, with the head free, the medium one, with the hand resting on it,
  and the high one, with a finger pressing its centre.
  The base plays the fundamental on each beat and three medium strokes after it.
  The roda's two-bar pattern leaves the second beat for a high stroke on its second half, held
  over the barline, and comes back down through three fundamental strokes.
  The variation rests on the beat, answers with three high strokes, and goes on in syncopated
  medium ones.
  The third and fourth sixteenths of a beat come early, as Naveda, Gouyon, Guedes and Leman
  measured across samba recordings.
  Each sound's note, scoop and level are those of the strokes of reinsamba's pack "Cuica" on
  Freesound, which the synth plays back.
  """

  use Mx.Song, tempo: 100

  # Where the four sixteenths of a beat start.
  @sixteenths [0, 0.25, 0.46, 0.71]

  # Each pattern's strokes: the sixteenth it starts on, its sound and how many sixteenths it
  # lasts.
  @base [{0, :low, 1}, {1, :mid, 1}, {2, :mid, 1}, {3, :mid, 1}]
  @roda [
    {0, :low, 1},
    {1, :mid, 1},
    {2, :mid, 1},
    {3, :mid, 1},
    {4, :low, 2},
    {6, :held, 3},
    {9, :low, 2},
    {11, :low, 1},
    {12, :low, 1},
    {13, :mid, 1},
    {14, :mid, 1},
    {15, :mid, 1}
  ]
  @variation [
    {1, :high, 1},
    {2, :high, 1},
    {3, :high, 1},
    {4, :mid, 2},
    {6, :mid, 2},
    {8, :mid, 3},
    {11, :mid, 1},
    {13, :mid, 2},
    {15, :mid, 1}
  ]

  part :cuica, synth: :cuica

  def song do
    base = List.duplicate(:base, 8)

    repeat(
      seq([
        played(base),
        played([:roda, :roda, :roda, :roda]),
        played([:variation, :roda, :variation]),
        played([:roda, :roda, :roda]),
        played(base),
        played([:variation, :roda])
      ])
    )
  end

  # The patterns named, one after another.
  defp played(names), do: part(:cuica, seq(names, &pass/1))

  # A pattern, each stroke lasting until its sixteenths are up.
  defp pass(name) do
    {pattern, beats} = pattern(name)

    strokes =
      for {sixteenth, sound, sixteenths} <- pattern do
        length = Float.round(beat(sixteenth + sixteenths) - beat(sixteenth), 2)
        {beat(sixteenth), hit(sound(sound, sixteenth) ++ [sustain: length])}
      end

    at(strokes, beats)
  end

  defp pattern(:base), do: {@base, 1}
  defp pattern(:roda), do: {@roda, 4}
  defp pattern(:variation), do: {@variation, 4}

  defp beat(sixteenth), do: div(sixteenth, 4) + Enum.at(@sixteenths, rem(sixteenth, 4))

  # The fundamental is strongest on the beat; the medium strokes rise into their note as the stick
  # goes one way and fall into it as it comes back.
  defp sound(:low, sixteenth) when rem(sixteenth, 4) == 0 do
    [note: 64.15, vel: 0.95, scoop: 0.8]
  end

  defp sound(:low, _), do: [note: 64.25, vel: 0.85, scoop: 0.3]
  defp sound(:mid, sixteenth) when rem(sixteenth, 2) == 0, do: [note: 76.8, vel: 0.7, scoop: 1.0]
  defp sound(:mid, _), do: [note: 75.7, vel: 0.85, scoop: -1.1]
  defp sound(:high, _), do: [note: 80.5, vel: 0.9]
  defp sound(:held, _), do: [note: 78.4, vel: 0.9]
end
