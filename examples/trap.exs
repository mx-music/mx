import Mx

# Cold Front, a trap beat in F minor at 140 bpm, written for mx and not transcribed from any record.
# The drums are trap's: the clap on beat three of every bar, so the bar feels half as fast, hi-hats in eighths that break into rolls of sixteenth triplets and thirty-seconds whose pitch bends, and a kick under every note of the 808.
# The 808 is a synth written in this file: a sine that drops onto its note as it is struck, with overtones a small speaker can carry, which glides from note to note where its line slides.
# The tune goes round four bars, F minor twice, D flat and C, on recordings from the Versilian Community Sample Library, under Creative Commons 0: the Knight upright piano breaks the chords, the ocarina plays the hook, the dan tranh is plucked in the verse, the bowed psaltery holds the chords far below the notes it was recorded on, and the tubular bells toll in the last hook with mx's timpani.
# The drums are mx's measured kit, with the claves, the glockenspiel is mx's too, and the vinyl hiss is Sonic Pi's.
# The desk opens and shuts a low-pass filter over the piano, crushes it in the bridge, gates the psaltery with a slicer in the verse, and opens filtered noise into each drop.
defmodule ColdFront.Synths do
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
        sine(hz: pitch * harmonic) |> gain(level * played.drive)
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

    (body + click) |> note_envelope(played)
  end
end

