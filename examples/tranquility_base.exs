import Mx

# Tranquility Base, a piece made only of public recordings, at 136 bpm, where Sputnik's beep, every 0.44 seconds, falls on the beat.
# It goes round C minor 9, A flat major 7, E flat major 7 and B flat, two bars each, chords that all hold the E flat Sputnik beeps near.
# VCSL's marimba plays the bass and an ostinato, its vibraphone the chords, struck and bowed, its hand chimes the melody, and its wine glasses, tuned by their rate, hold E flat major 7 over everything.
# Its bass drum, snare, hi-hat, frame drum, shaker, claps and tom keep time, each choosing strengths and alternating takes, with its cymbal, timpani, gong and wind chimes at the turns.
# NASA's recordings tell the story over it: Kennedy's challenge, the liftoff of Apollo 11, Apollo 13's problem through a bitcrusher, the landing stuttered into the drop, the first step, and the return.
# VCSL is Versilian Studios' Versilian Community Sample Library, under Creative Commons 0, downloaded with mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones" and the same for Membranophones
# NASA's recordings are in the folder beside this file, from https://nssdc.gsfc.nasa.gov/planetary/sound/index.html, courtesy of NASA.
defmodule TranquilityBase do
  import Mx

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
  @drums "Membranophones/Struck Membranophones"
  @struck "Idiophones/Struck Idiophones"
  @cymbals "Idiophones/Struck Idiophones/Hi-Hat Cymbal"
  @glasses "Idiophones/Friction Idiophones/Wine Glasses/Sustains/Slow"

  vcsl = fn path -> {:github, @repo, @commit, path} end

  # VCSL names each key an octave below the pitch mx names it by: its A2 sounds at 220 Hz.
  key = fn name ->
    name = name |> String.downcase() |> String.replace("#", "s") |> String.to_atom()
    pitch(name) + 12
  end

  @kick vcsl.("#{@drums}/Bass Drum 1")
  @snare for layer <- [3, 5, 6, 7],
             take <- [1, 2],
             do: vcsl.("#{@drums}/Snare Drum, Modern 1/Snare2_HitSN_v#{layer}_rr#{take}_Mid.wav")
  @hat_takes for layer <- [2, 3, 4],
                 take <- [1, 2],
                 do: vcsl.("#{@cymbals}/HiHat_HitC_v#{layer}_rr#{take}_Mid.wav")
  # The softest hi-hat stroke was recorded once.
  @hat [vcsl.("#{@cymbals}/HiHat_HitC_v1_rr1_Mid.wav") | @hat_takes]
  @open_hat for take <- [1, 2], do: vcsl.("#{@cymbals}/HiHat_HitO_rr#{take}_Mid.wav")
  @frame for layer <- [2, 3],
             take <- [1, 2],
             do: vcsl.("#{@drums}/Frame Drum/HDrumL_Hit_v#{layer}_rr#{take}_Sum.wav")
  # The shaker's strokes down and up are its takes, so they alternate.
  @shaker for {stroke, take} <- [{"Down_rr1", 1}, {"Up_rr1", 2}, {"Down_rr2", 3}, {"Up_rr2", 4}],
              do:
                {vcsl.("#{@struck}/Shaker, Small/Mid_ShakerLowFaster_#{stroke}.wav"), take: take}
  @claps for take <- 1..6, do: vcsl.("#{@struck}/Claps/Clap_rr#{take}.wav")
  @tom vcsl.("#{@drums}/Tom 1/Stick/TomH_HitS_v4_rr1_Mid.wav")

  @marimba for name <- ~w(F1 C2 G2 B2 F3 C4 G4 B4 F5 C6),
               do:
                 {vcsl.("#{@struck}/Marimba/Marimba_hit_Outrigger_#{name}_loud_01.wav"),
                  note: key.(name)}
  @vibes for name <- ~w(A2 C3 E3 G3 B3 D4 F4 A4 C5 E5),
             do:
               {vcsl.("#{@struck}/Vibraphone/Soft Mallets/Vibes_soft_#{name}_v2_rr1_Main.wav"),
                note: key.(name)}
  @bowed for name <- ~w(E3 G3 D4 A4 E5),
             do:
               {vcsl.("#{@struck}/Vibraphone/Bowed/Vibes_bowed_#{name}_rr1_Main.wav"),
                note: key.(name)}
  @chimes for name <- ~w(A#3 C4 D4 E4 F#4 G#4 C5 E5 F#5),
              do: {vcsl.("#{@struck}/Hand Chimes/sus_#{name}_r01_main.wav"), note: key.(name)}

  # The four wine glasses, each with the cents that bring it to E flat 5, G5, B flat 5 and D6.
  @glass [
    {vcsl.("#{@glasses}/glass1_D#4_Slow_1_Main.wav"), -23, -0.5},
    {vcsl.("#{@glasses}/glass3_A#4_Slow_1_Main.wav"), -57, 0.5},
    {vcsl.("#{@glasses}/glass2_F#4_Slow_1_Main.wav"), 118, -0.2},
    {vcsl.("#{@glasses}/glass4_D5_Slow_2_Main.wav"), -5, 0.2}
  ]

  @ocean vcsl.("Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_1_Mid.wav")
  @crash vcsl.("#{@struck}/Suspended Cymbal 1/susCymb1_hit_f1.wav")
  @swell vcsl.("#{@struck}/Suspended Cymbal 1/susCymb1_cresc_4s.wav")
  @gong vcsl.("#{@struck}/Gong 1/gong_f.wav")
  @soft_gong vcsl.("#{@struck}/Gong 1/gong_p.wav")
  @rising_chimes vcsl.("#{@struck}/Mark Trees/Legacy/windchimes_slowAsc1.wav")
  @falling_chimes vcsl.("#{@struck}/Mark Trees/Legacy/windchimes_slowDesc1.wav")
  @timpani vcsl.("#{@drums}/Timpani 1/Roll/Timpani1_Roll_v5_rr1_Sum.wav")
  @drum_swell vcsl.("#{@drums}/Bass Drum 2/bassdrum_cresc_short.wav")

  @nasa Path.expand("tranquility_base", __DIR__)
  @sputnik Path.join(@nasa, "sputnik.wav")
  @kennedy Path.join(@nasa, "a11kennedy.aiff")
  @landing Path.join(@nasa, "a11landing.aiff")
  @liftoff Path.join(@nasa, "a11liftoff.aiff")
  @step Path.join(@nasa, "a11step.aiff")
  @magnificent Path.join(@nasa, "a11magnif.aiff")
  @problem Path.join(@nasa, "apollo_13_problem.wav")

  # Each chord's bass notes, as root, fifth, octave and the note that leads to the next chord, the root and the leading note doubled an octave up, then its voicings.
  @chords [
    %{
      bass: [[:c2, :c3], :g2, :c3, [:bb1, :bb2]],
      vibes: [:bb3, :eb4, :g4, :d5],
      marimba: [:g4, :bb4, :c5, :eb5, :g5],
      pad: [:eb4, :g4, :d5],
      lead: [g5: 1.5, bb5: 0.5, c6: 2, bb5: 1, g5: 3]
    },
    %{
      bass: [[:ab1, :ab2], :eb2, :ab2, [:d2, :d3]],
      vibes: [:c4, :eb4, :g4, :bb4],
      marimba: [:ab4, :bb4, :c5, :eb5, :g5],
      pad: [:eb4, :ab4, :c5],
      lead: [eb5: 1.5, g5: 0.5, bb5: 2, g5: 1, f5: 3]
    },
    %{
      bass: [[:eb2, :eb3], :bb2, :eb3, [:c2, :c3]],
      vibes: [:g3, :bb3, :d4, :f4],
      marimba: [:g4, :bb4, :d5, :eb5, :g5],
      pad: [:eb4, :g4, :bb4],
      lead: [g5: 1.5, bb5: 0.5, eb6: 2, d6: 1, bb5: 3]
    },
    %{
      bass: [[:bb1, :bb2], :f2, :bb2, [:d2, :d3]],
      vibes: [:bb3, :c4, :f4, :bb4],
      marimba: [:f4, :bb4, :c5, :d5, :f5],
      pad: [:f4, :bb4, :d5],
      lead: [c6: 1.5, bb5: 0.5, f5: 2, g5: 1, f5: 3]
    }
  ]

  @drum [sustain: 1, release: 1]

  @parts [
    kick: [synth: sampled(@kick), defaults: [amp: 0.6] ++ @drum],
    snare: [
      synth: sampled(@snare),
      defaults: [amp: 0.6] ++ @drum,
      fx: [reverb: [room: 0.4, mix: 0.15]]
    ],
    hat: [
      synth: sampled(@hat),
      defaults: [amp: 1.2, sustain: 0.4, release: 0.2],
      fx: [hpf: [cutoff: 80], flanger: [phase: 8, feedback: 0.3, mix: 0.3]]
    ],
    open_hat: [
      synth: sampled(@open_hat),
      defaults: [amp: 0.3, sustain: 0.4, release: 0.3],
      fx: [hpf: [cutoff: 80]]
    ],
    frame: [
      synth: sampled(@frame),
      defaults: [amp: 0.8] ++ @drum,
      fx: [reverb: [room: 0.5, mix: 0.25]]
    ],
    shaker: [
      synth: sampled(@shaker),
      defaults: [normalize: true, amp: 0.15, sustain: 0.3, release: 0.1],
      fx: [hpf: [cutoff: 90], pan: [pan: 0.35]]
    ],
    claps: [
      synth: sampled(@claps),
      defaults: [amp: 0.25, sustain: 0.5, release: 0.3],
      fx: [reverb: [room: 0.6, mix: 0.3]]
    ],
    tom: [fx: [reverb: [room: 0.5, mix: 0.25]]],
    turns: [fx: [reverb: [room: 0.8, mix: 0.3]]],
    bass: [
      synth: sampled(@marimba),
      defaults: [normalize: true, amp: 0.54, release: 0.5],
      fx: [lpf: [cutoff: 67]]
    ],
    marimba: [
      synth: sampled(@marimba),
      defaults: [normalize: true, amp: 0.32, release: 0.5],
      fx: [rlpf: [cutoff: 72, res: 0.4], ping_pong: [phase: 0.75, feedback: 0.5, mix: 0.3]]
    ],
    vibes: [
      synth: sampled(@vibes),
      defaults: [normalize: true, amp: 0.13, release: 3],
      fx: [
        tremolo: [phase: 0.5, depth: 0.35, wave: 3],
        ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.2],
        reverb: [room: 0.7, mix: 0.3]
      ]
    ],
    bowed: [
      synth: sampled(@bowed),
      defaults: [normalize: true, amp: 0.08, attack: 1, release: 4],
      fx: [chorus: [mix: 0.4], reverb: [room: 0.9, mix: 0.5]]
    ],
    lead: [
      synth: sampled(@chimes),
      defaults: [normalize: true, amp: 0.27, release: 2],
      fx: [echo: [phase: 1.5, decay: 6, mix: 0.35], reverb: [room: 0.8, mix: 0.35]]
    ],
    glass: [fx: [chorus: [mix: 0.4], reverb: [room: 0.9, mix: 0.4]]],
    gate: [
      fx: [
        slicer: [phase: 0.5, pulse_width: 0.5, amp_min: 0.05, smooth: 0.01],
        ping_pong: [phase: 0.75, feedback: 0.5, mix: 0.3],
        reverb: [room: 0.8, mix: 0.3]
      ]
    ],
    ocean: [
      fx: [wobble: [phase: 16, cutoff_min: 80, cutoff_max: 125, res: 0.2, wave: 3]]
    ],
    sputnik: [fx: [lpf: [cutoff: 100], echo: [phase: 1.5, decay: 4, mix: 0.25]]],
    rocket: [fx: [flanger: [phase: 4, feedback: 0.5, mix: 0.5], reverb: [room: 0.9, mix: 0.4]]],
    radio: [
      fx: [
        bitcrusher: [bits: 6, sample_rate: 5000, mix: 0.8],
        ping_pong: [phase: 0.75, feedback: 0.5, mix: 0.35]
      ]
    ],
    voice: [
      fx: [
        hpf: [cutoff: 50],
        echo: [phase: 0.75, decay: 6, mix: 0.3],
        reverb: [room: 0.7, mix: 0.3]
      ]
    ]
  ]

  # A bar of drum hits, each character a sixth of a beat: x loud, o soft, a dot silent.
  def hits(pattern, loud, soft) do
    steps = pattern |> String.replace(" ", "") |> String.graphemes()

    hits =
      for {step, index} <- Enum.with_index(steps),
          step != ".",
          do: {index / 6, hit(vel: if(step == "x", do: loud, else: soft))}

    at(hits, length(steps) / 6)
  end

  # A line of notes, each character a sixth of a beat: a digit plays that note of the list, counted from 1, until the next note, loud on the beat and soft off it, and a dot is silent.
  def figure(pattern, notes, loud, soft) do
    steps = pattern |> String.replace(" ", "") |> String.graphemes()
    total = length(steps)
    starts = for {step, index} <- Enum.with_index(steps), step != ".", do: {index, step}
    stops = Enum.drop(Enum.map(starts, &elem(&1, 0)), 1) ++ [total]

    entries =
      for {{index, step}, stop} <- Enum.zip(starts, stops) do
        vel = if rem(index, 6) == 0, do: loud, else: soft

        {index / 6,
         note(Enum.at(notes, String.to_integer(step) - 1), (stop - index) / 6, vel: vel)}
      end

    at(entries, total / 6)
  end

  # The four chords, two bars each, played by the function.
  def cycle(fun), do: seq(Enum.map(@chords, fun))

  def groove(bars) do
    [
      kick: repeat(hits("x.....x..... x.....o.....", 0.9, 0.4), bars),
      snare: repeat(hits("............ x...........", 0.8, 0.4), bars),
      hat: repeat(hits("x.ox.ox.ox.o x.ox.ox.ox.o", 0.5, 0.25), bars),
      frame: repeat(hits("..x..o..x.o. ..x..o..xox.", 0.7, 0.35), bars)
    ]
  end

  def shaker(bars), do: repeat(hits("o..x..o..x.o o..x..o..xo.", 0.9, 0.5), bars)
  def claps(bars), do: repeat(hits("............ x.........o.", 0.9, 0.5), bars)

  def open_hat(bars) do
    repeat(hits("........................ .....................x..", 0.9, 0.5), div(bars, 2))
  end

  # Six strokes of the tom falling from E flat to G over the last two beats.
  def fill(beats) do
    strokes =
      for {semitones, amp} <-
            Enum.zip([6.2, 6.2, 3.2, 3.2, 1.2, -1.8], [0.4, 0.5, 0.55, 0.65, 0.7, 0.85]) do
        sample(@tom, 1 / 3, rate: :math.pow(2, semitones / 12), amp: amp, sustain: 1, release: 1)
      end

    seq([rest(beats - 2) | strokes])
  end

  def bass(chord) do
    figure("1........1.. ...3..2....1 1........3.. ...2..4.....", chord.bass, 0.9, 0.7)
  end

  def ostinato(chord) do
    figure("1..3.54..2.. 5..3.24..1.. 1..3.54..2.. 5..4.35..2.4", chord.marimba, 0.8, 0.55)
  end

  def comp(chord) do
    at(
      [
        {0, note(chord.vibes, 2.5, vel: 0.8, strum: 0.03)},
        {2.5, note(chord.vibes, 1.5, vel: 0.5)},
        {5.5, note(chord.vibes, 2.5, vel: 0.65, strum: 0.03)}
      ],
      8
    )
  end

  def held(chord), do: note(chord.vibes, 8, vel: 0.6, strum: 0.05)
  def pad(chord), do: note(chord.pad, 8, vel: 0.8)
  def lead(chord), do: seq(for {name, beats} <- chord.lead, do: note(name, beats, vel: 0.8))

  # Sputnik's beep, one stretch of four of its periods fitted to a bar.
  def beeps(beats, amp) do
    seq(
      for _ <- 1..div(beats, 4),
          do: sample(@sputnik, 4, from: 0.3, to: 2.06, beats: 4, amp: amp)
    )
  end

  def ocean(beats) do
    sample(@ocean, beats,
      normalize: true,
      amp: 0.43,
      attack: 4,
      sustain: beats - 8,
      release: 4
    )
  end

  # The glasses come in one after another over the first three eighths of the beats, and each fades in and out.
  def glasses(beats, amp) do
    entries =
      for {{file, cents, pan}, index} <- Enum.with_index(@glass) do
        start = index * beats / 8
        length = beats - start

        {start,
         sample(file, length,
           rate: :math.pow(2, cents / 1200),
           normalize: true,
           amp: amp,
           attack: 4,
           sustain: length - 4,
           release: 4,
           pan: pan
         )}
      end

    at(entries, beats)
  end

  def turn(file, opts), do: sample(file, 0, [normalize: true] ++ opts)
  def landing(beats, opts \\ []), do: sample(@landing, beats, opts)

  # Sputnik over the ocean and the glasses, then Kennedy's challenge over the four chords bowed, and a cymbal and a timpani roll rising to liftoff.
  def signal do
    section(48,
      ocean: ocean(48),
      glass: seq([glasses(32, 0.16), glasses(16, 0.16)]),
      sputnik: seq([beeps(16, 0.25), beeps(32, 0.12)]),
      bowed: seq([rest(16), cycle(&pad/1)]),
      vibes:
        at(
          [
            {16, note(hd(@chords).vibes, 8, vel: 0.45, strum: 0.08)},
            {32, note(Enum.at(@chords, 2).vibes, 8, vel: 0.45, strum: 0.08)}
          ],
          48
        ),
      voice: at([{16, sample(@kennedy, 22, from: 0.0, to: 8.95, amp: 1.15)}], 48),
      turns:
        at(
          [
            {0, turn(@rising_chimes, amp: 0.25)},
            {40, turn(@swell, amp: 0.4)},
            {40, turn(@timpani, rate: 1.025, amp: 0.45, attack: 6, sustain: 1.7, release: 0.3)}
          ],
          48
        ),
      tom: fill(48)
    )
  end

  # The band comes in with the liftoff, and the marimba's ostinato opens up over the second time round.
  def liftoff do
    section(
      64,
      [
        voice: sample(@liftoff, 16, amp: 0.85),
        sputnik: beeps(64, 0.1),
        glass: repeat(glasses(32, 0.12), 2),
        bass: repeat(cycle(&bass/1), 2),
        vibes: seq([cycle(&held/1), cycle(&comp/1)]),
        marimba:
          together([
            seq([rest(32), cycle(&ostinato/1)]),
            at([{32, change({:marimba, :rlpf}, cutoff: 112, cutoff_slide: 24)}], 64)
          ]),
        shaker: seq([rest(32), shaker(8)]),
        turns: at([{0, turn(@crash, amp: 0.25)}, {32, turn(@crash, amp: 0.2)}], 64),
        tom: seq([fill(32), fill(32)])
      ] ++ groove(16)
    )
  end

  # Apollo 13's problem stops the band, then a snare roll, a bass drum and a cymbal rise under the landing, "The Eagle" cut and repeated ever higher, until "The Eagle has landed" alone.
  def problem do
    roll =
      for {from, step} <- [{16, 1}, {20, 1 / 2}, {24, 1 / 3}, {28, 1 / 6}],
          count <- 0..(round(4 / step) - 1),
          beat = from + count * step,
          beat < 30,
          do: {beat, hit(vel: 0.2 + (beat - 16) / 14 * 0.75)}

    stutter =
      for cut <- 0..7,
          do: {26 + cut * 0.5, landing(0.5, from: 2.1, to: 2.4, amp: 0.8, rate: 1 + cut * 0.06)}

    slowing =
      for cut <- 0..3,
          do:
            {14 + cut * 0.5,
             sample(@problem, 0.5, from: 11.08, to: 11.3, amp: 1.2, rate: 1 - cut * 0.12)}

    section(32,
      radio:
        at(
          [
            {0, sample(@problem, 4, from: 0.65, to: 1.9, amp: 1.3)},
            {6, sample(@problem, 3, from: 4.75, to: 6.0, amp: 1.2)},
            {11, sample(@problem, 3, from: 10.3, to: 11.3, amp: 1.3)}
          ] ++ slowing,
          32
        ),
      voice:
        at(
          [
            {16, landing(4, from: 0.0, to: 1.8, amp: 1.1)},
            {30, change({:voice, :echo}, mix: 0.55)},
            {30, landing(2, from: 2.05, to: 3.3, amp: 1.2)}
          ] ++ stutter,
          32
        ),
      sputnik: beeps(28, 0.15),
      glass: glasses(32, 0.16),
      bowed:
        seq([
          pad(hd(@chords)),
          pad(Enum.at(@chords, 1)),
          note([:f4, :bb4, :d5], 14, vel: 0.8)
        ]),
      vibes: note(hd(@chords).vibes, 8, vel: 0.5, strum: 0.08),
      frame: seq([repeat(hits("x....o...... x....o......", 0.6, 0.3), 4), rest(16)]),
      hat: seq([rest(16), repeat(hits("x..o..x..o.. x..o..x..o..", 0.4, 0.2), 3)]),
      kick: seq([rest(22), repeat(hits("x.....", 0.7, 0.4), 8)]),
      snare: at(roll, 32),
      rocket:
        at(
          [
            {16,
             sample(@liftoff, 14,
               from: 0.0,
               to: 6.1,
               rate: -1,
               amp: 0.4,
               attack: 12,
               sustain: 1.5,
               release: 0.5
             )}
          ],
          32
        ),
      turns:
        at(
          [
            {0, turn(@soft_gong, amp: 0.3)},
            {16, turn(@timpani, rate: 1.025, amp: 0.45, attack: 12, sustain: 1.7, release: 0.3)},
            {22, turn(@drum_swell, from: 3.1, to: 9.0, amp: 0.35)},
            {22, turn(@swell, amp: 0.35)}
          ],
          32
        )
    )
  end

  # The drop: the gong, the band with claps under the first step, and the second time round the marimba again and the hand chimes' melody over the glasses cut into eighths.
  def tranquility do
    section(
      64,
      [
        voice:
          at(
            [
              {2, change({:voice, :echo}, mix: 0.3)},
              {4, sample(@step, 6, from: 0.0, to: 2.4, amp: 1.3)},
              {16, sample(@step, 8, from: 3.4, to: 6.4, amp: 1.3)}
            ],
            64
          ),
        sputnik: beeps(64, 0.1),
        glass: glasses(32, 0.12),
        gate: seq([rest(32), glasses(32, 0.2)]),
        bass: repeat(cycle(&bass/1), 2),
        vibes: repeat(cycle(&comp/1), 2),
        marimba: seq([rest(32), cycle(&ostinato/1)]),
        lead: seq([rest(32), cycle(&lead/1)]),
        shaker: shaker(16),
        claps: claps(16),
        open_hat: seq([rest(32), open_hat(8)]),
        turns:
          at(
            [
              {0, turn(@gong, rate: 0.9325, amp: 0.5)},
              {0, turn(@crash, amp: 0.3)},
              {32, turn(@crash, amp: 0.25)}
            ],
            64
          ),
        tom: seq([fill(32), fill(32)])
      ] ++ groove(16)
    )
  end

  # The band stops on the gong, and the ocean, the glasses and Sputnik are left under "magnificent desolation" and Kennedy's last words.
  def home do
    [ab, bb, eb] = [Enum.at(@chords, 1), Enum.at(@chords, 3), Enum.at(@chords, 2)]

    section(40,
      ocean: ocean(40),
      glass: glasses(32, 0.16),
      sputnik: seq([beeps(16, 0.12), beeps(8, 0.1), beeps(8, 0.06)]),
      bowed: seq([pad(ab), pad(bb), note(eb.pad, 16, vel: 0.8)]),
      vibes:
        at(
          [
            {0, note(ab.vibes, 8, vel: 0.55, strum: 0.08)},
            {8, note(bb.vibes, 8, vel: 0.5, strum: 0.08)},
            {16, note(eb.vibes, 8, vel: 0.7, strum: 0.08)},
            {28, note([:eb4, :g4, :bb4, :f5], 8, vel: 0.6, strum: 0.15)}
          ],
          40
        ),
      bass:
        at(
          [
            {0, note([:ab1, :ab2], 4, vel: 0.9)},
            {8, note([:bb1, :bb2], 4, vel: 0.8)},
            {16, note([:eb2, :eb3], 4, vel: 0.8)}
          ],
          40
        ),
      voice:
        at(
          [
            {2, sample(@magnificent, 9, amp: 1.2)},
            {19, sample(@kennedy, 6, from: 9.15, to: 11.3, amp: 1.0)}
          ],
          40
        ),
      turns:
        at(
          [
            {0, turn(@soft_gong, amp: 0.3)},
            {0, turn(@crash, amp: 0.2)},
            {28, turn(@falling_chimes, amp: 0.25)}
          ],
          40
        )
    )
  end

  def form, do: [signal(), liftoff(), problem(), tranquility(), home()]

  # Each part's music, padded to the section's beats.
  def section(beats, parts) do
    together(
      for {name, music} <- parts do
        part(name, together([rest(beats), music]), Keyword.fetch!(@parts, name))
      end
    )
  end
end

song(tempo: 136, music: seq(TranquilityBase.form()))
