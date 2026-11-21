defmodule Effects.Lpf do
  @moduledoc """
  The low-pass filter on a bright pad of sawtooth waves, which it closes down and opens again.
  Four bars of chord stabs, A minor, F, C and G, play five times:

  1. dry;
  2. the filter as it comes, `cutoff: 100`, which is E7 and takes off only the top;
  3. `cutoff: 80`, G sharp 5, where the chords lose their edge;
  4. `cutoff: 60`, middle C, where little but the bass notes is left;
  5. `cutoff` gliding from 50 up to 115 over the four bars, the sweep itself.
  """

  use Mx.Song, tempo: 126

  part :pad, synth: :supersaw, defaults: [vel: 0.3, release: 0.2], fx: [lpf: [mix: 0]]

  def song do
    form([:dry, :defaults, :soft, :closed, :sweep], fn section ->
      part(:pad, together([stabs(), at(set(section), 16)]))
    end)
  end

  defp set(:dry), do: [{0, lpf(mix: 0)}]
  defp set(:defaults), do: [{0, lpf(mix: 1, cutoff: 100)}]
  defp set(:soft), do: [{0, lpf(cutoff: 80)}]
  defp set(:closed), do: [{0, lpf(cutoff: 60)}]
  defp set(:sweep), do: [{0, lpf(cutoff: 50)}, {0.1, lpf(cutoff: 115, cutoff_slide: 15.9)}]

  defp lpf(opts), do: change({:pad, :lpf}, opts)

  # A bar a chord: the bass note on the one, the chord on the offbeats and held at the bar's end.
  defp stabs do
    seq(
      for {bass, chord} <- [
            {45, [57, 60, 64, 69]},
            {41, [57, 60, 65, 69]},
            {48, [55, 60, 64, 67]},
            {43, [55, 59, 62, 67]}
          ] do
        at(
          [
            {0, note(bass, 0, sustain: 0.9)},
            {0.5, note(chord, 0, sustain: 0.3)},
            {1.5, note(chord, 0, sustain: 0.3)},
            {2.5, note(chord, 0, sustain: 1.4)}
          ],
          4
        )
      end
    )
  end
end
