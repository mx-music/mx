import Mx

# Tranquility Base, a piece made only of public recordings, at 136 bpm, where Sputnik's beep, every 0.44 seconds, falls on the beat.
# VCSL's bass drum, snare, hi-hat and frame drum keep time, each choosing strengths and alternating takes, and its ocean drum and wine glasses hold the ground.
# NASA's recordings are cut up over it: the Apollo 11 landing stuttered, slowed and reversed, liftoff reversed, the first step, Apollo 13's problem, and Sputnik.
# VCSL is Versilian Studios' Versilian Community Sample Library, under Creative Commons 0, downloaded with mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones" and the same for Membranophones
# NASA's recordings are in the folder beside this file, from https://nssdc.gsfc.nasa.gov/planetary/sound/index.html, courtesy of NASA.
defmodule TranquilityBase do
  import Mx

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
  @drums "Membranophones/Struck Membranophones"
  @cymbals "Idiophones/Struck Idiophones/Hi-Hat Cymbal"
  @glasses "Idiophones/Friction Idiophones/Wine Glasses/Sustains/Slow"

  vcsl = fn path -> {:github, @repo, @commit, path} end

  @kick vcsl.("#{@drums}/Bass Drum 1")
  @snare for v <- [3, 5, 6],
             rr <- [1, 2],
             do: vcsl.("#{@drums}/Snare Drum, Modern 1/Snare2_HitSN_v#{v}_rr#{rr}_Mid.wav")
  # The softest hi-hat stroke was recorded once.
  @hat [vcsl.("#{@cymbals}/HiHat_HitC_v1_rr1_Mid.wav")] ++
         for(
           v <- [2, 3, 4],
           rr <- [1, 2],
           do: vcsl.("#{@cymbals}/HiHat_HitC_v#{v}_rr#{rr}_Mid.wav")
         )
  @frame for v <- [2, 3],
             rr <- [1, 2],
             do: vcsl.("#{@drums}/Frame Drum/HDrumL_Hit_v#{v}_rr#{rr}_Sum.wav")
  @ocean vcsl.("Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_1_Mid.wav")
  @glass_fs4 vcsl.("#{@glasses}/glass2_F#4_Slow_1_Main.wav")
  @glass_ds4 vcsl.("#{@glasses}/glass1_D#4_Slow_1_Main.wav")

  @nasa Path.expand("tranquility_base", __DIR__)
  @sputnik Path.join(@nasa, "sputnik.wav")
  @landing Path.join(@nasa, "a11landing.aiff")
  @liftoff Path.join(@nasa, "a11liftoff.aiff")
  @step Path.join(@nasa, "a11step.aiff")
  @problem Path.join(@nasa, "apollo_13_problem.wav")

  # A bar of drum hits, each character a sixth of a beat: x loud, o soft, a dot silent.
  def hits(pattern, loud, soft) do
    steps = pattern |> String.replace(" ", "") |> String.graphemes()

    hits =
      for {c, i} <- Enum.with_index(steps),
          c != ".",
          do: {i / 6, hit(vel: if(c == "x", do: loud, else: soft))}

    at(hits, length(steps) / 6)
  end

  def groove(bars) do
    [
      kick: repeat(hits("x.....x..... x.....o.....", 0.9, 0.4), bars),
      snare: repeat(hits("............ x...........", 0.8, 0.4), bars),
      hat: repeat(hits("x.ox.ox.ox.o x.ox.ox.ox.o", 0.5, 0.25), bars),
      frame: repeat(hits("..x..o..x.o. ..x..o..xox.", 0.7, 0.35), bars)
    ]
  end

  # Sputnik's beep, one stretch of four of its periods fitted to a bar.
  def beeps(beats, amp),
    do:
      seq(
        for _ <- 1..div(beats, 4),
            do: sample(@sputnik, 4, from: 0.3, to: 2.06, beats: 4, amp: amp)
      )

  def ocean(beats),
    do:
      sample(@ocean, beats,
        normalize: true,
        amp: 0.43,
        attack: 4,
        sustain: beats - 8,
        release: 4
      )

  # The two wine glasses, tuned down to E4 and C4.
  def glasses(beats) do
    together([
      sample(@glass_fs4, beats,
        rate: :math.pow(2, -2 / 12),
        normalize: true,
        amp: 0.15,
        attack: 6,
        release: 4,
        pan: -0.3
      ),
      sample(@glass_ds4, beats,
        rate: :math.pow(2, -3 / 12),
        normalize: true,
        amp: 0.2,
        attack: 8,
        release: 4,
        pan: 0.3
      )
    ])
  end

  def landing(beats, opts \\ []), do: sample(@landing, beats, opts)
  def eagle(beats, opts), do: landing(beats, [from: 2.0, to: 3.4] ++ opts)

  def intro do
    section(
      ocean: ocean(32),
      glass: glasses(32),
      sputnik: beeps(32, 0.25),
      voice: at([{16, landing(16, amp: 0.9)}], 32)
    )
  end

  def first do
    section(
      [
        sputnik: beeps(32, 0.12),
        voice: at([{28, eagle(4, amp: 0.9)}], 32)
      ] ++ groove(8)
    )
  end

  # The drop: "The Eagle has landed" cut and repeated, pitched down, then played backwards, over liftoff backwards.
  def drop do
    stutter =
      for i <- 0..7,
          do: {i * 0.5, landing(0.5, from: 2.0, to: 2.3, amp: 0.8, rate: 1 - i * 0.05)}

    section(
      voice:
        at(
          stutter ++
            [{4, eagle(4, amp: 0.9, rate: 0.7)}, {10, landing(6, amp: 0.7, rate: -1)}],
          16
        ),
      liftoff: sample(@liftoff, 16, rate: -0.9, amp: 0.6, attack: 6)
    )
  end

  def second do
    section(
      [
        voice:
          at(
            [
              {0, sample(@step, 16, amp: 0.8)},
              {20, sample(@problem, 4, from: 0.0, to: 3.0, amp: 0.8)},
              {24, sample(@problem, 2, from: 1.0, to: 2.0, amp: 0.7)},
              {26, sample(@problem, 2, from: 1.0, to: 2.0, amp: 0.6, rate: 0.8)}
            ],
            32
          )
      ] ++ groove(8)
    )
  end

  def outro do
    section(
      ocean: ocean(32),
      glass: glasses(32),
      sputnik: beeps(16, 0.2)
    )
  end

  def section(parts), do: together(Enum.map(parts, fn {name, music} -> play(name, music) end))

  defp play(:kick, music),
    do: part(:kick, music, synth: sampled(@kick), defaults: [amp: 0.6, sustain: 1, release: 1])

  defp play(:snare, music),
    do: part(:snare, music, synth: sampled(@snare), defaults: [amp: 0.6, sustain: 1, release: 1])

  defp play(:hat, music),
    do:
      part(:hat, music,
        synth: sampled(@hat),
        defaults: [amp: 0.6, sustain: 1, release: 1],
        fx: [hpf: [cutoff: 80]]
      )

  defp play(:frame, music),
    do:
      part(:frame, music,
        synth: sampled(@frame),
        defaults: [amp: 0.6, sustain: 1, release: 1],
        fx: [reverb: [room: 0.5, mix: 0.25]]
      )

  defp play(:ocean, music), do: part(:ocean, music)
  defp play(:glass, music), do: part(:glass, music, fx: [reverb: [room: 0.9, mix: 0.4]])
  defp play(:liftoff, music), do: part(:liftoff, music, fx: [reverb: [room: 0.9, mix: 0.4]])

  defp play(:sputnik, music),
    do: part(:sputnik, music, fx: [lpf: [cutoff: 100], echo: [phase: 1.5, decay: 4, mix: 0.25]])

  defp play(:voice, music),
    do:
      part(:voice, music,
        fx: [
          hpf: [cutoff: 50],
          echo: [phase: 0.75, decay: 6, mix: 0.3],
          reverb: [room: 0.7, mix: 0.3]
        ]
      )
end

alias TranquilityBase, as: T

song(tempo: 136, music: seq([T.intro(), T.first(), T.drop(), T.second(), T.outro()]))
