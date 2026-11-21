defmodule Effects.PitchShift do
  @moduledoc """
  The pitch shift on a clarinet, which moves the sound up or down without changing how long
  it lasts; mixed with the dry sound it plays a second voice beside the first, as the
  harmonizer of Wikipedia's "Pitch shifting" does, https://en.wikipedia.org/wiki/Pitch_shifting.
  A phrase in G minor plays six times:

  1. dry;
  2. the effect as it comes, `pitch: 0`, the same notes up to 40 ms late;
  3. `pitch: 12`, an octave up;
  4. `pitch: -12`, an octave down, into the range of a bass clarinet;
  5. `pitch: 7` with `mix: 0.5`, a second clarinet a fifth above the first;
  6. `pitch` gliding from 0 down an octave over each long note, with the dry sound left out.
  """

  use Mx.Song, tempo: 76

  part :clarinet, synth: :clarinet, fx: [pitch_shift: [mix: 0]]

  def song do
    form([:dry, :defaults, :up, :down, :fifth, :dive], fn section ->
      part(:clarinet, together([phrase(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, pitch_shift(mix: 0)}]
  defp set(:defaults), do: [{0, pitch_shift(mix: 1)}]
  defp set(:up), do: [{0, pitch_shift(pitch: 12)}]
  defp set(:down), do: [{0, pitch_shift(pitch: -12)}]
  defp set(:fifth), do: [{0, pitch_shift(pitch: 7, mix: 0.5)}]

  defp set(:dive) do
    [{0, pitch_shift(pitch: 0, mix: 1)}] ++
      for beat <- [2, 6],
          {offset, pitch, slide} <- [{0.5, -12, 1.2}, {1.9, 0, 0}],
          do: {beat + offset, pitch_shift(pitch: pitch, pitch_slide: slide)}
  end

  defp pitch_shift(opts), do: change({:clarinet, :pitch_shift}, opts)

  # Two slurred runs, each up to a long note: G, B flat, D, then A, C and the D above.
  defp phrase do
    seq([
      note(55, 3.8, vel: 0.6, changes: [{0.5, note: 58}, {1, note: 60}, {1.5, note: 62}]),
      rest(0.2),
      note(57, 3.8, vel: 0.6, changes: [{0.5, note: 60}, {1, note: 62}, {1.5, note: 67}]),
      rest(0.2)
    ])
  end
end
