defmodule Effects.Hpf do
  @moduledoc """
  The high-pass filter on a guitar's offbeat chords, the skank of reggae, thinned out by
  sweeping the filter up through it: Wikipedia's "King Tubby" tells how he played the high-pass
  filter of his mixing desk in his dubs, https://en.wikipedia.org/wiki/King_Tubby, and "Ska
  stroke" describes the skank, https://en.wikipedia.org/wiki/Ska_stroke.
  Two bars of A minor and D play five times:

  1. dry;
  2. the filter as it comes, `cutoff: 100`, which is E7 and leaves only the pick on the strings;
  3. `cutoff: 72`, the C above middle C, where the chords are thin but whole;
  4. `cutoff` gliding from 40 up to 100 over the two bars;
  5. `cutoff` gliding back down, the body of the guitar returning.
  """

  use Mx.Song, tempo: 74

  part :skank, synth: :guitar, defaults: [vel: 0.6], fx: [hpf: [mix: 0]]

  def song do
    form([:dry, :defaults, :thin, :up, :down], fn section ->
      part(:skank, together([chords(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, hpf(mix: 0)}]
  defp set(:defaults), do: [{0, hpf(mix: 1, cutoff: 100)}]
  defp set(:thin), do: [{0, hpf(cutoff: 72)}]
  defp set(:up), do: [{0, hpf(cutoff: 40)}, {0.1, hpf(cutoff: 100, cutoff_slide: 7.9)}]
  defp set(:down), do: [{0, hpf(cutoff: 40, cutoff_slide: 8)}]

  defp hpf(opts), do: change({:skank, :hpf}, opts)

  # Each chord on beats 2 and 4, a short downstroke and a shorter upstroke after it.
  defp chords do
    seq(
      for chord <- [[57, 60, 64], [57, 62, 66]] do
        at(
          for beat <- [1, 3],
              {offset, sustain, vel} <- [{0, 0.2, 0.7}, {0.5, 0.1, 0.45}] do
            {beat + offset, note(chord, 0, sustain: sustain, vel: vel, strum: 0.02)}
          end,
          4
        )
      end
    )
  end
end
