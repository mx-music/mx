defmodule Effects.Flanger do
  @moduledoc """
  The flanger on a hi-hat, which adds a copy of the sound a few milliseconds late and sweeps
  that delay, so a notch moves up and down through the hiss like a jet passing, as Wikipedia's
  "Flanging" describes, https://en.wikipedia.org/wiki/Flanging.
  Two bars of sixteenths play five times:

  1. dry;
  2. the flanger as it comes, one sweep every four beats;
  3. `feedback: 0.7`, the delayed sound fed back, which makes the sweep ring at a pitch;
  4. `phase: 1` with that feedback, a sweep every beat;
  5. `mix: 0.5` with that sweep, half the dry hi-hat and half the flanger.
  """

  use Mx.Song, tempo: 100

  part :hihat, synth: :closed_hihat, defaults: [amp: 1.5], fx: [flanger: [mix: 0]]

  def song do
    form([:dry, :defaults, :ringing, :fast, :half], fn section ->
      part(:hihat, together([sixteenths(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, flanger(mix: 0)}]
  defp set(:defaults), do: [{0, flanger(mix: 1)}]
  defp set(:ringing), do: [{0, flanger(feedback: 0.7)}]
  defp set(:fast), do: [{0, flanger(phase: 1)}]
  defp set(:half), do: [{0, flanger(mix: 0.5)}]

  defp flanger(opts), do: change({:hihat, :flanger}, opts)

  # Accents on the beat and softer strokes between, the last of each beat softest.
  defp sixteenths do
    seq(
      for _beat <- 1..8, vel <- [0.8, 0.35, 0.55, 0.3] do
        note(92, 0.25, vel: vel)
      end
    )
  end
end
