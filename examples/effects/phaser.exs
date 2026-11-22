defmodule Effects.Phaser do
  @moduledoc """
  The phaser on an electric piano, which turns the sound through a chain of all-pass filters and
  adds it to the dry sound, so notches with no pitch of their own sweep up and down through the
  chords, as Wikipedia's "Phaser (effect)" describes,
  https://en.wikipedia.org/wiki/Phaser_(effect).
  Two bars of held chords in A minor play six times:

  1. dry;
  2. the phaser at `mix: 0.5`, half dry and half turned, where its two notches are deepest, one
     sweep every four beats;
  3. `feedback: 0.7`, which raises the sound between the notches, so the sweep sings;
  4. `phase: 1` with that feedback, a sweep every beat;
  5. `stereo_invert_wave: 1` at the slow sweep, the left side rising as the right falls;
  6. `low: 48, high: 84`, the same sweep an octave and more lower, in the body of the chords.

  Its `stages`, here the 4 it comes with, are read when the part starts.
  """

  use Mx.Song, tempo: 80

  part :keys, synth: :electric_piano, defaults: [amp: 1.2], fx: [phaser: [mix: 0]]

  def song do
    form([:dry, :half, :singing, :fast, :across, :low], fn section ->
      part(:keys, together([chords(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, phaser(mix: 0)}]
  defp set(:half), do: [{0, phaser(mix: 0.5)}]
  defp set(:singing), do: [{0, phaser(feedback: 0.7)}]
  defp set(:fast), do: [{0, phaser(phase: 1)}]
  defp set(:across), do: [{0, phaser(phase: 4, stereo_invert_wave: 1)}]
  defp set(:low), do: [{0, phaser(stereo_invert_wave: 0, low: 48, high: 84)}]

  defp phaser(opts), do: change({:keys, :phaser}, opts)

  # A minor seventh for a bar, then D minor seventh, each note held the whole bar.
  defp chords do
    seq(
      for chord <- [[57, 60, 64, 67], [50, 60, 65, 69]] do
        together(for note <- chord, do: note(note, 4, vel: 0.6))
      end
    )
  end
end
