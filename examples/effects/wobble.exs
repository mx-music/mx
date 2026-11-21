defmodule Effects.Wobble do
  @moduledoc """
  The wobble on a sawtooth bass holding long notes, the wobble bass of dubstep: a long bass
  note moved in rhythm by a filter that sweeps in time, as Wikipedia's "Dubstep" describes,
  https://en.wikipedia.org/wiki/Dubstep.
  Four bars on E, G and A play five times:

  1. dry;
  2. the wobble as it comes: a sawtooth sweep twice a beat, falling from `cutoff_max` each time;
  3. `wave: 3`, a sine, which opens and closes the filter evenly;
  4. the sine with `phase` set bar by bar: 1, 0.5, a third of a beat and 0.25;
  5. `cutoff_max: 90` and `res: 0.95`, a darker sweep that whistles at its cutoff.
  """

  use Mx.Song, tempo: 140

  part :bass, synth: :saw, defaults: [vel: 0.5], fx: [wobble: [mix: 0]]

  def song do
    form([:dry, :defaults, :sine, :rates, :dark], fn section ->
      part(:bass, together([line(), at(set(section), 16)]))
    end)
  end

  defp set(:dry), do: [{0, wobble(mix: 0)}]
  defp set(:defaults), do: [{0, wobble(mix: 1)}]
  defp set(:sine), do: [{0, wobble(wave: 3)}]

  defp set(:rates) do
    for {beat, phase} <- [{0, 1}, {4, 0.5}, {8, 1 / 3}, {12, 0.25}],
        do: {beat, wobble(phase: phase)}
  end

  defp set(:dark), do: [{0, wobble(phase: 0.5, cutoff_max: 90, res: 0.95)}]

  defp wobble(opts), do: change({:bass, :wobble}, opts)

  defp line do
    seq([
      note(28, 4, sustain: 3.9),
      note(28, 4, sustain: 3.9),
      note(31, 4, sustain: 3.9),
      note(33, 2, sustain: 1.9),
      note(31, 2, sustain: 1.9)
    ])
  end
end
