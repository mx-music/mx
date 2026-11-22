Code.require_file("../piano/clair_de_lune_score.exs", __DIR__)

defmodule Salamander do
  @moduledoc """
  Debussy's Clair de lune on the Salamander Grand Piano, Alexander Holm's recordings of a Yamaha
  C5, shared under Creative Commons Attribution 3.0.
  The notes, the touch and the rubato are those of examples/piano/clair_de_lune.exs, from the
  Mutopia Project's public-domain engraving; only the instrument differs.
  The piano is recorded every minor third at sixteen strengths, and the piece asks for most of
  them, from its pianissimo opening to the forte of bar 41 and back.
  A strength is already as loud or as quiet as the piano was when it was recorded, so each note
  keeps the level of its recording instead of being made louder or quieter again by its velocity.
  The recordings have no sustain pedal, so each note is left to ring on after its key for a while
  in its place.
  Download them with mx samples download
  "salamander:Samples", which is
  about 700 MB.
  """

  use Mx.Song, tempo: 120

  # A note every minor third from the lowest A, each at sixteen strengths.
  @files (for index <- 0..29, strength <- 1..16 do
            letter = Enum.at(["A", "C", "D#", "F#"], rem(index, 4))
            octave = if letter == "A", do: div(index, 4), else: div(index, 4) + 1

            {{:salamander, "Samples/#{letter}#{octave}v#{strength}.flac"},
             note: 21 + 3 * index, strength: strength}
          end)

  part :piano,
    synth: sampled(@files),
    defaults: [release: 2.5],
    fx: [level: [amp: 0.85], reverb: [decay_seconds: 2.7, damp: 0.5, mix: 0.25]]

  def song do
    part(:piano, seq(1..72, &bar/1))
  end

  # A bar of the piece, each note's velocity choosing its recording and nothing more.
  defp bar(number) do
    strokes =
      for {beat, note, vel, sustain} <- ClairDeLune.strokes(number) do
        {beat, Mx.note(note, sustain, vel: vel, amp: :math.pow(vel, -0.7))}
      end

    Mx.at(strokes, Float.round(ClairDeLune.warp(number, 9), 3))
  end
end
