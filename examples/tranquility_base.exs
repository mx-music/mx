import Mx

# Tranquility Base, a piece made only of public recordings, at 136 bpm, where Sputnik's beep, every 0.44 seconds, falls on the beat.
# VCSL's mbira dzaVadzimu plays two interlocking lines, kushaura and kutsinhira, the second a pulse of a triplet behind the first, through the four phrases of three chords Andrew Tracey described as the cycle of Shona mbira music: on 1, 3 and 5, then 1, 3 and 6, 1, 4 and 6, and 2, 4 and 6, in B with A natural.
# VCSL's hi-hat plays the triplets as hosho, the gourd shakers beside the mbira, with its bass drum, snare and frame drum, each choosing strengths and alternating takes; its ocean drum and wine glasses lie underneath.
# NASA's recordings are cut over it: the Apollo 11 landing, liftoff and first step, Apollo 13's problem stuttered in slices, and Sputnik.
# VCSL is Versilian Studios' Versilian Community Sample Library, under Creative Commons 0, downloaded with mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones" and the same for Membranophones
# NASA's recordings are in the folder beside this file, from https://nssdc.gsfc.nasa.gov/planetary/sound/index.html, courtesy of NASA.
defmodule TranquilityBase do
  import Mx

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"

  # A third of a beat, one pulse of the triplets the mbira and hosho play in.
  @pulse 1 / 3
  @cycle 16

  # The scale in semitones above B, with A natural, and the roots of the cycle's twelve chords as its degrees.
  @steps [0, 2, 4, 5, 7, 9, 10]
  @roots [1, 3, 5, 1, 3, 6, 1, 4, 6, 2, 4, 6]

  def vcsl(path), do: {:github, @repo, @commit, path}
  def nasa(file), do: Path.expand("tranquility_base/#{file}", __DIR__)

  def mbira,
    do: sampled(vcsl("Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B"))

  def kick, do: sampled(vcsl("Membranophones/Struck Membranophones/Bass Drum 1"))

  def snare do
    for v <- [3, 5, 6, 7, 9],
        rr <- [1, 2],
        do:
          vcsl(
            "Membranophones/Struck Membranophones/Snare Drum, Modern 1/Snare2_HitSN_v#{v}_rr#{rr}_Mid.wav"
          )
  end

  def hat do
    for v <- [2, 3, 4],
        rr <- [1, 2],
        do: vcsl("Idiophones/Struck Idiophones/Hi-Hat Cymbal/HiHat_HitC_v#{v}_rr#{rr}_Mid.wav")
  end

  def frame do
    for v <- [2, 3],
        rr <- [1, 2],
        do:
          vcsl("Membranophones/Struck Membranophones/Frame Drum/HDrumL_Hit_v#{v}_rr#{rr}_Sum.wav")
  end

  # A degree of the scale as a note, from B2 for the bass and B3 for the treble.
  defp pitch(degree, b) do
    b + 12 * div(degree - 1, 7) + Enum.at(@steps, rem(degree - 1, 7))
  end

  # Each chord lasts four pulses; kushaura strikes its root low on the first and its third high on the third, and with `lead` its fifth on the fourth.
  def kushaura(lead) do
    notes =
      for {root, i} <- Enum.with_index(@roots), at = 4 * i * @pulse do
        [
          {at, note(pitch(root, 47), 0, vel: 0.9)},
          {at + 2 * @pulse, note(pitch(root + 2, 59), 0, vel: 0.7)}
        ] ++
          if(lead, do: [{at + 3 * @pulse, note(pitch(root + 4, 59), 0, vel: 0.6)}], else: [])
      end

    at(List.flatten(notes), @cycle)
  end

  # Kutsinhira answers a pulse behind: the chord's fifth low on the second pulse, its root high on the fourth.
  def kutsinhira do
    notes =
      for {root, i} <- Enum.with_index(@roots), at = 4 * i * @pulse do
        [
          {at + @pulse, note(pitch(root + 4, 47), 0, vel: 0.8)},
          {at + 3 * @pulse, note(pitch(root, 59), 0, vel: 0.65)}
        ]
      end

    at(List.flatten(notes), @cycle)
  end

  # Hosho on the hi-hat: three strokes a beat, the first strongest and the third answering it.
  def hosho(soft) do
    vels = if soft, do: [0.5, 0.2, 0.35], else: [0.95, 0.4, 0.7]
    at(for(pulse <- 0..47, do: {pulse * @pulse, hit(vel: Enum.at(vels, rem(pulse, 3)))}), @cycle)
  end

  # The bass drum on the first and third beats of each bar, with a pickup into every second bar.
  def kicks do
    hits =
      for bar <- 0..3,
          {beat, vel} <-
            [{0, 1}, {2, 0.8}] ++ if(rem(bar, 2) == 0, do: [{3 + 2 * @pulse, 0.5}], else: []),
          do: {bar * 4 + beat, hit(vel: vel)}

    at(hits, @cycle)
  end

  # The snare on the second and fourth beats, with a ghost stroke before the fourth.
  def snares do
    hits =
      for bar <- 0..3,
          {beat, vel} <- [{1, 0.85}, {3 - @pulse, 0.15}, {3, 0.95}],
          do: {bar * 4 + beat, hit(vel: vel)}

    at(hits, @cycle)
  end

  # The frame drum crossing the beat, two strokes against every three pulses' worth of triplets.
  def frames do
    at(
      for(
        bar <- 0..3,
        pulse <- [0, 5, 7, 10],
        do: {bar * 4 + pulse * @pulse, hit(vel: if(pulse == 0, do: 0.9, else: 0.4))}
      ),
      @cycle
    )
  end

  # Sputnik's beep, one period cut from the recording and fitted to a beat.
  def sputnik(beats, amp),
    do:
      seq(
        for _ <- 1..beats,
            do: sample(nasa("sputnik.wav"), 1, from: 0.0, to: 0.4366, beats: 1, amp: amp)
      )

  def ocean(amp),
    do:
      sample(
        vcsl("Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_1_Mid.wav"),
        @cycle,
        to: 14.0,
        normalize: true,
        amp: amp,
        attack: 4,
        release: 4
      )

  def glasses(amp) do
    together([
      sample(
        vcsl(
          "Idiophones/Friction Idiophones/Wine Glasses/Sustains/Slow/glass1_D#4_Slow_1_Main.wav"
        ),
        @cycle,
        to: 7.0,
        normalize: true,
        amp: amp,
        attack: 3,
        release: 4
      ),
      at(
        [
          {8,
           sample(
             vcsl(
               "Idiophones/Friction Idiophones/Wine Glasses/Sustains/Slow/glass2_F#4_Slow_1_Main.wav"
             ),
             8,
             to: 3.5,
             normalize: true,
             amp: amp,
             attack: 2,
             release: 3
           )}
        ],
        @cycle
      )
    ])
  end

  def landing, do: at([{4, sample(nasa("a11landing.aiff"), 8, amp: 0.7)}], @cycle)

  def eagle,
    do:
      at(
        [
          {2, sample(nasa("a11landing.aiff"), 4, from: 2.0, to: 3.589, amp: 0.7)},
          {10, sample(nasa("a11landing.aiff"), 4, from: 2.0, to: 3.589, amp: 0.3)}
        ],
        @cycle
      )

  def liftoff,
    do:
      at(
        [
          {8,
           sample(nasa("a11liftoff.aiff"), 8,
             from: 3.0,
             to: 6.8,
             amp: 0.25,
             attack: 3,
             release: 1
           )}
        ],
        @cycle
      )

  def step, do: sample(nasa("a11step.aiff"), @cycle, amp: 0.7)

  # Apollo 13's call cut in four slices, each fitted to a beat; the first slice stutters before the whole call plays.
  def problem do
    slice = fn n, amp ->
      sample(nasa("apollo_13_problem.wav"), 1,
        from: 0.0,
        to: 1.6,
        slices: 4,
        slice: n,
        beats: 1,
        amp: amp
      )
    end

    at(
      [
        {4, slice.(0, 0.7)},
        {5, slice.(0, 0.55)},
        {6, slice.(0, 0.45)},
        {8, seq(for n <- 0..3, do: slice.(n, 0.7))}
      ],
      @cycle
    )
  end

  def section(parts), do: together(Enum.map(parts, fn {name, music} -> play(name, music) end))

  defp play(:kushaura, music),
    do:
      part(:kushaura, music,
        synth: mbira(),
        defaults: [amp: 2.5, pan: -0.3, sustain: 3, release: 1],
        fx: [reverb: [room: 0.5, mix: 0.25]]
      )

  defp play(:kutsinhira, music),
    do:
      part(:kutsinhira, music,
        synth: mbira(),
        defaults: [amp: 2.5, pan: 0.3, sustain: 3, release: 1],
        fx: [reverb: [room: 0.5, mix: 0.25]]
      )

  defp play(:kick, music),
    do: part(:kick, music, synth: kick(), defaults: [amp: 0.7, sustain: 1, release: 1])

  defp play(:snare, music),
    do:
      part(:snare, music,
        synth: sampled(snare()),
        defaults: [amp: 0.4, sustain: 0.5, release: 0.5],
        fx: [reverb: [room: 0.4, mix: 0.2]]
      )

  defp play(:hat, music),
    do:
      part(:hat, music,
        synth: sampled(hat()),
        defaults: [amp: 0.5, pan: 0.2, sustain: 0.25, release: 0.25]
      )

  defp play(:frame, music),
    do:
      part(:frame, music,
        synth: sampled(frame()),
        defaults: [amp: 0.6, pan: -0.2, sustain: 1, release: 0.5]
      )

  defp play(:space, music), do: part(:space, music, fx: [reverb: [room: 0.9, mix: 0.5]])

  defp play(:sputnik, music),
    do: part(:sputnik, music, fx: [echo: [phase: 0.75, decay: 4, mix: 0.3]])

  defp play(:voice, music),
    do:
      part(:voice, music,
        fx: [echo: [phase: 1.5, decay: 6, mix: 0.3], reverb: [room: 0.7, mix: 0.3]]
      )
