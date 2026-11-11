import Mx

# Bach's aria "Erbarme dich, mein Gott", BWV 244/39, as a roots dub on mx's measured synths.
# The aria's 12/8 bar is a reggae bar of four beats swung in triplets, so the ritornello's eight bars become the riddim: the double bass plucks the continuo's falling bass over a saw filtered round and dark, as a bass guitar with its tone rolled off plays it, the harp skanks on 2 and 4, and the organ bubbles, its left hand steady on the last triplet of each beat and its right hand chopping 2 and 4.
# The drum kit leads: the one drop, kick and rimshot together on beat 3 with beat 1 left empty, the rimshot's ghost strokes, the hi-hat riding the triplets and opening into the next bar, snare pickups and tom rolls.
# Under it the congas play the Nyabinghi drums of Rastafari, the thunder open on 1 and damped on 3, the funde's heartbeat on 2 and 4 and the repeater riding it, and the shaker and the güiro fill the triplets the hi-hat leaves.
# A dub siren and the hand drums open it, and a horn section of trumpet, tenor saxophone and trombone states the aria's opening sigh before the riddim drops.
# A trombone leads with the ritornello, slurring its runs as Rico Rodriguez and Vin Gordon played dub's trombone leads, the harmonium sings the alto's "Erbarme dich" as a melodica does in Augustus Pablo's dubs, and the horns sing it the second time.
# In the dubs the parts drop out and come back, the rimshot, harp, harmonium and horns are thrown into the echo, the harp and organ sweep through a high-pass filter as King Tubby's big knob did, the tabla's bayan bends down on the drop, and the tanpura drones on B while the bass is out.
# The notes come from the score beside this song, under CC BY 4.0, as LICENSE.md says.
defmodule Dub do
  import Mx

  # The chord on each of a ritornello bar's four beats, as its root, its quality and the continuo's bass note.
  @harmony [
    [{:b3, :minor, :b1}, {:b3, :minor, :a1}, {:g3, :major, :g1}, {:b3, :dom7, :fs1}],
    [{:e3, :minor, :e1}, {:b3, :dom7, :fs1}, {:e3, :minor, :e1}, {:e3, :minor, :g1}],
    [{:c3, :major, :e2}, {:e3, :minor7, :d2}, {:cs3, :dim7, :cs2}, {:fs3, :dom7, :as1}],
    [{:b3, :minor, :b1}, {:e3, :minor, :g1}, {:fs3, :dom7, :cs2}, {:fs3, :dom7, :as1}],
    [{:fs3, :dom7, :fs1}, {:fs3, :dom7, :fs2}, {:fs3, :dom7, :fs1}, {:fs3, :dom7, :fs2}],
    [{:b3, :dom7, :b1}, {:b3, :dom7, :b2}, {:b3, :dom7, :b1}, {:b3, :dom7, :b1}],
    [{:e3, :minor, :e1}, {:e3, :minor, :e1}, {:c3, :major, :e1}, {:cs3, :dim7, :e1}],
    [{:b3, :minor, :b1}, {:fs3, :dom7, :fs1}, {:b3, :minor, :b1}, {:b3, :minor, :b1}]
  ]

  @room [reverb: [room: 0.7, mix: 0.3]]

  @parts [
    kick: [synth: :kick, defaults: [amp: 1]],
    rimshot: [
      synth: :rimshot,
      defaults: [amp: 0.55],
      fx: [echo: [phase: 1, decay: 4, mix: 0.15]] ++ @room
    ],
    snare: [synth: :snare, defaults: [vel: 0.6], fx: [reverb: [room: 0.85, mix: 0.4]]],
    hihat: [synth: :closed_hihat, defaults: [pan: 0.3]],
    open_hihat: [synth: :open_hihat, defaults: [vel: 0.4, amp: 0.3, pan: 0.3, sustain: 0.5]],
    tom: [synth: :mid_tom, defaults: [vel: 0.6, amp: 0.6], fx: @room],
    crash: [synth: :crash, defaults: [vel: 0.5, amp: 0.35, pan: -0.2], fx: @room],
    thunder: [synth: :low_conga, defaults: [amp: 0.45, pan: -0.15]],
    funde: [synth: :mid_conga, defaults: [amp: 0.35, pan: 0.1]],
    repeater: [synth: :high_conga, defaults: [amp: 0.3, pan: 0.4], fx: @room],
    shaker: [synth: :shaker, defaults: [vel: 0.2, amp: 0.25, pan: -0.4]],
    guiro: [synth: :guiro, defaults: [vel: 0.25, amp: 0.6, pan: -0.45]],
    bass: [synth: :double_bass, defaults: [pizz: 1, vel: 0.8], fx: [lpf: [cutoff: 76]]],
    electric_bass: [
      synth: :saw,
      defaults: [amp: 0.4, cutoff: 64, res: 0.1, attack: 0.02, release: 0.15]
    ],
    organ: [
      synth: :organ,
      defaults: [amp: 0.3, pan: -0.3, release: 0.1],
      fx: [hpf: [cutoff: 0]]
    ],
    harp: [
      synth: :harp,
      defaults: [vel: 0.55, pan: 0.35, release: 0.1],
      fx: [
        hpf: [cutoff: 0],
        echo: [phase: 1, decay: 3, mix: 0.15],
        reverb: [room: 0.6, mix: 0.25]
      ]
    ],
    lead: [
      synth: :trombone,
      defaults: [vel: 0.65, note_slide: 0.06, pan: 0.15],
      fx: [echo: [phase: 1.5, decay: 6, mix: 0.25], reverb: [room: 0.8, mix: 0.35]]
    ],
    harmonium: [
      synth: :harmonium,
      defaults: [vel: 0.55, pan: -0.1],
      fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room
    ],
    trumpet: [
      synth: :trumpet,
      defaults: [vel: 0.6, amp: 0.8, pan: 0.2],
      fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room
    ],
    tenor_sax: [
      synth: :tenor_sax,
      defaults: [vel: 0.6, amp: 0.8, pan: -0.2],
      fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room
    ],
    trombone: [
      synth: :trombone,
      defaults: [vel: 0.6, amp: 0.7],
      fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room
    ],
    siren: [
      synth: :square,
      defaults: [amp: 0.07, cutoff: 92, note_slide: 0.4],
      fx: [echo: [phase: 0.75, decay: 4, mix: 0.4], reverb: [room: 0.8, mix: 0.4]]
    ],
    marimba: [
      synth: :marimba,
      defaults: [vel: 0.5, pan: -0.35],
      fx: [echo: [phase: 1.5, decay: 6, mix: 0.4], reverb: [room: 0.8, mix: 0.4]]
    ],
    tabla: [
      synth: :tabla_ghe,
      defaults: [vel: 0.8],
      fx: [echo: [phase: 1, decay: 4, mix: 0.35]] ++ @room
    ],
    tanpura: [
      synth: :tanpura,
      defaults: [vel: 0.45, release: 3],
      fx: [reverb: [room: 0.8, mix: 0.3]]
    ]
  ]

  @horns [:trumpet, :tenor_sax, :trombone]

  def play(name, music), do: part(name, music, Keyword.fetch!(@parts, name))

  # The horns in octaves: the trumpet at the melody's pitch, the saxophone and the trombone an octave below.
  def horns(music) do
    low = transpose(music, -12)
    [play(:trumpet, music), play(:tenor_sax, low), play(:trombone, low)]
  end

  # The parts thrown into the echo from one beat and brought back at another, within music of the given length.
  def throw(names, from, back, length) do
    entries =
      for name <- names,
          {beat, mix} <- [{from, 0.5}, {back, 0.15}],
          do: {beat, change({name, :echo}, mix: mix)}

    at(entries, length)
  end

  def beat(index), do: index * 1.5

  def bars(range, fun), do: seq(Enum.map(range, fun))

  def kick(:one_drop), do: at([{3, hit()}], 6)

  def kick(:steppers) do
    entries = for index <- 0..3, do: {beat(index), hit()}
    at(entries, 6)
  end

  # The rimshot on the drop, with ghost strokes around it that change from bar to bar.
  def rimshot(bar) do
    ghosts = ring([[5.5], [2, 4], [5, 5.5], [1, 4, 5.5]], bar - 1)
    ghosts = for offset <- ghosts, do: {offset, hit(amp: 0.15)}
    at(Enum.sort([{3, hit()} | ghosts]), 6)
  end

  # The ride on every triplet but the middle one of each beat, the beat itself softer than the swung note before the next.
  def hihat do
    entries =
      for index <- 0..3,
          {offset, amp} <- [{0, 0.22}, {1, 0.32}],
          do: {beat(index) + offset, hit(amp: amp)}

    at(entries, 6)
  end

  # The hi-hat opening on the last triplet of every other bar, into the next.
  def open_hihat(bar), do: if(rem(bar, 2) == 0, do: at([{5.5, hit()}], 6), else: rest(6))

  # A snare pickup into the second half of the riddim.
  def snare(4), do: at([{5, hit(vel: 0.4)}, {5.5, hit(vel: 0.7)}], 6)
  def snare(_bar), do: rest(6)

  # The roll closing the riddim: the tom down the triplets of beats 3 and 4.
  def roll do
    entries =
      for {note, step} <- Enum.with_index([55, 52, 50, 47, 45, 43]),
          do: {3 + step * 0.5, hit(note: note)}

    at(entries, 6)
  end

  def tom(8), do: roll()
  def tom(_bar), do: rest(6)

  def thunder, do: at([{0, hit(vel: 0.6)}, {3, hit(vel: 0.4, mute: 1)}], 6)

  # The funde's heartbeat: a damped stroke on the last triplet before beats 2 and 4, and an open one on them.
  def funde do
    at(
      [
        {1, hit(vel: 0.3, mute: 1)},
        {1.5, hit(vel: 0.45)},
        {4, hit(vel: 0.3, mute: 1)},
        {4.5, hit(vel: 0.45)}
      ],
      6
    )
  end

  # The repeater riding the heartbeat, slapping 2 and 4 and changing what it plays between them from bar to bar.
  def repeater(bar) do
    open = [vel: 0.5]
    mute = [vel: 0.35, mute: 1]
    slap = [vel: 0.6, slap: 1]

    strokes =
      ring(
        [
          [{1.5, slap}, {2.5, open}, {4.5, slap}, {5.5, mute}],
          [{1, mute}, {1.5, slap}, {4, open}, {4.5, slap}, {5, open}],
          [{1.5, slap}, {2, mute}, {2.5, mute}, {4.5, slap}, {5, open}, {5.5, open}],
          [{0.5, open}, {1.5, slap}, {3.5, mute}, {4.5, slap}, {5.5, slap}]
        ],
        bar - 1
      )

    entries = for {offset, options} <- strokes, do: {offset, hit(options)}
    at(entries, 6)
  end

  # The shaker on the middle triplet of each beat, the one the hi-hat leaves.
  def shaker do
    entries = for index <- 0..3, do: {beat(index) + 0.5, hit(up: 1)}
    at(entries, 6)
  end

  def guiro, do: at([{1, hit(sustain: 0.4)}, {4, hit(sustain: 0.4)}], 6)

  # The continuo's bass on beats 1, 2 and 4, and the bass of beat 3 around the drop instead of on it.
  def bass(bar) do
    [first, second, third, fourth] = for {_, _, bass} <- Enum.at(@harmony, bar - 1), do: bass

    at(
      [
        {0, note(first, 1)},
        {1.5, note(second, 0.5)},
        {2.5, note(third, 0.5)},
        {4, note(third, 0.5)},
        {4.5, note(fourth, 1.25)}
      ],
      6
    )
  end

  def skank(bar, length) do
    chords = Enum.at(@harmony, bar - 1)

    entries =
      for index <- [1, 3] do
        {root, quality, _} = Enum.at(chords, index)
        {beat(index), note(voice(chord(root, quality), from: 62, to: 74), length)}
      end

    at(entries, 6)
  end

  # The bubble's left hand: each beat's root and fifth on its last triplet.
  def bubble(bar) do
    entries =
      for {{root, _, _}, index} <- Enum.with_index(Enum.at(@harmony, bar - 1)) do
        root = pitch(root)
        {beat(index) + 1, note([root, root + 7], 0.3)}
      end

    together([at(entries, 6), skank(bar, 0.3)])
  end

  # The sound system's siren: a swoop up from B4 to B6, then a wail between B6 and F#6.
  def siren do
    wail =
      for {offset, index} <- Enum.with_index([1, 1.5, 2, 2.5, 3]),
          do: {offset, [note: if(rem(index, 2) == 0, do: :fs6, else: :b6)]}

    note(:b4, 4, changes: [{0.1, note: :b6} | wail] ++ [{3.5, note: :b4}])
  end

  # The bayan struck on the drop and bent down a fourth as it rings.
  def boom, do: at([{3, hit(note: 45, note_slide: 1, changes: [{0.1, note: 40}])}], 6)

  # The ritornello's melody, bar by bar, with each bar's pickup into the next at its end.
  def ritornello(1) do
    [d5: 0.75, cs5: 0.25, b4: 0.5, b4: 0.75, as4: 0.25, b4: 0.5, b4: 2.5, b4: 0.5]
  end

  def ritornello(2) do
    [
      g5: 0.75,
      fs5: 0.125,
      g5: 0.125,
      a5: 1.25,
      g5: 0.25,
      fs5: 0.5,
      e5: 2.25,
      g5: 0.25,
      e5: 0.5
    ]
  end

  def ritornello(3) do
    [
      c5: 0.75,
      g5: 0.25,
      e5: 0.5,
      b4: 0.75,
      g5: 0.25,
      e5: 0.5,
      as4: 0.75,
      e5: 0.125,
      fs5: 0.125,
      g5: 1.25,
      fs5: 0.25,
      e5: 0.5
    ]
  end

  def ritornello(4) do
    [
      d5: 0.75,
      cs5: 0.125,
      d5: 0.125,
      e5: 1.25,
      d5: 0.25,
      cs5: 0.5,
      as4: 1.5,
      as4: 0.75,
      fs4: 0.25,
      as4: 0.25,
      cs5: 0.25
    ]
  end

  def ritornello(5) do
    [
      e5: 0.125,
      d5: 0.125,
      cs5: 0.25,
      b4: 0.5,
      as4: 0.25,
      b4: 0.25,
      cs5: 0.125,
      b4: 0.125,
      as4: 0.25,
      g4: 0.5,
      fs4: 0.25,
      g4: 0.25,
      g4: 0.125,
      fs4: 0.125,
      e4: 0.25,
      as4: 0.75,
      g4: 0.125,
      fs4: 0.125,
      g4: 0.125,
      fs4: 0.125,
      e4: 0.25,
      cs5: 0.75,
      fs4: 0.125,
      e4: 0.125
    ]
  end

  def ritornello(6) do
    [
      fs4: 0.125,
      e4: 0.125,
      ds4: 0.25,
      c4: 0.5,
      b3: 0.25,
      a4: 0.125,
      g4: 0.125,
      a4: 0.125,
      g4: 0.125,
      fs4: 0.25,
      e4: 0.5,
      ds4: 0.25,
      c5: 0.125,
      b4: 0.125,
      c5: 0.125,
      b4: 0.125,
      a4: 0.25,
      g4: 0.5,
      fs4: 0.25,
      fs5: 0.125,
      e5: 0.125,
      fs5: 0.125,
      e5: 0.125,
      ds5: 0.25,
      c5: 0.5,
      b4: 0.25,
      fs5: 0.25
    ]
  end

  def ritornello(7) do
    [
      g5: 0.125,
      a5: 0.125,
      b5: 0.5,
      a5: 0.125,
      g5: 0.125,
      a5: 0.125,
      g5: 0.125,
      fs5: 0.25,
      e5: 0.125,
      fs5: 0.125,
      g5: 0.5,
      fs5: 0.125,
      e5: 0.125,
      fs5: 0.125,
      e5: 0.125,
      d5: 0.25,
      c5: 0.125,
      d5: 0.125,
      e5: 0.5,
      d5: 0.125,
      c5: 0.125,
      d5: 0.125,
      c5: 0.125,
      b4: 0.25,
      as4: 0.125,
      b4: 0.125,
      cs5: 0.5,
      b4: 0.125,
      as4: 0.125,
      b4: 0.125,
      as4: 0.125,
      gs4: 0.25
    ]
  end

  def ritornello(8) do
    [
      fs4: 0.75,
      gs4: 0.125,
      as4: 0.125,
      b4: 0.125,
      cs5: 0.125,
      d5: 0.125,
      cs5: 0.125,
      e5: 0.5,
      d5: 0.5,
      cs5: 0.5,
      b4: 2.5,
      r: 0.5
    ]
  end

  # The ritornello on the trombone an octave down, each run of different notes slurred into one held note that slides between them.
  def lead(bar), do: slur(ritornello(bar))

  def slur(notes) do
    {notes, _} =
      Enum.map_reduce(notes, 0, fn {name, beats}, onset ->
        {{name, beats, onset}, onset + beats}
      end)

    notes
    |> Enum.chunk_while([], &run/2, fn
      [] -> {:cont, []}
      run -> {:cont, Enum.reverse(run), []}
    end)
    |> Enum.map(&held/1)
    |> seq()
  end

  # A rest, a repeated note or a note on the beat starts a new note, as the player tongues it.
  defp run(item, []), do: {:cont, [item]}

  defp run({name, _, onset} = item, [{last, _, _} | _] = run) do
    if :r in [name, last] or name == last or rem(round(onset * 8), 12) == 0 do
      {:cont, Enum.reverse(run), [item]}
    else
      {:cont, [item | run]}
    end
  end

  defp held([{:r, length, _}]), do: rest(length)

  defp held([{first, length, _} | others]) do
    {changes, total} =
      Enum.map_reduce(others, length, fn {name, beats, _}, beat ->
        {{beat, note: pitch(name) - 12}, beat + beats}
      end)

    note(pitch(first) - 12, total, changes: changes)
  end

  # The alto's first phrase, "Erbarme dich, mein Gott, um meiner Zähren willen", bars 9 to 12, over the ritornello's first four bars.
  def alto do
    seq(
      d5: 0.75,
      cs5: 0.25,
      b4: 1.25,
      as4: 0.25,
      b4: 0.5,
      b4: 3,
      b4: 1,
      e4: 0.5,
      e4: 0.5,
      ds4: 0.5,
      a4: 0.5,
      g4: 1,
      fs4: 0.5,
      g4: 1,
      b4: 0.5,
      c5: 1,
      b4: 0.5,
      b4: 1,
      as4: 0.5,
      as4: 1,
      b4: 0.5,
      cs5: 2.25,
      as4: 0.25,
      b4: 0.5,
      cs5: 0.25,
      d5: 0.25,
      e5: 0.5,
      cs5: 0.5,
      as4: 1,
      gs4: 0.5,
      fs4: 1,
      e4: 0.5
    )
  end

  def sigh, do: seq(b4: 0.75, as4: 0.25, b4: 0.5)

  # The aria's opening sigh, as the horns state it in the intro.
  def motto, do: seq(d5: 0.75, cs5: 0.25, b4: 0.5, b4: 0.75, as4: 0.25, b4: 0.5, b4: 3)

  def pickup(note, length), do: at([{length - 0.5, note(note, 0.5)}], length)

  def kit(range) do
    [
      play(:kick, bars(range, fn _ -> kick(:one_drop) end)),
      play(:rimshot, bars(range, &rimshot/1)),
      play(:snare, bars(range, &snare/1)),
      play(:tom, bars(range, &tom/1)),
      play(:hihat, bars(range, fn _ -> hihat() end)),
      play(:open_hihat, bars(range, &open_hihat/1)),
      play(:crash, at([{0, hit()}], 6 * Enum.count(range)))
    ]
  end

  def hand_drums(range) do
    [
      play(:thunder, bars(range, fn _ -> thunder() end)),
      play(:funde, bars(range, fn _ -> funde() end)),
      play(:repeater, bars(range, &repeater/1)),
      play(:shaker, bars(range, fn _ -> shaker() end)),
      play(:guiro, bars(range, fn _ -> guiro() end))
    ]
  end

  def band(range) do
    [
      play(:bass, bars(range, &bass/1)),
      play(:electric_bass, bars(range, &bass/1)),
      play(:organ, bars(range, &bubble/1)),
      play(:harp, bars(range, &skank(&1, 0.25)))
    ]
  end

  def riddim, do: kit(1..8) ++ hand_drums(1..8) ++ band(1..8)

  # The siren and the hand drums, then the one drop and the bass in the echo, the horns' motto, and a tom roll into the riddim.
  def section(:intro) do
    together(
      [
        play(:siren, at([{0, siren()}, {18, siren()}], 24)),
        play(:thunder, bars(1..4, fn _ -> thunder() end)),
        play(:funde, bars(1..4, fn _ -> funde() end)),
        play(:repeater, seq([rest(6), bars(2..4, &repeater/1)])),
        play(:tabla, boom()),
        play(:kick, seq([rest(6), bars(2..4, fn _ -> kick(:one_drop) end)])),
        play(
          :rimshot,
          together([seq([rest(6), bars(2..4, &rimshot/1)]), throw([:rimshot], 6, 21, 24)])
        ),
        play(:hihat, seq([rest(12), bars(3..4, fn _ -> hihat() end)])),
        play(:open_hihat, seq([rest(12), open_hihat(2), rest(6)])),
        play(:tom, seq([rest(18), roll()])),
        play(:bass, seq([rest(6), bass(1), bass(1), bass(8)])),
        play(:electric_bass, seq([rest(6), bass(1), bass(1), bass(8)])),
        play(:lead, pickup(:fs3, 24))
      ] ++ horns(seq([rest(12), motto()]))
    )
  end

  def section(:riddim) do
    together(riddim() ++ [play(:lead, bars(1..8, &lead/1)), play(:harmonium, pickup(:fs4, 48))])
  end

  # The harmonium sings the alto's phrase and the lead trombone answers with the ritornello's second half.
  def section(:verse) do
    together(
      riddim() ++
        [
          play(:harmonium, seq([alto(), rest(24)])),
          play(:lead, seq([rest(24), bars(5..8, &lead/1)]))
        ]
    )
  end

  # The horns sing the alto's phrase the second time.
  def section(:horn_verse) do
    together(
      riddim() ++
        horns(seq([alto(), rest(24)])) ++
        [play(:lead, seq([rest(24), bars(5..8, &lead/1)]))]
    )
  end

  # Drums and bass with the rimshot in the echo, then the bass and kick drop out for the hand drums, the tanpura, the siren and the harp sweeping up through the filter, and the band comes back stepping with the organ sweeping down.
  def section(:dub) do
    out = fn music -> seq([music.(1..4), rest(12), music.(7..8)]) end

    together(
      [
        play(
          :kick,
          seq([
            bars(1..4, fn _ -> kick(:one_drop) end),
            rest(12),
            bars(7..8, fn _ -> kick(:steppers) end)
          ])
        ),
        play(:rimshot, together([bars(1..8, &rimshot/1), throw([:rimshot], 0, 42, 48)])),
        play(
          :snare,
          at(
            [
              {21, hit(vel: 0.55)},
              {34.5, hit(vel: 0.3)},
              {35, hit(vel: 0.5)},
              {35.5, hit(vel: 0.7)}
            ],
            48
          )
        ),
        play(:tom, seq([rest(42), roll()])),
        play(:hihat, out.(&bars(&1, fn _ -> hihat() end))),
        play(:open_hihat, out.(&bars(&1, fn bar -> open_hihat(bar) end))),
        play(:crash, at([{36, hit()}], 48)),
        play(:thunder, bars(1..8, fn _ -> thunder() end)),
        play(:funde, bars(1..8, fn _ -> funde() end)),
        play(:repeater, bars(1..8, &repeater/1)),
        play(:shaker, seq([rest(24), bars(5..8, fn _ -> shaker() end)])),
        play(:guiro, seq([rest(36), bars(7..8, fn _ -> guiro() end)])),
        play(:bass, out.(&bars(&1, fn bar -> bass(bar) end))),
        play(:electric_bass, out.(&bars(&1, fn bar -> bass(bar) end))),
        play(
          :organ,
          together([
            seq([rest(36), bars(7..8, &bubble/1)]),
            at(
              [
                {35, change({:organ, :hpf}, cutoff: 100, cutoff_slide: 0)},
                {36, change({:organ, :hpf}, cutoff: 0, cutoff_slide: 12)}
              ],
              48
            )
          ])
        ),
        play(
          :harp,
          together([
            seq([rest(12), bars(3..8, &skank(&1, 0.25))]),
            throw([:harp], 12, 36, 48),
            at(
              [
                {12, change({:harp, :hpf}, cutoff: 92, cutoff_slide: 18)},
                {30, change({:harp, :hpf}, cutoff: 0, cutoff_slide: 6)}
              ],
              48
            )
          ])
        ),
        play(
          :harmonium,
          together([
            at([{6, seq(d5: 0.75, cs5: 0.25, b4: 1.25)}], 48),
            throw([:harmonium], 6, 18, 48)
          ])
        ),
        play(:tabla, seq([bars(1..6, fn _ -> boom() end), rest(12)])),
        play(:tanpura, seq([rest(24), note(:b2, 12), rest(12)])),
        play(:siren, at([{28, siren()}], 48)),
        play(:marimba, at([{25.5, sigh()}, {31.5, sigh()}], 48))
      ] ++ horns(pickup(:fs4, 48))
    )
  end

  # The riddim's second half stepping, with the horns' phrases thrown into the echo and the organ swept up through the filter.
  def section(:horn_dub) do
    range = 5..8

    together(
      [
        play(:kick, bars(range, fn _ -> kick(:steppers) end)),
        play(:rimshot, together([bars(range, &rimshot/1), throw([:rimshot], 0, 21, 24)])),
        play(:tom, bars(range, &tom/1)),
        play(:hihat, bars(range, fn _ -> hihat() end)),
        play(:open_hihat, bars(range, &open_hihat/1)),
        play(:bass, seq([bass(5), bass(6), rest(6), bass(8)])),
        play(:electric_bass, seq([bass(5), bass(6), rest(6), bass(8)])),
        play(
          :organ,
          together([
            bars(range, &bubble/1),
            at(
              [
                {0, change({:organ, :hpf}, cutoff: 96, cutoff_slide: 12)},
                {12, change({:organ, :hpf}, cutoff: 0, cutoff_slide: 0.5)}
              ],
              24
            )
          ])
        ),
        play(:harp, bars(range, &skank(&1, 0.25))),
        play(:siren, together([at([{18, siren()}], 24), throw(@horns, 0, 22, 24)]))
      ] ++
        hand_drums(range) ++
        horns(
          at([{0, seq(as4: 1, b4: 0.5, cs5: 3)}, {12, seq(g4: 1, fs4: 0.5, g4: 1, b4: 0.5)}], 24)
        )
    )
  end

  # The last two bars of the riddim, then B held by the horns over the tanpura while the echoes die away.
  def section(:outro) do
    together([
      play(:kick, seq([kick(:one_drop), kick(:one_drop), rest(12)])),
      play(:rimshot, seq([rimshot(7), rimshot(8), rest(12)])),
      play(:tom, seq([rest(6), roll(), rest(12)])),
      play(:hihat, seq([hihat(), hihat(), rest(12)])),
      play(:crash, at([{12, hit(vel: 0.6)}], 24)),
      play(:thunder, seq([thunder(), thunder(), at([{0, hit(vel: 0.7)}], 12)])),
      play(:funde, seq([funde(), funde(), rest(12)])),
      play(:repeater, seq([repeater(7), repeater(8), rest(12)])),
      play(:bass, seq([bass(7), bass(8), note(:b1, 8)])),
      play(:electric_bass, seq([bass(7), bass(8), note(:b1, 8)])),
      play(:organ, seq([bubble(7), bubble(8), rest(12)])),
      play(
        :harp,
        seq([
          skank(7, 0.25),
          skank(8, 0.25),
          note(voice(chord(:b3, :minor), from: 62, to: 74), 4)
        ])
      ),
      play(:trumpet, seq([rest(12), note(:d5, 6)])),
      play(:tenor_sax, seq([rest(12), note(:fs4, 6)])),
      play(:trombone, seq([rest(12), note(:b3, 6)])),
      play(:tanpura, seq([rest(12), note(:b2, 12)])),
      play(:marimba, at([{19.5, sigh()}], 24))
    ])
  end
end

song(
  tempo: 104,
  music:
    seq(Enum.map([:intro, :riddim, :verse, :dub, :horn_verse, :horn_dub, :outro], &Dub.section/1))
)
