defmodule ColdFront.Synths do
  @moduledoc "The synth written for Cold Front: its 808 bass."

  use Mx.Instrument

  @doc "An 808 bass: a sine that drops onto its note, with overtones, and fades by itself."
  attr :note, :note, default: 29, doc: "The pitch, which a change glides."
  attr :vel, :float, default: 0.8, range: 0..1, doc: "How hard it is struck."
  attr :drive, :float, default: 0.5, range: 0..1, doc: "How loud its overtones are."
  attr :fade, :float, default: 1.6, range: 0.05..10, doc: "The seconds it takes to fade."
  envelope_attrs sustain: 1, release: 0.08

  defsynth sub808(played) do
    pitch = hz(follow(played.note)) * 2 ** envelope([{0, 2.2}, {0.045, 0, -4}])

    overtones =
      for {harmonic, level} <- [{2, 0.35}, {3, 0.22}, {5, 0.08}] do
        gain(sine(hz: pitch * harmonic), level * played.drive)
      end

    click =
      noise(:white)
      |> lowpass(hz: 3000, q: 0.7)
      |> perc(attack: 0.0005, release: 0.012)
      |> gain(0.25 * played.vel)

    body =
      mix([sine(hz: pitch) | overtones])
      |> envelope([{0.002, 1}, {played.fade, 0, -3}])
      |> gain(0.5 * played.vel)

    note_envelope(body + click, played)
  end
end

