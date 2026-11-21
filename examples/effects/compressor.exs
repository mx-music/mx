defmodule Effects.Compressor do
  @moduledoc """
  The compressor on a bass guitar whose notes come out uneven, some plucked hard and some
  barely touched: it turns the loud notes down, so the line sits at one level, the use
  Wikipedia's "Dynamic range compression" gives for it on a bass,
  https://en.wikipedia.org/wiki/Dynamic_range_compression.
  Two bars in A minor play five times:

  1. dry;
  2. the compressor as it comes: above `threshold: 0.2` the level rises half as fast, which
     turns only the hardest notes down, by about 1 dB;
  3. `threshold: 0.05`, which catches the soft notes too, with `amp: 2` to bring the line back up;
  4. `slope_above: 0` at that threshold, where nothing rises above it and every note is as loud;
  5. `relax_time: 0.3`, which takes 300 ms to let go, so a soft note after a hard one stays down.
  """

  use Mx.Song, tempo: 96

  part :bass, synth: :deep_bass, defaults: [amp: 2], fx: [compressor: [mix: 0]]

  def song do
    form([:dry, :defaults, :low, :flat, :slow], fn section ->
      part(:bass, together([line(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, compressor(mix: 0)}]
  defp set(:defaults), do: [{0, compressor(mix: 1)}]
  defp set(:low), do: [{0, compressor(threshold: 0.05, amp: 2)}]
  defp set(:flat), do: [{0, compressor(slope_above: 0, amp: 4)}]
  defp set(:slow), do: [{0, compressor(relax_time: 0.3)}]

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
