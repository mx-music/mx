defmodule Rewind do
  @moduledoc """
  Rewind, a jungle track in E minor at 165 bpm made only of the samples Sonic Pi ships, which are
  under Creative Commons 0 and which mx plays by name.
  Its drums are one bar of the Amen break, loop_amen, cut into eight pieces and played back in new
  orders, which is how jungle is made.
  The bass is bass_woodsy_c, a single C played faster or slower to reach the other notes, with
  bass_dnb_f under the accents.
  The guitar chords, the choir and the bell are the pack's too, each one recording moved to the
  notes of E minor by its rate.
  A record's hiss opens it over a tabla loop, a rewind brings in the drums, and a backspin ends
  the middle.
  Download them with mx samples download sonic_pi.
  """

  use Mx.Song, tempo: 165

  part :breaks, fx: [level: [amp: 0.5]]
  part :bass, fx: [level: [amp: 0.35]]
  part :stabs, fx: [level: [amp: 0.3], reverb: [decay_seconds: 1.5, mix: 0.2]]
  part :bell, fx: [level: [amp: 0.4], echo: [phase: 0.75, decay: 4, mix: 0.4], pan: [pan: 0.3]]
  part :choir, fx: [level: [amp: 0.45], reverb: [decay_seconds: 4, mix: 0.5], pan: [pan: -0.3]]
  part :guitar, fx: [level: [amp: 0.6], reverb: [decay_seconds: 2.3, mix: 0.3]]
  part :tabla, fx: [level: [amp: 1.2], pan: [pan: 0.2]]
  part :record, fx: [level: [amp: 0.45]]
  part :crash, fx: [level: [amp: 0.35]]

  # The break at this tempo: its bar lasts 1.75 seconds and four beats here last 1.45.
  @faster 1.203

  @straight [0, 1, 2, 3, 4, 5, 6, 7]
  @pushed [0, 1, 2, 2, 4, 5, 6, 2]
  @doubled [0, 1, 2, 3, 0, 1, 2, 6]
  @stutter [0, 0, 2, 0, 0, 1, 6, 6]

  # Two bars: E held, G and A, then E, D and B.
  @line [{4, 2.5}, {7, 1}, {9, 0.5}, {4, 2}, {2, 1}, {-1, 1}]
  @high_line [{4, 2.5}, {7, 1}, {9, 0.5}, {11, 1.5}, {9, 0.5}, {7, 1}, {2, 1}]

  def song do
    seq([intro(), drop(), middle(), second_drop(), outro()])
  end

  # The hiss, the E minor ninth and the tabla loop, then the choir and the bell, and a rewind into
  # the drums.
  defp intro do
    together(
      record:
        seq([
          sample({:sonic_pi, :vinyl_hiss}, 12),
          sample({:sonic_pi, :vinyl_hiss}, 12),
          sample({:sonic_pi, :vinyl_rewind}, 8)
        ]),
      guitar:
        seq([
          sample({:sonic_pi, :guit_em9}, 16),
          sample({:sonic_pi, :guit_harmonics}, 8),
          rest(8)
        ]),
      tabla:
        seq([rest(8), sample({:sonic_pi, :loop_tabla}, 24, beats: 32, sustain: 15, release: 1)]),
      choir: seq([rest(16), choir(4)]),
      bell: seq([rest(16), bell()])
    )
  end

  # Sixteen bars of the break and the bass.
  defp drop do
    together(
      breaks:
        seq([
          four(@straight, @pushed),
          four(@straight, @doubled),
          four(@pushed, @doubled),
          four(@pushed, @stutter)
        ]),
      bass: repeat(bass(@line), 8),
      stabs: seq([rest(32), stabs(8)]),
      bell: seq([rest(16), bell(), rest(16), bell()]),
      crash:
        seq([
          sample({:sonic_pi, :drum_splash_hard}, 32),
          sample({:sonic_pi, :drum_cymbal_open}, 32)
        ])
    )
  end

  # Eight bars without the break: the guitar's fifths, the choir and the tabla, then a roll and a
  # backspin.
  defp middle do
    together(
      guitar:
        seq([sample({:sonic_pi, :guit_e_fifths}, 16), sample({:sonic_pi, :guit_e_slide}, 16)]),
      choir: choir(8),
      tabla: sample({:sonic_pi, :loop_tabla}, 32, beats: 32, sustain: 27, release: 1),
      bell: seq([rest(8), bell(), rest(8)]),
      bass: seq([bass([{4, 8}, {0, 8}, {4, 8}]), rest(8)]),
      breaks: seq([rest(28), roll(4, 8), roll(12, 8)]),
      record: seq([rest(30), sample({:sonic_pi, :vinyl_backspin}, 2)])
    )
  end

  # Sixteen bars again, the break cut harder and the bass climbing.
  defp second_drop do
    together(
      breaks:
        seq([
          four(@pushed, @doubled),
          four(@doubled, @stutter),
          four(@pushed, @doubled),
          seq([repeat(chop(@stutter), 2), chop(@doubled), roll(4, 8), roll(12, 8)])
        ]),
      bass: repeat(seq([bass(@line), bass(@high_line)]), 4),
      stabs: stabs(16),
      choir: choir(16),
      bell: seq([bell(), rest(16), bell(), rest(16)]),
      crash:
        seq([
          sample({:sonic_pi, :drum_splash_hard}, 32),
          sample({:sonic_pi, :drum_splash_hard}, 32)
        ])
    )
  end

  # The chord again over the hiss, and a low boom.
  defp outro do
    together(
      guitar: sample({:sonic_pi, :guit_em9}, 20),
      record: sample({:sonic_pi, :vinyl_hiss}, 20),
      crash: sample({:sonic_pi, :drum_splash_hard}, 20),
      bass: sample({:sonic_pi, :bd_boom}, 20, rate: 0.8)
    )
  end

  # The choir, a note near C sharp, moved to B and to E and held.
  defp choir(bars) do
    repeat(
      seq([
        sample({:sonic_pi, :ambi_choir}, 8, rate: semitones(-2), attack: 0.5, release: 1),
        sample({:sonic_pi, :ambi_choir}, 8, rate: semitones(3) / 2, attack: 0.5, release: 1)
      ]),
      div(bars, 4)
    )
  end

  # The bell, elec_bell, a C: a phrase of E minor over four bars.
  defp bell do
    phrase = [
      {16, 0.75},
      {19, 0.75},
      {23, 1.5},
      {21, 1},
      {19, 0.75},
      {16, 0.75},
      {14, 1.5},
      {16, 9}
    ]

    seq(phrase, fn {steps, beats} ->
      sample({:sonic_pi, :elec_bell}, beats, rate: semitones(steps))
    end)
  end

  # Four bars of the break: three as given and a turn.
  defp four(bar, turn), do: seq([repeat(chop(bar), 3), chop(turn)])

  # The bass, as semitones from its C and beats.
  defp bass(notes) do
    seq(notes, fn {steps, beats} ->
      sample({:sonic_pi, :bass_woodsy_c}, beats,
        rate: semitones(steps),
        sustain: beats - 0.15,
        release: 0.15
      )
    end)
  end

  # bass_dnb_f, an F brought down to E, on the first beat of every other bar.
  defp stabs(bars) do
    repeat(seq([sample({:sonic_pi, :bass_dnb_f}, 8, rate: semitones(-1))]), div(bars, 2))
  end

  # A roll: one sixteenth of the break again and again, growing.
  defp roll(piece, strokes) do
    seq(1..strokes, fn stroke ->
      sample({:sonic_pi, :loop_amen}, 0.25,
        slices: 16,
        slice: piece,
        rate: @faster,
        amp: 0.5 + 0.5 * stroke / strokes
      )
    end)
  end

  # Pieces of the break in the order given, half a beat each: 0 and 1 are its kicks, 2 and 6 its
  # snares.
  defp chop(pieces) do
    seq(pieces, fn piece ->
      sample({:sonic_pi, :loop_amen}, 0.5, slices: 8, slice: piece, rate: @faster)
    end)
  end

  # The rate that moves a recording by so many semitones.
  defp semitones(steps), do: :math.pow(2, steps / 12)
end
