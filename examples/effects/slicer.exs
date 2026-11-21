defmodule Effects.Slicer do
  @moduledoc """
  The slicer on a held pad of sawtooth waves, which it turns on and off in time: the gated pad
  of trance records, which Wikipedia describes under "Trance gating" in "Noise gate",
  https://en.wikipedia.org/wiki/Noise_gate.
  Four held chords, A minor, F, C and G, play six times:

  1. dry;
  2. the slicer as it comes: on and off four times a beat, half of each cycle on;
  3. `phase: 0.5`, twice a beat;
  4. `pulse_width: 0.25` at four times a beat, a quarter of each cycle on, so the pad stabs;
  5. `amp_min: 0.4`, the pad turned down between the stabs instead of off;
  6. `phase` gliding from a beat down to an eighth of one over the four chords, the gate
     speeding up.
  """

  use Mx.Song, tempo: 132

  part :pad, synth: :supersaw, defaults: [vel: 0.3], fx: [slicer: [mix: 0]]

  def song do
    form([:dry, :defaults, :slow, :stabs, :shallow, :faster], fn section ->
      part(:pad, together([chords(), at(set(section), 16)]))
    end)
  end

  defp set(:dry), do: [{0, slicer(mix: 0)}]
  defp set(:defaults), do: [{0, slicer(mix: 1)}]
  defp set(:slow), do: [{0, slicer(phase: 0.5)}]
  defp set(:stabs), do: [{0, slicer(phase: 0.25, pulse_width: 0.25)}]
  defp set(:shallow), do: [{0, slicer(amp_min: 0.4)}]

  defp set(:faster) do
    [
      {0, slicer(amp_min: 0, pulse_width: 0.5, phase: 1)},
      {0.1, slicer(phase: 0.125, phase_slide: 15.9)}
    ]
  end

  defp slicer(opts), do: change({:pad, :slicer}, opts)

  defp chords do
    seq(
      for chord <- [[45, 57, 60, 64], [41, 57, 60, 65], [48, 55, 60, 64], [43, 55, 59, 62]] do
        note(chord, 4, sustain: 3.9)
      end
    )
  end
end
