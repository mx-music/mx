defmodule Effects.Distortion do
  @moduledoc """
  The distortion on an electric guitar playing power chords, a root and its fifth, the chord
  that Wikipedia's "Power chord" says is commonly played through distortion,
  https://en.wikipedia.org/wiki/Power_chord.
  Two bars on E, G, A and E play five times:

  1. dry;
  2. the distortion as it comes, `distort: 0.5`;
  3. `distort: 0.2`, an amplifier just starting to break up;
  4. `distort: 0.95`, where the chords sustain and buzz;
  5. `distort` gliding from 0 to 0.95 over the two bars.

  The distortion brings every chord up to full scale, so the driven sections play with
  `amp: 0.15` to sit near the level of the dry one.
  """

  use Mx.Song, tempo: 100

  part :guitar,
    synth: :electric_guitar,
    defaults: [vel: 0.8, amp: 1.5],
    fx: [distortion: [mix: 0]]

  def song do
    form([:dry, :defaults, :light, :heavy, :rising], fn section ->
      part(:guitar, together([riff(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, distortion(mix: 0, amp: 1)}]
  defp set(:defaults), do: [{0, distortion(mix: 1, amp: 0.15, distort: 0.5)}]
  defp set(:light), do: [{0, distortion(distort: 0.2)}]
  defp set(:heavy), do: [{0, distortion(distort: 0.95)}]

  defp set(:rising) do
    [{0, distortion(distort: 0)}, {0.1, distortion(distort: 0.95, distort_slide: 7.9)}]
  end

  defp distortion(opts), do: change({:guitar, :distortion}, opts)

  # Eighths on the low E string, muted short, with a power chord held on each change.
  defp riff do
    at(
      for {beat, root, sustain} <- [
            {0, 40, 1.4},
            {1.5, 40, 0.2},
            {2, 43, 0.9},
            {3, 45, 0.9},
            {4, 40, 1.4},
            {5.5, 40, 0.2},
            {6, 45, 0.4},
            {6.5, 43, 0.4},
            {7, 40, 0.9}
          ] do
        {beat, note([root, root + 7, root + 12], 0, sustain: sustain)}
      end,
      8
    )
  end
end
