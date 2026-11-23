defmodule Effects.Width do
  @moduledoc """
  The width effect on a guitar picking A minor and F, the thumb's bass notes on the left and the
  fingers' notes on the right.
  It works on the sum of the two sides, the centre, and on their difference, as Wikipedia's
  "Joint encoding" describes under mid/side stereo, https://en.wikipedia.org/wiki/Joint_encoding.
  The two bars play five times:

  1. as written, `side: 1`, the bass on the left and the fingers on the right;
  2. `side: 0`, mono: both hands in the centre;
  3. `side: 2`, twice the difference between the sides, so each hand is further out than a
     speaker alone puts it;
  4. `mono_below: 60`, which puts everything below middle C in the centre: the bass moves
     there and the fingers stay on the right;
  5. `side` gliding from mono out to 2 over the first bar and back over the second.
  """

  use Mx.Song, tempo: 84

  part :guitar, synth: :guitar, defaults: [vel: 0.5], fx: [width: []]

  def song do
    form([:written, :mono, :wide, :low_centre, :across], fn section ->
      part(:guitar, together([picking(), at(set(section), 8)]))
    end)
  end

  defp set(:written), do: [{0, width(side: 1, mono_below: 0)}]
  defp set(:mono), do: [{0, width(side: 0)}]
  defp set(:wide), do: [{0, width(side: 2)}]
  defp set(:low_centre), do: [{0, width(side: 1, mono_below: 60)}]

  defp set(:across) do
    [
      {0, width(side: 0, mono_below: 0)},
      {0.1, width(side: 2, side_slide: 3.9)},
      {4, width(side: 0, side_slide: 4)}
    ]
  end

  defp width(opts), do: change({:guitar, :width}, opts)

  # Eighths, the thumb on the bass string and three fingers above it, each note left to ring.
  defp picking do
    seq(
      for [bass, low, middle, high] <- [[45, 57, 60, 64], [41, 57, 60, 65]] do
        seq(
          for note <- [bass, middle, high, middle, low, middle, high, middle] do
            pan = if note == bass, do: -0.8, else: 0.6
            note(note, 0.5, sustain: 2, pan: pan)
          end
        )
      end
    )
  end
end
