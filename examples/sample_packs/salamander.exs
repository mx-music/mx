import Mx

# Debussy's Clair de lune on the Salamander Grand Piano, Alexander Holm's recordings of a Yamaha C5, shared under Creative Commons Attribution 3.0.
# The notes, the touch and the rubato are those of examples/piano/clair_de_lune.exs, from the Mutopia Project's public-domain engraving; only the instrument differs.
# The piano is recorded every minor third at sixteen strengths, and the piece asks for most of them, from its pianissimo opening to the forte of bar 41 and back.
# A strength is already as loud or as quiet as the piano was when it was recorded, so each note keeps the level of its recording instead of being made louder or quieter again by its velocity.
# The recordings have no sustain pedal, so each note is left to ring on after its key for a while in its place.
# Download them with mx samples download "sfzinstruments/SalamanderGrandPiano@3382bf9496bba2486f5ab0de55a264d1dfc38404:Samples", which is about 700 MB.
Code.require_file("../piano/clair_de_lune.exs", __DIR__)

defmodule Salamander do
  @repo "sfzinstruments/SalamanderGrandPiano"
  @commit "3382bf9496bba2486f5ab0de55a264d1dfc38404"

  # A note every minor third from the lowest A, each at sixteen strengths.
  def files do
    for index <- 0..29, strength <- 1..16 do
      letter = Enum.at(["A", "C", "D#", "F#"], rem(index, 4))
      octave = if letter == "A", do: div(index, 4), else: div(index, 4) + 1

      {{:github, @repo, @commit, "Samples/#{letter}#{octave}v#{strength}.flac"},
       note: 21 + 3 * index, strength: strength}
    end
  end

  # A bar of the piece, each note's velocity choosing its recording and nothing more.
  def bar(number) do
    strokes =
      for {beat, note, vel, sustain} <- ClairDeLune.strokes(number) do
        {beat, Mx.note(note, sustain, vel: vel, amp: :math.pow(vel, -0.7))}
      end

    Mx.at(strokes, Float.round(ClairDeLune.warp(number, 9), 3))
  end
end

song(
  tempo: 120,
  music:
    part(:piano, seq(Enum.map(1..72, &Salamander.bar/1)),
      synth: sampled(Salamander.files()),
      defaults: [release: 2.5],
      fx: [level: [amp: 0.85], reverb: [room: 0.75, damp: 0.5, mix: 0.25]]
    )
)
