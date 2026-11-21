defmodule Effects.Bpf do
  @moduledoc """
  The band-pass filter on a trumpet, which keeps one band of the sound and cuts the rest above
  and below it, as a mute in the bell does; moved while a note holds, it speaks "wah" as a
  plunger moved in and out of the bell does, which Wikipedia's "Wah-wah (music)" describes,
  https://en.wikipedia.org/wiki/Wah-wah_(music).
  A phrase in B flat plays five times:

  1. dry;
  2. the filter as it comes, `centre: 100`, E7, a thin band at the top of the trumpet's sound;
  3. `centre: 84`, the C two octaves above middle C, the sound of a small loudspeaker;
  4. `res: 0.85` at that centre, a narrower band, quieter and more nasal;
  5. `centre` gliding from 70 up to 94 and back on each long note, the plunger.
  """

  use Mx.Song, tempo: 80

  part :trumpet, synth: :trumpet, fx: [bpf: [mix: 0]]

  def song do
    form([:dry, :defaults, :speaker, :narrow, :plunger], fn section ->
      part(:trumpet, together([phrase(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, bpf(mix: 0)}]
  defp set(:defaults), do: [{0, bpf(mix: 1, centre: 100)}]
  defp set(:speaker), do: [{0, bpf(centre: 84)}]
  defp set(:narrow), do: [{0, bpf(res: 0.85)}]

  defp set(:plunger) do
    [{0, bpf(res: 0.6, centre: 70)}] ++
      for beat <- [0, 2, 4, 6],
          {offset, centre} <- [{0.1, 94}, {1, 70}],
          do: {beat + offset, bpf(centre: centre, centre_slide: 0.9)}
  end

  defp bpf(opts), do: change({:trumpet, :bpf}, opts)

  # Four long notes, each slurred to from the note before it: B flat, D, F and the D below.
  defp phrase do
    seq([
      note(70, 2, vel: 0.7, sustain: 1.8),
      note(72, 2, vel: 0.7, sustain: 1.8, changes: [{0.25, note: 74}]),
      note(77, 2, vel: 0.8, sustain: 1.8),
      note(75, 2, vel: 0.7, sustain: 1.8, changes: [{0.25, note: 74}])
    ])
  end
end
