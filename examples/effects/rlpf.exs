defmodule Effects.Rlpf do
  @moduledoc """
  The resonant low-pass filter on a sawtooth bass playing sixteenths, the line of acid house,
  made by lowering the filter's cutoff and raising its resonance on a Roland TB-303, as
  Wikipedia's "Acid house" describes, https://en.wikipedia.org/wiki/Acid_house.
  Four bars in A minor play five times:

  1. dry;
  2. the filter as it comes, `cutoff: 100` and `res: 0.5`;
  3. `cutoff: 70`, the B flat above middle C, where the line turns round and dull;
  4. `res: 0.9` at that cutoff, the filter ringing at B flat on every note;
  5. `cutoff` gliding from 50 up to 100 over two bars and back down, with the filter ringing.
  """

  use Mx.Song, tempo: 124

  part :bass, synth: :saw, defaults: [vel: 0.5, release: 0.05], fx: [rlpf: [mix: 0]]

  def song do
    form([:dry, :defaults, :closed, :ringing, :sweep], fn section ->
      part(:bass, together([line(), at(set(section), 16)]))
    end)
  end

  defp set(:dry), do: [{0, rlpf(mix: 0)}]
  defp set(:defaults), do: [{0, rlpf(mix: 1, cutoff: 100)}]
  defp set(:closed), do: [{0, rlpf(cutoff: 70)}]
  defp set(:ringing), do: [{0, rlpf(res: 0.9)}]

  defp set(:sweep) do
    [
      {0, rlpf(cutoff: 50)},
      {0.1, rlpf(cutoff: 100, cutoff_slide: 7.9)},
      {8, rlpf(cutoff: 50, cutoff_slide: 8)}
    ]
  end

  defp rlpf(opts), do: change({:bass, :rlpf}, opts)

  # A bar of sixteenths, a rest written as nil and an accent as a note an octave up, four times.
  defp line do
    bar = [33, 33, 45, 33, nil, 33, 36, 33, 45, nil, 33, 31, 33, 45, 40, 43]

    seq(
      for _bar <- 1..4, step <- bar do
        if step, do: note(step, 0.25, sustain: 0.2), else: rest(0.25)
      end
    )
  end
end
