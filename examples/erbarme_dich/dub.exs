defmodule Dub do
  @moduledoc """
  Bach's aria "Erbarme dich, mein Gott", BWV 244/39, as a roots dub on mx's measured synths.
  The aria's 12/8 bar is a reggae bar of four beats swung in triplets, so the ritornello's eight
  bars become the riddim: the double bass plucks the continuo's falling bass over a saw filtered
  round and dark, as a bass guitar with its tone rolled off plays it, the harp skanks on 2 and 4,
  and the organ bubbles, its left hand steady on the last triplet of each beat and its right hand
  chopping 2 and 4.
  The drum kit leads: the one drop, kick and rimshot together on beat 3 with beat 1 left empty,
  the rimshot's ghost strokes, the hi-hat riding the triplets and opening into the next bar, snare
  pickups and tom rolls.
  Under it the congas play the Nyabinghi drums of Rastafari, the thunder open on 1 and damped on
  3, the funde's heartbeat on 2 and 4 and the repeater riding it, and the shaker and the güiro
  fill the triplets the hi-hat leaves.
  A dub siren and the hand drums open it, and a horn section of trumpet, tenor saxophone and
  trombone states the aria's opening sigh before the riddim drops.
  A trombone leads with the ritornello, slurring its runs as Rico Rodriguez and Vin Gordon played
  dub's trombone leads, the harmonium sings the alto's "Erbarme dich" as a melodica does in
  Augustus Pablo's dubs, and the horns sing it the second time.
  In the dubs the parts drop out and come back, the rimshot, harp, harmonium and horns are thrown
  into the echo, the harp and organ sweep through a high-pass filter as King Tubby's big knob did,
  the tabla's bayan bends down on the drop, and the tanpura drones on B while the bass is out.
  The notes come from the score beside this song, under CC BY 4.0, as LICENSE.md says.
  """

  use Mx.Song, tempo: 104

  # The chord on each of a ritornello bar's four beats, as its root, its quality and the
  # continuo's bass note.
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

  part :kick, synth: :kick, defaults: [amp: 0.75]

  part :rimshot,
    synth: :rimshot,
    defaults: [amp: 0.7],
    fx: [echo: [phase: 1, decay: 4, mix: 0.15]] ++ @room

  part :snare, synth: :snare, defaults: [vel: 0.6], fx: [reverb: [room: 0.85, mix: 0.4]]

  part :hihat,
    synth: :closed_hihat,
    defaults: [pan: 0.3],
    fx: [flanger: [phase: 12, feedback: 0.4, mix: 0.3]]

  part :open_hihat, synth: :open_hihat, defaults: [vel: 0.4, amp: 0.7, pan: 0.3, sustain: 0.5]
  part :tom, synth: :mid_tom, defaults: [vel: 0.6, amp: 1.2], fx: @room
  part :crash, synth: :crash, defaults: [vel: 0.5, amp: 0.8, pan: -0.2], fx: @room
  part :thunder, synth: :low_conga, defaults: [amp: 0.9, pan: -0.15]
  part :funde, synth: :mid_conga, defaults: [amp: 0.5, pan: 0.1]
  part :repeater, synth: :high_conga, defaults: [amp: 0.45, pan: 0.4], fx: @room
  part :shaker, synth: :shaker, defaults: [vel: 0.5, amp: 0.8, pan: -0.4]
  part :guiro, synth: :guiro, defaults: [vel: 0.25, amp: 1, pan: -0.45]

  part :bass,
    synth: :double_bass,
    defaults: [pizz: 1, vel: 0.8, amp: 1.6],
    fx: [lpf: [cutoff: 76]]

  part :electric_bass,
    synth: :saw,
    defaults: [amp: 0.6, cutoff: 70, res: 0.1, attack: 0.02, release: 0.15]

  part :organ,
    synth: :organ,
    defaults: [loud: 1, amp: 0.5, pan: -0.3, release: 0.1],
    fx: [hpf: [cutoff: 0]]

  part :harp,
    synth: :harp,
    defaults: [vel: 0.8, amp: 1.2, pan: 0.35, release: 0.1],
    fx: [hpf: [cutoff: 0], echo: [phase: 1, decay: 3, mix: 0.15], reverb: [room: 0.6, mix: 0.25]]

  part :lead,
    synth: :trombone,
    defaults: [vel: 0.8, amp: 0.8, note_slide: 0.06, pan: 0.15],
    fx: [echo: [phase: 1.5, decay: 6, mix: 0.25], reverb: [room: 0.8, mix: 0.35]]

  part :harmonium,
    synth: :harmonium,
    defaults: [vel: 0.55, amp: 6, pan: -0.1],
    fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room

  part :trumpet,
    synth: :trumpet,
    defaults: [vel: 0.75, amp: 0.9, pan: 0.2],
    fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room

  part :tenor_sax,
    synth: :tenor_sax,
    defaults: [vel: 0.75, amp: 0.9, pan: -0.2],
    fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room

  part :trombone,
    synth: :trombone,
    defaults: [vel: 0.75, amp: 0.8],
    fx: [echo: [phase: 1.5, decay: 4, mix: 0.15]] ++ @room

  part :siren,
    synth: :square,
    defaults: [amp: 0.07, cutoff: 92, note_slide: 0.4],
    fx: [echo: [phase: 0.75, decay: 4, mix: 0.4], reverb: [room: 0.8, mix: 0.4]]

  part :marimba,
    synth: :marimba,
    defaults: [vel: 0.5, pan: -0.35],
    fx: [echo: [phase: 1.5, decay: 6, mix: 0.4], reverb: [room: 0.8, mix: 0.4]]

  part :tabla,
    synth: :tabla_ghe,
    defaults: [vel: 0.8, amp: 0.7],
    fx: [echo: [phase: 1, decay: 4, mix: 0.35]] ++ @room

  part :tanpura,
    synth: :tanpura,
    defaults: [vel: 0.45, release: 3],
    fx: [reverb: [room: 0.8, mix: 0.3]]

  @horns [:trumpet, :tenor_sax, :trombone]

  def song do
    seq([:intro, :riddim, :verse, :dub, :horn_verse, :horn_dub, :outro], &section/1)
  end

  # The siren and the hand drums, then the one drop and the bass in the echo, the horns' motto,
  # and a tom roll into the riddim.
  defp section(:intro) do
    together(
      [
        part(:siren, at([{0, siren()}, {18, siren()}], 24)),
        part(:thunder, seq(1..4, fn _ -> thunder() end)),
        part(:funde, seq(1..4, fn _ -> funde() end)),
        part(:repeater, seq([rest(6), seq(2..4, &repeater/1)])),
        part(:tabla, boom()),
        part(:kick, seq([rest(6), seq(2..4, fn _ -> kick(:one_drop) end)])),
        part(
          :rimshot,
          together([seq([rest(6), seq(2..4, &rimshot/1)]), throw([:rimshot], 6, 21, 24)])
        ),
        part(:hihat, seq([rest(12), seq(3..4, fn _ -> hihat() end)])),
        part(:open_hihat, seq([rest(12), open_hihat(2), rest(6)])),
        part(:tom, seq([rest(18), roll()])),
        part(:bass, seq([rest(6), bass(1), bass(1), bass(8)])),
        part(:electric_bass, seq([rest(6), bass(1), bass(1), bass(8)])),
        part(:lead, pickup(:fs3, 24))
      ] ++ horns(seq([rest(12), motto()]))
    )
  end

  defp section(:riddim) do
    together(riddim() ++ [part(:lead, seq(1..8, &lead/1)), part(:harmonium, pickup(:fs4, 48))])
  end

  # The harmonium sings the alto's phrase and the lead trombone answers with the ritornello's
  # second half.
  defp section(:verse) do
    together(
      riddim() ++
        [
          part(:harmonium, seq([alto(), rest(24)])),
          part(:lead, seq([rest(24), seq(5..8, &lead/1)]))
        ]
    )
  end

  # The horns sing the alto's phrase the second time, over the kick stepping on every beat.
  defp section(:horn_verse) do
    together(
      riddim(:steppers) ++
        horns(seq([alto(), rest(24)])) ++
        [part(:lead, seq([rest(24), seq(5..8, &lead/1)]))]
    )
  end

  # Drums and bass with the rimshot in the echo, then the bass and kick drop out for the hand
  # drums, the tanpura, the siren and the harp sweeping up through the filter, and the band comes
  # back stepping with the organ sweeping down.
  defp section(:dub) do
    out = fn music -> seq([music.(1..4), rest(12), music.(7..8)]) end

    together(
      [
        part(
          :kick,
          seq([
            seq(1..4, fn _ -> kick(:one_drop) end),
            rest(12),
            seq(7..8, fn _ -> kick(:steppers) end)
          ])
        ),
        part(:rimshot, together([seq(1..8, &rimshot/1), throw([:rimshot], 0, 42, 48)])),
        part(
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
        part(:tom, seq([rest(42), roll()])),
        part(:hihat, out.(&seq(&1, fn _ -> hihat() end))),
        part(:open_hihat, out.(&seq(&1, fn bar -> open_hihat(bar) end))),
        part(:crash, at([{36, hit()}], 48)),
        part(:thunder, seq(1..8, fn _ -> thunder() end)),
        part(:funde, seq(1..8, fn _ -> funde() end)),
        part(:repeater, seq(1..8, &repeater/1)),
        part(:shaker, seq([rest(24), seq(5..8, fn _ -> shaker() end)])),
        part(:guiro, seq([rest(36), seq(7..8, fn _ -> guiro() end)])),
        part(:bass, out.(&seq(&1, fn bar -> bass(bar) end))),
        part(:electric_bass, out.(&seq(&1, fn bar -> bass(bar) end))),
        part(
          :organ,
          together([
            seq([rest(36), seq(7..8, &bubble/1)]),
            at(
              [
                {35, change({:organ, :hpf}, cutoff: 100, cutoff_slide: 0)},
                {36, change({:organ, :hpf}, cutoff: 0, cutoff_slide: 12)}
              ],
              48
            )
          ])
        ),
        part(
          :harp,
          together([
            seq([rest(12), seq(3..8, &skank(&1, 0.25))]),
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
        part(
          :harmonium,
          together([
            at([{6, seq(d5: 0.75, cs5: 0.25, b4: 1.25)}], 48),
            throw([:harmonium], 6, 18, 48)
          ])
        ),
        part(:tabla, seq([seq(1..6, fn _ -> boom() end), rest(12)])),
        part(:tanpura, seq([rest(24), note(:b2, 12), rest(12)])),
        part(:siren, at([{28, siren()}], 48)),
        part(:marimba, at([{25.5, sigh()}, {31.5, sigh()}], 48))
      ] ++ horns(pickup(:fs4, 48))
    )
  end

  # The riddim's second half stepping, with the horns' phrases thrown into the echo and the organ
  # swept up through the filter.
  defp section(:horn_dub) do
    range = 5..8

    together(
      [
        part(:kick, seq(range, fn _ -> kick(:steppers) end)),
        part(:rimshot, together([seq(range, &rimshot/1), throw([:rimshot], 0, 21, 24)])),
        part(:tom, seq(range, &tom/1)),
        part(:hihat, seq(range, fn _ -> hihat() end)),
        part(:open_hihat, seq(range, &open_hihat/1)),
        part(:bass, seq([bass(5), bass(6), rest(6), bass(8)])),
        part(:electric_bass, seq([bass(5), bass(6), rest(6), bass(8)])),
        part(
          :organ,
          together([
            seq(range, &bubble/1),
            at(
              [
                {0, change({:organ, :hpf}, cutoff: 96, cutoff_slide: 12)},
                {12, change({:organ, :hpf}, cutoff: 0, cutoff_slide: 0.5)}
              ],
              24
            )
          ])
        ),
        part(:harp, seq(range, &skank(&1, 0.25))),
        part(:siren, together([at([{18, siren()}], 24), throw(@horns, 0, 22, 24)]))
      ] ++
        hand_drums(range) ++
        horns(
          at([{0, seq(as4: 1, b4: 0.5, cs5: 3)}, {12, seq(g4: 1, fs4: 0.5, g4: 1, b4: 0.5)}], 24)
        )
    )
  end

  # The last two bars of the riddim, then B held by the horns over the tanpura while the echoes
  # die away.
  defp section(:outro) do
    together([
      part(:kick, seq([kick(:one_drop), kick(:one_drop), rest(12)])),
      part(:rimshot, seq([rimshot(7), rimshot(8), rest(12)])),
      part(:tom, seq([rest(6), roll(), rest(12)])),
      part(:hihat, seq([hihat(), hihat(), rest(12)])),
      part(:crash, at([{12, hit(vel: 0.6)}], 24)),
      part(:thunder, seq([thunder(), thunder(), at([{0, hit(vel: 0.7)}], 12)])),
      part(:funde, seq([funde(), funde(), rest(12)])),
      part(:repeater, seq([repeater(7), repeater(8), rest(12)])),
      part(:bass, seq([bass(7), bass(8), note(:b1, 8)])),
      part(:electric_bass, seq([bass(7), bass(8), note(:b1, 8)])),
      part(:organ, seq([bubble(7), bubble(8), rest(12)])),
      part(
        :harp,
        seq([
          skank(7, 0.25),
          skank(8, 0.25),
          note(voice(chord(:b3, :minor), from: 62, to: 74), 4)
        ])
      ),
      part(:trumpet, seq([rest(12), note(:d5, 6)])),
      part(:tenor_sax, seq([rest(12), note(:fs4, 6)])),
      part(:trombone, seq([rest(12), note(:b3, 6)])),
      part(:tanpura, seq([rest(12), note(:b2, 12)])),
      part(:marimba, at([{19.5, sigh()}], 24))
    ])
  end

  # The sound system's siren: a swoop up from B4 to B6, then a wail between B6 and F#6.
  defp siren do
    wail =
      for {offset, index} <- Enum.with_index([1, 1.5, 2, 2.5, 3]),
          do: {offset, [note: if(rem(index, 2) == 0, do: :fs6, else: :b6)]}

    note(:b4, 4, changes: [{0.1, note: :b6} | wail] ++ [{3.5, note: :b4}])
  end

  defp thunder, do: at([{0, hit(vel: 0.6)}, {3, hit(vel: 0.4, mute: 1)}], 6)

  # The funde's heartbeat: a damped stroke on the last triplet before beats 2 and 4, and an open
  # one on them.
  defp funde do
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

  # The repeater riding the heartbeat, slapping 2 and 4 and changing what it plays between them
  # from bar to bar.
  defp repeater(bar) do
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

  # The bayan struck on the drop and bent down a fourth as it rings.
  defp boom, do: at([{3, hit(note: 45, note_slide: 1, changes: [{0.1, note: 40}])}], 6)

  defp kick(:one_drop), do: at([{3, hit()}], 6)

  defp kick(:steppers) do
    entries = for index <- 0..3, do: {beat(index), hit()}
    at(entries, 6)
  end

  # The rimshot on the drop, with ghost strokes around it that change from bar to bar.
  defp rimshot(bar) do
    ghosts = ring([[5.5], [2, 4], [5, 5.5], [1, 4, 5.5]], bar - 1)
    ghosts = for offset <- ghosts, do: {offset, hit(amp: 0.15)}
    at(Enum.sort([{3, hit()} | ghosts]), 6)
  end

  # The parts thrown into the echo from one beat and brought back at another, within music of the
  # given length.
  defp throw(names, from, back, length) do
    entries =
      for name <- names,
          {beat, mix} <- [{from, 0.6}, {back, 0.15}],
          do: {beat, change({name, :echo}, mix: mix)}

    at(entries, length)
  end

  # The ride on every triplet but the middle one of each beat, the beat itself softer than the
  # swung note before the next.
  defp hihat do
    entries =
      for index <- 0..3,
          {offset, amp} <- [{0, 1.0}, {1, 1.5}],
          do: {beat(index) + offset, hit(amp: amp)}

    at(entries, 6)
  end

  # The hi-hat opening on the last triplet of every other bar, into the next.
  defp open_hihat(bar), do: if(rem(bar, 2) == 0, do: at([{5.5, hit()}], 6), else: rest(6))

  # The roll closing the riddim: the tom down the triplets of beats 3 and 4.
  defp roll do
    entries =
      for {note, step} <- Enum.with_index([55, 52, 50, 47, 45, 43]),
          do: {3 + step * 0.5, hit(note: note)}

    at(entries, 6)
  end

  # The continuo's bass on beats 1, 2 and 4, and the bass of beat 3 around the drop instead of on
  # it.
  defp bass(bar) do
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

  defp pickup(note, length), do: at([{length - 0.5, note(note, 0.5)}], length)

  # The horns in octaves: the trumpet at the melody's pitch, the saxophone and the trombone an
  # octave below.
  defp horns(music) do
    low = transpose(music, -12)
    [part(:trumpet, music), part(:tenor_sax, low), part(:trombone, low)]
  end

  # The aria's opening sigh, as the horns state it in the intro.
  defp motto, do: seq(d5: 0.75, cs5: 0.25, b4: 0.5, b4: 0.75, as4: 0.25, b4: 0.5, b4: 3)

  defp riddim(kick \\ :one_drop), do: drums(1..8, kick) ++ hand_drums(1..8) ++ band(1..8)

  # The ritornello on the trombone an octave down, each run of different notes slurred into one
  # held note that slides between them.
  defp lead(bar), do: legato(ritornello(bar))

  # The alto's first phrase, "Erbarme dich, mein Gott, um meiner Zähren willen", bars 9 to 12,
  # over the ritornello's first four bars.
  defp alto do
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

  # The shaker on the middle triplet of each beat, the one the hi-hat leaves.
  defp shaker do
    entries = for index <- 0..3, do: {beat(index) + 0.5, hit(up: 1)}
    at(entries, 6)
  end

  defp guiro, do: at([{1, hit(sustain: 0.4)}, {4, hit(sustain: 0.4)}], 6)

  # The bubble's left hand: each beat's root and fifth on its last triplet.
  defp bubble(bar) do
    entries =
      for {{root, _, _}, index} <- Enum.with_index(Enum.at(@harmony, bar - 1)) do
        root = pitch(root)
        {beat(index) + 1, note([root, root + 7], 0.3)}
      end

    together([at(entries, 6), skank(bar, 0.3)])
  end

  defp skank(bar, length) do
    chords = Enum.at(@harmony, bar - 1)

    entries =
      for index <- [1, 3] do
        {root, quality, _} = Enum.at(chords, index)
        {beat(index), note(voice(chord(root, quality), from: 62, to: 74), length)}
      end

    at(entries, 6)
  end

  defp sigh, do: seq(b4: 0.75, as4: 0.25, b4: 0.5)

  defp tom(8), do: roll()
  defp tom(_bar), do: rest(6)

  defp hand_drums(range) do
    [
      part(:thunder, seq(range, fn _ -> thunder() end)),
      part(:funde, seq(range, fn _ -> funde() end)),
      part(:repeater, seq(range, &repeater/1)),
      part(:shaker, seq(range, fn _ -> shaker() end)),
      part(:guiro, seq(range, fn _ -> guiro() end))
    ]
  end

  defp beat(index), do: index * 1.5

  defp drums(range, kick) do
    [
      part(:kick, seq(range, fn _ -> kick(kick) end)),
      part(:rimshot, seq(range, &rimshot/1)),
      part(:snare, seq(range, &snare/1)),
      part(:tom, seq(range, &tom/1)),
      part(:hihat, seq(range, fn _ -> hihat() end)),
      part(:open_hihat, seq(range, &open_hihat/1)),
      part(:crash, at([{0, hit()}], 6 * Enum.count(range)))
    ]
  end

  defp band(range) do
    [
      part(:bass, seq(range, &bass/1)),
      part(:electric_bass, seq(range, &bass/1)),
      part(:organ, seq(range, &bubble/1)),
      part(:harp, seq(range, &skank(&1, 0.25)))
    ]
  end

  defp legato(notes) do
    {notes, _} =
      Enum.map_reduce(notes, 0, fn {name, beats}, onset ->
        {{name, beats, onset}, onset + beats}
      end)

    notes
    |> Enum.chunk_while([], &run/2, fn
      [] -> {:cont, []}
      run -> {:cont, Enum.reverse(run), []}
    end)
    |> seq(&held/1)
  end

  # The ritornello's melody, bar by bar, with each bar's pickup into the next at its end.
  defp ritornello(1) do
    [d5: 0.75, cs5: 0.25, b4: 0.5, b4: 0.75, as4: 0.25, b4: 0.5, b4: 2.5, b4: 0.5]
  end

  defp ritornello(2) do
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

  defp ritornello(3) do
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

  defp ritornello(4) do
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

  defp ritornello(5) do
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

  defp ritornello(6) do
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

  defp ritornello(7) do
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

  defp ritornello(8) do
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

  # A snare pickup into the second half of the riddim.
  defp snare(4), do: at([{5, hit(vel: 0.4)}, {5.5, hit(vel: 0.7)}], 6)
  defp snare(_bar), do: rest(6)

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

  defp held(run), do: slur(seq(run, fn {name, beats, _} -> note(pitch(name) - 12, beats) end))
end
