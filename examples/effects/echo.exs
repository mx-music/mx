defmodule Effects.Echo do
  @moduledoc """
  The echo on a harmonium played as the melodica of a dub record, where a short phrase is thrown
  into a tape echo and the repeats fill the bar it leaves empty; Wikipedia's "Dub music"
  describes the echo's place in dub, https://en.wikipedia.org/wiki/Dub_music.
  A phrase in A minor and two beats of silence play six times:

  1. dry;
  2. the echo as it comes: a repeat every quarter of a beat, dying away over two beats;
  3. `phase: 0.75`, a repeat every three quarters of a beat, which falls between the beats;
  4. `decay: 8`, the same repeats lasting four times as long;
  5. `mix: 0.3`, the repeats under the phrase instead of as loud as it;
  6. `phase` gliding from 0.75 down to 0.5 while the repeats ring, which bends them up in pitch,
     as turning the speed of a tape echo does.
  """

  use Mx.Song, tempo: 74

  part :melodica, synth: :harmonium, defaults: [vel: 0.7, amp: 4], fx: [echo: [mix: 0]]

  def song do
    form([:dry, :defaults, :dotted, :long, :under, :bend], fn section ->
      part(:melodica, together([phrase(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, echo(mix: 0)}]
  defp set(:defaults), do: [{0, echo(mix: 1)}]
  defp set(:dotted), do: [{0, echo(phase: 0.75)}]
  defp set(:long), do: [{0, echo(decay: 8)}]
  defp set(:under), do: [{0, echo(decay: 2, mix: 0.3)}]

  defp set(:bend) do
    [{0, echo(decay: 8, mix: 1)}, {4, echo(phase: 0.5, phase_slide: 3)}]
  end

  defp echo(opts), do: change({:melodica, :echo}, opts)

  defp phrase do
    seq([
      note(76, 0.5, sustain: 0.4),
      note(72, 0.5, sustain: 0.4),
      note(69, 1, sustain: 0.8),
      rest(1),
      note(74, 0.5, sustain: 0.4),
      note(72, 0.5, sustain: 0.4),
      note(69, 1.5, sustain: 1.2),
      rest(2.5)
    ])
  end
end
