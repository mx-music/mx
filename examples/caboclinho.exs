defmodule Caboclinho do
  @moduledoc """
  A study after the caboclinhos of Pernambuco in 2/4, played only on synths measured from
  recordings.
  The terno, the order of the toques and the gaita's neutral third are written after Climério de
  Oliveira Santos, "Guerra: uma introdução ao estudo da performance dos caboclinhos Canindés"
  (ANPPOM, 2007), and the preacas after him and Jaqueline de Oliveira e Silva, "Guerra, perré e
  outras manobras" (Revista Dança, 2014).
  The melodies, the rest of the gaita's scale and its pitch, the tempos, the tarol outside guerra
  and the atabaque's pattern are mx's own, where a gaiteiro varies melodies the tradition hands
  down.
  flute plays the gaita, ganza and shaker the two caracaxás, low_bongo the tarol, high_bongo muted
  the preacas, and cajon the atabaque.
  """

  use Mx.Song, tempo: 132

  part :flute, synth: :flute, defaults: [vibrato: 0.1], fx: [reverb: [room: 0.3, mix: 0.15]]
  part :ganza, synth: :ganza, defaults: [amp: 0.5]
  part :shaker, synth: :shaker, defaults: [amp: 0.3, pan: 0.3]
  part :low_bongo, synth: :low_bongo
  part :high_bongo, synth: :high_bongo, defaults: [muted: 1, amp: 0.6, pan: -0.3]
  part :cajon, synth: :cajon, defaults: [amp: 0.8]

  # Each pass plays one toque for eight bars, in the order a rehearsal plays them, then goes round
  # again from guerra.
  def song do
    toques = [:guerra, :guerra, :perre, :perre, :baiao, :baiao, :macumba, :macumba]

    toques
    |> Enum.map(&toque/1)
    |> seq()
    |> repeat()
  end

  defp toque(toque) do
    together([
      part(:flute, gaita(toque)),
      part(:ganza, caracaxa(toque, ~MX"duDu"s, 0.8, 0.45)),
      part(:shaker, caracaxa(toque, ~MX"udUd"s, 0.75, 0.4)),
      part(:low_bongo, tarol(toque)),
      part(:high_bongo, preacas(toque)),
      part(:cajon, atabaque(toque))
    ])
  end

  defp gaita(toque) do
    unit = unit(toque)

    notes =
      for phrase <- melody(toque), note <- phrase do
        {step, beats, graces} =
          case note do
            {step, beats} -> {step, beats, []}
            note -> note
          end

        # An appoggiatura takes a thirty-second note from the start of the note it leads to.
        graces =
          for grace <- graces,
              do:
                note(gaita_note(grace), 0.125 * unit,
                  vel: 0.5,
                  sustain: 0.08 * unit,
                  release: 0.03 * unit
                )

        length = (beats - 0.125 * length(graces)) * unit
        vel = if beats >= 1, do: 0.75, else: 0.6

        seq(
          graces ++
            [
              note(gaita_note(step), length,
                vel: vel,
                sustain: Float.round(length * 0.75, 4),
                release: Float.round(length * 0.15, 4)
              )
            ]
        )
      end

    seq(notes)
  end

  # Each toque's melody, four phrases of two bars, as {step, beats of the toque} or {step, beats,
  # appoggiaturas}.
  defp melody(:guerra) do
    [
      [
        {4, 0.5},
        {2, 0.5},
        {1, 0.25},
        {2, 0.25},
        {0, 0.5},
        {2, 0.5},
        {4, 0.5},
        {5, 0.5},
        {4, 0.5}
      ],
      [{4, 0.5, [5]}, {2, 0.5}, {1, 0.25}, {2, 0.25}, {0, 0.5}, {2, 0.5}, {4, 0.5}, {2, 1}],
      [{7, 0.5}, {5, 0.5}, {4, 0.5}, {5, 0.5}, {4, 0.25}, {2, 0.25}, {1, 0.5}, {0, 1, [1, 2]}],
      [{2, 0.5}, {1, 0.5}, {0, 0.5}, {-1, 0.5}, {0, 2, [-1]}]
    ]
  end

  defp melody(:perre) do
    [
      [{0, 1, [1]}, {2, 0.5}, {1, 0.5}, {0, 1.5}, {-1, 0.5}],
      [{0, 1, [2, 1]}, {2, 0.5}, {4, 0.5}, {2, 1.5}, {1, 0.5}],
      [{4, 1, [5]}, {5, 0.5}, {4, 0.5}, {2, 1}, {1, 1}],
      [{2, 1}, {1, 0.5}, {-1, 0.5}, {0, 2, [1]}]
    ]
  end

  defp melody(:baiao) do
    [
      [{0, 0.75}, {2, 0.25}, {4, 1}, {5, 0.75}, {4, 0.25}, {2, 1}],
      [{0, 0.75}, {2, 0.25}, {4, 1, [5]}, {7, 0.75}, {5, 0.25}, {4, 1}],
      [{5, 0.5}, {4, 0.5}, {2, 0.75}, {1, 0.25}, {2, 0.5}, {1, 0.5}, {0, 1}],
      [{-1, 0.75}, {0, 0.25}, {2, 0.5}, {1, 0.5}, {0, 2, [2, 1]}]
    ]
  end

  defp melody(:macumba) do
    [
      [{0, 0.5}, {0, 0.5}, {2, 0.5}, {0, 0.5}, {-1, 1}, {-3, 1}],
      [{0, 0.5}, {0, 0.5}, {2, 0.5}, {3, 0.5}, {2, 1, [3]}, {0, 1}],
      [{2, 0.5}, {2, 0.5}, {3, 0.5}, {2, 0.5}, {0, 1}, {-1, 1}],
      [{-1, 0.5}, {0, 0.5}, {-1, 0.5}, {-3, 0.5}, {0, 2, [-1]}]
    ]
  end

  # The gaita's notes as steps from its tonic, G5: a neutral third, 3.5 semitones up, in place of
  # the minor or the major third.
  defp gaita_note(step) do
    degrees = [0, 2, 3.5, 5, 7, 9, 10]
    79 + 12 * Integer.floor_div(step, 7) + Enum.at(degrees, Integer.mod(step, 7))
  end

  # The caracaxás shake sixteenths, the third of each beat accented, written for one beat: d is
  # down and u is up, in capitals where accented.
  defp caracaxa(toque, beat, accent, soft) do
    strokes = [
      d: [vel: soft, up: 0],
      u: [vel: soft, up: 1],
      D: [vel: accent, up: 0],
      U: [vel: accent, up: 1]
    ]

    steps(List.duplicate(beat, 16), sixteenth(toque), strokes: strokes)
  end

  # The tarol's bar in sixteenths, and the fourth bar of each four, which varies.
  # A number is how hard a stroke is, in tenths, and an m before it mutes the stroke.
  # In guerra: a dotted eighth and a sixteenth, a rest on the second beat, and the bacalhau,
  # struck muted, on the fourth bar.
  # Its perré and baião are mx's own; it rests while the atabaque plays.
  defp tarol(:guerra), do: tarol(:guerra, ~MX"8 _ _ 7 | _ _ _ _", ~MX"8 _ _ 7 | m5 m4 m55 m4")
  defp tarol(:baiao), do: tarol(:baiao, ~MX"8 _ _ 6 | 7 _ _ _", ~MX"8 _ _ 6 | 7 _ m45 _")
  defp tarol(:perre), do: tarol(:perre, ~MX"8 _ _ _ | 6 _ _ _", ~MX"8 _ _ _ | 6 _ m45 _")
  defp tarol(:macumba), do: rest(16 * unit(:macumba))

  defp tarol(toque, bar, fourth) do
    strokes = [
      "8": [vel: 0.8],
      "7": [vel: 0.7],
      "6": [vel: 0.6],
      m55: [muted: 1, vel: 0.55],
      m5: [muted: 1, vel: 0.5],
      m45: [muted: 1, vel: 0.45],
      m4: [muted: 1, vel: 0.4]
    ]

    four = [bar, bar, bar, fourth]
    steps(four ++ four, sixteenth(toque), strokes: strokes)
  end

  # The preacas: in guerra one strike on the first beat of each bar, as Santos hears the Canindés
  # play it.
  # Silva counts two strikes in baião and one in perré, set here on the beats; macumba do índio's
  # one is mx's own.
  defp preacas(toque) do
    bar = if toque == :baiao, do: ~MX"x...x..."s, else: ~MX"x......."s
    steps(List.duplicate(bar, 8), sixteenth(toque), vel: 0.7)
  end

  # The atabaque of macumba do índio, written for mx: the bass tone on the beats and slaps between
  # them.
  # A number is how hard a tone is, in tenths, and an s before it makes it a slap.
  defp atabaque(:macumba) do
    strokes = [
      "8": [vel: 0.8],
      "7": [vel: 0.7],
      "6": [vel: 0.6],
      s6: [slap: 1, vel: 0.6],
      s5: [slap: 1, vel: 0.5]
    ]

    steps(List.duplicate(~MX"8 _ s5 6 | 7 _ s6 _", 8), sixteenth(:macumba), strokes: strokes)
  end

  defp atabaque(toque), do: rest(16 * unit(toque))

  # Beats of the song to one beat of the toque: guerra is the fastest.
  defp unit(:guerra), do: 1
  defp unit(:baiao), do: 1.25
  defp unit(:macumba), do: 1.25
  defp unit(:perre), do: 1.5

  defp sixteenth(toque), do: 0.25 * unit(toque)
end
