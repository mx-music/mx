Code.require_file("piano/clair_de_lune_score.exs", __DIR__)

defmodule ClairDeLune.Marimba do
  @moduledoc """
  Debussy's Clair de lune, the third piece of his Suite bergamasque, published by Fromont in 1905
  and in the public domain, played on mx's marimba over a pad, a sub bass and a light kit.
  The notes are those of the Mutopia Project's public-domain engraving of that edition,
  https://www.mutopiaproject.org, piece 1778, at a steady pulse instead of the piano's rubato.
  A beat is an eighth note, so each bar of 9/8 is nine beats.

  The marimba plays as marimba players play the piece: both hands' notes in the opening, each
  note three eighths or longer rolled, the two mallets of a hand taking turns about twelve times a
  second, since a struck bar cannot hold a note.
  From Un poco mosso a second marimba takes the left hand's arpeggios through a ping-pong echo,
  and the kit comes in under them, kick and rimshot in the three beats of 9/8 with the hi-hat on
  every eighth; it thins to a kick on the bar and half the hi-hat when the theme comes back, and
  leaves for the last bars.
  The marimba's brightness follows the piece, as a player changes to harder mallets for the
  climax of bar 41 and back to soft yarn for the end; the ends of phrases are thrown into the
  echo, and the last chord sinks a quarter tone as it fades.
  """

  use Mx.Song, tempo: 126

  # One room every part shares, its lows kept out of the reverb.
  bus :room,
    fx: [
      reverb: [decay_seconds: 3.4, damp: 0.55, predelay_ms: 18],
      eq: [low_at: 50, low_gain: -10]
    ]

  part :marimba,
    synth: :marimba,
    fx: [
      compressor: [threshold: -20, ratio: 2.5, makeup: 3],
      eq: [low_at: 43, low_gain: -3, high_at: 100, high_gain: 2],
      chorus: [phase: 2, mix: 0.12],
      ping_pong: [phase: 1.5, feedback: 0.45, mix: 0.0],
      level: [amp: 0.5]
    ],
    send: [room: 0.3]

  part :arps,
    synth: :marimba,
    defaults: [brightness: 0.4, pan: -0.25],
    fx: [ping_pong: [phase: 0.75, feedback: 0.3, mix: 0.18], eq: [low_at: 48, low_gain: -4]],
    send: [room: 0.35]

  part :pad,
    synth: :supersaw,
    defaults: [attack: 2, release: 3, cutoff: 62, res: 0.1, amp: 0.012],
    fx: [chorus: [phase: 4, mix: 0.3]],
    send: [room: 0.5]

  part :sub,
    synth: :tri,
    defaults: [attack: 0.04, release: 1.2],
    fx: [lpf: [cutoff: 55], level: [amp: 0.07]]

  part :kick, synth: :kick, defaults: [amp: 0.3]
  part :rimshot, synth: :rimshot, defaults: [amp: 0.22, pan: 0.15], send: [room: 0.25]
  part :hihat, synth: :closed_hihat, defaults: [amp: 0.3, pan: 0.3]

  def song do
    together([
      part(:marimba, seq(1..72, &marimba/1)),
      part(:arps, seq(1..72, &arps/1)),
      part(:pad, seq(1..72, &pad/1)),
      part(:sub, seq(1..72, &sub/1)),
      part(:kick, seq(1..72, &kick/1)),
      part(:rimshot, seq(1..72, &rimshot/1)),
      part(:hihat, seq(1..72, &hihat/1))
    ])
  end

  # The marimba's bar: the right hand throughout, and the left hand's notes in the treble while no
  # second marimba plays them, with the phrase ends thrown into the echo.
  defp marimba(72) do
    chord = [61, 68, 73, 77, 80, 85, 89, 92]

    strokes =
      for {note, index} <- Enum.with_index(chord) do
        {index * 0.12, note, 12,
         vel: 0.3, brightness: 0.35, changes: [{2, bend: -0.5, bend_slide: 10}]}
      end

    at(strokes, 14)
  end

  defp marimba(bar) do
    own =
      for {staff, beat, notes, length} <- ClairDeLune.written(bar),
          lowest = Enum.min(notes),
          staff == :upper or (bar < 27 and lowest >= 48),
          do: {beat, notes |> Enum.filter(&(&1 >= 48)) |> Enum.map(&in_range/1), length}

    tops =
      Map.new(Enum.group_by(own, &elem(&1, 0), &elem(&1, 1)), fn {beat, sets} ->
        {beat, sets |> List.flatten() |> Enum.max()}
      end)

    bright = brightness(bar)

    strokes =
      for {beat, notes, length} <- own, notes != [], stroke <- played(beat, notes, length) do
        {at, note, touch} = stroke
        top = if note == tops[beat], do: 1.15, else: 0.8
        {at, note, length, vel: min(level(bar + at / 9) * top * touch, 1.0), brightness: bright}
      end

    at(Enum.uniq_by(strokes, &Enum.take(Tuple.to_list(&1), 2)) ++ thrown(bar), 9)
  end

  # The left hand's arpeggios on the second marimba, from Un poco mosso to the end of the theme's
  # return.
  defp arps(bar) when bar in 27..66 do
    strokes =
      for {:lower, beat, notes, length} <- ClairDeLune.written(bar),
          note <- notes,
          note >= 41,
          do: {beat, in_range(note), length, vel: level(bar + beat / 9) * 0.7}

    at(strokes, 9)
  end

  defp arps(_bar), do: rest(9)

  # The left hand's harmony held under the bar from bar 9, each pitch once, an octave up where it
  # would sit in the sub's register.
  defp pad(bar) when bar in 9..71 do
    notes =
      for {:lower, _beat, notes, _length} <- ClairDeLune.written(bar),
          note <- notes,
          uniq: true,
          do: if(note < 48, do: note + 12, else: note)

    at([{0, Enum.uniq(notes), 9}], 9)
  end

  defp pad(_bar), do: rest(9)

  # The bar's lowest note, under two octaves and a half above the lowest A, held for the bar.
  defp sub(bar) when bar in 9..71 do
    low =
      bar
      |> ClairDeLune.written()
      |> Enum.flat_map(fn {_, _, notes, _} -> notes end)
      |> Enum.min()

    at([{0, fold(low), 8.5, vel: 0.6}], 9)
  end

  defp sub(_bar), do: rest(9)

  # The kick on the first and third beats of 9/8 while the arpeggios move, a pickup before the
  # climax, and on the first beat alone when the theme comes back.
  defp kick(bar) when bar in 27..50 do
    pattern = if bar in 39..42, do: ~MX"7..3..6.4"s, else: ~MX"9.....7.."s
    steps(pattern, 1, vel: 0.7)
  end

  defp kick(bar) when bar in 51..62, do: steps(~MX"7........"s, 1, vel: 0.5)
  defp kick(_bar), do: rest(9)

  defp rimshot(bar) when bar in 29..50, do: steps(~MX"...7....."s, 1, vel: 0.6)
  defp rimshot(_bar), do: rest(9)

  # The hi-hat on every eighth, the first of each beat leaning, half again when the theme returns.
  defp hihat(bar) when bar in 27..50, do: steps(~MX"735735735"s, 1, vel: 0.5)
  defp hihat(bar) when bar in 51..64, do: steps(~MX"5.35.35.3"s, 1, vel: 0.4)
  defp hihat(_bar), do: rest(9)

  # A note as struck once, or as a roll when it lasts three eighths or longer: the mallets of a
  # hand take turns every sixth of an eighth, the first stroke full and the rest softer.
  defp played(beat, notes, length) when length >= 3 do
    turns = trunc((length - 0.5) * 6)

    for turn <- 0..turns, beat + turn / 6 < 9, note <- notes do
      touch =
        cond do
          turn == 0 -> 1.0
          rem(turn, 2) == 0 -> 0.5
          true -> 0.42
        end

      {Float.round(beat + turn / 6, 3), note, touch}
    end
  end

  defp played(beat, notes, _length) do
    for note <- notes, do: {beat, note, 1.0}
  end

  # The phrase ends that ring on in the echo: the throw opens on the sixth beat of each and closes
  # in the next bar.
  defp thrown(bar) do
    cond do
      bar in [8, 14, 26, 50, 66] ->
        [{6, change({:marimba, :ping_pong}, mix: 0.3)}]

      (bar - 1) in [8, 14, 26, 50, 66] ->
        [{0, change({:marimba, :ping_pong}, mix: 0.0, mix_slide: 4)}]

      true ->
        []
    end
  end

  # How bright the marimba's mallets are through the piece, soft yarn to start, harder at the
  # climax, softer again at the end.
  defp brightness(bar) do
    cond do
      bar < 15 -> 0.4
      bar < 27 -> 0.47
      bar < 37 -> 0.5
      bar < 43 -> 0.62
      bar < 51 -> 0.55
      bar < 67 -> 0.45
      true -> 0.38
    end
  end

  # How hard the marimba is struck, as {bar, velocity}, straight between the keys: pianissimo to
  # the forte of bar 41 and back.
  defp level(at) do
    keys = [
      {1, 0.4},
      {13, 0.42},
      {13.5, 0.52},
      {15, 0.42},
      {25, 0.65},
      {27, 0.45},
      {37, 0.6},
      {41, 0.85},
      {43, 0.45},
      {51, 0.42},
      {66, 0.38},
      {73, 0.25}
    ]

    [{from, a}, {to, b}] =
      keys
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.find(List.last(Enum.chunk_every(keys, 2, 1, :discard)), fn [{from, _}, {to, _}] ->
        at >= from and at < to
      end)

    a + (b - a) * (at - from) / (to - from)
  end

  # The marimba's bars reach from F1 to C7, so a higher note is struck an octave down.
  defp in_range(note) when note > 96, do: note - 12
  defp in_range(note), do: note

  # The sub's register, from the E an octave under the bass clef to the G above it.
  defp fold(note) when note > 43, do: fold(note - 12)
  defp fold(note), do: note
end
