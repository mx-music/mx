defmodule PoeiraNoTerreiro do
  @moduledoc """
  Poeira no Terreiro, a forró pé de serra in G at 104 bpm, two beats to the bar, written for mx
  and not transcribed from any record.
  It is played by the trio Luiz Gonzaga gave the genre: the sanfona, the accordion, the zabumba,
  a flat bass drum, and the triangle.
  The zabumba and triangle patterns are the bases given in Roberto Kauffmann's "A sanfona no
  forró pé-de-serra: um pequeno estudo sobre Eron Lima e Nandinho Barros" (UNIRIO, 2019).
  The zabumbeiro's mallet strikes the upper head, closed, pressed into the skin, or open, and a
  thin stick, the bacalhau, snaps on the lower head.
  The place of the open stroke names the rhythm.
  In the baião the mallet is closed on one and open a sixteenth before two, and the bacalhau
  plays the eighths off the beat; in the forró the mallet is open on one and the bacalhau
  accents two; in the xaxado both mallet strokes are closed, and an open one answers after two.
  The triangle plays every sixteenth, the hand open on the third of each beat.
  The sanfona's left hand follows the zabumba, as the bass buttons do: a bass note where the
  mallet falls and a chord where the bacalhau does.
  Its right hand plays the theme in the scale of the northeast, G with a raised fourth and a
  flat seventh, runs under one stroke of the bellows, and a second voice a third below on each
  repeat; the forró turns to G minor, and in the xaxado the bellows shake a chord in sixteenths.
  The right hand sounds two sets of reeds an octave apart, and both hands share the bellows,
  which press where the zabumba plays and ease between, louder and brighter as they press.
  All three are mx's own synths.
  mx has no zabumba, so the mallet is its surdo, tuned up a minor third and half muted for the
  closed stroke, over its kick with a felt beater for the thump, and the bacalhau its tamborim,
  a stick on a tight head, tuned down a minor sixth.
  """

  use Mx.Song, tempo: 104

  @room [reverb: [decay_seconds: 1.5, damp: 0.5, mix: 0.16]]

  part :sanfona,
    synth: :accordion,
    defaults: [detune: 2.5],
    fx: [lpf: [cutoff: 106], level: [amp: 1.6]] ++ @room

  part :low_reed,
    synth: :accordion,
    defaults: [detune: 0],
    fx: [lpf: [cutoff: 106], level: [amp: 0.3]] ++ @room

  part :second_voice,
    synth: :accordion,
    defaults: [detune: 3.4],
    fx: [lpf: [cutoff: 106], level: [amp: 1.0], pan: [pan: 0.1]] ++ @room

  part :basses,
    synth: :accordion,
    defaults: [detune: 0],
    fx: [lpf: [cutoff: 94], level: [amp: 0.4], pan: [pan: -0.1]] ++ @room

  part :mallet, synth: :surdo, defaults: [note: 39], fx: [level: [amp: 1.2]] ++ @room
  part :thump, synth: :kick, defaults: [note: 37, beater: 0], fx: [level: [amp: 0.2]]

  part :bacalhau,
    synth: :tamborim,
    defaults: [note: 64],
    fx: [level: [amp: 1.5], pan: [pan: -0.1]] ++ @room

  part :triangle, synth: :triangle, fx: [level: [amp: 1.6], pan: [pan: 0.3]] ++ @room

  def song do
    seq([
      call(),
      intro(),
      baiao(:alone),
      baiao(:thirds),
      forro(:alone),
      forro(:thirds),
      xaxado(),
      baiao(:thirds),
      ending()
    ])
  end

  # The sanfona calls over the triangle: the bellows shake G seventh for a bar, a run falls
  # through the scale, and the zabumba answers into the first bar.
  defp call do
    together([
      lead(seq([shake([:g7]), sung([~MX"g5 ~f5 ~e5 ~d5 ~cs5 ~b4 ~a4 ~g4"], 0.75)])),
      hand(:basses, steps(~MX"g2:8 _:8", 0.25, vel: 0.6, sustain: 1.8, release: 0.1)),
      zabumba([:silence, :pickup]),
      triangle(2)
    ])
  end

  # The baião starts under a riff of four bars, played twice, the second time in thirds.
  defp intro do
    together([
      lead(repeat(riff(), 2)),
      hand(:second_voice, delay(riff_thirds(), 8)),
      hand(:basses, basses(:baiao, List.duplicate(:g7, 8))),
      zabumba(~w(baiao baiao baiao baiao_turn baiao baiao baiao baiao_turn)a),
      triangle(8)
    ])
  end

  # The theme, eight bars over G seventh with two of C seventh; on a repeat a second voice joins
  # a third below and the bacalhau plays both eighths off the beat.
  defp baiao(voices) do
    chords = ~w(g7 g7 g7 g7 c7 c7 g7 g7)a

    bars =
      case voices do
        :alone ->
          ~w(baiao baiao baiao baiao_turn baiao baiao baiao baiao_turn)a

        :thirds ->
          ~w(baiao_old baiao_old baiao_old baiao_turn baiao_old baiao_old baiao baiao_turn)a
      end

    together(
      [
        lead(theme()),
        hand(:basses, basses(:baiao, chords)),
        zabumba(bars),
        triangle(8)
      ] ++ second(voices, theme_thirds())
    )
  end

  # The second part, in G minor: the zabumba opens on one, and the tune holds its notes across
  # the beat before it runs.
  defp forro(voices) do
    chords = ~w(gm gm c7 c7 gm gm d7 gm)a

    together(
      [
        lead(answer()),
        hand(:basses, basses(:forro, chords)),
        zabumba(~w(forro forro forro forro_turn forro forro forro forro_turn)a),
        triangle(8)
      ] ++ second(voices, answer_thirds())
    )
  end

  # The xaxado: the bellows shake the chords for six bars, the zabumba and the triangle play a
  # bar alone, and a run climbs back to the theme.
  defp xaxado do
    together([
      lead(
        seq([
          shake(~w(g7 g7 c7 c7 g7 g7)a),
          rest(2),
          sung([~MX"d4 ~e4 ~f4 ~g4 ~a4 ~b4 ~cs5 ~d5"], 0.8)
        ])
      ),
      hand(:basses, basses(:xaxado, ~w(g7 g7 c7 c7 g7 g7)a)),
      zabumba(~w(xaxado xaxado xaxado xaxado_turn xaxado xaxado xaxado_turn roll)a),
      triangle(8)
    ])
  end

  # The riff once more in thirds, a run down the scale together, and the last three strokes:
  # one, the sixteenth before two, and two.
  defp ending do
    last = [vel: 0.7, sustain: 1.5, release: 0.4]

    together([
      lead(
        seq([
          sung(Enum.take(riff_bars(), 2) ++ [~MX"g5 ~f5 ~e5 ~d5 ~cs5 ~b4 ~a4 ~f4"], 0.8),
          steps(~MX"g4/b4/d5/g5:3 g4/b4/d5/g5", 0.25, vel: 0.8, sustain: 0.15, release: 0.05),
          note([:g4, :b4, :d5, :g5], 4, last)
        ])
      ),
      hand(
        :second_voice,
        sung(Enum.take(riff_thirds_bars(), 2) ++ [~MX"e5 ~d5 ~cs5 ~b4 ~a4 ~g4 ~f4 ~d4"], 0.7)
      ),
      hand(
        :basses,
        seq([
          basses(:baiao, ~w(g7 g7 g7)a),
          steps(~MX"g2:3 g2", 0.25, vel: 0.75, sustain: 0.2, release: 0.05),
          note([:g2, :g3, :b3, :d4], 4, last)
        ])
      ),
      zabumba(~w(baiao_old baiao_old roll last)a),
      part(
        :triangle,
        seq([triangle_bars(3), steps(~MX"c..cO..."s, 0.25, strokes: triangle_strokes())])
      )
    ])
  end

  # A second voice plays only on a repeat.
  defp second(:alone, _music), do: []
  defp second(:thirds, music), do: [hand(:second_voice, music)]

  # The right hand on two sets of reeds, the second an octave below.
  defp lead(music) do
    together([hand(:sanfona, music), hand(:low_reed, transpose(music, -12))])
  end

  # A hand of the sanfona, under the bellows the hands share.
  defp hand(name, music), do: part(name, together([music, bellows(name, beats(music))]))

  # The bellows press on one, on the sixteenth before two and on the eighth after it, where the
  # zabumba plays, and ease between: pressed, the reeds are louder and brighter.
  defp bellows(name, beats) do
    {bright, dark} = if name == :basses, do: {96, 90}, else: {110, 102}

    changes =
      for bar <- 0..(ceil(beats / 2) - 1), {beat, level} <- [{0, 1.0}, {0.75, 1.0}, {1.5, 0.9}] do
        at = bar * 2 + beat

        [
          {at,
           change({name, :lpf}, amp: level, amp_slide: 0.04, cutoff: bright, cutoff_slide: 0.04)},
          {at + 0.08,
           change({name, :lpf}, amp: 0.7, amp_slide: 0.6, cutoff: dark, cutoff_slide: 0.6)}
        ]
      end

    at(Enum.filter(List.flatten(changes), fn {at, _change} -> at < beats end), beats)
  end

  defp riff, do: sung(riff_bars(), 0.8)
  defp riff_thirds, do: sung(riff_thirds_bars(), 0.7)

  # Four bars, a sixteenth to a step: a note struck three times climbs to the flat seventh, and
  # the answer lands on the sixteenth before two, where the zabumba opens.
  defp riff_bars do
    [
      ~MX"d5 d5:2 d5 f5:2 e5 ~d5",
      ~MX"cs5 ~d5 ~b4 g4:5",
      ~MX"d5 d5:2 d5 f5:2 e5 ~d5",
      ~MX"b4 ~cs5 ~d5 g5:5"
    ]
  end

  defp riff_thirds_bars do
    [
      ~MX"b4 b4:2 b4 d5:2 cs5 ~b4",
      ~MX"a4 ~b4 ~g4 d4:5",
      ~MX"b4 b4:2 b4 d5:2 cs5 ~b4",
      ~MX"g4 ~a4 ~b4 d5:5"
    ]
  end

  # The baião's theme: the chord climbed to its flat seventh and turned on the raised fourth,
  # twice, then C seventh in struck notes, and home down the scale.
  defp theme do
    sung(
      [
        ~MX"g4 ~b4 ~d5 g5 f5:2 e5 ~d5",
        ~MX"cs5 ~d5 ~e5 d5:5",
        ~MX"g4 ~b4 ~d5 g5 f5:2 e5 ~d5",
        ~MX"cs5 ~d5 ~b4 g4:3 _ d5",
        ~MX"e5:2 e5 g5:2 g5 e5:2",
        ~MX"d5 ~e5 ~d5 c5 bb4:2 g4:2",
        ~MX"a4 ~b4 ~cs5 d5:2 f5 e5 ~d5",
        ~MX"cs5 ~b4 ~a4 g4:5"
      ],
      0.8
    )
  end

  # The voice under the theme, which joins at the top of each climb.
  defp theme_thirds do
    sung(
      [
        ~MX"_:3 b4 d5:2 cs5 ~b4",
        ~MX"a4 ~b4 ~cs5 b4:5",
        ~MX"_:3 b4 d5:2 cs5 ~b4",
        ~MX"a4 ~b4 ~g4 d4:3 _ b4",
        ~MX"c5:2 c5 e5:2 e5 c5:2",
        ~MX"bb4 ~c5 ~bb4 a4 g4:2 e4:2",
        ~MX"f4 ~g4 ~a4 b4:2 d5 cs5 ~b4",
        ~MX"a4 ~g4 ~f4 d4:5"
      ],
      0.7
    )
  end

  # The forró's tune: three notes to a bar, long, long, short, then runs up G minor and down
  # through D seventh.
  defp answer do
    sung(
      [
        ~MX"d5:3 g5:3 f5:2",
        ~MX"d5:3 bb4:3 d5:2",
        ~MX"e5:3 g5:3 e5:2",
        ~MX"d5 ~c5 ~bb4 c5:5",
        ~MX"bb4 ~d5 ~g5 bb5:3 a5 ~g5",
        ~MX"f5 ~g5 ~f5 d5:3 bb4 ~d5",
        ~MX"c5 ~d5 ~c5 a4:3 fs4 ~a4",
        ~MX"g4:6 _:2"
      ],
      0.8
    )
  end

  defp answer_thirds do
    sung(
      [
        ~MX"bb4:3 d5:3 d5:2",
        ~MX"bb4:3 g4:3 bb4:2",
        ~MX"c5:3 e5:3 c5:2",
        ~MX"bb4 ~a4 ~g4 e4:5",
        ~MX"g4 ~bb4 ~d5 g5:3 f5 ~d5",
        ~MX"d5 ~e5 ~d5 bb4:3 g4 ~bb4",
        ~MX"a4 ~bb4 ~a4 fs4:3 d4 ~fs4",
        ~MX"d4:6 _:2"
      ],
      0.7
    )
  end

  # Bars of the right hand, a sixteenth to a step.
  # The notes joined by ~ sound under one stroke of the bellows, the fingers alone changing the
  # note; a note on the beat or held is pressed a little harder.
  defp sung(bars, vel) do
    press = fn step, length ->
      accent = if rem(step, 4) == 0 or length > 2, do: 0.05, else: -0.03

      [
        vel: min(vel + accent + wobble(step, 0.03), 1),
        sustain: length * 0.25 * 0.88,
        release: 0.06
      ]
    end

    steps(bars, 0.25, each: press, slide: 0.02)
  end

  # A bar of each chord in sixteenths, the bellows turning on every one and pressing harder on
  # the first, the fourth and the seventh.
  defp shake(chords) do
    bars = %{
      g7: ~MX"f4/b4/d5 f4/b4/d5 f4/b4/d5 f4/b4/d5 f4/b4/d5 f4/b4/d5 f4/b4/d5 f4/b4/d5",
      c7: ~MX"e4/bb4/c5 e4/bb4/c5 e4/bb4/c5 e4/bb4/c5 e4/bb4/c5 e4/bb4/c5 e4/bb4/c5 e4/bb4/c5"
    }

    turn = fn step ->
      loud = if rem(step, 8) in [0, 3, 6], do: 0.7, else: 0.42
      [vel: loud + wobble(step, 0.03), sustain: 0.13, release: 0.04]
    end

    steps(Enum.map(chords, &bars[&1]), 0.25, each: turn)
  end

  # The left hand's bar for each chord, a sixteenth to a step: bass notes where the zabumba's
  # mallet falls and the chord button where its bacalhau does.
  defp basses(rhythm, chords) do
    bars = %{
      baiao: %{
        g7: ~MX"g2:2 f3/g3/b3 g2 d2:2 f3/g3/b3 _",
        c7: ~MX"c3:2 bb3/c4/e4 c3 g2:2 bb3/c4/e4 _"
      },
      forro: %{
        gm: ~MX"g2:2 _ g2 g3/bb3/d4:2 g3/bb3/d4 d2",
        c7: ~MX"c3:2 _ c3 bb3/c4/e4:2 bb3/c4/e4 g2",
        d7: ~MX"d3:2 _ d3 fs3/c4/d4:2 fs3/c4/d4 a2"
      },
      xaxado: %{
        g7: ~MX"g2 f3/g3/b3:2 g2 f3/g3/b3:2 d2:2",
        c7: ~MX"c3 bb3/c4/e4:2 c3 bb3/c4/e4:2 g2:2"
      }
    }

    button = fn step, length ->
      vel = if rem(step, 8) in [0, 3], do: 0.72, else: 0.6
      [vel: vel + wobble(step, 0.03), sustain: length * 0.25 * 0.6, release: 0.05]
    end

    steps(Enum.map(chords, &bars[rhythm][&1]), 0.25, each: button)
  end

  # The zabumba's bars, each named by what it plays, on its two heads.
  defp zabumba(bars) do
    mallet = [
      O: [vel: 0.9],
      o: [vel: 0.7],
      c: [vel: 0.75, muted: 0.5]
    ]

    thump = [O: [vel: 0.8], o: [vel: 0.6], c: [vel: 0.65]]
    stick = [X: [vel: 0.9], x: [vel: 0.7], g: [vel: 0.4]]
    head = fn head -> Enum.map(bars, fn bar -> zabumba_bar(bar)[head] end) end

    together([
      part(:mallet, steps(head.(:mallet), 0.25, strokes: mallet)),
      part(:thump, steps(head.(:mallet), 0.25, strokes: thump)),
      part(:bacalhau, steps(head.(:bacalhau), 0.25, strokes: stick))
    ])
  end

  # A bar of the two heads in sixteenths: for the mallet, O is an open stroke, o a softer one and
  # c a closed one; for the bacalhau, X is an accent, x a stroke and g a soft one.
  defp zabumba_bar(:baiao), do: %{mallet: ~MX"c..O...."s, bacalhau: ~MX"......x."s}
  defp zabumba_bar(:baiao_turn), do: %{mallet: ~MX"c..O..o."s, bacalhau: ~MX".x......"s}

  # The baião of the old records, with both eighths off the beat on the bacalhau.
  defp zabumba_bar(:baiao_old), do: %{mallet: ~MX"c..Oo..."s, bacalhau: ~MX"..x...x."s}
  defp zabumba_bar(:forro), do: %{mallet: ~MX"O..c...o"s, bacalhau: ~MX"....X..."s}
  defp zabumba_bar(:forro_turn), do: %{mallet: ~MX"O..c.o.o"s, bacalhau: ~MX"....X..."s}
  defp zabumba_bar(:xaxado), do: %{mallet: ~MX"c..c..O."s, bacalhau: ~MX".x..x..."s}
  defp zabumba_bar(:xaxado_turn), do: %{mallet: ~MX"c..c..Oo"s, bacalhau: ~MX".xx.x..."s}
  defp zabumba_bar(:roll), do: %{mallet: ~MX"c..O.ooO"s, bacalhau: ~MX".xx.x.x."s}
  defp zabumba_bar(:pickup), do: %{mallet: ~MX"......oO"s, bacalhau: ~MX"....x..."s}
  defp zabumba_bar(:last), do: %{mallet: ~MX"c..OO..."s, bacalhau: ~MX"........"s}
  defp zabumba_bar(:silence), do: %{mallet: ~MX"........"s, bacalhau: ~MX"........"s}

  defp triangle(bars), do: part(:triangle, triangle_bars(bars))

  # Every sixteenth, the hand open on the third of each beat.
  defp triangle_bars(bars) do
    repeat(steps(~MX"ccocccoc"s, 0.25, strokes: triangle_strokes()), bars)
  end

  # O rings until it fades, o rings until the hand closes on the next stroke, and c is a stroke
  # the hand keeps closed.
  defp triangle_strokes do
    [
      O: [vel: 0.85],
      o: [vel: 0.75, sustain: 0.2, release: 0.1],
      c: [vel: 0.6, sustain: 0.02, release: 0.15]
    ]
  end

  # A small amount, up to `size` either way, that is the same each time for the same `seed`.
  defp wobble(seed, size), do: (:erlang.phash2(seed, 1000) / 999 - 0.5) * 2 * size
end
