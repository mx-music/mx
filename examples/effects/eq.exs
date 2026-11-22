defmodule Effects.Eq do
  @moduledoc """
  The equaliser on a piano, whose notes reach from the bass to the top, so each band has something
  to act on.
  Four bars of a bass note and chords, A minor, F, C and G, play five times:

  1. the equaliser as it comes, with no band given, which changes nothing;
  2. `low: [at: 60, gain: -15]`, everything below middle C turned down, so the bass notes thin
     out;
  3. `mid: [at: 72, gain: 9, q: 2]`, a peak around the C above middle C, which makes the piano
     sound boxed in;
  4. `high: [at: 72, gain: 9]`, everything above that C turned up, the hammers brighter;
  5. the mid peak again, narrower at `q: 4`, its `at` gliding from 48 up to 96 over the four bars.
  """

  use Mx.Song, tempo: 108

  part :piano, synth: :piano, defaults: [vel: 0.5], fx: [eq: []]

  def song do
    form([:flat, :thin, :boxed, :bright, :sweep], fn section ->
      part(:piano, together([chords(), at(set(section), 16)]))
    end)
  end

  defp set(:flat), do: []
  defp set(:thin), do: [{0, eq(low: [at: 60, gain: -15])}]
  defp set(:boxed), do: [{0, eq(low: [gain: 0], mid: [at: 72, gain: 9, q: 2])}]
  defp set(:bright), do: [{0, eq(mid: [gain: 0], high: [at: 72, gain: 9])}]

  defp set(:sweep) do
    [
      {0, eq(high: [gain: 0], mid: [at: 48, gain: 9, q: 4])},
      {0.1, eq(mid: [at: 96, at_slide: 15.9])}
    ]
  end

  defp eq(opts), do: change({:piano, :eq}, opts)

  # A bar a chord: the bass note on the one, the chord on the offbeats and held at the bar's end.
  defp chords do
    seq(
      for {bass, chord} <- [
            {33, [57, 60, 64, 69]},
            {29, [57, 60, 65, 69]},
            {36, [55, 60, 64, 67]},
            {31, [55, 59, 62, 67]}
          ] do
        at(
          [
            {0, note(bass, 0, sustain: 3.5)},
            {0.5, note(chord, 0, sustain: 0.4)},
            {1.5, note(chord, 0, sustain: 0.4)},
            {2.5, note(chord, 0, sustain: 1.4)}
          ],
          4
        )
      end
    )
  end
end