defmodule ColdFront do
  @moduledoc """
  Cold Front, a trap beat in F minor at 140 bpm, written for mx and not transcribed from any
  record.
  The drums are trap's: the clap on beat three of every bar, so the bar feels half as fast,
  hi-hats in eighths that break into rolls of sixteenth triplets and thirty-seconds whose pitch
  bends, and a kick under every note of the 808.
  The 808 is a synth written in this file: a sine that drops onto its note as it is struck, with
  overtones a small speaker can carry, which glides from note to note where its line slides.
  The tune goes round four bars, F minor twice, D flat and C, on recordings from the Versilian
  Community Sample Library, under Creative Commons 0: the Knight upright piano breaks the chords,
  the ocarina plays the hook, the dan tranh is plucked in the verse, the bowed psaltery holds the
  chords far below the notes it was recorded on, and the tubular bells toll in the last hook with
  mx's timpani.
  The drums are mx's measured kit, with the claves, the glockenspiel is mx's too, and the vinyl
  hiss is Sonic Pi's.
  The desk opens and shuts a low-pass filter over the piano, crushes it in the bridge, gates the
  psaltery with a slicer in the verse, and opens filtered noise into each drop.
  """

  use Mx.Song, tempo: 140

  # A sampled instrument from a folder of VCSL, which names each key an octave below the pitch mx
  # names it by.
  keys = fn folder, prefix, suffix, names ->
    sampled(
      for name <- names do
        key = name |> String.split("_") |> hd()
        note = key |> String.downcase() |> String.replace("#", "s") |> pitch()
        path = "#{folder}/#{prefix}#{name}#{suffix}.wav"

        {{:vcsl, path}, note: pitch(note) + 12}
      end
    )
  end

  @room [reverb: [decay_seconds: 2.3, damp: 0.6, mix: 0.3]]

  player = for octave <- 1..4, key <- ~w(C# D# F G A B), do: "#{key}#{octave}"

  @piano keys.(
           "Chordophones/Zithers/Upright Piano, Knight/Sustains",
           "Player_vl2_rr1_",
           "",
           ~w(A0 B0) ++ player ++ ~w(C#5 D#5 F5)
         )

  @ocarina keys.(
             "Aerophones/Edge-blown Aerophones/Ocarina, Typical/Sustains/Sus",
             "StdOcarina_Sus_",
             "",
             ~w(A3 B3 C#4 D4 E4 F#4 G#4 A4 A#4 C5 C#5)
           )

  @dan_tranh keys.(
               "Chordophones/Zithers/Dan Tranh/Normal",
               "",
               "_ff_1",
               ~w(B1 C#2 D#2 F#2 G#2 B2 C#3 D#3 F#3 G#3 B3 C#4 D#4 F#4 G#4 B4)
             )

  @psaltery keys.(
              "Chordophones/Zithers/Psaltery, Bowed and Plucked/LongBow",
              "BowedPsaltery_",
              "",
              ~w(A#3_Main_LongBow_rr2 C4_Main_LongBow_rr1 D4_Main_LongBow_rr1 E4_Main_LongBow_rr2 F#4_Main_LongBow_rr1 G#4_Main_LongBow_rr1 A#4_Main_LongBow_rr2 C5_Main_LongBow_rr1)
            )

  @tubular_bells keys.(
                   "Idiophones/Struck Idiophones/Tubular Bells 1",
                   "chimes_",
                   "",
                   ~w(C3_f_rr1 D3_ff_rr1 E3_ff_rr2 G#3_ff_rr1 A#3_ff_rr1 C4_ff_rr2 D4_ff_rr2 E4_ff_rr2)
                 )

  part :kick, synth: :kick, defaults: [vel: 0.8], fx: [level: [amp: 0.21]]

  part :sub,
    synth: :sub808,
    defaults: [drive: 0.6],
    fx: [distortion: [distort: 0.55, mix: 0.4], level: [amp: 0.31]]

  part :clap, synth: :clap, fx: [level: [amp: 1.6], reverb: [decay_seconds: 1.5, mix: 0.2]]

  part :snare,
    synth: :snare,
    defaults: [vel: 0.75],
    fx: [level: [amp: 2.0], reverb: [decay_seconds: 1.5, mix: 0.2]]

  part :hats,
    synth: :closed_hihat,
    defaults: [vel: 0.7],
    fx: [level: [amp: 1.25], pan: [pan: 0.2]]

  part :open_hat,
    synth: :open_hihat,
    defaults: [vel: 0.7, sustain: 0.4, release: 0.2],
    fx: [level: [amp: 1.25], pan: [pan: -0.25]]

  part :rim,
    synth: :clave,
    fx: [
      level: [amp: 1.0],
      ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.3],
      reverb: [decay_seconds: 1.5, mix: 0.2]
    ]

  part :cymbals,
    synth: :crash,
    defaults: [vel: 0.7, sustain: 4, release: 3],
    fx: [level: [amp: 1.3], reverb: [decay_seconds: 2.3, mix: 0.3]]

  part :hiss, fx: [level: [amp: 0.5]]

  part :riser,
    synth: :noise,
    defaults: [res: 0.5],
    fx: [level: [amp: 0.16], reverb: [decay_seconds: 3.2, mix: 0.4]]

  part :piano,
    synth: @piano,
    defaults: [amp: 1.2, release: 0.4],
    fx: [
      bitcrusher: [bits: 9, sample_rate: 11_000, mix: 0],
      lpf: [cutoff: 118],
      reverb: [decay_seconds: 3.2, damp: 0.5, mix: 0.35]
    ]

  part :glock,
    synth: :glockenspiel,
    defaults: [vel: 0.45, amp: 2.0, sustain: 2, release: 1.5],
    fx: [ping_pong: [phase: 0.75, feedback: 0.5, mix: 0.4]] ++ @room

  part :lead,
    synth: @ocarina,
    defaults: [amp: 0.5, attack: 0.02, release: 0.15],
    fx: [echo: [phase: 0.75, decay: 3, mix: 0.25], reverb: [decay_seconds: 3.2, mix: 0.35]]

  part :plucks,
    synth: @dan_tranh,
    defaults: [amp: 1.0, release: 0.6, pan: -0.3],
    fx: [echo: [phase: 0.375, decay: 1.5, mix: 0.2]] ++ @room

  part :pad,
    synth: @psaltery,
    defaults: [amp: 3, attack: 0.5, release: 1.5],
    fx: [
      slicer: [phase: 0.25, pulse_width: 0.6, smooth_ms: 10, mix: 0],
      lpf: [cutoff: 95],
      reverb: [decay_seconds: 5.1, mix: 0.4]
    ]

  part :bells, synth: @tubular_bells, defaults: [amp: 0.3, release: 2], fx: @room

  part :timpani,
    synth: :timpani,
    defaults: [vel: 0.8, amp: 1.3, sustain: 1.5, release: 1],
    fx: @room

  def song do
    seq([
      intro(),
      groove(false),
      hook(false),
      verse(),
      bridge(),
      groove(true),
      hook(true),
      outro()
    ])
  end

  # The piano behind a closed filter that opens, the psaltery and the hiss, and and a roll and
  # rising noise into the hook.
  defp intro do
    together([
      part(
        :piano,
        together([
          motif(2),
          desk(:piano, [{0, :lpf, [cutoff: 68]}, {0, :lpf, [cutoff: 118, cutoff_slide: 30]}], 32)
        ])
      ),
      part(:pad, together([pad(2), desk(:pad, [{0, :slicer, [mix: 0]}], 32)])),
      part(:hiss, hiss(32)),
      part(:hats, delay(hats(["x.x.x.x.", "x.x.x.xt", "x.x.x.x.", "x.xdx.sr"]), 16)),
      part(:snare, roll(32)),
      part(:riser, delay(riser(8), 24))
    ])
  end

  # Everything but the lead, over the plain 808; in the last one the bells and the timpani toll.
  defp groove(last?) do
    ending = if last?, do: toll(2), else: []

    together(
      [
        part(:cymbals, cymbal(4)),
        part(:kick, kick(:plain, 2)),
        part(:sub, bass(:plain, 2)),
        part(:clap, clap(8)),
        part(:snare, snare(8)),
        part(:rim, rim(8)),
        part(:hats, hats(plain_hats() ++ busy_hats())),
        part(:open_hat, open_hat([~MX"....|....|....|...."s, ~MX"....|....|....|..7."s], 4)),
        part(
          :piano,
          together([
            motif(2),
            desk(:piano, [{0, :lpf, [cutoff: 118]}, {0, :bitcrusher, [mix: 0]}], 32)
          ])
        ),
        part(:glock, glock(2)),
        part(:pad, together([pad(2), desk(:pad, [{0, :slicer, [mix: 0]}], 32)]))
      ] ++ ending
    )
  end

  # The lead's hook over the busier 808, and the piano an octave up in the last one.
  defp hook(last?) do
    ending = if last?, do: toll(2), else: [part(:riser, delay(riser(8), 24))]

    together(
      [
        part(:cymbals, cymbal(4)),
        part(:kick, kick(:busy, 2)),
        part(:sub, bass(:busy, 2)),
        part(:clap, clap(8)),
        part(:snare, snare(8)),
        part(:rim, rim(8)),
        part(:hats, hats(busy_hats() ++ busy_hats())),
        part(:open_hat, open_hat(~MX"....|....|....|..7."s, 8)),
        part(:piano, motif(2, if(last?, do: 12, else: 0))),
        part(:glock, glock(2)),
        part(:pad, pad(2)),
        part(:lead, lead(hook_phrases()))
      ] ++ ending
    )
  end

  # The piano out: the psaltery cut into sixteenths by the slicer, the dan tranh plucked, the
  # lead's calls, and the hats leaving gaps.
  defp verse do
    together([
      part(:kick, kick(:plain, 2)),
      part(:sub, bass(:plain, 2)),
      part(:clap, clap(8)),
      part(:snare, snare(8)),
      part(:rim, rim(8)),
      part(:hats, hats(verse_hats() ++ verse_hats())),
      part(
        :pad,
        together([pad(2), desk(:pad, [{0, :slicer, [mix: 1]}, {0, :lpf, [cutoff: 105]}], 32)])
      ),
      part(:plucks, plucks(2)),
      part(:lead, lead(calls()))
    ])
  end

  # The drums stop: the piano crushed behind a filter that opens again, the hiss, noise rising and
  # a roll.
  defp bridge do
    together([
      part(
        :piano,
        together([
          motif(1),
          desk(
            :piano,
            [
              {0, :bitcrusher, [mix: 0.7]},
              {0, :lpf, [cutoff: 74]},
              {0, :lpf, [cutoff: 112, cutoff_slide: 15]},
              {12, :bitcrusher, [mix: 0, mix_slide: 3.5]}
            ],
            16
          )
        ])
      ),
      part(
        :pad,
        together([pad(1), desk(:pad, [{0, :slicer, [mix: 0]}, {0, :lpf, [cutoff: 95]}], 16)])
      ),
      part(:hiss, hiss(16)),
      part(:riser, riser(16)),
      part(:snare, roll(16))
    ])
  end

  # The piano alone behind the closing filter, and an 808 that falls an octave as it fades.
  defp outro do
    last = note([:f2, :f3, :c4, :f4, :ab4], 8, sustain: 6, amp: 0.7)

    together([
      part(:cymbals, cymbal(4)),
      part(
        :piano,
        together([
          seq([motif(1), last]),
          desk(:piano, [{0, :lpf, [cutoff: 118]}, {0, :lpf, [cutoff: 76, cutoff_slide: 16]}], 24)
        ])
      ),
      part(:pad, pad(1)),
      part(:hiss, hiss(24)),
      part(
        :sub,
        note(:f1, 16, sustain: 6, fade: 5, changes: [{2, note: pitch(:f0), note_slide: 5}])
      )
    ])
  end

  # The piano's four bars in sixteenths: each chord broken in groups of three, three, four, three
  # and three, with its root held below.
  # Each note rings 0.7 beats, and the last of a bar until the bar ends; up raises the right hand.
  defp motif(rounds, up \\ 0) do
    right = [
      ~MX"c5:3 ab4:3 f4:4 c5:3 ab4:3",
      ~MX"g4:3 f4:3 g4:4 ab4:6",
      ~MX"db5:3 ab4:3 f4:4 db5:3 ab4:3",
      ~MX"c5:3 g4:3 e4:4 g4:3 bb4:3"
    ]

    held = fn step, steps ->
      [sustain: if(rem(step + steps, 16) == 0, do: steps / 4, else: 0.7)]
    end

    left = steps(~MX"f2/f3 f2/f3 db2/db3 c2/c3", 4, sustain: 3.8, amp: 0.6)
    repeat(together([left, transpose(steps(right, 0.25, each: held), up)]), rounds)
  end

  # The desk: changes to a part's effects at beats of a section.
  defp desk(name, changes, beats) do
    changes = for {beat, target, opts} <- changes, do: {beat, change({name, target}, opts)}
    at(changes, beats)
  end

  defp pad(rounds) do
    repeat(
      steps(~MX"f3/ab3/c4/f4 f3/ab3/c4/f4 db3/f3/ab3/db4 c3/e3/g3/c4", 4, sustain: 3),
      rounds
    )
  end

  defp hiss(beats) do
    repeat(sample({:sonic_pi, :vinyl_hiss}, 8, attack: 0.5, release: 0.5), div(beats, 8))
  end

  # What an eighth of the hi-hat holds: how many strokes, and how many semitones the first and the
  # last are tuned up.
  # Bars of the hi-hat in eighths, a character to each: x one stroke, d two, t a triplet, r four
  # that rise in pitch, s six that fall, and a dot silence.
  # The strokes on the beat are the loudest, and a roll grows towards the next eighth.
  defp hats(patterns) do
    rolls = %{
      "x" => {1, 0, 0},
      "d" => {2, 0, 0},
      "t" => {3, 0, 0},
      "r" => {4, 0, 4},
      "s" => {6, 3, -4}
    }

    patterns
    |> List.wrap()
    |> seq(fn pattern ->
      cells = pattern |> String.replace(" ", "") |> String.graphemes()

      hits =
        for {cell, eighth} <- Enum.with_index(cells),
            cell != ".",
            {count, first, last} = rolls[cell],
            stroke <- 0..(count - 1) do
          along = if count == 1, do: 1.0, else: stroke / (count - 1)
          level = if rem(eighth, 2) == 0, do: 1.0, else: 0.6
          amp = if count == 1, do: level, else: 0.45 + 0.5 * along
          note = 92 + first + (last - first) * along
          {(eighth + stroke / count) / 2, hit(amp: amp, note: note)}
        end

      at(hits, length(cells) / 2)
    end)
  end

  # A snare roll over the last bar of so many beats: eighths, sixteenths, then thirty-seconds,
  # growing.
  defp roll(beats) do
    louder = fn step -> [vel: 0.3 + 0.15 * (step / 8), amp: 0.25 + 0.1 * (step / 8)] end
    delay(steps(~MX"x...x...x...x...|x.x.x.x.|xxxxxxxx"s, 0.125, each: louder), beats - 4)
  end

  # Filtered noise that opens up over so many beats.
  defp riser(beats) do
    note(:c4, beats,
      cutoff: 70,
      attack: beats - 0.5,
      sustain: 0,
      release: 0.5,
      changes: [{0, cutoff: 128, cutoff_slide: beats}]
    )
  end

  defp cymbal(beats), do: seq([hit(), rest(beats)])

  # The kick strikes with every note of the 808, softer where two come a sixteenth or two apart.
  defp kick(:plain, rounds) do
    kick(
      [
        ~MX"K.....K...K....."s,
        ~MX"K..K......K...k."s,
        ~MX"K.....K...K....."s,
        ~MX"K..K.....K..k.k."s
      ],
      rounds
    )
  end

  defp kick(:busy, rounds) do
    kick(
      [
        ~MX"K.....K...K....."s,
        ~MX"K..K..K...K...k."s,
        ~MX"K.....K...K..K.."s,
        ~MX"K..K....k.k.k.k."s
      ],
      rounds
    )
  end

  defp kick(bars, rounds) do
    repeat(steps(bars, 0.25, strokes: [K: [amp: 1.0], k: [amp: 0.7]]), rounds)
  end

  # The 808's four bars in sixteenths: a word after ~ is the note it glides to, starting that many
  # sixteenths into the note.
  # Each note stops a little before its length is up.
  defp bass(:plain, rounds) do
    bass(
      [
        ~MX"f1:6 f1:4 f1:6",
        ~MX"f1:3 f1:7 f1:4 f1:0.4 ~f2:1.6",
        ~MX"db2:6 db2:4 db2:6",
        ~MX"c2:3 c2:6 c2:3 c2:2 c2:0.4 ~c3:1.6"
      ],
      rounds
    )
  end

  # The busier line of the hook, which climbs through the chord's notes and slides down an octave
  # into the next round.
  defp bass(:busy, rounds) do
    bass(
      [
        ~MX"f1:6 f1:4 f1:6",
        ~MX"f1:3 ab1:3 f1:4 c2:2 ~f2:2 f2:0.4 ~db2:1.6",
        ~MX"db2:6 db2:4 ab1:3 db2:3",
        ~MX"c2:3 c2:5 g1:2 c2:2 e2:2 g2:0.4 ~f1:1.6"
      ],
      rounds
    )
  end

  defp bass(bars, rounds) do
    short = fn _step, steps -> [sustain: steps / 4 - 0.05] end
    repeat(steps(bars, 0.25, slide: 0.3, each: short), rounds)
  end

  # The clap on three, over a snare, and the claves between the kicks.
  defp clap(bars), do: repeat(steps(~MX"....|....|9...|...."s, 0.25, digit: :amp), bars)

  defp snare(bars) do
    repeat(
      steps([~MX"....|....|6...|...."s, ~MX"....|....|6...|..3."s], 0.25, digit: :amp),
      div(bars, 2)
    )
  end

  defp rim(bars) do
    repeat(
      steps([~MX"...7|....|....|..5."s, ~MX"....|..7.|...5|...."s], 0.25, digit: :amp),
      div(bars, 2)
    )
  end

  defp open_hat(bars, rounds), do: repeat(steps(bars, 0.25, digit: :amp), rounds)

  # The glockenspiel answers in the second and fourth bars, a sixteenth to a step.
  defp glock(rounds) do
    bars = [~MX"_:16", ~MX"_:10 c7:2 ab6:2 f6:2", ~MX"_:16", ~MX"c7:3 bb6:3 g6:4 e6:6"]
    repeat(steps(bars, 0.25), rounds)
  end

  # The tubular bells toll each chord's root and fifth on one, and the timpani strikes the root
  # and leads into the next on the and of four, softer.
  defp toll(rounds) do
    loud = fn step -> [vel: if(rem(step, 8) == 0, do: 0.9, else: 0.5)] end

    [
      part(:bells, repeat(steps(~MX"f4/c5 f4/c5 db4/ab4 c4/g4", 4, sustain: 3), rounds)),
      part(
        :timpani,
        repeat(steps(~MX"f2:7 f2 f2:7 f2 db3:7 db3 c3:7 c3", 0.5, each: loud), rounds)
      )
    ]
  end

  # The hook, eight bars for the lead: each phrase is its beat, the beats it lasts and its notes,
  # each at the beat it comes after the first and held until the next.
  defp hook_phrases do
    [
      {0.5, 3.2, [{0, :f5}, {0.5, :ab5}, {1, :f5}, {1.5, :eb5}, {2, :f5}]},
      {4.5, 3, [{0, :c5}, {0.5, :eb5}, {1, :f5}]},
      {8.5, 3.2, [{0, :ab5}, {0.5, :f5}, {1, :db5}, {1.5, :f5}]},
      {12.5, 3, [{0, :g5}, {0.5, :e5}, {1, :g5}, {1.5, :bb5}, {2, :g5}]},
      {16.5, 3.2, [{0, :f5}, {0.5, :ab5}, {1, :c6}, {1.5, :ab5}, {2, :f5}]},
      {20.5, 3, [{0, :eb5}, {0.5, :f5}, {1, :ab5}, {1.75, :f5}]},
      {24.5, 3.2, [{0, :ab5}, {0.5, :bb5}, {1, :db6}, {1.75, :ab5}]},
      {28.5, 3.2, [{0, :g5}, {0.5, :bb5}, {1, :c6}]}
    ]
  end

  defp lead(phrases) do
    notes =
      for {beat, held, steps} <- phrases,
          {{at, name}, index} <- Enum.with_index(steps) do
        ends = steps |> Enum.at(index + 1, {held, nil}) |> elem(0)
        {beat + at, note(name, 0, sustain: ends - at)}
      end

    at(notes, 32)
  end

  # The verse leaves the lead only the ends of its phrases, for the echo to carry.
  defp calls do
    [
      {6.5, 1.2, [{0, :eb5}, {0.5, :f5}]},
      {14.5, 1.2, [{0, :bb5}, {0.5, :g5}]},
      {22.5, 1.2, [{0, :ab5}, {0.5, :f5}]},
      {30, 1.7, [{0, :g5}, {0.5, :bb5}, {1, :c6}]}
    ]
  end

  # The dan tranh plucks each chord in eighths, low, fifth, octave and fifth.
  defp plucks(rounds) do
    bars = [
      ~MX"f3 c4 f4 c4 f3 c4 f4 ab4",
      ~MX"f3 c4 f4 c4 f3 c4 f4 ab4",
      ~MX"db3 ab3 db4 ab3 db3 ab3 db4 e4",
      ~MX"c3 g3 c4 g3 c3 g3 c4 eb4"
    ]

    repeat(steps(bars, 0.5, sustain: 0.2, release: 0.2), rounds)
  end

  defp plain_hats, do: ["xxxxxxxx", "xxxtxxxx", "xxxxxxxx", "xxxxxxtr"]
  defp busy_hats, do: ["xxxtxxxx", "xdxxxxrx", "xxtxxxxd", "xxxxtxss"]
  defp verse_hats, do: ["x.xxx.xt", "x.xxxdx.", "x.xtx.xx", "xdx.xxsr"]
end
