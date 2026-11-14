# Seven Strokes, a piece for the mallet instruments of VCSL, Versilian Studios' Versilian
# Community Sample Library, under Creative Commons 0: marimba, vibraphone struck and bowed,
# glockenspiel, hand chimes and tubular bells, with its finger cymbals, suspended cymbal, gong and
# wind chimes.
# It is written as music for mallet ensembles often is, as a steady pulse of twelve to the bar
# that the players share.
# The marimba plays the seven strokes of the bell pattern of West African music, added one to a
# bar until all seven are there, and the vibraphone plays the five pulses the marimba leaves
# empty, so that between them every pulse sounds.
# Under them the chords change every two bars, D, B minor, G and A, and each time round another
# instrument joins: the bowed vibraphone, then the glockenspiel and the hand chimes, then the
# tubular bells.
# VCSL names each key an octave below the pitch mx names it by, and records its instruments at
# very different levels, so each part is brought to its place by its own level.
# Download them with mx samples download
# "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones".
defmodule SevenStrokes do
  use Mx.Song, tempo: 100

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
  @struck "Idiophones/Struck Idiophones"

  vcsl = fn path -> {:github, @repo, @commit, "#{@struck}/#{path}"} end

  key = fn name ->
    name = name |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
    pitch(name) + 12
  end

  @marimba for name <- ~w(F1 C2 G2 B2 F3 C4 G4 B4 F5 C6),
               do: {vcsl.("Marimba/Marimba_hit_Outrigger_#{name}_loud_01.wav"), note: key.(name)}
  @vibes for name <- ~w(F2 A2 C3 E3 G3 B3 D4 F4 A4 C5 E5),
             do:
               {vcsl.("Vibraphone/Soft Mallets/Vibes_soft_#{name}_v2_rr1_Main.wav"),
                note: key.(name)}
  @bowed for name <- ~w(E3 G3 D4 A4 E5),
             do: {vcsl.("Vibraphone/Bowed/Vibes_bowed_#{name}_rr1_Main.wav"), note: key.(name)}
  @glock for name <- ~w(G4 C5 G5 C6 G6 C7),
             do: {vcsl.("Glockenspiel/glock_medium_#{name}_01.wav"), note: key.(name)}
  @chimes for name <- ~w(C3 D3 E3 F#3 G#3 A#3 C4 D4 E4 F#4 G#4 A4 C5 D5 E5 F#5 G#5 A#5 C6),
              do: {vcsl.("Hand Chimes/sus_#{name}_r01_main.wav"), note: key.(name)}
  @bells for {name, take} <- [
               {"C3_f_rr1", 48},
               {"D3_ff_rr1", 50},
               {"E3_ff_rr2", 52},
               {"G#3_ff_rr1", 56},
               {"A#3_ff_rr1", 58},
               {"C4_ff_rr2", 60},
               {"D4_ff_rr2", 62},
               {"E4_ff_rr2", 64}
             ],
             do: {vcsl.("Tubular Bells 1/chimes_#{name}.wav"), note: take + 12}

  @finger_cymbals vcsl.("Finger Cymbals/Fing_Cymb.wav")
  @swell vcsl.("Suspended Cymbal 1/susCymb1_cresc_4s.wav")
  @gong vcsl.("Gong 1/gong_mf.wav")
  @wind_chimes vcsl.("Mark Trees/Legacy/windchimes_slowDesc1.wav")

  part :marimba,
    synth: sampled(@marimba),
    defaults: [sustain: 1, release: 1],
    fx: [level: [amp: 3.0], reverb: [room: 0.6, mix: 0.2], pan: [pan: -0.35]]

  part :bass,
    synth: sampled(@marimba),
    defaults: [sustain: 2, release: 1],
    fx: [level: [amp: 3.2], reverb: [room: 0.6, mix: 0.15]]

  part :vibes,
    synth: sampled(@vibes),
    defaults: [sustain: 2, release: 2],
    fx: [level: [amp: 1.0], reverb: [room: 0.6, mix: 0.2], pan: [pan: 0.35]]

  part :bowed,
    synth: sampled(@bowed),
    defaults: [sustain: 9, release: 3],
    fx: [level: [amp: 5.0], reverb: [room: 0.8, mix: 0.4]]

  part :glock,
    synth: sampled(@glock),
    defaults: [sustain: 4, release: 3],
    fx: [level: [amp: 8.0], reverb: [room: 0.7, mix: 0.3], pan: [pan: 0.15]]

  part :chimes,
    synth: sampled(@chimes),
    defaults: [sustain: 6, release: 3],
    fx: [level: [amp: 1.5], reverb: [room: 0.7, mix: 0.3], pan: [pan: -0.15]]

  part :bells,
    synth: sampled(@bells),
    defaults: [sustain: 8, release: 4],
    fx: [level: [amp: 0.5], reverb: [room: 0.8, mix: 0.3]]

  part :metal, fx: [reverb: [room: 0.8, mix: 0.3]]

  @pulse 1 / 3

  # The marimba's seven pulses of twelve, and the five between them.
  @seven [0, 2, 4, 5, 7, 9, 11]
  @five [1, 3, 6, 8, 10]

  # Each chord: the bass, the marimba's notes, the vibraphone's, the bowed pair, the
  # glockenspiel's two notes, the hand chime and the bell.
  @chords [
    %{
      bass: :d3,
      marimba: [:d4, :a4, :e5, :fs5],
      vibes: [:fs4, :a4, :d5, :e5],
      bowed: [:d5, :a5],
      glock: [:a6, :fs6],
      chime: :e5,
      bell: :d4
    },
    %{
      bass: :b2,
      marimba: [:b3, :fs4, :d5, :fs5],
      vibes: [:fs4, :b4, :d5, :a4],
      bowed: [:d5, :fs5],
      glock: [:d6, :fs6],
      chime: :fs5,
      bell: :b4
    },
    %{
      bass: :g2,
      marimba: [:g4, :b4, :d5, :fs5],
      vibes: [:b4, :d5, :fs5, :g5],
      bowed: [:g4, :d5],
      glock: [:b6, :a6],
      chime: :d5,
      bell: :g4
    },
    %{
      bass: :a2,
      marimba: [:a4, :cs5, :e5, :b4],
      vibes: [:a4, :b4, :cs5, :e5],
      bowed: [:e5, :a5],
      glock: [:e6, :cs7],
      chime: :e5,
      bell: :a4
    }
  ]

  def song do
    seq([
      play(marimba: marimba(true), bass: bass(), bells: seq([note(:d4, 8), rest(24)])),
      play(marimba: marimba(), bass: bass(), vibes: vibes(), bowed: bowed()),
      play(
        marimba: marimba(),
        bass: bass(),
        vibes: vibes(),
        bowed: bowed(),
        glock: glock(),
        chimes: chimes(),
        metal: metal()
      ),
      play(
        marimba: marimba(),
        bass: bass(),
        vibes: vibes(),
        bowed: bowed(),
        glock: glock(),
        chimes: chimes(),
        bells: bells()
      ),
      play(
        vibes: note([:d4, :a4, :d5, :e5, :fs5], 16, strum: 0.1, sustain: 12, release: 4),
        bass: note(:d3, 16),
        glock: note(:d7, 16),
        bells: note(:d4, 16),
        metal:
          together([
            sample(@gong, 16, amp: 1.2, sustain: 12, release: 4),
            sample(@wind_chimes, 16, amp: 0.4)
          ])
      )
    ])
  end

  defp play(voices) do
    together(for {name, music} <- voices, do: part(name, music))
  end

  # The marimba through the chords; when growing, each bar of the eight has one stroke more until
  # all seven play.
  defp marimba(growing \\ false) do
    seq(
      for {chord, index} <- Enum.with_index(@chords), half <- 0..1 do
        count = if growing, do: min(index * 2 + half + 1, 7), else: 7
        bar(Enum.take(@seven, count), chord.marimba)
      end
    )
  end

  defp bass do
    seq(
      for chord <- @chords, _ <- 1..2 do
        seq([
          note(chord.bass, 2),
          note(pitch(chord.bass) + 7, 1, amp: 0.6),
          note(chord.bass, 1, amp: 0.7)
        ])
      end
    )
  end

  defp vibes, do: seq(for chord <- @chords, _ <- 1..2, do: bar(@five, chord.vibes))

  defp bowed, do: seq(for chord <- @chords, do: note(chord.bowed, 8))

  # The glockenspiel: a note at the start of each bar.
  defp glock do
    seq(for %{glock: [first, second]} <- @chords, do: seq([note(first, 4), note(second, 4)]))
  end

  # A hand chime in each chord's second bar, a beat in.
  defp chimes do
    seq(for chord <- @chords, do: seq([rest(5), note(chord.chime, 3)]))
  end

  # The finger cymbals every two bars, and the cymbal's four seconds of swell ending with the
  # eight bars.
  defp metal do
    together([
      repeat(sample(@finger_cymbals, 8, amp: 8), 4),
      seq([rest(32 - 6.7), sample(@swell, 6.7, amp: 0.5)])
    ])
  end

  defp bells, do: seq(for chord <- @chords, do: note(chord.bell, 8))

  # A bar of strokes at the pulses given, going round the notes, the first pulse of the bar the
  # strong one.
  defp bar(pulses, notes) do
    strokes =
      for {pulse, index} <- Enum.with_index(pulses) do
        name = Enum.at(notes, rem(index, length(notes)))
        {pulse * @pulse, note(name, @pulse, amp: if(pulse == 0, do: 1.0, else: 0.7))}
      end

    at(strokes, 4)
  end
end
