Code.require_file("clair_de_lune_score.exs", __DIR__)

defmodule ClairDeLune.Piano do
  @moduledoc """
  Debussy's Clair de lune, the third piece of his Suite bergamasque, published by Fromont in 1905
  and in the public domain.
  The notes are those of the Mutopia Project's public-domain engraving of that edition,
  https://www.mutopiaproject.org, piece 1778.
  The touch, the pedal and the rubato are this performance's, read from Debussy's markings.
  A beat is an eighth note, and each bar of 9/8 is stretched or pressed by the pace of the moment.
  It plays once, all 72 bars, and the song ends.
  """

  use Mx.Song, tempo: 120

  # The dampers fall fast, so each pedal change clears the harmony before.
  part :piano,
    synth: :piano,
    defaults: [pedal: 1, release: 0.3],
    fx: [reverb: [decay_seconds: 2.7, damp: 0.5, mix: 0.3]]

  def song do
    part(:piano, seq(1..72, &bar/1))
  end

  # Each bar's strokes at their beats, the bar lasting as long as its nine eighths take at its
  # pace.
  defp bar(number) do
    strokes =
      for {beat, note, vel, sustain} <- ClairDeLune.strokes(number),
          do: {beat, note(note, sustain, vel: vel)}

    beats = number |> ClairDeLune.warp(9) |> Float.round(3)
    at(strokes, beats)
  end
end