end

alias TranquilityBase, as: T

song(
  tempo: 136,
  music:
    seq([
      T.section(
        space: together([T.ocean(0.12), T.glasses(0.1)]),
        sputnik: T.sputnik(16, 0.25),
        kushaura: T.kushaura(false)
      ),
      T.section(
        space: T.ocean(0.1),
        sputnik: T.sputnik(8, 0.2),
        kushaura: T.kushaura(false),
        kutsinhira: T.kutsinhira(),
        voice: T.landing()
      ),
      T.section(
        kushaura: T.kushaura(false),
        kutsinhira: T.kutsinhira(),
        hat: T.hosho(true),
        voice: T.liftoff()
      ),
      T.section(
        kushaura: T.kushaura(false),
        kutsinhira: T.kutsinhira(),
        hat: T.hosho(false),
        kick: T.kicks(),
        snare: T.snares()
      ),
      T.section(
        kushaura: T.kushaura(true),
        kutsinhira: T.kutsinhira(),
        hat: T.hosho(false),
        kick: T.kicks(),
        snare: T.snares(),
        frame: T.frames(),
        voice: T.problem()
      ),
      T.section(
        kushaura: T.kushaura(true),
        kutsinhira: T.kutsinhira(),
        hat: T.hosho(false),
        kick: T.kicks(),
        snare: T.snares(),
        frame: T.frames(),
        voice: T.step()
      ),
      T.section(
        space: T.glasses(0.1),
        kushaura: T.kushaura(false),
        kutsinhira: T.kutsinhira(),
        hat: T.hosho(true),
        frame: T.frames(),
        voice: T.eagle()
      ),
      T.section(
        space: together([T.ocean(0.1), T.glasses(0.08)]),
        sputnik: T.sputnik(16, 0.2),
        kushaura: T.kushaura(false)
      )
    ])
)
