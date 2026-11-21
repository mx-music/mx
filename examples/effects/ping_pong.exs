defmodule Effects.PingPong do
  @moduledoc """
  The ping-pong echo on a rimshot, whose repeats alternate between the right speaker and the
  left: a few strokes fill both sides of an empty bar.
  Three strokes and the silence after them play six times:

  1. dry;
  2. the echo as it comes: a repeat every quarter of a beat, each half as loud as the last,
     the first on the right;
  3. `phase: 0.75`, a repeat every three quarters of a beat;
  4. `feedback: 0.8`, each repeat keeping four fifths of the last, so they cross many times;
  5. `mix: 0.3`, the repeats under the strokes;
  6. `phase` gliding from 0.75 down to 0.25 while the repeats ring, which raises their pitch.
  """

  use Mx.Song, tempo: 74

  part :rimshot, synth: :rimshot, defaults: [amp: 0.5], fx: [ping_pong: [mix: 0]]

  def song do
    form([:dry, :defaults, :dotted, :long, :under, :bend], fn section ->
      part(:rimshot, together([strokes(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, ping_pong(mix: 0)}]
  defp set(:defaults), do: [{0, ping_pong(mix: 1)}]
  defp set(:dotted), do: [{0, ping_pong(phase: 0.75)}]
  defp set(:long), do: [{0, ping_pong(feedback: 0.8)}]
  defp set(:under), do: [{0, ping_pong(feedback: 0.5, mix: 0.3)}]

  defp set(:bend) do
    [{0, ping_pong(feedback: 0.8, mix: 1)}, {4, ping_pong(phase: 0.25, phase_slide: 3)}]
  end

  defp ping_pong(opts), do: change({:rimshot, :ping_pong}, opts)

  defp strokes do
    at([{0, note(74, 0, vel: 0.8)}, {2, note(74, 0, vel: 0.6)}, {2.5, note(74, 0, vel: 0.8)}], 8)
  end
end
