defmodule Effects.Reverb do
  @moduledoc """
  The reverb on a flute, a room around an instrument recorded close: two slurred phrases in D
  minor with a rest after each, where the room is left on its own.
  The phrases play five times:

  1. dry;
  2. the reverb as it comes, `mix: 1`, which is the room alone with none of the flute itself;
  3. `mix: 0.3`, the flute in front and the room behind it, as it is mostly used;
  4. `room: 0.9`, a bigger room that rings into the rests;
  5. `damp: 1` in that room, which dulls its highs.
  """

  use Mx.Song, tempo: 60

  part :flute, synth: :flute, defaults: [amp: 2], fx: [reverb: [mix: 0]]

  def song do
    form([:dry, :defaults, :behind, :big, :dull], fn section ->
      part(:flute, together([phrases(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, reverb(mix: 0)}]
  defp set(:defaults), do: [{0, reverb(mix: 1)}]
  defp set(:behind), do: [{0, reverb(mix: 0.3)}]
  defp set(:big), do: [{0, reverb(room: 0.9)}]
  defp set(:dull), do: [{0, reverb(damp: 1)}]

  defp reverb(opts), do: change({:flute, :reverb}, opts)

  # D, F and A slurred upward and held, then G falling by step to E.
  defp phrases do
    seq([
      note(74, 2.5, vel: 0.6, changes: [{0.5, note: 77}, {1, note: 81}]),
      rest(1.5),
      note(79, 2, vel: 0.55, changes: [{0.5, note: 77}, {1, note: 76}]),
      rest(2)
    ])
  end
end