defmodule ColdFront do
  import Mx

  # A sampled instrument from a folder of VCSL, which names each key an octave below the pitch mx names it by.
  keys = fn folder, prefix, suffix, names ->
    sampled(
      for name <- names do
        key = name |> String.split("_") |> hd()
        note = key |> String.downcase() |> String.replace("#", "s") |> String.to_atom()
        path = "#{folder}/#{prefix}#{name}#{suffix}.wav"

        {{:github, "sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e", path},
         note: pitch(note) + 12}
      end
    )
  end

  @room [reverb: [room: 0.7, damp: 0.6, mix: 0.3]]

  @parts [
    kick: [synth: :kick, defaults: [vel: 0.8], fx: [level: [amp: 0.21]]],
    sub: [
      synth: :sub808,
      defaults: [drive: 0.6],
      fx: [distortion: [distort: 0.55, mix: 0.4], level: [amp: 0.31]]
    ],
    clap: [synth: :clap, fx: [level: [amp: 1.6], reverb: [room: 0.5, mix: 0.2]]],
    snare: [
      synth: :snare,
      defaults: [vel: 0.75],
      fx: [level: [amp: 2.0], reverb: [room: 0.5, mix: 0.2]]
    ],
    hats: [synth: :closed_hihat, defaults: [vel: 0.7], fx: [level: [amp: 1.25], pan: [pan: 0.2]]],
    open_hat: [
      synth: :open_hihat,
      defaults: [vel: 0.7, sustain: 0.4, release: 0.2],
      fx: [level: [amp: 1.25], pan: [pan: -0.25]]
    ],
    rim: [
      synth: :clave,
      fx: [
        level: [amp: 1.0],
        ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.3],
        reverb: [room: 0.5, mix: 0.2]
      ]
    ],
    cymbals: [
      synth: :crash,
      defaults: [vel: 0.7, sustain: 4, release: 3],
      fx: [level: [amp: 1.3], reverb: [room: 0.7, mix: 0.3]]
    ],
    hiss: [fx: [level: [amp: 0.5]]],
    riser: [
      synth: :noise,
      defaults: [res: 0.5],
      fx: [level: [amp: 0.16], reverb: [room: 0.8, mix: 0.4]]
    ],
    piano: [
      synth:
        keys.(
          "Chordophones/Zithers/Upright Piano, Knight/Sustains",
          "Player_vl2_rr1_",
          "",
          ~w(A0 B0) ++
            for(octave <- 1..4, key <- ~w(C# D# F G A B), do: "#{key}#{octave}") ++
            ~w(C#5 D#5 F5)
        ),
      defaults: [amp: 1.2, release: 0.4],
      fx: [
        bitcrusher: [bits: 9, sample_rate: 11_000, mix: 0],
        lpf: [cutoff: 118],
        reverb: [room: 0.8, damp: 0.5, mix: 0.35]
      ]
    ],
    glock: [
      synth: :glockenspiel,
      defaults: [vel: 0.45, amp: 2.0, sustain: 2, release: 1.5],
      fx: [ping_pong: [phase: 0.75, feedback: 0.5, mix: 0.4]] ++ @room
    ],
    lead: [
      synth:
        keys.(
          "Aerophones/Edge-blown Aerophones/Ocarina, Typical/Sustains/Sus",
          "StdOcarina_Sus_",
          "",
          ~w(A3 B3 C#4 D4 E4 F#4 G#4 A4 A#4 C5 C#5)
        ),
      defaults: [amp: 0.5, attack: 0.02, release: 0.15],
      fx: [echo: [phase: 0.75, decay: 3, mix: 0.25], reverb: [room: 0.8, mix: 0.35]]
    ],
    plucks: [
      synth:
        keys.(
          "Chordophones/Zithers/Dan Tranh/Normal",
          "",
          "_ff_1",
          ~w(B1 C#2 D#2 F#2 G#2 B2 C#3 D#3 F#3 G#3 B3 C#4 D#4 F#4 G#4 B4)
        ),
      defaults: [amp: 1.0, release: 0.6, pan: -0.3],
      fx: [echo: [phase: 0.375, decay: 1.5, mix: 0.2]] ++ @room
    ],
    pad: [
      synth:
        keys.(
          "Chordophones/Zithers/Psaltery, Bowed and Plucked/LongBow",
          "BowedPsaltery_",
          "",
          ~w(A#3_Main_LongBow_rr2 C4_Main_LongBow_rr1 D4_Main_LongBow_rr1 E4_Main_LongBow_rr2 F#4_Main_LongBow_rr1 G#4_Main_LongBow_rr1 A#4_Main_LongBow_rr2 C5_Main_LongBow_rr1)
        ),
      defaults: [amp: 3, attack: 0.5, release: 1.5],
      fx: [
        slicer: [phase: 0.25, pulse_width: 0.6, smooth: 0.01, mix: 0],
        lpf: [cutoff: 95],
        reverb: [room: 0.9, mix: 0.4]
      ]
    ],
    bells: [
      synth:
        keys.(
          "Idiophones/Struck Idiophones/Tubular Bells 1",
          "chimes_",
          "",
          ~w(C3_f_rr1 D3_ff_rr1 E3_ff_rr2 G#3_ff_rr1 A#3_ff_rr1 C4_ff_rr2 D4_ff_rr2 E4_ff_rr2)
        ),
      defaults: [amp: 0.3, release: 2],
      fx: @room
    ],
    timpani: [
      synth: :timpani,
      defaults: [vel: 0.8, amp: 1.3, sustain: 1.5, release: 1],
      fx: @room
    ]
  ]

  # A section's voices, each a part's name and its music; a part named more than once plays all its music together.
  def band(voices) do
    voices
    |> List.flatten()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {name, music} -> part(name, together(music), Keyword.fetch!(@parts, name)) end)
    |> together()
  end

  defp play(name, music), do: {name, music}

  # Bars of one drum in sixteenths, a character to each: a digit is a stroke of that level, a dot is silence, and spaces are left out.
  def strokes(patterns) do
    seq(
      for pattern <- List.wrap(patterns) do
        cells = pattern |> String.replace(" ", "") |> String.graphemes()

        hits =
          for {cell, index} <- Enum.with_index(cells), cell != "." do
            {index / 4, hit(amp: String.to_integer(cell) / 9)}
          end

        at(hits, length(cells) / 4)
      end
    )
  end

  # What an eighth of the hi-hat holds: how many strokes, and how many semitones the first and the last are tuned up.
  @rolls %{
    "x" => {1, 0, 0},
    "d" => {2, 0, 0},
    "t" => {3, 0, 0},
    "r" => {4, 0, 4},
    "s" => {6, 3, -4}
  }

  # Bars of the hi-hat in eighths, a character to each: x one stroke, d two, t a triplet, r four that rise in pitch, s six that fall, and a dot silence.
  # The strokes on the beat are the loudest, and a roll grows towards the next eighth.
  def hats(patterns) do
    seq(
      for pattern <- List.wrap(patterns) do
        cells = pattern |> String.replace(" ", "") |> String.graphemes()

        hits =
          for {cell, eighth} <- Enum.with_index(cells),
              cell != ".",
              {count, first, last} = @rolls[cell],
              stroke <- 0..(count - 1) do
            along = if count == 1, do: 1.0, else: stroke / (count - 1)
            level = if rem(eighth, 2) == 0, do: 1.0, else: 0.6
            amp = if count == 1, do: level, else: 0.45 + 0.5 * along
            note = 92 + first + (last - first) * along
            {(eighth + stroke / count) / 2, hit(amp: amp, note: note)}
          end

        at(hits, length(cells) / 2)
      end
    )
  end

  @hats_plain ["xxxxxxxx", "xxxtxxxx", "xxxxxxxx", "xxxxxxtr"]
  @hats_busy ["xxxtxxxx", "xdxxxxrx", "xxtxxxxd", "xxxxtxss"]
  @hats_verse ["x.xxx.xt", "x.xxxdx.", "x.xtx.xx", "xdx.xxsr"]

  # The 808's four bars, as the sixteenth each note starts on, its note, how many sixteenths it holds and where it slides: the beats into the note and the note it glides to.
  @line [
    {0, :f1, 6, []},
    {6, :f1, 4, []},
    {10, :f1, 6, []},
    {16, :f1, 3, []},
    {19, :f1, 7, []},
    {26, :f1, 4, []},
    {30, :f1, 2, [{0.1, :f2}]},
    {32, :db2, 6, []},
    {38, :db2, 4, []},
    {42, :db2, 6, []},
    {48, :c2, 3, []},
    {51, :c2, 6, []},
    {57, :c2, 3, []},
    {60, :c2, 2, []},
    {62, :c2, 2, [{0.1, :c3}]}
  ]

  # The busier line of the hook's second half, which climbs through the chord's notes and slides down an octave into the next round.
  @line_busy [
    {0, :f1, 6, []},
    {6, :f1, 4, []},
    {10, :f1, 6, []},
    {16, :f1, 3, []},
    {19, :ab1, 3, []},
    {22, :f1, 4, []},
    {26, :c2, 4, [{0.5, :f2}]},
    {30, :f2, 2, [{0.1, :db2}]},
    {32, :db2, 6, []},
    {38, :db2, 4, []},
    {42, :ab1, 3, []},
    {45, :db2, 3, []},
    {48, :c2, 3, []},
    {51, :c2, 5, []},
    {56, :g1, 2, []},
    {58, :c2, 2, []},
    {60, :e2, 2, []},
    {62, :g2, 2, [{0.1, :f1}]}
  ]

  def sub(line, rounds) do
    notes =
      for {step, pitch, steps, slides} <- line do
        changes = for {beat, to} <- slides, do: {beat, note: pitch(to), note_slide: 0.3}
        {step / 4, note(pitch, 0, sustain: steps / 4 - 0.05, changes: changes)}
      end

    play(:sub, repeat(at(notes, 16), rounds))
  end

  # The kick strikes with every note of the 808, softer where two come a sixteenth or two apart.
  def kick(line, rounds) do
    hits =
      for {step, _pitch, steps, _slides} <- line do
        {step / 4, hit(amp: if(steps <= 2, do: 0.7, else: 1.0))}
      end

    play(:kick, repeat(at(hits, 16), rounds))
  end

  # The clap on three, over a snare, and the claves between the kicks.
  def backbeat(bars) do
    [
      play(:clap, repeat(strokes(".... .... 9... ...."), bars)),
      play(:snare, repeat(strokes([".... .... 6... ....", ".... .... 6... ..3."]), div(bars, 2))),
      play(
        :rim,
        repeat(strokes(["...7 .... .... ..5.", ".... ..7. ...5 ...."]), div(bars, 2))
      )
    ]
  end

  def cymbal(beats), do: play(:cymbals, seq([hit(), rest(beats)]))

  # A snare roll over the last bar of so many beats: eighths, sixteenths, then thirty-seconds, growing.
  def roll(beats) do
    hits =
      for {from, step} <- [{0, 0.5}, {2, 0.25}, {3, 0.125}],
          count = round(if(from == 0, do: 2, else: 1) / step),
          index <- 0..(count - 1) do
        beat = from + index * step
        {beat, hit(vel: 0.3 + 0.15 * beat, amp: 0.25 + 0.1 * beat)}
      end

    play(:snare, seq([rest(beats - 4), at(hits, 4)]))
  end

  # Filtered noise that opens up over so many beats.
  def riser(beats) do
    play(
      :riser,
      note(:c4, beats,
        cutoff: 70,
        attack: beats - 0.5,
        sustain: 0,
        release: 0.5,
        changes: [{0, cutoff: 128, cutoff_slide: beats}]
      )
    )
  end

  def hiss(beats) do
    play(:hiss, repeat(sample(:vinyl_hiss, 8, attack: 0.5, release: 0.5), div(beats, 8)))
  end

  # The piano's four bars: each chord broken over sixteenths grouped in three, three, four, three and three, with its root held below.
  @motif [
    {:f2, [{0, :c5}, {0.75, :ab4}, {1.5, :f4}, {2.5, :c5}, {3.25, :ab4}]},
    {:f2, [{0, :g4}, {0.75, :f4}, {1.5, :g4}, {2.5, :ab4}]},
    {:db2, [{0, :db5}, {0.75, :ab4}, {1.5, :f4}, {2.5, :db5}, {3.25, :ab4}]},
    {:c2, [{0, :c5}, {0.75, :g4}, {1.5, :e4}, {2.5, :g4}, {3.25, :bb4}]}
  ]

  def motif(rounds, opts \\ []) do
    up = Keyword.get(opts, :up, 0)

    bars =
      for {root, notes} <- @motif do
        last = notes |> List.last() |> elem(0)

        right =
          for {beat, name} <- notes do
            held = if beat == last, do: 4 - beat, else: 0.7
            {beat, note(pitch(name) + up, 0, sustain: held)}
          end

        left = {0, note([pitch(root), pitch(root) + 12], 0, sustain: 3.8, amp: 0.6)}
        at([left | right], 4)
      end

    repeat(seq(bars), rounds)
  end

  # The glockenspiel answers in the second and fourth bars.
  def glock(rounds) do
    answers = [
      {6.5, :c7},
      {7, :ab6},
      {7.5, :f6},
      {12, :c7},
      {12.75, :bb6},
      {13.5, :g6},
      {14.5, :e6}
    ]

    notes = for {beat, name} <- answers, do: {beat, note(name, 0)}
    play(:glock, repeat(at(notes, 16), rounds))
  end

  # The hook, eight bars for the lead: each phrase is its beat, the beats it lasts and its notes, each at the beat it comes after the first and held until the next.
  @hook [
    {0.5, 3.2, [{0, :f5}, {0.5, :ab5}, {1, :f5}, {1.5, :eb5}, {2, :f5}]},
    {4.5, 3, [{0, :c5}, {0.5, :eb5}, {1, :f5}]},
    {8.5, 3.2, [{0, :ab5}, {0.5, :f5}, {1, :db5}, {1.5, :f5}]},
    {12.5, 3, [{0, :g5}, {0.5, :e5}, {1, :g5}, {1.5, :bb5}, {2, :g5}]},
    {16.5, 3.2, [{0, :f5}, {0.5, :ab5}, {1, :c6}, {1.5, :ab5}, {2, :f5}]},
    {20.5, 3, [{0, :eb5}, {0.5, :f5}, {1, :ab5}, {1.75, :f5}]},
    {24.5, 3.2, [{0, :ab5}, {0.5, :bb5}, {1, :db6}, {1.75, :ab5}]},
    {28.5, 3.2, [{0, :g5}, {0.5, :bb5}, {1, :c6}]}
  ]

  # The verse leaves the lead only the ends of its phrases, for the echo to carry.
  @calls [
    {6.5, 1.2, [{0, :eb5}, {0.5, :f5}]},
    {14.5, 1.2, [{0, :bb5}, {0.5, :g5}]},
    {22.5, 1.2, [{0, :ab5}, {0.5, :f5}]},
    {30, 1.7, [{0, :g5}, {0.5, :bb5}, {1, :c6}]}
  ]

  def lead(phrases) do
    notes =
      for {beat, held, steps} <- phrases,
          {{at, name}, index} <- Enum.with_index(steps) do
        ends = steps |> Enum.at(index + 1, {held, nil}) |> elem(0)
        {beat + at, note(name, 0, sustain: ends - at)}
      end

    play(:lead, at(notes, 32))
  end

  # The dan tranh plucks each chord in eighths, low, fifth, octave and fifth.
  def plucks(rounds) do
    bars =
      for root <- [:f3, :f3, :db3, :c3] do
        low = pitch(root)

        notes =
          for {step, up} <- Enum.with_index([0, 7, 12, 7, 0, 7, 12, 15]), do: {up / 2, low + step}

        at(for({beat, pitch} <- notes, do: {beat, note(pitch, 0, sustain: 0.2, release: 0.2)}), 4)
      end

    play(:plucks, repeat(seq(bars), rounds))
  end

  @chords [
    [:f3, :ab3, :c4, :f4],
    [:f3, :ab3, :c4, :f4],
    [:db3, :f3, :ab3, :db4],
    [:c3, :e3, :g3, :c4]
  ]

  def pad(rounds) do
    play(:pad, repeat(seq(for chord <- @chords, do: note(chord, 4, sustain: 3)), rounds))
  end

  # The tubular bells toll each chord's root and fifth on one, and the timpani strikes the root and leads into the next.
  def toll(rounds) do
    bars =
      for root <- [:f4, :f4, :db4, :c4], do: note([pitch(root), pitch(root) + 7], 4, sustain: 3)

    strokes =
      for {root, bar} <- Enum.with_index([:f2, :f2, :db3, :c3]),
          {beat, vel} <- [{0, 0.9}, {3.5, 0.5}],
          do: {bar * 4 + beat, note(root, 0, vel: vel)}

    [play(:bells, repeat(seq(bars), rounds)), play(:timpani, repeat(at(strokes, 16), rounds))]
  end

  # The desk: changes to a part's effects at beats of a section.
  def desk(name, changes, beats) do
    play(
      name,
      at(for({beat, target, opts} <- changes, do: {beat, change({name, target}, opts)}), beats)
    )
  end

  # The piano behind a closed filter that opens, the psaltery and the hiss, and and a roll and rising noise into the hook.
  def intro do
    band([
      play(:piano, motif(2)),
      desk(:piano, [{0, :lpf, [cutoff: 68]}, {0, :lpf, [cutoff: 118, cutoff_slide: 30]}], 32),
      pad(2),
      desk(:pad, [{0, :slicer, [mix: 0]}], 32),
      hiss(32),
      play(:hats, seq([rest(16), hats(["x.x.x.x.", "x.x.x.xt", "x.x.x.x.", "x.xdx.sr"])])),
      roll(32),
      riser_from(24, 8)
    ])
  end

  defp riser_from(beat, beats), do: play(:riser, seq([rest(beat), elem(riser(beats), 1)]))

  # Everything but the lead, then its hook over the busier 808.
  def hook(last?) do
    first =
      band(
        [
          cymbal(4),
          kick(@line, 2),
          sub(@line, 2),
          backbeat(8),
          play(:hats, hats(@hats_plain ++ @hats_busy)),
          play(
            :open_hat,
            repeat(strokes([".... .... .... ....", ".... .... .... ..7."]), 4)
          ),
          play(:piano, motif(2)),
          desk(:piano, [{0, :lpf, [cutoff: 118]}, {0, :bitcrusher, [mix: 0]}], 32),
          glock(2),
          pad(2),
          desk(:pad, [{0, :slicer, [mix: 0]}], 32)
        ] ++ if(last?, do: [toll(2)], else: [])
      )

    second =
      band(
        [
          cymbal(4),
          kick(@line_busy, 2),
          sub(@line_busy, 2),
          backbeat(8),
          play(:hats, hats(@hats_busy ++ @hats_busy)),
          play(:open_hat, repeat(strokes(".... .... .... ..7."), 8)),
          play(:piano, motif(2, up: if(last?, do: 12, else: 0))),
          glock(2),
          pad(2),
          lead(@hook)
        ] ++ if(last?, do: [toll(2)], else: [riser_from(24, 8)])
      )

    [first, second]
  end

  # The piano out: the psaltery cut into sixteenths by the slicer, the dan tranh plucked, the lead's calls, and the hats leaving gaps.
  def verse do
    band([
      kick(@line, 2),
      sub(@line, 2),
      backbeat(8),
      play(:hats, hats(@hats_verse ++ @hats_verse)),
      pad(2),
      desk(:pad, [{0, :slicer, [mix: 1]}, {0, :lpf, [cutoff: 105]}], 32),
      plucks(2),
      lead(@calls)
    ])
  end

  # The drums stop: the piano crushed behind a filter that opens again, the hiss, noise rising and a roll.
  def bridge do
    band([
      play(:piano, motif(1)),
      desk(
        :piano,
        [
          {0, :bitcrusher, [mix: 0.7]},
          {0, :lpf, [cutoff: 74]},
          {0, :lpf, [cutoff: 112, cutoff_slide: 15]},
          {12, :bitcrusher, [mix: 0, mix_slide: 3.5]}
        ],
        16
      ),
      pad(1),
      desk(:pad, [{0, :slicer, [mix: 0]}, {0, :lpf, [cutoff: 95]}], 16),
      hiss(16),
      riser(16),
      roll(16)
    ])
  end

  # The piano alone behind the closing filter, and an 808 that falls an octave as it fades.
  def outro do
    band([
      cymbal(4),
      play(:piano, seq([motif(1), note([:f2, :f3, :c4, :f4, :ab4], 8, sustain: 6, amp: 0.7)])),
      desk(:piano, [{0, :lpf, [cutoff: 118]}, {0, :lpf, [cutoff: 76, cutoff_slide: 16]}], 24),
      pad(1),
      hiss(24),
      play(
        :sub,
        note(:f1, 16, sustain: 6, fade: 5, changes: [{2, note: pitch(:f0), note_slide: 5}])
      )
    ])
  end

  def music, do: seq([intro()] ++ hook(false) ++ [verse(), bridge()] ++ hook(true) ++ [outro()])
end

song(tempo: 140, music: ColdFront.music())
