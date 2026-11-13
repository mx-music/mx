import Mx

# Rewind, a jungle track in E minor at 165 bpm made only of the samples Sonic Pi ships, which are under Creative Commons 0 and which mx plays by name.
# Its drums are one bar of the Amen break, loop_amen, cut into eight pieces and played back in new orders, which is how jungle is made.
# The bass is bass_woodsy_c, a single C played faster or slower to reach the other notes, with bass_dnb_f under the accents.
# The guitar chords, the choir and the bell are the pack's too, each one recording moved to the notes of E minor by its rate.
# A record's hiss opens it over a tabla loop, a rewind brings in the drums, and a backspin ends the middle.
# Download them with mx samples download sonic_pi.
defmodule Rewind do
  import Mx

  @parts [
    breaks: [fx: [level: [amp: 0.5]]],
    bass: [fx: [level: [amp: 0.35]]],
    stabs: [fx: [level: [amp: 0.3], reverb: [room: 0.5, mix: 0.2]]],
    bell: [fx: [level: [amp: 0.4], echo: [phase: 0.75, decay: 4, mix: 0.4], pan: [pan: 0.3]]],
    choir: [fx: [level: [amp: 0.45], reverb: [room: 0.85, mix: 0.5], pan: [pan: -0.3]]],
    guitar: [fx: [level: [amp: 0.6], reverb: [room: 0.7, mix: 0.3]]],
    tabla: [fx: [level: [amp: 1.2], pan: [pan: 0.2]]],
    record: [fx: [level: [amp: 0.45]]],
    crash: [fx: [level: [amp: 0.35]]]
  ]

  def play(voices) do
    together(for {name, music} <- voices, do: part(name, music, @parts[name]))
  end

  # The rate that moves a recording by so many semitones.
  defp semitones(steps), do: :math.pow(2, steps / 12)

  # The break at this tempo: its bar lasts 1.75 seconds and four beats here last 1.45.
  @faster 1.203

  # Pieces of the break in the order given, half a beat each: 0 and 1 are its kicks, 2 and 6 its snares.
  def chop(pieces) do
    seq(for piece <- pieces, do: sample(:loop_amen, 0.5, slices: 8, slice: piece, rate: @faster))
  end

  # A roll: one sixteenth of the break again and again, growing.
  def roll(piece, strokes) do
    seq(
      for stroke <- 1..strokes do
        sample(:loop_amen, 0.25,
          slices: 16,
          slice: piece,
          rate: @faster,
          amp: 0.5 + 0.5 * stroke / strokes
        )
      end
    )
  end

  @straight [0, 1, 2, 3, 4, 5, 6, 7]
  @pushed [0, 1, 2, 2, 4, 5, 6, 2]
  @doubled [0, 1, 2, 3, 0, 1, 2, 6]
  @stutter [0, 0, 2, 0, 0, 1, 6, 6]

  # Four bars of the break: three as given and a turn.
  def four(bar, turn), do: seq([repeat(chop(bar), 3), chop(turn)])

  # The bass, as semitones from its C and beats.
  def bass(notes) do
    seq(
      for {steps, beats} <- notes do
        sample(:bass_woodsy_c, beats,
          rate: semitones(steps),
          sustain: beats - 0.15,
          release: 0.15
        )
      end
    )
  end

  # Two bars: E held, G and A, then E, D and B.
  @line [{4, 2.5}, {7, 1}, {9, 0.5}, {4, 2}, {2, 1}, {-1, 1}]
  @high_line [{4, 2.5}, {7, 1}, {9, 0.5}, {11, 1.5}, {9, 0.5}, {7, 1}, {2, 1}]

  # bass_dnb_f, an F brought down to E, on the first beat of every other bar.
  def stabs(bars) do
    repeat(seq([sample(:bass_dnb_f, 8, rate: semitones(-1))]), div(bars, 2))
  end

  # The bell, elec_bell, a C: a phrase of E minor over four bars.
  def bell do
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

    seq(for {steps, beats} <- phrase, do: sample(:elec_bell, beats, rate: semitones(steps)))
  end

  # The choir, a note near C sharp, moved to B and to E and held.
  def choir(bars) do
    repeat(
      seq([
        sample(:ambi_choir, 8, rate: semitones(-2), attack: 0.5, release: 1),
        sample(:ambi_choir, 8, rate: semitones(3) / 2, attack: 0.5, release: 1)
      ]),
      div(bars, 4)
    )
  end

  # The hiss, the E minor ninth and the tabla loop, then the choir and the bell, and a rewind into the drums.
  def intro do
    play(
      record:
        seq([
          sample(:vinyl_hiss, 12),
          sample(:vinyl_hiss, 12),
          sample(:vinyl_rewind, 8)
        ]),
      guitar: seq([sample(:guit_em9, 16), sample(:guit_harmonics, 8), rest(8)]),
      tabla: seq([rest(8), sample(:loop_tabla, 24, beats: 32, sustain: 15, release: 1)]),
      choir: seq([rest(16), choir(4)]),
      bell: seq([rest(16), bell()])
    )
  end

  # Sixteen bars of the break and the bass.
  def drop do
    play(
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
      crash: seq([sample(:drum_splash_hard, 32), sample(:drum_cymbal_open, 32)])
    )
  end

  # Eight bars without the break: the guitar's fifths, the choir and the tabla, then a roll and a backspin.
  def middle do
    play(
      guitar: seq([sample(:guit_e_fifths, 16), sample(:guit_e_slide, 16)]),
      choir: choir(8),
      tabla: sample(:loop_tabla, 32, beats: 32, sustain: 27, release: 1),
      bell: seq([rest(8), bell(), rest(8)]),
      bass: seq([bass([{4, 8}, {0, 8}, {4, 8}]), rest(8)]),
      breaks: seq([rest(28), roll(4, 8), roll(12, 8)]),
      record: seq([rest(30), sample(:vinyl_backspin, 2)])
    )
  end

  # Sixteen bars again, the break cut harder and the bass climbing.
  def second_drop do
    play(
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
      crash: seq([sample(:drum_splash_hard, 32), sample(:drum_splash_hard, 32)])
    )
  end

  # The chord again over the hiss, and a low boom.
  def outro do
    play(
      guitar: sample(:guit_em9, 20),
      record: sample(:vinyl_hiss, 20),
      crash: sample(:drum_splash_hard, 20),
      bass: sample(:bd_boom, 20, rate: 0.8)
    )
  end

  def music, do: seq([intro(), drop(), middle(), second_drop(), outro()])
end

song(tempo: 165, music: Rewind.music())
