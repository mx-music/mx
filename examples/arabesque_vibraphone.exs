Code.require_file("vibraphone/arabesque_score.exs", __DIR__)

defmodule Arabesque.Vibraphone do
  @moduledoc """
  Claude Debussy's first Arabesque, in Durand's edition of 1904 and in the public domain, played
  on mx's vibraphone over a plucked arpeggio, a sub bass and Afro-Cuban percussion in 12/8.
  The notes are those of the Mutopia Project's public-domain engraving of that edition,
  https://www.mutopiaproject.org, piece 1777, at a steady pulse instead of the piano's rubato.
  A beat is a quarter note, so each bar of 4/4 is four beats.

  The vibraphone takes the upper staff, and the lower staff too where both hands share the
  triplet runs, as in the introduction, each note held by the pedal to the next beat until it is
  struck again.
  The left hand's eighth-note arpeggios go to a plucked synth through a ping-pong echo, its bass
  to a sub, and in the slower middle section, where the left hand holds its notes, to a pad.
  The Arabesque moves in triplets, so each bar is a bar of 12/8 to the percussion of the
  Afro-Cuban 6/8: the bell's standard pattern, as Wikipedia's article on bell patterns gives it,
  and the conga's figure twice to a bar with its open tones where the clave's first three strokes
  fall, as Pulsewave's lesson on bembé describes it, over a shaker; the clave alone with the
  shaker where the groove is light, and the tumba joining for the Risoluto, where the vibraphone's
  short notes are dead-stroked.
  The middle section's first eight bars and the last eight are open: the vibraphone strikes only
  its longer notes, pedalled through the bar, in a wider room with a little echo.
  The vibraphone's motor turns in the middle section and from the return of the theme on, slower
  with each bar of the last eight; the ends of phrases are thrown into the echo.
  """

  use Mx.Song, tempo: 112

  # One room every part shares, its lows kept out of the reverb.
  bus :room,
    fx: [
      reverb: [decay_seconds: 2.4, damp: 0.5, predelay_ms: 15],
      eq: [low_at: 60, low_gain: -10]
    ]

  part :vibraphone,
    synth: :vibraphone,
    fx: [
      compressor: [threshold: -20, ratio: 2.5, makeup: 3],
      ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.0],
      level: [amp: 0.32]
    ],
    send: [room: 0.3]

  part :pluck,
    synth: :pluck,
    defaults: [pan: -0.2, coef: 0.3, release: 1.5],
    fx: [
      hpf: [cutoff: 50],
      lpf: [cutoff: 88],
      ping_pong: [phase: 0.75, feedback: 0.35, mix: 0.25],
      level: [amp: 0.3]
    ],
    send: [room: 0.3]

  part :pad,
    synth: :supersaw,
    defaults: [attack: 0.5, release: 1.5, cutoff: 62, res: 0.1, amp: 0.027],
    fx: [chorus: [phase: 4, mix: 0.3]],
    send: [room: 0.5]

  part :sub,
    synth: :tri,
    defaults: [attack: 0.02, release: 0.4],
    fx: [lpf: [cutoff: 55], level: [amp: 0.113]]

  part :bell, synth: :cowbell, defaults: [amp: 0.3, pan: 0.25], send: [room: 0.2]
  part :clave, synth: :clave, defaults: [amp: 0.3, pan: -0.3], send: [room: 0.2]
  part :conga, synth: :mid_conga, defaults: [amp: 0.4, pan: 0.15], send: [room: 0.15]
  part :tumba, synth: :low_conga, defaults: [amp: 0.8, pan: -0.15], send: [room: 0.15]
  part :shaker, synth: :shaker, defaults: [amp: 0.16, pan: 0.35]
  part :surdo, synth: :surdo, defaults: [note: 40, amp: 0.6]

  def song do
    together([
      part(:vibraphone, seq(1..106, &vibraphone/1)),
      part(:pluck, seq(1..106, &pluck/1)),
      part(:pad, seq(1..106, &pad/1)),
      part(:sub, seq(1..106, &sub/1)),
      part(:bell, seq(1..106, &bell/1)),
      part(:clave, seq(1..106, &clave/1)),
      part(:conga, seq(1..106, &conga/1)),
      part(:tumba, seq(1..106, &tumba/1)),
      part(:shaker, seq(1..106, &shaker/1)),
      part(:surdo, seq(1..106, &surdo/1))
    ])
  end

  # The vibraphone's bar: the upper staff, and the lower where it shares the runs, each note held
  # by the pedal to the next beat, through the bar in the introduction and the open passages and
  # through each half in the middle section, until it is struck again; the last chord rings for
  # two bars.
  defp vibraphone(bar) do
    played =
      for {staff, twelfth, notes, length} <- Arabesque.written(bar),
          staff == :upper or shared?(bar),
          length >= 6 or not open?(bar),
          do: {twelfth, Enum.map(notes, &in_range/1), length}

    struck = for {twelfth, notes, _} <- played, note <- notes, do: {twelfth, note}

    strokes =
      for {twelfth, notes, length} <- played, note <- notes do
        held =
          min(max(length, pedal(bar, twelfth) - twelfth), again(struck, note, twelfth) - twelfth)

        lean = if note == Enum.max(notes), do: 1.0, else: 0.8
        vel = Float.round(min(level(bar + twelfth / 48) * lean, 1.0), 2)
        opts = [vel: vel, brightness: brightness(bar), motor: motor(bar)]
        {twelfth / 12, note, ring(bar, length, held), opts}
      end

    at(strokes ++ thrown(bar) ++ opened(bar), if(bar == 106, do: 8, else: 4))
  end

  # The open passages, the middle section's first eight bars and the last eight, where the
  # vibraphone strikes only the notes held a triplet quarter or longer and rings them in a wider
  # room with a little echo.
  defp open?(bar), do: bar in 39..46 or bar >= 99

  # The room opening at the start of an open passage and closing after it.
  defp opened(bar) when bar in [39, 99] do
    [
      {0, change(:vibraphone, send: [room: 0.6], send_slide: 2)},
      {0, change({:vibraphone, :ping_pong}, mix: 0.15, mix_slide: 2)}
    ]
  end

  defp opened(47), do: [{0, change(:vibraphone, send: [room: 0.3], send_slide: 2)}]
  defp opened(_bar), do: []

  # Whether the vibraphone plays the lower staff too: in the introduction, and wherever the lower
  # staff stays above the bass, carrying on the upper staff's runs.
  defp shared?(bar) do
    lower = for {:lower, _, notes, _} <- Arabesque.written(bar), note <- notes, do: note
    lowest = Enum.min(lower, fn -> 0 end)
    bar <= 5 or lowest >= 53
  end

  # The twelfth at which the pedal lifts: the bar's end in the introduction, each half bar in the
  # middle section, and each beat elsewhere.
  defp pedal(bar, _twelfth) when bar <= 5 or bar in 39..46 or bar >= 99, do: 48
  defp pedal(bar, twelfth) when bar in 39..62, do: (div(twelfth, 24) + 1) * 24
  defp pedal(_bar, twelfth), do: (div(twelfth, 12) + 1) * 12

  # The twelfth at which a note is struck again in the bar, or the bar's end.
  defp again(struck, note, twelfth) do
    struck
    |> Enum.filter(fn {at, struck} -> struck == note and at > twelfth end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.min(fn -> 48 end)
  end

  # How long a note rings, in beats: the short notes of the Risoluto dead-stroked at once, the
  # last chord for two bars, and otherwise as long as the pedal holds it.
  defp ring(bar, length, _held) when bar in 63..69 and length <= 4, do: 0.08
  defp ring(106, _length, _held), do: 8
  defp ring(_bar, _length, held), do: held / 12

  # The left hand's arpeggios, plucked, from the theme on, wherever the vibraphone does not play
  # them and the pad does not hold them.
  defp pluck(bar) do
    if bar < 6 or bar in 39..62 or shared?(bar) do
      rest(4)
    else
      strokes =
        for {:lower, twelfth, notes, length} <- Arabesque.written(bar),
            note <- notes,
            note >= 45,
            do: {twelfth / 12, note, length / 12, vel: 0.55}

      at(strokes, 4)
    end
  end

  # The left hand held under each half bar in the middle section, each pitch once.
  defp pad(bar) when bar in 39..62 do
    halves =
      for {:lower, twelfth, notes, _} <- Arabesque.written(bar),
          note <- notes,
          note >= 50,
          do: {div(twelfth, 24), note}

    chords =
      for {half, held} <- Enum.group_by(halves, &elem(&1, 0), &elem(&1, 1)),
          do: {half * 2, Enum.uniq(held), 1.9, vel: 0.6}

    at(chords, 4)
  end

  defp pad(_bar), do: rest(4)

  # The lowest note of the left hand in each half bar, under the bass clef's G, in the sub's
  # register and held through the half, from the theme on.
  defp sub(bar) when bar >= 6 do
    lows =
      for {:lower, twelfth, notes, _} <- Arabesque.written(bar),
          note <- notes,
          note < 52,
          do: {div(twelfth, 24), twelfth, note}

    basses =
      for {_half, held} <- Enum.group_by(lows, &elem(&1, 0)) do
        {_, twelfth, note} = Enum.min_by(held, &elem(&1, 1))
        {twelfth / 12, fold(note), (24 - rem(twelfth, 24)) / 12, vel: 0.6}
      end

    at(basses, 4)
  end

  defp sub(_bar), do: rest(4)

  # The percussion counts a bar as twelve triplet eighths, the twelve pulses of a bar of 12/8,
  # its four main beats on pulses 1, 4, 7 and 10.

  # The bell's standard pattern of 12/8, on pulses 1, 3, 5, 6, 8, 10 and 12.
  defp bell(bar) do
    case groove(bar) do
      :full -> steps(~MX"8.6.66.6.6.6"s, 1 / 3)
      :risoluto -> steps(~MX"9.7.77.7.7.7"s, 1 / 3)
      _ -> rest(4)
    end
  end

  # The clave of 6/8, the bell's pattern without its sixth and last strokes, where the groove is
  # light.
  defp clave(bar) do
    case groove(bar) do
      :light -> steps(~MX"7.6.6..6.6.."s, 1 / 3)
      _ -> rest(4)
    end
  end

  # The conga's figure, twice to a bar: open tones on the first, third and fifth pulses of each
  # half, as the clave's first three strokes fall, and the heel and tip between; in the Risoluto
  # the third pulse of each half is slapped.
  defp conga(bar) do
    case groove(bar) do
      :full -> steps(~MX"OhOtOtOhOtOt"s, 1 / 3, strokes: strokes())
      :risoluto -> steps(~MX"OhStOtOhStOt"s, 1 / 3, strokes: strokes())
      _ -> rest(4)
    end
  end

  # The tumba's open tones on the second and fourth main beats, in the Risoluto alone.
  defp tumba(bar) do
    case groove(bar) do
      :risoluto -> steps(~MX"...O.....O.."s, 1 / 3, strokes: strokes())
      _ -> rest(4)
    end
  end

  # The shaker on the first and last pulse of each beat, leaning on the main beats, softer where
  # the groove is light.
  defp shaker(bar) do
    case groove(bar) do
      :none -> rest(4)
      :light -> steps(~MX"3.23.23.23.2"s, 1 / 3)
      _ -> steps(~MX"4.34.34.34.3"s, 1 / 3)
    end
  end

  # The surdo on the four main beats, open on the first and third and muted on the second and
  # fourth, the floor under the groove; on the downbeat alone where the groove is light.
  defp surdo(bar) do
    case groove(bar) do
      :full -> steps(~MX"O..m..O..m.."s, 1 / 3, strokes: strokes())
      :risoluto -> steps(~MX"O..O..O..O.."s, 1 / 3, strokes: strokes())
      :light -> steps(~MX"o..........."s, 1 / 3, strokes: strokes())
      :none -> rest(4)
    end
  end

  # The drums' strokes: the congas' as examples/solo/congas.exs plays them, the heel a soft open
  # tone and the tip muted, and the surdo's soft open stroke and muted one.
  defp strokes do
    [
      O: [vel: 0.9],
      S: [vel: 0.9, slap: 1],
      h: [vel: 0.3],
      t: [vel: 0.3, mute: 1, amp: 0.7],
      o: [vel: 0.5],
      m: [vel: 0.45, muted: 1]
    ]
  end

  # How much of the percussion plays a bar: none through the introduction, the theme's first
  # bars, the middle section's opening and the last bars; shaker and clave as the theme settles,
  # in the passage before the middle section and in the coda; bell, conga and shaker in the
  # theme's groove, the middle section's second half and the return; the tumba too, and the
  # conga's slaps, in the Risoluto.
  defp groove(bar) do
    cond do
      bar in 10..16 or bar in 26..36 or bar in 89..98 -> :light
      bar in 17..25 or bar in 47..62 or bar in 71..88 -> :full
      bar in 63..69 -> :risoluto
      true -> :none
    end
  end

  # How fast the vibraphone's motor turns, in pulses a second: off in the first section and the
  # Risoluto, slow in the middle section, and from the return on, slower with each of the last
  # eight bars.
  defp motor(bar) do
    cond do
      bar in 39..62 -> 3
      bar in 71..98 -> 4
      bar >= 99 -> Float.round(4 - 0.35 * (bar - 98), 2)
      true -> 0
    end
  end

  # The ends of phrases that ring on in the echo: the throw opens on the third beat and closes in
  # the next bar.
  defp thrown(bar) do
    ends = [5, 16, 38, 46, 62, 70, 88]
    after_throw = if open?(bar), do: 0.15, else: 0.0

    cond do
      bar in ends ->
        [{2, change({:vibraphone, :ping_pong}, mix: 0.3)}]

      (bar - 1) in ends ->
        [{1, change({:vibraphone, :ping_pong}, mix: after_throw, mix_slide: 3)}]

      true ->
        []
    end
  end

  # How hard the vibraphone's mallets are: softer in the introduction and the middle section,
  # hardest in the Risoluto.
  defp brightness(bar) do
    cond do
      bar < 6 -> 0.45
      bar < 39 -> 0.5
      bar < 63 -> 0.45
      bar < 70 -> 0.68
      bar < 89 -> 0.56
      true -> 0.48
    end
  end

  # How hard the vibraphone is struck, as {bar, velocity}, straight between the keys: piano, a
  # crescendo to bar 25, forte in the middle section's climb and loudest in the Risoluto, and
  # dying away through the coda.
  defp level(at) do
    keys = [
      {1, 0.5},
      {17, 0.55},
      {25, 0.88},
      {26, 0.5},
      {38, 0.42},
      {39, 0.5},
      {47, 0.55},
      {49, 0.88},
      {62, 0.75},
      {63, 1.0},
      {66, 1.0},
      {70, 0.45},
      {71, 0.68},
      {89, 0.7},
      {98, 0.5},
      {107, 0.3}
    ]

    pairs = Enum.chunk_every(keys, 2, 1, :discard)

    [{from, a}, {to, b}] =
      Enum.find(pairs, List.last(pairs), fn [{from, _}, {to, _}] -> at >= from and at < to end)

    a + (b - a) * (at - from) / (to - from)
  end

  # The vibraphone's bars reach from C3 to F6, so a note past them is struck an octave in.
  defp in_range(note) when note > 89, do: note - 12
  defp in_range(note) when note < 48, do: note + 12
  defp in_range(note), do: note

  # The sub's register, from the E an octave under the bass clef to the G above it.
  defp fold(note) when note > 43, do: fold(note - 12)
  defp fold(note), do: note
end
