import Mx

# Sgubhu, an amapiano track in D minor at 112 bpm, written for mx and not transcribed from any record.
# The log drum is a synth written in this file: a low note whose overtones, the odd ones, sound as it is struck and die away at once, which knocks down onto its pitch and slides where its line slides.
# It plays the bass between the kicks, with octave jumps and slides, under a kick on every beat, the shaker's swung sixteenths, an open hi-hat off the beat, the congas, and the claves on every third sixteenth, across the bar.
# The chords go round four bars, D minor 9, B flat major 9, G minor 9 and A7 flat 9, on the FM piano of a Yamaha TX81Z under a tremolo, with the bowed vibraphone as a pad.
# The Steinway plays the tune in octaves, the small ocarina whistles, the vibraphone breaks the chords, and the tenor saxophone takes a solo.
# Those are recordings from the Versilian Community Sample Library, under Creative Commons 0; the drums and the percussion are mx's measured synths.
defmodule Sgubhu.Synths do
  use Mx.Instrument

  @doc "A log drum, amapiano's bass: a low note with the odd overtones of a struck slit drum, which die away as it rings."
  attr :note, :note, default: 38, doc: "The pitch, which a change glides."
  attr :vel, :float, default: 0.8, range: 0..1, doc: "How hard it is struck; harder is brighter."
  attr :fade, :float, default: 0.6, range: 0.05..10, doc: "The seconds it takes to fade."
  envelope_attrs sustain: 1, release: 0.05

  defsynth log_drum(played) do
    pitch = hz(follow(played.note)) * 2 ** envelope([{0, 0.9}, {0.035, 0, -4}])
    index = envelope([{0, 2.6 * played.vel + 0.6}, {0.12, 0.5, -3}, {played.fade, 0.05}])
    wood = sine(hz: pitch + sine(hz: pitch * 2) * pitch * index)
    low = sine(hz: pitch) |> gain(0.7)

    knock =
      noise(:white)
      |> bandpass(hz: 1800, q: 1.5)
      |> perc(attack: 0.0005, release: 0.01)
      |> gain(0.3 * played.vel)

    body =
      mix([wood, low])
      |> envelope([{0.003, 1}, {0.06, 0.75, -2}, {played.fade, 0, -2}])
      |> gain(0.35 * played.vel)

    (body + knock) |> note_envelope(played)
  end
end

