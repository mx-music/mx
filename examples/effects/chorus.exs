defmodule Effects.Chorus do
  @moduledoc """
  The chorus on a clean electric guitar picking chords, which adds a copy of the sound whose
  delay sweeps back and forth, so one guitar sounds like two slightly apart; Wikipedia's "Chorus
  (audio effect)" describes it, https://en.wikipedia.org/wiki/Chorus_(audio_effect).
  Two bars of A minor 9 and F major 7 play five times:

  1. dry;
  2. the chorus as it comes, its delay sweeping four times a beat;
  3. `phase: 2`, a slow sweep once every two beats;
  4. `decay: 0.25` with that sweep, the delayed sound fed back so it rings;
  5. `mix: 0.5`, half the dry guitar and half the chorus.
  """

  use Mx.Song, tempo: 92

  part :guitar, synth: :electric_guitar, defaults: [vel: 0.6, amp: 2], fx: [chorus: [mix: 0]]

  def song do
    form([:dry, :defaults, :slow, :ringing, :half], fn section ->
      part(:guitar, together([picking(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, chorus(mix: 0)}]
  defp set(:defaults), do: [{0, chorus(mix: 1)}]
  defp set(:slow), do: [{0, chorus(phase: 2)}]
  defp set(:ringing), do: [{0, chorus(decay: 0.25)}]
  defp set(:half), do: [{0, chorus(decay: 0.00001, mix: 0.5)}]

  defp chorus(opts), do: change({:guitar, :chorus}, opts)

  # Eighths up and down each chord, every note left to ring into the next.
  defp picking do
    seq(
      for chord <- [[45, 52, 59, 60, 64], [41, 48, 57, 60, 64]] do
        [a, b, c, d, e] = chord
        seq(for note <- [a, b, c, d, e, d, c, b], do: note(note, 0.5, sustain: 2))
      end
    )
  end
end
