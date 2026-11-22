defmodule Effects.Limiter do
  @moduledoc """
  The limiter on a piano whose bass notes are struck hard under soft chords: it holds every peak
  under its `ceiling`, so the part can be turned up without clipping, the use Wikipedia's
  "Limiter" gives for it, https://en.wikipedia.org/wiki/Limiter.
  Two bars in D minor play five times:

  1. dry, the bass notes far louder than the chords;
  2. `ceiling: -18`, which holds each bass note 18 dB under full scale and lets the chords through
     as they are, so the two come out nearly as loud;
  3. `amp: 4` after it, the whole part 12 dB up, the chords now louder than they were dry and no
     peak above -6 dB;
  4. `relax_ms: 1500`, which takes a second and a half to let the sound back up, so the chords
     after each bass note stay down;
  5. `relax_ms: 1`, which lets go within each wave of a bass note and so bends it, heard as a
     buzz.
  """

  use Mx.Song, tempo: 84

  part :piano, synth: :piano, fx: [limiter: [mix: 0]]

  def song do
    form([:dry, :held, :up, :slow, :fast], fn section ->
      part(:piano, together([bars(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, limiter(mix: 0)}]
  defp set(:held), do: [{0, limiter(mix: 1, ceiling: -18)}]
  defp set(:up), do: [{0, limiter(amp: 4)}]
  defp set(:slow), do: [{0, limiter(relax_ms: 1500)}]
  defp set(:fast), do: [{0, limiter(relax_ms: 1)}]

  defp limiter(opts), do: change({:piano, :limiter}, opts)

  # A bar a chord, D minor then A7: the bass note struck hard on the one, the chord soft on each
  # beat after.
  defp bars do
    seq(
      for {bass, chord} <- [{38, [62, 65, 69]}, {33, [61, 64, 67]}] do
        at(
          [
            {0, note(bass, 0, vel: 1, sustain: 3.5)},
            {1, note(chord, 0, vel: 0.25, sustain: 0.8)},
            {2, note(chord, 0, vel: 0.25, sustain: 0.8)},
            {3, note(chord, 0, vel: 0.25, sustain: 0.8)}
          ],
          4
        )
      end
    )
  end
end
