defmodule PlanxtyIrwin do
  @moduledoc """
  Planxty Irwin, a tune by the Irish harper Turlough O'Carolan, on the plucked strings of VCSL,
  Versilian Studios' Versilian Community Sample Library, under Creative Commons 0: concert harp,
  folk harp, strumstick, and the bowed psaltery, plucked and bowed.
  The tune is as O'Neill's Music of Ireland of 1903 prints it, number 677, a jig in D of two
  strains of eight bars, each played twice; the chords under it are this arrangement's.
  It is played twice through: first by the concert harp alone, the tune in one hand and a bass and
  chord in the other, then by the folk harp over the concert harp's broken chords and the
  strumstick's strumming, the psaltery plucking the tune an octave above in the first strain and
  bowing long notes in the second.
  VCSL names the keys of the concert harp at their pitch and those of the others an octave below
  it.
  The concert harp's notes start some 40 thousandths of a second into their files, so it plays
  that much early.
  The files are fetched as the song loads, about 135 MB.
  """

  use Mx.Song, tempo: 92

  vcsl = fn path -> {:vcsl, "Chordophones/#{path}"} end

  # The files of one instrument, each key the start of its name, so many semitones above that
  # name.
  keys = fn folder, prefix, octave, names ->
    for name <- names do
      key = name |> String.split("_") |> hd()
      note = key |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
      {vcsl.("#{folder}/#{prefix}#{name}.wav"), note: pitch(note) + octave}
    end
  end

  @concert_harp keys.(
                  "Composite Chordophones/Concert Harp",
                  "KSHarp_",
                  0,
                  ~w(E1_f1 G1_f1 B1_f1 D2_f1 F2_f1 A2_f1 C3_f2 E3_f1 G3_f1 B3_f1 D4_f1 F4_f1 A4_f1 C5_f1 E5_f1 G5_f1 B5_f1 D6_f1)
                )

  folk_harp = for octave <- 2..4, key <- ~w(C D E F# G# A#), do: "#{key}#{octave}_v3_RR1"

  @folk_harp keys.(
               "Composite Chordophones/Folk Harp",
               "EWHarp_Normal_",
               12,
               folk_harp ++ ~w(C5_v3_RR1 D5_v3_RR1)
             )

  # The strumstick's files name their string before their key.
  @strumstick (for {string, names} <- [
                     {1, ~w(D2 E2 F#2 G2)},
                     {2, ~w(A2 B2 C#3 D3)},
                     {3, ~w(E3 F#3 G3 A3 B3 C#4 D4 E4 F#4)}
                   ],
                   name <- names do
                 note = name |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()

                 path =
                   "Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str#{string}_Main_#{name}_vl2_rr1.wav"

                 {vcsl.(path), note: pitch(note) + 12}
               end)

  psaltery = fn way, names ->
    for name <- names do
      key = name |> String.split("_") |> hd()
      note = key |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
      path = "Zithers/Psaltery, Bowed and Plucked/#{way}/BowedPsaltery_#{name}.wav"
      {vcsl.(path), note: pitch(note) + 12}
    end
  end

  @plucked psaltery.(
             "Pluck",
             ~w(A#3_Main_Pluck_rr1 C4_Main_Pluck_rr1 D4_Main_Pluck_rr1 E4_Main_Pluck_rr2 F#4_Main_Pluck_rr1 G#4_Main_Pluck_rr3 A#4_Main_Pluck_rr1 C5_Main_Pluck_rr1 D5_Main_Pluck_rr1 E5_Main_Pluck_rr1 F#5_Main_Pluck_rr3)
           )
  @bowed psaltery.(
           "LongBow",
           ~w(A#3_Main_LongBow_rr2 C4_Main_LongBow_rr1 D4_Main_LongBow_rr1 E4_Main_LongBow_rr2 F#4_Main_LongBow_rr1 G#4_Main_LongBow_rr1 A#4_Main_LongBow_rr2 C5_Main_LongBow_rr1 D5_Main_LongBow_rr2 E5_Main_LongBow_rr2 F#5_Main_LongBow_rr2)
         )

  @room [room: 0.7, mix: 0.22]
  @ringing [sustain: 2, release: 1.5]

  part :concert_harp,
    synth: sampled(@concert_harp),
    defaults: @ringing,
    fx: [level: [amp: 1.5], reverb: @room, pan: [pan: -0.2]]

  part :folk_harp,
    synth: sampled(@folk_harp),
    defaults: @ringing,
    fx: [level: [amp: 1.4], reverb: @room, pan: [pan: 0.2]]

  part :strumstick,
    synth: sampled(@strumstick),
    defaults: [sustain: 1, release: 0.6],
    fx: [level: [amp: 1.2], reverb: @room, pan: [pan: -0.4]]

  part :plucked,
    synth: sampled(@plucked),
    defaults: @ringing,
    fx: [level: [amp: 2.6], reverb: @room, pan: [pan: 0.4]]

  part :bowed,
    synth: sampled(@bowed),
    defaults: [attack: 0.05, release: 0.6],
    fx: [level: [amp: 4.5], reverb: [room: 0.8, mix: 0.35], pan: [pan: 0.4]]

  # An eighth note; a bar is six, and two beats.
  @eighth 1 / 3

  # The first half of the first strain, the half that ends both strains, and the first half of the
  # second, as notes and their lengths in eighths.
  @opening [
    d5: 2,
    cs5: 1,
    b4: 1,
    cs5: 1,
    d5: 1,
    a4: 2,
    g4: 1,
    fs4: 1,
    e4: 1,
    d4: 1,
    g4: 2,
    e4: 1,
    fs4: 1,
    g4: 1,
    a4: 1,
    cs4: 2,
    d4: 1,
    e4: 2,
    cs5: 1
  ]
  @closing [
    d5: 2,
    cs5: 1,
    b4: 1,
    cs5: 1,
    d5: 1,
    a4: 2,
    g4: 1,
    fs4: 1,
    e4: 1,
    d4: 1,
    g4: 2,
    e4: 1,
    fs4: 1,
    g4: 1,
    a4: 1,
    d4: 2,
    cs4: 1,
    d4: 2
  ]
  @turn [
    d5: 1.5,
    e5: 0.5,
    d5: 1,
    d5: 2,
    d5: 1,
    e5: 2,
    e5: 1,
    e5: 1,
    cs5: 1,
    a4: 1,
    a4: 0.5,
    fs5: 1.5,
    fs5: 1,
    e5: 2,
    d5: 1,
    d5: 1,
    cs5: 1,
    b4: 1,
    a4: 1,
    b4: 1,
    cs5: 1
  ]

  # Each strain's chords, a bar to each, ga a bar of G and then A.
  @chords %{first: ~w(d d g a d d ga d)a, second: ~w(d a d a d d ga d)a}

  @lead_in [a4: 1]

  # The left hand: the chord's lowest note on the first beat and two above it on the second.
  @left %{d: {:d3, [:fs3, :a3]}, g: {:g2, [:d3, :g3]}, a: {:a2, [:e3, :a3]}}

  # The chords broken into eighths, up and down.
  @broken %{
    d: ~w(d3 a3 d4 fs4 d4 a3)a,
    g: ~w(g2 d3 g3 b3 g3 d3)a,
    a: ~w(a2 e3 a3 cs4 a3 e3)a,
    ga: ~w(g2 d3 g3 a2 e3 a3)a
  }

  # The strumstick: down on each beat and back up before the next, over its open low D.
  @strummed %{d: [:d3, :a3, :fs4], g: [:d3, :g3, :b3], a: [:e3, :a3, :cs4]}

  # The lead-in takes the last eighth of a bar of two beats, and each time through is 64 beats.
  def song do
    wait = 2 - @eighth
    left = left()

    together([
      part(
        :concert_harp,
        early(
          seq([
            rest(wait),
            together([tune(), left]),
            broken(),
            note([:d2, :a2, :d3, :fs3, :a3, :d4], 6, strum: 0.07, sustain: 6, release: 3)
          ])
        )
      ),
      part(
        :folk_harp,
        seq([
          rest(wait + 64),
          tune(),
          note([:d4, :fs4, :a4, :d5], 6, strum: 0.07, sustain: 6, release: 3)
        ])
      ),
      part(
        :strumstick,
        seq([
          rest(wait + 64),
          strums(),
          note([:d3, :a3, :d4, :fs4], 6, strum: 0.05, sustain: 6, release: 3)
        ])
      ),
      part(
        :plucked,
        seq([
          rest(wait + 64),
          transpose(seq([line(@lead_in), strain(:first), line(@lead_in), strain(:first)]), 12),
          rest(@eighth + 32),
          note(:d6, 6, sustain: 6, release: 3)
        ])
      ),
      part(:bowed, seq([rest(2 + 64 + 32), long_notes(), note(:fs5, 6, sustain: 5, release: 2)]))
    ])
  end

  defp left do
    bars =
      for name <- [:first, :first, :second, :second], chord <- @chords[name] do
        case chord do
          :ga ->
            seq([note(:g2, 1, amp: 2.0), note(:a2, 1, amp: 2.0)])

          chord ->
            {low, pair} = @left[chord]
            seq([note(low, 1, amp: 2.0), note(pair, 1, amp: 1.4)])
        end
      end

    seq([rest(@eighth) | bars])
  end

  # The concert harp's notes start late in their files, so it plays 0.06 beats early.
  defp early(music), do: Mx.swing(music, &(&1 - 0.06))

  # The tune once through, each strain twice, an A before each and none after the last.
  defp tune do
    strains = [:first, :first, :second, :second]

    seq([
      line(@lead_in),
      Enum.map(strains, &strain/1) |> Enum.intersperse(line(@lead_in)) |> seq(),
      rest(@eighth)
    ])
  end

  defp broken do
    bars =
      for name <- [:first, :first, :second, :second], chord <- @chords[name] do
        seq(for name <- @broken[chord], do: note(name, @eighth, amp: 0.7))
      end

    seq(bars)
  end

  defp strums do
    strum = fn chord ->
      notes = @strummed[chord]

      seq([
        note(notes, 2 * @eighth, strum: 0.03),
        note(Enum.reverse(notes), @eighth, strum: 0.02, amp: 0.5)
      ])
    end

    bars =
      for name <- [:first, :first, :second, :second], chord <- @chords[name] do
        case chord do
          :ga -> seq([strum.(:g), strum.(:a)])
          chord -> seq([strum.(chord), strum.(chord)])
        end
      end

    seq([rest(@eighth) | bars])
  end

  defp line(steps) do
    seq(
      for {name, eighths} <- steps,
          do: if(name == :r, do: rest(eighths * @eighth), else: note(name, eighths * @eighth))
    )
  end

  # A strain of the tune: its eight bars, less the last eighth, where the A that leads into the
  # next strain goes.
  defp strain(:first), do: line(@opening ++ @closing)
  defp strain(:second), do: line(@turn ++ @closing)

  # The bowed psaltery in the second strain: a long note to each bar.
  defp long_notes do
    notes = %{d: [:fs5, 2], a: [:e5, 2], g: [:g5, 2], ga: [:g5, 1, :e5, 1]}

    bars =
      for _ <- 1..2, chord <- @chords.second do
        seq(for [name, beats] <- Enum.chunk_every(notes[chord], 2), do: note(name, beats))
      end

    seq(bars)
  end
end
