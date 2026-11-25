Code.require_file("xylophone/maple_leaf_rag_score.exs", __DIR__)

defmodule MapleLeafRag.Xylophone do
  @moduledoc """
  Scott Joplin's Maple Leaf Rag, published in 1899 and in the public domain, played on mx's
  xylophone over a pad, a sub bass and a broken-beat kit.
  The notes are those of the Mutopia Project's public-domain engraving of the 1899 edition,
  https://www.mutopiaproject.org, piece 23, at Joplin's Tempo di marcia.
  A beat is a quarter note, so each bar of 2/4 is two beats.

  The xylophone takes the right hand as xylophonists of the ragtime era played rags, an octave
  above the piano, with two mallets, so a chord gives its top and bottom notes, and a tied note
  is rolled.
  The left hand's stride goes to the band instead: its bass notes to a sub, its chords to a pad,
  its pulse to the kit.
  The strains come as the score repeats them, A A B B A C C D D: the hi-hat comes in with the
  second A, the whole kit with B, it thins for the A that comes back, leaves for the first C, the
  trio, and returns for the second C and D.
  Each repeat is played another way: the second A in octaves, the second B with its off-beat
  sixteenths dead-stroked, the second C an octave higher on soft mallets, the rolls of D swelling,
  and the second D in octaves again.
  The band plays stop-time, striking each downbeat alone while the xylophone carries on, in the
  last two bars of the second A, B and C and two bars before the end.
  The xylophone's mallets follow the strains, softer for the trio and hardest for the second D,
  and the end of each strain is thrown into a ping-pong echo.
  """

  use Mx.Song, tempo: 92

  # One room every part shares, its lows kept out of the reverb.
  bus :room,
    fx: [
      reverb: [decay_seconds: 1.8, damp: 0.5, predelay_ms: 12],
      eq: [low_at: 60, low_gain: -10]
    ]

  part :xylophone,
    synth: :xylophone,
    fx: [
      compressor: [threshold: -20, ratio: 2.5, makeup: 3],
      ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.0],
      level: [amp: 1.2]
    ],
    send: [room: 0.25]

  part :pad,
    synth: :supersaw,
    defaults: [attack: 0.15, release: 0.6, cutoff: 64, res: 0.1, amp: 0.027],
    fx: [chorus: [phase: 4, mix: 0.3]],
    send: [room: 0.4]

  part :sub,
    synth: :tri,
    defaults: [attack: 0.01, release: 0.25],
    fx: [lpf: [cutoff: 55], level: [amp: 0.08]]

  part :kick, synth: :kick, defaults: [amp: 0.15]
  part :rimshot, synth: :rimshot, defaults: [amp: 0.11, pan: 0.15], send: [room: 0.2]
  part :hihat, synth: :closed_hihat, defaults: [amp: 0.15, pan: 0.3]

  def song do
    together([
      part(:xylophone, seq(0..144, &xylophone/1)),
      part(:pad, seq(0..144, &pad/1)),
      part(:sub, seq(0..144, &sub/1)),
      part(:kick, seq(0..144, &kick/1)),
      part(:rimshot, seq(0..144, &rimshot/1)),
      part(:hihat, seq(0..144, &hihat/1))
    ])
  end

  # The xylophone's bar: the right hand an octave up, or two where one would fall under the
  # xylophone's lowest bar, varied as the strain's repeat asks, with the strain's end thrown into
  # the echo; the last chord is rolled for a bar.
  defp xylophone(bar) do
    written = for {:right, _, notes, _} <- MapleLeafRag.written(bar), do: notes
    lowest = written |> List.flatten() |> Enum.min(fn -> 72 end)
    octaves = if lowest + 12 < 65, do: 24, else: 12
    treatment = variation(bar)
    up = if treatment == :high, do: octaves + 12, else: octaves

    right =
      for {:right, sixteenth, notes, length} <- MapleLeafRag.written(bar) do
        held = if bar == 144 and sixteenth == 4, do: 8, else: length
        sounding = Enum.map(notes, &in_range(&1 + up))
        {sixteenth, mallets(sounding, treatment), held}
      end

    strokes =
      for {sixteenth, notes, length} <- right,
          {at, touch} <- played(sixteenth, length, bar >= 113),
          at < 8 or bar == 144,
          note <- notes do
        lean = if note == Enum.max(notes), do: 1.0, else: 0.85
        vel = min(level(bar + at / 8) * touch * lean, 1.0)
        dead = treatment == :dead and length == 1 and rem(sixteenth, 2) == 1
        ring = if dead, do: 0.06, else: 4
        {start(bar, at), note, ring, vel: Float.round(vel, 2), brightness: brightness(bar)}
      end

    length = if bar == 144, do: 4, else: span(bar)
    at(strokes ++ thrown(bar), length)
  end

  # The left hand's chords held under each beat, each pitch once, from the pickup on; in a
  # stop-time bar, the first chord alone, short.
  defp pad(bar) do
    beats =
      for {:left, sixteenth, notes, _} <- MapleLeafRag.written(bar),
          note <- notes,
          note >= 50,
          do: {sixteenth, note}

    chords =
      for {beat, held} <- Enum.group_by(beats, &div(elem(&1, 0), 4)),
          kit(bar) != :stop or beat == 0 do
        {first, _} = Enum.min(held)
        notes = held |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
        length = if kit(bar) == :stop, do: 0.3, else: 0.95
        {start(bar, first), notes, length, vel: 0.6}
      end

    at(chords, span(bar))
  end

  # The left hand's bass notes on the beat, in the sub's register, each held for an eighth; in a
  # stop-time bar, the downbeat alone.
  defp sub(bar) do
    beats = if kit(bar) == :stop, do: [0], else: [0, 4]

    basses =
      for {:left, sixteenth, notes, _} <- MapleLeafRag.written(bar),
          (sixteenth in [0, 4, 6] and bar == 0) or sixteenth in beats,
          Enum.min(notes) < 52,
          do: {start(bar, sixteenth), fold(Enum.min(notes)), 0.5, vel: 0.6}

    at(basses, span(bar))
  end

  # The kick on the beat and pushed ahead of the second where the whole kit plays, on the
  # downbeat alone where it is lighter or the band stops, and once under the last chord.
  defp kick(144), do: steps(~MX"9......."s, 0.25, vel: 0.8)

  defp kick(bar) do
    case kit(bar) do
      :whole -> steps(~MX"9..6..5."s, 0.25, vel: 0.7)
      :stop -> steps(~MX"9......."s, 0.25, vel: 0.75)
      :none -> rest(span(bar))
      _ -> steps(~MX"7......."s, 0.25, vel: 0.6)
    end
  end

  defp rimshot(bar) do
    case kit(bar) do
      :whole -> steps(~MX"....8..."s, 0.25, vel: 0.6)
      :stop -> steps(~MX"8......."s, 0.25, vel: 0.6)
      :back -> steps(~MX"....6..."s, 0.25, vel: 0.5)
      _ -> rest(span(bar))
    end
  end

  # The hi-hat on every sixteenth, leaning on each eighth, in eighths where the kit is lighter.
  defp hihat(bar) do
    case kit(bar) do
      :whole -> steps(~MX"73537353"s, 0.25, vel: 0.5)
      kit when kit in [:none, :stop] -> rest(span(bar))
      _ -> steps(~MX"5.3.5.3."s, 0.25, vel: 0.4)
    end
  end

  # How much of the kit plays a bar: none in the first A and the first C, the trio; a light kick
  # and hi-hat in the second A, with the rimshot too in the A that comes back; all of it in B,
  # the second C and D; and stop-time, the band striking each downbeat alone, in the last two
  # bars of the second A, B and C and two bars before the end.
  defp kit(bar) do
    cond do
      bar in [31, 32, 63, 64, 111, 112, 141, 142] -> :stop
      bar in 17..32 -> :light
      bar in 33..64 -> :whole
      bar in 65..80 -> :back
      bar in 97..143 -> :whole
      true -> :none
    end
  end

  # How the xylophone varies a strain's repeat: the second A and the second D in octaves, the
  # second B with its off-beat sixteenths dead-stroked, the mallet left on the bar to stop it,
  # and the second C an octave higher still.
  defp variation(bar) do
    cond do
      bar in 17..32 or bar in 129..144 -> :octaves
      bar in 49..64 -> :dead
      bar in 97..112 -> :high
      true -> :plain
    end
  end

  # Two mallets take a chord's top and bottom notes, and a single note's octave when the repeat
  # is played in octaves, below it where the octave above is past the top bar.
  defp mallets([note], :octaves) when note + 12 > 108, do: [note - 12, note]
  defp mallets([note], :octaves), do: [note, note + 12]
  defp mallets(notes, _treatment), do: Enum.uniq([Enum.min(notes), Enum.max(notes)])

  # A note as struck once, or as a roll when it is held three sixteenths or longer: the mallets
  # take turns every thirty-second, the first stroke full and the rest softer, or in D, the rest
  # swelling toward the next note.
  defp played(sixteenth, length, swell) when length >= 3 do
    turns = 2 * length - 2

    for turn <- 0..turns do
      touch =
        cond do
          turn == 0 -> 1.0
          swell -> 0.55 + 0.4 * turn / turns
          rem(turn, 2) == 0 -> 0.6
          true -> 0.5
        end

      {sixteenth + turn / 2, touch}
    end
  end

  defp played(sixteenth, length, _swell) do
    touch = if length >= 2, do: 1.0, else: 0.88
    [{sixteenth, touch}]
  end

  # The ends of strains that ring on in the echo: the throw opens on the second beat and closes
  # in the next bar.
  defp thrown(bar) do
    cond do
      bar in [16, 32, 64, 80, 112] ->
        [{1, change({:xylophone, :ping_pong}, mix: 0.3)}]

      (bar - 1) in [16, 32, 64, 80, 112] ->
        [{0.5, change({:xylophone, :ping_pong}, mix: 0.0, mix_slide: 2)}]

      true ->
        []
    end
  end

  # How hard the xylophone's mallets are through the strains: softer for the trio and softest
  # for its high repeat, hardest for the second D.
  defp brightness(bar) do
    cond do
      bar < 17 -> 0.5
      bar < 33 -> 0.52
      bar < 65 -> 0.58
      bar < 81 -> 0.52
      bar < 97 -> 0.42
      bar < 113 -> 0.4
      bar < 129 -> 0.6
      true -> 0.66
    end
  end

  # How hard the xylophone is struck, as {bar, velocity}, straight between the keys: forte, piano
  # for the low arpeggio of bar 7 and a crescendo from bar 9 in each A, softer in the trio and
  # loudest in D.
  defp level(at) do
    keys = [
      {0, 0.72},
      {6.9, 0.72},
      {7, 0.45},
      {9, 0.55},
      {11, 0.7},
      {22.9, 0.72},
      {23, 0.45},
      {25, 0.55},
      {27, 0.7},
      {33, 0.75},
      {64, 0.75},
      {70.9, 0.7},
      {71, 0.45},
      {73, 0.55},
      {75, 0.7},
      {81, 0.52},
      {97, 0.62},
      {113, 0.8},
      {146, 0.85}
    ]

    pairs = Enum.chunk_every(keys, 2, 1, :discard)

    [{from, a}, {to, b}] =
      Enum.find(pairs, List.last(pairs), fn [{from, _}, {to, _}] -> at >= from and at < to end)

    a + (b - a) * (at - from) / (to - from)
  end

  # Where a sixteenth falls in its bar, in beats, the pickup being its last eighth.
  defp start(0, sixteenth), do: (sixteenth - 6) / 4
  defp start(_bar, sixteenth), do: sixteenth / 4

  defp span(0), do: 0.5
  defp span(_bar), do: 2

  # The xylophone's bars reach from F4 to C8, so a note past them is struck an octave in.
  defp in_range(note) when note > 108, do: note - 12
  defp in_range(note) when note < 65, do: note + 12
  defp in_range(note), do: note

  # The sub's register, from the E an octave under the bass clef to the G above it.
  defp fold(note) when note > 43, do: fold(note - 12)
  defp fold(note), do: note
end
