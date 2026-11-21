defmodule Effects.Level do
  @moduledoc """
  The level effect on a pipe organ, whose keys cannot play louder or softer: an organist changes
  the level with the swell pedal, which opens and closes shutters in front of the pipes, as
  Wikipedia's "Swell box" describes, https://en.wikipedia.org/wiki/Swell_box.
  The same four chords, C, F, G and C, play four times:

  1. as written, `amp: 1`;
  2. `amp: 0.5`, half the level, 6 dB down;
  3. `amp: 0.25`, 12 dB down;
  4. `amp` gliding from 0.25 up to 1 over the first two chords and back down over the last two,
     as the pedal swells a phrase.
  """

  use Mx.Song, tempo: 72

  part :organ, synth: :organ, defaults: [loud: 1], fx: [level: []]

  def song do
    form([:full, :half, :quarter, :swell], fn section ->
      part(:organ, together([chords(), at(set(section), 8)]))
    end)
  end

  defp set(:full), do: [{0, level(amp: 1)}]
  defp set(:half), do: [{0, level(amp: 0.5)}]
  defp set(:quarter), do: [{0, level(amp: 0.25)}]

  defp set(:swell) do
    [{0, level(amp: 1, amp_slide: 4)}, {4, level(amp: 0.25, amp_slide: 4)}]
  end

  defp level(opts), do: change({:organ, :level}, opts)

  # Two beats a chord, over its root in the pedals.
  defp chords do
    seq(
      for {root, chord} <- [
            {36, [60, 64, 67, 72]},
            {41, [60, 65, 69, 72]},
            {43, [59, 62, 67, 71]},
            {36, [60, 64, 67, 72]}
          ] do
        note([root | chord], 2, sustain: 1.9)
      end
    )
  end
end