defmodule Sgubhu do
  import Mx

  @room [reverb: [room: 0.6, damp: 0.5, mix: 0.25]]
  @hall [reverb: [room: 0.85, damp: 0.4, mix: 0.35]]

  vcsl = fn path ->
    {:github, "sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e", path}
  end

  # A sampled instrument from a folder of VCSL: its files' names around each key, the keys recorded, and how many semitones the names are under the pitch.
  keys = fn folder, prefix, suffix, names, under ->
    sampled(
      for name <- names do
        key = name |> String.split("_") |> hd()
        note = key |> String.downcase() |> String.replace("#", "s") |> String.to_atom()
        {vcsl.("#{folder}/#{prefix}#{name}#{suffix}.wav"), note: pitch(note) + under}
      end
    )
  end

  # The FM piano was recorded at three strengths on every fourth key.
  @fm_piano sampled(
              for octave <- 1..5, key <- ~w(C E G#), strength <- 1..3 do
                note = "#{key}#{octave}" |> String.downcase() |> String.replace("#", "s")
                path = "Electrophones/TX81Z/FM Piano/FMPiano_#{key}#{octave}_vl#{strength}.wav"
                {vcsl.(path), note: String.to_atom(note), strength: strength}
              end
            )

  @parts [
    log_drum: [synth: :log_drum, fx: [level: [amp: 1.35]]],
    kick: [synth: :kick, defaults: [vel: 0.7, amp: 0.18]],
    shaker: [synth: :ganza, defaults: [amp: 1.0, pan: 0.35]],
    cabasa: [synth: :cabasa, defaults: [amp: 0.6, pan: -0.4]],
    open_hat: [
      synth: :open_hihat,
      defaults: [amp: 1.2, sustain: 0.15, release: 0.1, pan: -0.2]
    ],
    claves: [
      synth: :clave,
      defaults: [amp: 0.25, pan: 0.3],
      fx: [ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.3]] ++ @room
    ],
    conga: [synth: :high_conga, defaults: [amp: 0.8, pan: -0.3], fx: @room],
    tumba: [synth: :low_conga, defaults: [amp: 1.2, pan: -0.3], fx: @room],
    clap: [synth: :clap, defaults: [amp: 0.75], fx: [reverb: [room: 0.7, mix: 0.35]]],
    cowbell: [synth: :cowbell, defaults: [amp: 0.8, pan: 0.5], fx: @room],
    keys: [
      synth: @fm_piano,
      defaults: [vel: 0.6, amp: 3, release: 0.3],
      fx: [
        hpf: [cutoff: 43],
        tremolo: [phase: 0.5, depth: 0.35, wave: 3],
        chorus: [phase: 2, mix: 0.3],
        lpf: [cutoff: 112],
        reverb: [room: 0.6, mix: 0.25]
      ]
    ],
    pad: [
      synth:
        keys.(
          "Idiophones/Struck Idiophones/Vibraphone/Bowed",
          "Vibes_bowed_",
          "_rr1_Main",
          ~w(A2 E3 G3 D4 A4 E5),
          12
        ),
      defaults: [amp: 7, attack: 0.3, release: 1.5],
      fx: [chorus: [phase: 4, mix: 0.4]] ++ @hall
    ],
    piano: [
      synth:
        keys.(
          "Chordophones/Zithers/Grand Piano, Steinway B/Sus",
          "JHPiano_Sus_Close_",
          "_vl3_rr1",
          for(octave <- 3..5, key <- ~w(C D E F# G# A#), do: "#{key}#{octave}") ++ ["C6"],
          0
        ),
      defaults: [amp: 0.28, release: 0.3],
      fx: [echo: [phase: 0.75, decay: 2, mix: 0.15]] ++ @hall
    ],
    whistle: [
      synth:
        keys.(
          "Aerophones/Edge-blown Aerophones/Ocarina, Small/Sustain",
          "ocarina_",
          "_sustain0",
          ~w(C5 D5 E5 F5 G5 G#5 A5 A#5 B5),
          12
        ),
      defaults: [amp: 0.65, attack: 0.01, release: 0.1, pan: 0.4],
      fx: [ping_pong: [phase: 0.75, feedback: 0.55, mix: 0.45]] ++ @hall
    ],
    vibraphone: [
      synth:
        keys.(
          "Idiophones/Struck Idiophones/Vibraphone/Soft Mallets",
          "Vibes_soft_",
          "_v2_rr1_Main",
          ~w(F2 A2 C3 E3 G3 B3 D4 F4 A4 C5 E5),
          12
        ),
      defaults: [amp: 0.6, pan: -0.35, release: 0.6],
      fx: @hall
    ],
    sax: [
      synth:
        keys.(
          "Aerophones/Reed Aerophones/Tenor Saxophone/Vibrato",
          "BrettTenor_Vib_Main_",
          "",
          ~w(A#2_var4 C3_var1 D3_var1 E3_var3 F#3_var2 A#3_var3 C4_var2 D4_var1 E4_var4 G4_var3),
          12
        ),
      defaults: [amp: 1.7, attack: 0.03, release: 0.15],
      fx: [echo: [phase: 0.75, decay: 2.5, mix: 0.2]] ++ @hall
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

  # The second and fourth sixteenths of each beat come this much of a beat late, which is the groove's swing.
  @late 0.03

  defp beat(step), do: step / 4 + if(rem(step, 2) == 1, do: @late, else: 0)

  # Bars of strokes in swung sixteenths, a character to each: a digit is a stroke of that strength, u an up stroke of the shaker, and a dot silence; spaces are left out.
  # A digit sets the stroke's vel, or its amp on a drum that has no vel.
  def strokes(patterns, bars \\ 1, digit \\ :vel) do
    one =
      for pattern <- List.wrap(patterns) do
        cells = pattern |> String.replace(" ", "") |> String.graphemes()

        hits =
          for {cell, step} <- Enum.with_index(cells), cell != "." do
            opts =
              if cell == "u", do: [vel: 0.45, up: 1], else: [{digit, String.to_integer(cell) / 9}]

            {beat(step), hit(opts)}
          end

        at(hits, length(cells) / 4)
      end

    repeat(seq(one), max(div(bars, length(one)), 1))
  end

  # The shaker, louder off the beat, and the cabasa on the and of each beat.
  def shakers(bars) do
    [shaker: strokes("5u7u 5u7u 5u7u 5u7u", bars), cabasa: strokes("..5. ..5. ..5. ..5.", bars)]
  end

  # The claves on every third sixteenth, which takes three bars to come round, and the congas' two bars.
  def hands(bars) do
    three = ["9..6 ..6. .6.. 6..6", "..6. .6.. 6..6 ..6.", ".6.. 6..6 ..6. .6.."]
    claves = three |> Stream.cycle() |> Enum.take(bars)

    [
      claves: strokes(claves, bars),
      conga: strokes([".... 7..6 ..7. 6...", ".... 7..6 ..7. 6..."], bars),
      tumba: strokes([".... .... .... ....", ".... .... .... ..7."], bars)
    ]
  end

  def drums(bars) do
    [
      kick: strokes("8... 8... 8... 8...", bars),
      open_hat: strokes("..5. ..5. ..5. ..5.", bars)
    ]
  end

  def clap(bars) do
    [
      clap: strokes("....6.......6...", bars, :amp),
      cowbell: strokes([".... .... .... ....", ".... ..6. .... .6.."], bars)
    ]
  end

  # A roll on the shaker over two beats, in thirty-seconds, growing.
  def shaker_roll do
    hits = for index <- 0..15, do: {index / 8, hit(vel: 0.3 + index * 0.04, up: rem(index, 2))}
    {:shaker, at(hits, 2)}
  end

  # The log drum's four bars, as the sixteenth each note starts on, its note, how many sixteenths it holds and the note it slides to before it ends.
  @line [
    {3, :d2, 3, nil},
    {6, :d2, 2, nil},
    {9, :d3, 1, nil},
    {11, :d2, 3, :f2},
    {14, :a1, 2, nil},
    {19, :bb1, 3, nil},
    {22, :bb1, 2, nil},
    {25, :bb2, 1, nil},
    {27, :bb1, 2, nil},
    {30, :c2, 2, :d2},
    {35, :g1, 3, nil},
    {38, :g1, 2, nil},
    {41, :g2, 1, nil},
    {43, :g1, 3, :bb1},
    {46, :d2, 2, nil},
    {50, :a1, 2, nil},
    {54, :a1, 2, nil},
    {57, :a2, 1, nil},
    {59, :e2, 1, nil},
    {60, :a1, 2, nil},
    {62, :cs2, 2, :d2}
  ]

  # The same line with its last bar a run of sixteenths up to the octave.
  @line_run Enum.reject(@line, fn {step, _, _, _} -> step >= 54 end) ++
              [
                {54, :a1, 2, nil},
                {56, :a1, 1, nil},
                {57, :a2, 1, nil},
                {58, :a1, 1, nil},
                {59, :e2, 1, nil},
                {60, :g2, 1, nil},
                {61, :a2, 1, nil},
                {62, :cs3, 2, :d3}
              ]

  def log_drum(line, rounds) do
    notes =
      for {step, name, steps, slide} <- line do
        held = steps / 4
        changes = if slide, do: [{held / 2, note: pitch(slide), note_slide: held / 2}], else: []
        vel = if steps == 1, do: 0.6, else: 0.85
        {beat(step), note(name, 0, sustain: held, vel: vel, changes: changes)}
      end

    {:log_drum, repeat(at(notes, 16), rounds)}
  end

  # Each bar's chord: its root for the pad, and the FM piano's four notes.
  @chords [
    {:d2, [:f3, :a3, :c4, :e4]},
    {:bb1, [:a3, :c4, :d4, :f4]},
    {:g2, [:f3, :a3, :bb3, :d4]},
    {:a1, [:g3, :bb3, :cs4, :e4]}
  ]

  # The chord struck on one, short on the and of two, and held from the last sixteenth of three.
  def keys(rounds) do
    bars =
      for {_root, chord} <- @chords do
        at(
          [
            {0, note(chord, 0, sustain: 0.9, vel: 0.7)},
            {beat(6), note(chord, 0, sustain: 0.2, vel: 0.5)},
            {beat(11), note(chord, 0, sustain: 1.1, vel: 0.6)}
          ],
          4
        )
      end

    {:keys, repeat(seq(bars), rounds)}
  end

  def pad(rounds) do
    bars =
      for {root, chord} <- @chords do
        note([pitch(root) + 12, Enum.at(chord, 1), Enum.at(chord, 3)], 4, sustain: 3)
      end

    {:pad, repeat(seq(bars), rounds)}
  end

  # The piano's tune, four bars in octaves, as beat, note and beats held.
  @tune [
    {0.5, :a5, 0.5},
    {1, :f5, 0.5},
    {1.5, :e5, 0.5},
    {2, :d5, 1},
    {3.25, :e5, 0.25},
    {3.5, :f5, 0.5},
    {4, :a5, 1.5},
    {5.5, :g5, 0.5},
    {6, :f5, 0.75},
    {6.75, :d5, 1},
    {8.5, :bb5, 0.5},
    {9, :a5, 0.5},
    {9.5, :g5, 0.5},
    {10, :f5, 1},
    {11.25, :g5, 0.25},
    {11.5, :a5, 0.5},
    {12, :cs6, 1},
    {13, :bb5, 0.5},
    {13.5, :a5, 0.5},
    {14, :g5, 0.5},
    {14.5, :e5, 0.5},
    {15, :cs5, 1}
  ]

  def piano(rounds) do
    notes =
      for {at, name, held} <- @tune do
        {at, note([pitch(name) - 12, pitch(name)], 0, sustain: held, amp: [0.2, 0.28])}
      end

    {:piano, repeat(at(notes, 16), rounds)}
  end

  # The whistle: two notes a fourth apart at the end of every second bar.
  def whistle(rounds) do
    call = fn at, from, to ->
      [{at, note(from, 0, sustain: 0.2)}, {at + 0.2, note(to, 0, sustain: 0.3)}]
    end

    calls = call.(7, :a6, :d7) ++ call.(14.5, :e6, :a6) ++ call.(15.25, :a6, :cs7)
    {:whistle, repeat(at(calls, 16), rounds)}
  end

  # The vibraphone breaks each chord upwards in eighths, from the second beat.
  def vibraphone(rounds) do
    bars =
      for {_root, chord} <- @chords do
        notes =
          for {name, index} <- Enum.with_index(chord),
              do: {1 + index / 2, note(pitch(name) + 12, 0, sustain: 2)}

        at(notes, 4)
      end

    {:vibraphone, repeat(seq(bars), rounds)}
  end

  # The saxophone's solo, eight bars: each phrase is its beat, the beats it lasts and its notes, each at the beat it comes after the first and held until the next.
  @solo [
    {0.5, 3, [{0, :d4}, {0.5, :f4}, {1, :a4}, {1.5, :c5}, {2, :a4}]},
    {4.5, 3, [{0, :d5}, {0.75, :c5}, {1.5, :a4}, {2, :f4}]},
    {8.5, 3, [{0, :g4}, {0.5, :bb4}, {1, :d5}, {1.5, :f5}, {2.25, :d5}]},
    {12.5, 3.2, [{0, :e5}, {0.5, :cs5}, {1, :bb4}, {1.5, :a4}, {2.5, :g4}]},
    {16, 3.5, [{0, :a4}, {0.75, :c5}, {1.5, :e5}, {2.25, :f5}, {3, :e5}]},
    {20.5, 3, [{0, :d5}, {0.5, :f5}, {1, :a5}, {2, :f5}]},
    {24, 3.5, [{0, :g5}, {0.5, :f5}, {1, :d5}, {1.5, :bb4}, {2.5, :d5}]},
    {28, 3.7, [{0, :e5}, {0.5, :g5}, {1, :bb5}, {1.5, :a5}, {2.5, :cs5}, {3, :d5}]}
  ]

  def sax(phrases \\ @solo) do
    notes =
      for {beat, held, steps} <- phrases,
          {{at, name}, index} <- Enum.with_index(steps) do
        ends = steps |> Enum.at(index + 1, {held, nil}) |> elem(0)
        {beat + at, note(name, 0, sustain: ends - at)}
      end

    {:sax, at(notes, 32)}
  end

  # A change to one of a part's effects at a beat.
  def desk(name, effect, changes) do
    {name, at(for({at, opts} <- changes, do: {at, change({name, effect}, opts)}), 1)}
  end

  defp later(voices, beats),
    do: for({name, music} <- List.wrap(voices), do: {name, seq([rest(beats), music])})

  # The chords behind a filter that opens, the shakers, then the claves and the congas, and the log drum's first slide.
  def intro do
    band([
      keys(2),
      desk(:keys, :lpf, [{0, [cutoff: 72]}, {0, [cutoff: 112, cutoff_slide: 30]}]),
      pad(2),
      shakers(8),
      later(hands(4), 16),
      later(shaker_roll(), 30),
      later(
        {:log_drum,
         note(:a1, 2, sustain: 1.8, changes: [{0.6, note: pitch(:d2), note_slide: 1}])},
        30
      )
    ])
  end

  # The kick and the log drum come in; the second time the piano plays its tune.
  def groove(tune?) do
    band(
      [log_drum(@line, 2), drums(8), shakers(8), hands(8), keys(2), pad(2), whistle(2)] ++
        if(tune?, do: [piano(2), clap(8)], else: [])
    )
  end

  # The kick and the log drum out: the chords, the pad and the vibraphone over the shakers, and a roll back in.
  def breakdown do
    band([
      keys(1),
      desk(:keys, :lpf, [{0, [cutoff: 80]}, {0, [cutoff: 112, cutoff_slide: 14]}]),
      pad(1),
      vibraphone(1),
      shakers(4),
      {:claves, strokes(["9..6 ..6. .6.. 6..6", "..6. .6.. 6..6 ..6.", ".6.. 6..6 ..6. .6.."])},
      later(shaker_roll(), 14),
      later(
        {:log_drum,
         note(:a1, 2, sustain: 1.8, changes: [{0.6, note: pitch(:d2), note_slide: 1}])},
        14
      )
    ])
  end

  # The saxophone's solo over the busier log drum; the second time the piano's tune comes back under it.
  def solo(tune?) do
    phrases = if tune?, do: Enum.drop(@solo, 4) ++ Enum.take(@solo, 4), else: @solo

    band(
      [
        log_drum(@line_run, 2),
        drums(8),
        shakers(8),
        hands(8),
        clap(8),
        keys(2),
        pad(2),
        sax(phrases)
      ] ++
        if(tune?, do: [piano(2), whistle(2)], else: [vibraphone(2)])
    )
  end

  # The drums thin out, and the log drum slides down to its last note.
  def outro do
    band([
      keys(1),
      desk(:keys, :lpf, [{0, [cutoff: 112]}, {0, [cutoff: 76, cutoff_slide: 16]}]),
      pad(1),
      vibraphone(1),
      shakers(4),
      later(
        {:log_drum,
         note(:d3, 4, sustain: 3, fade: 3, changes: [{0.3, note: pitch(:d2), note_slide: 1.5}])},
        16
      ),
      later({:keys, note([:d3, :f3, :a3, :c4, :e4], 4, sustain: 4, vel: 0.5)}, 16)
    ])
  end

  def music do
    seq([intro(), groove(false), groove(true), breakdown(), solo(false), solo(true), outro()])
  end
end

song(tempo: 112, music: Sgubhu.music())
