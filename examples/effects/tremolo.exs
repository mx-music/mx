defmodule Effects.Tremolo do
  @moduledoc """
  The tremolo on an electric piano: the Rhodes and the Wurlitzer both have one built in, as
  Wikipedia's "Rhodes piano", https://en.wikipedia.org/wiki/Rhodes_piano, and "Wurlitzer
  electronic piano" describe.
  The same two bars, D minor 9 and G13, play six times:

  1. dry;
  2. the tremolo as it comes: a triangle that turns the sound down to half and back once a bar;
  3. `phase: 0.5`, two pulses a beat, the speed the instruments' own tremolos sit near;
  4. `depth: 1`, each pulse down to silence;
  5. `wave: 1`, a pulse wave, which cuts the sound to half and back with no slope;
  6. `wave: 3`, a sine, with `phase` gliding from a beat to an eighth of one as the chords hold.
  """

  use Mx.Song, tempo: 84

  part :keys, synth: :electric_piano, defaults: [vel: 0.6, amp: 2], fx: [tremolo: [mix: 0]]

  def song do
    form([:dry, :defaults, :fast, :deep, :pulse, :glide], fn section ->
      part(:keys, together([chords(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, tremolo(mix: 0)}]
  defp set(:defaults), do: [{0, tremolo(mix: 1)}]
  defp set(:fast), do: [{0, tremolo(phase: 0.5)}]
  defp set(:deep), do: [{0, tremolo(depth: 1)}]
  defp set(:pulse), do: [{0, tremolo(depth: 0.5, wave: 1)}]

  defp set(:glide) do
    [{0, tremolo(wave: 3, depth: 0.8, phase: 1)}, {0.1, tremolo(phase: 0.125, phase_slide: 7)}]
  end

  defp tremolo(opts), do: change({:keys, :tremolo}, opts)

  # A bar each, the bass note on the one and the chord above it held to the bar's end.
  defp chords do
    seq(
      for {bass, chord} <- [
            {38, [53, 57, 60, 64]},
            {43, [53, 57, 59, 64]}
          ] do
        together([note(bass, 4, vel: 0.7), note(chord, 4)])
      end
    )
  end
end
