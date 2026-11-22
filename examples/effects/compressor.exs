defmodule Effects.Compressor do
  @moduledoc """
  The compressor on a bass guitar whose notes come out uneven, some plucked hard and some
  barely touched: it turns the loud notes down, so the line sits at one level, the use
  Wikipedia's "Dynamic range compression" gives for it on a bass,
  https://en.wikipedia.org/wiki/Dynamic_range_compression.
  Two bars in A minor play five times:

  1. dry, the notes from 7 to 15 dB below full scale;
  2. the compressor as it comes: every note is over `threshold: -18`, and at `ratio: 4` the line
     comes out within 4 dB, about 7 dB lower;
  3. `threshold: -10`, which only the hard notes pass, so they come down 2 dB and the soft ones
     stay as they were;
  4. `threshold: -18, ratio: 20, makeup: 9`, where almost nothing rises above the threshold, and
     `makeup` brings the line back up;
  5. `ratio: 4, makeup: 7, relax_ms: 1200`, which takes over a second to let go, so a soft note
     after a hard one stays down.
  """

  use Mx.Song, tempo: 96

  part :bass, synth: :deep_bass, defaults: [amp: 2], fx: [compressor: [mix: 0]]

  def song do
    form([:dry, :defaults, :high, :flat, :slow], fn section ->
      part(:bass, together([line(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, compressor(mix: 0)}]
  defp set(:defaults), do: [{0, compressor(mix: 1)}]
  defp set(:high), do: [{0, compressor(threshold: -10)}]
  defp set(:flat), do: [{0, compressor(threshold: -18, ratio: 20, makeup: 9)}]
  defp set(:slow), do: [{0, compressor(ratio: 4, makeup: 7, relax_ms: 1200)}]

  defp compressor(opts), do: change({:bass, :compressor}, opts)

  # Eighths on A and its octave, fifth and seventh, each with the vel it is plucked at.
  defp line do
    at(
      for {beat, note, vel, sustain} <- [
            {0, 33, 1.0, 0.9},
            {1, 45, 0.3, 0.4},
            {1.5, 33, 0.9, 0.4},
            {2, 40, 0.4, 0.9},
            {3, 43, 1.0, 0.4},
            {3.5, 45, 0.25, 0.4},
            {4, 33, 1.0, 0.9},
            {5, 45, 0.3, 0.4},
            {5.5, 43, 0.5, 0.4},
            {6, 40, 0.9, 0.9},
            {7, 36, 0.3, 0.4},
            {7.5, 38, 1.0, 0.4}
          ] do
        {beat, note(note, 0, vel: vel, sustain: sustain)}
      end,
      8
    )
  end
end
