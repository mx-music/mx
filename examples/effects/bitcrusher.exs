defmodule Effects.Bitcrusher do
  @moduledoc """
  The bitcrusher on piano chords, the sound of a piano record played back by an early sampler,
  which stored fewer samples a second and fewer bits in each than a compact disc does: the E-mu
  SP-1200 sampled at 26.04 kHz in 12 bits, as Wikipedia's "E-mu SP-1200" gives,
  https://en.wikipedia.org/wiki/E-mu_SP-1200.
  Two bars of D minor 9 and G13 play five times:

  1. dry;
  2. the bitcrusher as it comes: 10000 samples a second of 8 bits each;
  3. `sample_rate: 4000`, where the top of the piano folds back as tones outside the chord;
  4. `bits: 4` at 10000 samples a second, 16 levels, which adds a hiss that follows the notes;
  5. `cutoff: 90` at 4000 samples a second, a low-pass after it that takes the edge off.
  """

  use Mx.Song, tempo: 84

  part :piano, synth: :piano, defaults: [vel: 0.6], fx: [bitcrusher: [mix: 0]]

  def song do
    form([:dry, :defaults, :slow_rate, :few_bits, :filtered], fn section ->
      part(:piano, together([chords(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, bitcrusher(mix: 0)}]
  defp set(:defaults), do: [{0, bitcrusher(mix: 1)}]
  defp set(:slow_rate), do: [{0, bitcrusher(sample_rate: 4000)}]
  defp set(:few_bits), do: [{0, bitcrusher(sample_rate: 10_000, bits: 4)}]
  defp set(:filtered), do: [{0, bitcrusher(sample_rate: 4000, bits: 8, cutoff: 90)}]

  defp bitcrusher(opts), do: change({:piano, :bitcrusher}, opts)

  # The bass note on the one, the chord after it and again before the bar ends.
  defp chords do
    seq(
      for {bass, chord} <- [{38, [57, 60, 64, 65]}, {43, [57, 59, 64, 65]}] do
        at(
          [
            {0, note(bass, 0, vel: 0.7, sustain: 3.5)},
            {0.5, note(chord, 0, sustain: 1.8)},
            {2.5, note(chord, 0, vel: 0.5, sustain: 0.4)},
            {3, note(chord, 0, sustain: 0.9)}
          ],
          4
        )
      end
    )
  end
end
