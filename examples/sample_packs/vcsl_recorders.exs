defmodule Consort do
  @moduledoc """
  Bach's chorale "Wachet auf, ruft uns die Stimme", BWV 140/7, on the four Baroque recorders of
  VCSL, Versilian Studios' Versilian Community Sample Library, under Creative Commons 0.
  A recorder consort plays four-part vocal music an octave above the voices, the soprano's line on
  the soprano recorder and so on down to the bass, and so it does here.
  The notes are imported from examples/wachet_auf/bwv140.7.mxl by mix mx.import, music21's
  encoding under its BSD License, and the whole chorale plays once with its repeat.
  VCSL names each key an octave below the pitch mx names it by, and records each recorder at every
  second or third key.
  The files are fetched as the song loads, about 50 MB.
  """

  use Mx.Song, tempo: 66

  @folder "Aerophones/Edge-blown Aerophones"

  # Each recorder's file prefix and the keys it was recorded at.
  @recorders [
    soprano: {"Soprano", "SopRecorder", ~w(C4 D4 E4 F#4 G#4 A#4 C5 D5 E5 F#5 G5 A#5 C6)},
    alto: {"Alto", "AltRecorder", ~w(F3 G#3 A#3 C4 D4 E4 F#4 G#4 A#4 C5 D5 E5)},
    tenor: {"Tenor", "TenRecorder", ~w(C3 D3 E3 F#3 G#3 A#3 C4 D4 E4 F#4 G#4 A4 C5)},
    bass: {"Bass", "BassRecorder", ~w(F#2 G#2 A#2 C3 D3 E3 F#3 G#3 A#3 C4 D4 E4)}
  ]

  @pans [soprano: -0.4, alto: -0.15, tenor: 0.15, bass: 0.4]

  # The lower recorders are recorded more quietly, so each has its own level.
  @levels [soprano: 2.0, alto: 2.2, tenor: 2.2, bass: 3.5]

  # A recorder's part: its files, an octave above the voice it plays, and its level and place.
  recorder = fn voice ->
    {size, prefix, keys} = @recorders[voice]

    files =
      for key <- keys do
        name = key |> String.downcase() |> String.replace("#", "s") |> pitch()
        path = "#{@folder}/Baroque #{size} Recorder/Sustain/#{prefix}_Sus_#{key}_rr1_Main.wav"
        {{:vcsl, path}, note: name + 12}
      end

    [
      synth: sampled(files),
      defaults: [attack: 0.03, release: 0.15],
      fx: [
        level: [amp: @levels[voice]],
        reverb: [room: 0.8, damp: 0.4, mix: 0.3],
        pan: [pan: @pans[voice]]
      ]
    ]
  end

  part :soprano, recorder.(:soprano)
  part :alto, recorder.(:alto)
  part :tenor, recorder.(:tenor)
  part :bass, recorder.(:bass)

  def song do
    together([
      part(:soprano, played(&soprano/1)),
      part(:alto, played(&alto/1)),
      part(:tenor, played(&tenor/1)),
      part(:bass, played(&bass/1))
    ])
  end

  # A voice's bars in the order the score plays them, its repeat taken, an octave up on its
  # recorder.
  defp played(bar) do
    order = Enum.concat([1..8, 1..8, 9..18])
    transpose(seq(Enum.map(order, bar)), 12)
  end

  defp soprano(1), do: seq(eb4: 1, g4: 1, bb4: 1.5, bb4: 0.5)
  defp soprano(2), do: seq(bb4: 1, bb4: 1, c5: 2)
  defp soprano(3), do: seq(bb4: 2, r: 1, bb4: 1)
  defp soprano(4), do: seq(eb5: 1, bb4: 1, eb5: 0.5, f5: 0.5, g5: 1)
  defp soprano(5), do: seq(f5: 1, eb5: 1, d5: 1, c5: 1)
  defp soprano(6), do: seq(bb4: 2, r: 1, bb4: 1)
  defp soprano(7), do: seq(eb5: 1, bb4: 1, c5: 1, g4: 1)
  defp soprano(8), do: seq(ab4: 0.5, g4: 0.5, f4: 1, eb4: 1)
  defp soprano(9), do: seq(bb4: 1)
  defp soprano(10), do: seq(bb4: 1.5, ab4: 0.5, g4: 1, f4: 1)
  defp soprano(11), do: seq(eb4: 2, r: 1, bb4: 1)
  defp soprano(12), do: seq(bb4: 1.5, ab4: 0.5, g4: 1, f4: 1)
  defp soprano(13), do: seq(eb4: 2, r: 1, f4: 1)
  defp soprano(14), do: seq(g4: 1, ab4: 1, g4: 1, bb4: 1)
  defp soprano(15), do: seq(c5: 1, d5: 1, eb5: 1, eb5: 0.5, f5: 0.5)
  defp soprano(16), do: seq(g5: 1, f5: 1, eb5: 1, bb4: 1)
  defp soprano(17), do: seq(eb5: 1, bb4: 1, c5: 1, g4: 1)
  defp soprano(18), do: seq(ab4: 0.5, g4: 0.5, f4: 1, eb4: 2)

  defp alto(1), do: seq(bb3: 1, eb4: 1, g4: 1, f4: 1)
  defp alto(2), do: seq(g4: 1, f4: 1, g4: 1, f4: 1)
  defp alto(3), do: seq(f4: 2, r: 1, f4: 1)
  defp alto(4), do: seq(bb4: 1.5, ab4: 0.5, g4: 0.5, ab4: 0.5, bb4: 1)
  defp alto(5), do: seq(bb4: 1, c5: 1.5, bb4: 1, a4: 0.5)
  defp alto(6), do: seq(f4: 2, r: 1, g4: 1)
  defp alto(7), do: seq(ab4: 1, g4: 1, eb4: 1, eb4: 1)
  defp alto(8), do: seq(eb4: 1, d4: 1, bb3: 1)
  defp alto(9), do: seq(f4: 1)
  defp alto(10), do: seq(g4: 1.5, f4: 0.5, bb3: 0.5, c4: 0.5, d4: 1)
  defp alto(11), do: seq(c4: 2, r: 1, d4: 0.5, eb4: 0.5)
  defp alto(12), do: seq(f4: 1, f4: 1.5, eb4: 1, d4: 0.5)
  defp alto(13), do: seq(bb3: 2, r: 1, d4: 1)

  defp alto(14) do
    seq([note(:eb4, 1.5), note(:d4, 0.5), note(:eb4, 1), note(:g4, 1, sustain: 1.5)])
  end

  defp alto(15), do: seq(r: 0.5, f4: 1, g4: 0.5, g4: 1, g4: 0.5, ab4: 0.5)
  defp alto(16), do: seq(bb4: 1.5, ab4: 0.5, g4: 1, g4: 0.5, ab4: 0.5)
  defp alto(17), do: seq(bb4: 0.5, ab4: 0.5, bb4: 0.5, g4: 0.5, ab4: 1, eb4: 1)
  defp alto(18), do: seq(eb4: 1, d4: 1, bb3: 2)

  defp tenor(1), do: seq(g3: 1, bb3: 1, eb4: 1, d4: 1)
  defp tenor(2), do: seq(eb4: 1, bb3: 1, bb3: 1, a3: 1)
  defp tenor(3), do: seq(d4: 2, r: 1, d4: 1)
  defp tenor(4), do: seq(eb4: 1, eb4: 1, bb3: 1, eb4: 1)
  defp tenor(5), do: seq(f4: 1, f4: 1, f4: 1.5, c4: 0.5)
  defp tenor(6), do: seq(d4: 2, r: 1, eb4: 1)
  defp tenor(7), do: seq(eb4: 1.5, db4: 0.5, c4: 1, c4: 1)
  defp tenor(8), do: seq(c4: 0.5, bb3: 0.5, ab3: 1, g3: 1)
  defp tenor(9), do: seq(bb3: 1)
  defp tenor(10), do: seq(eb4: 0.5, d4: 0.5, c4: 0.5, d4: 0.5, eb4: 1, bb3: 0.5, ab3: 0.5)
  defp tenor(11), do: seq(g3: 2, r: 1, bb3: 1)
  defp tenor(12), do: seq(bb3: 0.5, c4: 0.5, d4: 1, bb3: 0.5, c4: 1, bb3: 0.5)
  defp tenor(13), do: seq(g3: 2, r: 1, bb3: 1)
  defp tenor(14), do: seq(bb3: 1, c4: 0.5, ab3: 0.5, bb3: 1, eb4: 1)
  defp tenor(15), do: seq(eb4: 1, d4: 1, c4: 1, eb4: 1)
  defp tenor(16), do: seq(eb4: 1, d4: 1, eb4: 1, eb4: 1)
  defp tenor(17), do: seq(bb3: 1, eb4: 1, eb4: 1.5, c4: 0.5)
  defp tenor(18), do: seq(c4: 0.5, bb3: 0.5, ab3: 1, g3: 2)

  defp bass(1) do
    seq([
      note(:eb3, 2, sustain: 2.5),
      rest(0.5),
      note(:g3, 0.5),
      note(:bb3, 0.5),
      note(:ab3, 0.5)
    ])
  end

  defp bass(2), do: seq(g3: 0.5, f3: 0.5, eb3: 0.5, d3: 0.5, eb3: 0.5, c3: 0.5, f3: 1)
  defp bass(3), do: seq(bb2: 2, r: 1, bb3: 0.5, ab3: 0.5)
  defp bass(4), do: seq(g3: 0.5, ab3: 0.5, g3: 0.5, f3: 0.5, eb3: 1, eb4: 1)
  defp bass(5), do: seq(d4: 0.5, c4: 0.5, bb3: 0.5, a3: 0.5, bb3: 1, f3: 1)
  defp bass(6), do: seq(bb2: 2, r: 1, eb3: 0.5, db3: 0.5)
  defp bass(7), do: seq(c3: 0.5, d3: 0.5, eb3: 1, ab2: 0.5, bb2: 0.5, c3: 1)
  defp bass(8), do: seq(f2: 1, bb2: 1, eb2: 1)
  defp bass(9), do: seq(d3: 1)
  defp bass(10), do: seq(eb3: 1, f3: 1, g3: 0.5, ab3: 0.5, bb3: 0.5, bb2: 0.5)
  defp bass(11), do: seq(c3: 2, r: 1, g3: 1)
  defp bass(12), do: seq(d3: 0.5, c3: 0.5, bb2: 1, eb3: 0.5, c3: 0.5, ab2: 0.5, bb2: 0.5)
  defp bass(13), do: seq(eb3: 2, r: 1, bb3: 0.5, ab3: 0.5)
  defp bass(14), do: seq(g3: 1, f3: 1, eb3: 1, eb4: 1)
  defp bass(15), do: seq(a3: 1, b3: 1, c4: 1, c4: 1)
  defp bass(16), do: seq(g3: 0.5, ab3: 0.5, bb3: 1, c3: 1, eb3: 0.5, f3: 0.5)
  defp bass(17), do: seq(g3: 0.5, f3: 0.5, g3: 0.5, eb3: 0.5, ab2: 0.5, bb2: 0.5, c3: 1)
  defp bass(18), do: seq(f2: 1, bb2: 1, eb2: 2)
end
