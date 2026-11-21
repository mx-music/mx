defmodule GymnopedieElectric do
  @moduledoc """
  Satie's first Gymnopédie, of 1888 and in the public domain, on the electric piano and the
  electric guitar.
  The notes are those of the Mutopia Project's public-domain engraving of the Dover edition,
  https://www.mutopiaproject.org, piece 37.
  The electric piano plays the whole piece the first time through, both hands, as a pianist plays
  it on a Rhodes; the second time the electric guitar takes the melody, picked clean, over the
  electric piano's bass and chords, as jazz guitarists play it, and the piece ends on the second
  ending's D minor.
  """

  use Mx.Song, tempo: 72

  part :electric_piano,
    synth: :electric_piano,
    defaults: [pan: -0.2],
    fx: [reverb: [room: 0.5, damp: 0.5, mix: 0.2]]

  part :electric_guitar,
    synth: :electric_guitar,
    defaults: [pan: 0.25],
    fx: [reverb: [room: 0.5, damp: 0.5, mix: 0.2]]

  def song do
    seq([first_time(), second_time()])
  end

  # Bars 1 to 39 with the first ending, all on the electric piano.
  defp first_time do
    part(:electric_piano, seq(1..39, &both_hands/1))
  end

  # Bars 1 to 31 again and the second ending, the melody on the electric guitar.
  defp second_time do
    bars = Enum.concat(1..31, 40..47)

    together([
      part(:electric_piano, seq(bars, &left_hand/1)),
      part(:electric_guitar, seq(bars, &tune(&1, 0.6)))
    ])
  end

  defp both_hands(number), do: together([left_hand(number), tune(number, 0.5)])

  # The bass on the downbeat, held through the bar, and the chord on beats two and three.
  defp left_hand(number) do
    {bass, chords, _melody} = bar(number)

    bass = note(bass, 3, vel: 0.42, sustain: last(number, 3))

    chords =
      case chords do
        [{_beat, _chord} | _] = struck ->
          ends = Enum.map(Enum.drop(struck, 1), &elem(&1, 0)) ++ [3]

          notes =
            for {{beat, chord}, until} <- Enum.zip(struck, ends),
                do:
                  {beat,
                   note(chord, until - beat, vel: 0.28, sustain: last(number, until - beat))}

          at(notes, 3)

        chord ->
          delay(note(chord, 2, vel: 0.28, sustain: last(number, 2)), 1)
      end

    together([bass, chords])
  end

  # The melody of a bar, each note held for its sustain where it is tied into the next bars.
  defp tune(number, vel) do
    {_bass, _chords, notes} = bar(number)

    seq(
      for item <- notes do
        case item do
          {:r, beats} -> rest(beats)
          {pitch, beats} -> note(pitch, beats, vel: vel, sustain: last(number, beats))
          {pitch, beats, sustain} -> note(pitch, beats, vel: vel, sustain: sustain)
        end
      end
    )
  end

  # The last bar's notes ring on for two more bars as the piece ends.
  defp last(47, beats), do: beats + 6
  defp last(_number, beats), do: beats

  # Each bar as its bass, its chord on beats two and three, or chords at their beats, and its
  # melody.
  defp bar(1), do: {:g2, [:b3, :d4, :fs4], [r: 3]}
  defp bar(2), do: {:d2, [:a3, :cs4, :fs4], [r: 3]}
  defp bar(3), do: {:g2, [:b3, :d4, :fs4], [r: 3]}
  defp bar(4), do: {:d2, [:a3, :cs4, :fs4], [r: 3]}
  defp bar(5), do: {:g2, [:b3, :d4, :fs4], [r: 1, fs5: 1, a5: 1]}
  defp bar(6), do: {:d2, [:a3, :cs4, :fs4], [g5: 1, fs5: 1, cs5: 1]}
  defp bar(7), do: {:g2, [:b3, :d4, :fs4], [b4: 1, cs5: 1, d5: 1]}
  defp bar(8), do: {:d2, [:a3, :cs4, :fs4], [a4: 3]}
  defp bar(9), do: {:g2, [:b3, :d4], [{:fs4, 3, 12}]}
  defp bar(10), do: {:d2, [:a3, :cs4], [r: 3]}
  defp bar(11), do: {:g2, [:b3, :d4], [r: 3]}
  defp bar(12), do: {:d2, [:a3, :cs4], [r: 3]}
  defp bar(13), do: {:g2, [:b3, :d4, :fs4], [r: 1, fs5: 1, a5: 1]}
  defp bar(14), do: {:d2, [:a3, :cs4, :fs4], [g5: 1, fs5: 1, cs5: 1]}
  defp bar(15), do: {:g2, [:b3, :d4, :fs4], [b4: 1, cs5: 1, d5: 1]}
  defp bar(16), do: {:d2, [:a3, :cs4, :fs4], [a4: 3]}
  defp bar(17), do: {:fs2, [:a3, :cs4, :fs4], [cs5: 3]}
  defp bar(18), do: {:b1, [:b3, :d4, :fs4], [fs5: 3]}
  defp bar(19), do: {:e2, [:g3, :b3], [{:e4, 3, 9}]}
  defp bar(20), do: {:e2, [:b3, :d4, :g4], [r: 3]}
  defp bar(21), do: {:d2, [:f3, :a3, :d4], [r: 3]}
  defp bar(22), do: {:a1, [:a3, :c4, :e4], [a4: 1, b4: 1, c5: 1]}
  defp bar(23), do: {:d2, [:g3, :b3, :e4], [e5: 1, d5: 1, b4: 1]}
  defp bar(24), do: {:d2, [:d3, :g3, :b3, :e4], [d5: 1, c5: 1, b4: 1]}
  defp bar(25), do: {:d2, [:c3, :e3, :a3, :d4], [{:d5, 3, 5}]}
  defp bar(26), do: {:d2, [:c3, :fs3, :a3, :d4], [r: 2, d5: 1]}
  defp bar(27), do: {:d2, [:a3, :c4, :f4], [e5: 1, f5: 1, g5: 1]}
  defp bar(28), do: {:d2, [:a3, :c4, :e4], [a5: 1, c5: 1, d5: 1]}
  defp bar(29), do: {:d2, [:d3, :g3, :b3, :e4], [e5: 1, d5: 1, b4: 1]}
  defp bar(30), do: {:d2, [:c3, :e3, :a3, :d4], [{:d5, 3, 5}]}
  defp bar(31), do: {:d2, [:c3, :fs3, :a3, :d4], [r: 2, d5: 1]}
  defp bar(32), do: {:e2, [:b3, :e4, :g4], [g5: 3]}
  defp bar(33), do: {:fs2, [:a3, :cs4, :fs4], [fs5: 3]}
  defp bar(34), do: {:b1, [:b3, :d4, :fs4], [b4: 1, a4: 1, b4: 1]}
  defp bar(35), do: {:e2, [:cs4, :e4, :a4], [cs5: 1, d5: 1, e5: 1]}
  defp bar(36), do: {:e2, [:a3, :cs4, :fs4, :a4], [cs5: 1, d5: 1, e5: 1]}
  defp bar(37), do: {:e2, [{1, [:b2, :a3, :d4]}, {2, [:e3, :b3, :d4, :g4]}], [fs4: 3]}
  defp bar(38), do: {[:a2, :g3], [{0, [:c4, :e4, :a4]}], [c5: 3]}
  defp bar(39), do: {[:d2, :a2, :d3], [{0, [:d4, :fs4, :a4]}], [d5: 3]}
  defp bar(40), do: {:e2, [:b3, :e4, :g4], [g5: 3]}
  defp bar(41), do: {:e2, [:a3, :d4, :f4, :a4], [f5: 3]}
  defp bar(42), do: {:e2, [:a3, :c4, :f4], [b4: 1, c5: 1, f5: 1]}
  defp bar(43), do: {:e2, [:c4, :e4, :a4], [e5: 1, d5: 1, c5: 1]}
  defp bar(44), do: {:e2, [:a3, :c4, :f4, :a4], [e5: 1, d5: 1, c5: 1]}
  defp bar(45), do: {:e2, [{1, [:b2, :a3, :d4]}, {2, [:e3, :b3, :d4, :g4]}], [f4: 3]}
  defp bar(46), do: {[:a2, :g3], [{0, [:c4, :e4, :a4]}], [c5: 3]}
  defp bar(47), do: {[:d2, :a2, :d3], [{0, [:d4, :f4, :a4]}], [d5: 3]}
end
