defmodule Effects.Pan do
  @moduledoc """
  The pan effect on a guitar picking A minor and F, placing it between the two speakers.
  The two bars play five times:

  1. as written, in the centre, `pan: 0`;
  2. `pan: -1`, all the way left;
  3. `pan: 1`, all the way right;
  4. `pan: 0.4`, a little right of centre;
  5. `pan` gliding from the left to the right over the first bar and back over the second.
  """

  use Mx.Song, tempo: 84

  part :guitar, synth: :guitar, defaults: [vel: 0.6], fx: [pan: []]

  def song do
    form([:centre, :left, :right, :off_centre, :across], fn section ->
      part(:guitar, together([picking(), at(set(section), 8)]))
    end)
  end

  defp set(:centre), do: [{0, pan(pan: 0)}]
  defp set(:left), do: [{0, pan(pan: -1)}]
  defp set(:right), do: [{0, pan(pan: 1)}]
  defp set(:off_centre), do: [{0, pan(pan: 0.4)}]

  defp set(:across) do
    [{0, pan(pan: -1)}, {0.1, pan(pan: 1, pan_slide: 3.9)}, {4, pan(pan: -1, pan_slide: 4)}]
  end

  defp pan(opts), do: change({:guitar, :pan}, opts)

  # Eighths, the thumb on the bass string and three fingers above it, each note left to ring.
  defp picking do
    seq(
      for [bass, low, middle, high] <- [[45, 57, 60, 64], [41, 57, 60, 65]] do
        seq(
          for note <- [bass, middle, high, middle, low, middle, high, middle],
              do: note(note, 0.5, sustain: 2)
        )
      end
    )
  end
end
