defmodule Dubwise do
  @moduledoc """
  A dub in A dorian on mx's measured synths, its riddim written for mx: four bars of Am7, D9, Am7
  and G, with the double bass plucking a line that leaves the drop open, a guitar skanking on 2
  and 4 and the organ bubbling.
  The kit leads: the one drop, kick and rimshot together on beat 3, then rockers with the kick on
  1 and 3, as Sly Dunbar played them, and steppers with the kick on every beat; the hi-hat rides
  swung sixteenths, and the congas and the shaker stay under it.
  The harmonium plays as the melodica in Augustus Pablo's dubs, each run slurred into one held
  note, the vibraphone answers with its motor turning, and the trombone doubles the melodica an
  octave down in the last riddim.
  The desk does the rest, as King Tubby and Lee Perry played their mixing desks: parts thrown into
  the tape echo and pulled back, the skank and the organ swept through a high-pass filter, the
  hi-hat through a flanger standing in for the Black Ark's phaser, the echo's delay slid while its
  repeats ring so they bend in pitch, the organ gated by a slicer, and a dub siren.
  Before the last riddim the selector pulls the record back, as sound systems rewind a tune the
  crowd calls for.
  The samples are Sonic Pi's, from freesound.org under Creative Commons 0: vinyl hiss, a rewind, a
  dub snare, a haunted hum, a dark woosh played backwards into the drops, and a boom where the
  bass comes back.
  """

  use Mx.Song, tempo: 74

  @room [reverb: [room: 0.7, mix: 0.3]]
  @tape [echo: [phase: 0.75, decay: 4, max_phase: 2, mix: 0.2]]

  part :kick, synth: :kick, defaults: [amp: 1]

  part :rimshot,
    synth: :rimshot,
    defaults: [amp: 0.5],
    fx: [ping_pong: [phase: 0.75, feedback: 0.45, mix: 0.12]] ++ @room

  part :snare,
    synth: :snare,
    defaults: [vel: 0.6, amp: 0.7],
    fx: [reverb: [room: 0.9, damp: 0.3, mix: 0.45]]

  part :hihat,
    synth: :closed_hihat,
    defaults: [pan: 0.3],
    fx: [flanger: [phase: 16, feedback: 0.4, mix: 0.25]]

  part :open_hihat, synth: :open_hihat, defaults: [vel: 0.4, amp: 0.3, pan: 0.3, sustain: 0.4]
  part :tom, synth: :mid_tom, defaults: [vel: 0.6, amp: 0.6], fx: @tape ++ @room
  part :crash, synth: :crash, defaults: [vel: 0.5, amp: 0.3, pan: -0.2], fx: @room
  part :thunder, synth: :low_conga, defaults: [amp: 0.4, pan: -0.15]
  part :funde, synth: :mid_conga, defaults: [amp: 0.3, pan: 0.15], fx: @room
  part :shaker, synth: :shaker, defaults: [vel: 0.2, amp: 0.2, pan: -0.4]
  part :bass, synth: :double_bass, defaults: [pizz: 1, vel: 0.8], fx: [lpf: [cutoff: 76]]

  part :electric_bass,
    synth: :saw,
    defaults: [amp: 0.4, cutoff: 64, res: 0.1, attack: 0.02, release: 0.15]

  part :skank,
    synth: :guitar,
    defaults: [vel: 0.5, pan: 0.35, release: 0.1],
    fx: [hpf: [cutoff: 0]] ++ @tape ++ @room

  part :organ,
    synth: :organ,
    defaults: [amp: 0.25, pan: -0.3, release: 0.1],
    fx: [slicer: [phase: 0.25, mix: 0], hpf: [cutoff: 0]]

  part :melodica,
    synth: :harmonium,
    defaults: [vel: 0.55, note_slide: 0.06, pan: -0.1],
    fx: @tape ++ [reverb: [room: 0.8, mix: 0.3]]

  part :trombone,
    synth: :trombone,
    defaults: [vel: 0.6, amp: 0.7, note_slide: 0.06, pan: 0.15],
    fx: @tape ++ @room

  part :vibes,
    synth: :vibraphone,
    defaults: [vel: 0.45, motor: 1, pan: 0.45],
    fx: [ping_pong: [phase: 1.5, feedback: 0.5, mix: 0.35], reverb: [room: 0.85, mix: 0.4]]

  part :siren,
    synth: :fm,
    defaults: [amp: 0.07, divisor: 4, depth: 0.6, note_slide: 0.4],
    fx: [echo: [phase: 0.75, decay: 5, mix: 0.4], reverb: [room: 0.9, mix: 0.45]]

  part :drone, synth: :tanpura, defaults: [vel: 0.4], fx: [reverb: [room: 0.8, mix: 0.35]]

  part :dub_snare,
    fx: [
      ping_pong: [phase: 0.75, feedback: 0.55, max_phase: 2, mix: 0.4],
      reverb: [room: 0.9, mix: 0.4]
    ]

  part :vinyl, []
  part :space, fx: [reverb: [room: 0.9, mix: 0.4]]

  def song do
    seq(
      Enum.map([:intro, :riddim, :rockers, :dub, :deep, :rewind, :steppers, :outro], &section/1)
    )
  end

  # The part's echo opened to a mix at one beat and closed again at another, within music of the
  # given length.
  defp throw(name, from, back, length, mix \\ 0.55) do
    entries =
      for {beat, mix} <- [{from, mix}, {back, 0.2}],
          do: {beat, change({name, echo(name)}, mix: mix)}

    at(entries, length)
  end

  # The rimshot's echo is a ping-pong, and every other part's thrown is the tape echo.
  defp echo(:rimshot), do: :ping_pong
  defp echo(_name), do: :echo

  # The hiss and a haunted hum, the siren, the melodica's first bars thrown into the echo, then
  # the one drop and the bass, and a roll into the riddim.
  defp section(:intro) do
    together([
      part(:vinyl, hiss(16)),
      part(
        :space,
        at(
          [
            {0, sample({:sonic_pi, :ambi_haunted_hum}, 12, amp: 0.2, attack: 2, release: 4)},
            woosh(16)
          ],
          16
        )
      ),
      part(:siren, at([{1, siren()}], 16)),
      part(
        :melodica,
        together([
          seq([legato(Enum.take(phrase(:a), 11)), rest(8)]),
          throw(:melodica, 0, 12, 16, 0.5)
        ])
      ),
      part(:vibes, vibes([{8, [:a4, :e5]}, {12, [:g4, :d5]}], 16)),
      part(:kick, delay(seq([kick(:one_drop), kick(:one_drop)]), 8)),
      part(
        :rimshot,
        together([delay(seq([rimshot(1), rimshot(2)]), 8), throw(:rimshot, 8, 15, 16)])
      ),
      part(:hihat, delay(seq([hihat(1), hihat(2)]), 8)),
      part(:tom, delay(roll(), 12)),
      part(:bass, delay(seq([bass(1), bass(4)]), 8)),
      part(:electric_bass, delay(seq([bass(1), bass(4)]), 8))
    ])
  end

  # The riddim twice, the melodica's two phrases over it and the vibraphone answering in their
  # gaps.
  defp section(:riddim) do
    together(
      drums(1..8, :one_drop) ++
        hands(1..8) ++
        band(1..8) ++
        [
          part(:melodica, legato(phrase(:a) ++ phrase(:b))),
          part(:vibes, vibes([{15, [:e5, :a5]}, {30, [:a4, :c5, :e5]}], 32))
        ]
    )
  end

  # Rockers, the melodica's phrases in the other order, and the skank thrown into the echo at the
  # turn.
  defp section(:rockers) do
    together(
      drums(1..8, :rockers) ++
        hands(1..8) ++
        [
          part(:bass, seq(1..8, &bass/1)),
          part(:electric_bass, seq(1..8, &bass/1)),
          part(:skank, together([seq(1..8, &skank/1), throw(:skank, 12, 17, 32)])),
          part(:organ, seq(1..8, &bubble/1)),
          part(:melodica, legato(phrase(:b) ++ phrase(:a))),
          part(:vibes, vibes([{14, [:a4, :e5]}, {31, [:g4, :b4, :d5]}], 32)),
          part(:siren, at([{28, siren()}], 32))
        ]
    )
  end

  # Drums and bass alone, the skank swept up through the filter into the echo, the bass out while
  # the melodica's tape echo bends, and the organ swept down as the band comes back.
  defp section(:dub) do
    out = fn music -> seq([music.(1..4), rest(8), music.(7..8)]) end

    together(
      [
        part(
          :kick,
          seq([
            seq(1..4, fn _ -> kick(:one_drop) end),
            rest(8),
            seq(7..8, fn _ -> kick(:rockers) end)
          ])
        ),
        part(
          :rimshot,
          together([
            seq(1..8, &rimshot/1),
            throw(:rimshot, 4, 8, 32),
            throw(:rimshot, 28, 31, 32)
          ])
        ),
        part(
          :snare,
          at(
            [
              {14, hit(vel: 0.55)},
              {27.25, hit(vel: 0.3)},
              {27.5, hit(vel: 0.5)},
              {27.75, hit(vel: 0.7)}
            ],
            32
          )
        ),
        part(
          :dub_snare,
          at(
            [
              {22, sample({:sonic_pi, :sn_dub}, 1, amp: 0.7)},
              {30, sample({:sonic_pi, :sn_dub}, 1, amp: 0.6)}
            ],
            32
          )
        ),
        part(:tom, delay(roll(), 28)),
        part(
          :hihat,
          together([
            seq(1..8, &hihat/1),
            at(
              [
                {8, change({:hihat, :flanger}, mix: 0.75, mix_slide: 8)},
                {28, change({:hihat, :flanger}, mix: 0.25, mix_slide: 2)}
              ],
              32
            )
          ])
        ),
        part(:open_hihat, seq(1..8, &open_hihat/1)),
        part(:bass, out.(&seq(&1, fn bar -> bass(bar) end))),
        part(:electric_bass, out.(&seq(&1, fn bar -> bass(bar) end))),
        part(
          :skank,
          together([
            delay(seq(3..8, &skank/1), 8),
            throw(:skank, 8, 24, 32),
            at(
              [
                {8, change({:skank, :hpf}, cutoff: 96, cutoff_slide: 8)},
                {24, change({:skank, :hpf}, cutoff: 0, cutoff_slide: 4)}
              ],
              32
            )
          ])
        ),
        part(
          :organ,
          together([
            delay(seq(5..8, &bubble/1), 16),
            at(
              [
                {15, change({:organ, :hpf}, cutoff: 100, cutoff_slide: 0)},
                {16, change({:organ, :hpf}, cutoff: 0, cutoff_slide: 16)}
              ],
              32
            )
          ])
        ),
        part(
          :melodica,
          together([
            at([{16, legato(Enum.take(phrase(:a), 5))}], 32),
            throw(:melodica, 16, 28, 32, 0.6),
            at(
              [
                {18, change({:melodica, :echo}, phase: 0.5, phase_slide: 3)},
                {22, change({:melodica, :echo}, phase: 0.75, phase_slide: 2)}
              ],
              32
            )
          ])
        ),
        part(:siren, at([{19, siren()}], 32)),
        part(:space, at([woosh(32)], 32))
      ] ++ hands(1..8)
    )
  end

  # The kick and bass out under the drone, the hi-hat deep in the flanger and the dub snare's echo
  # running away and bending up; then a boom, the bass back, and the organ's chords cut up by the
  # slicer.
  defp section(:deep) do
    snare_echo = fn opts -> change({:dub_snare, :ping_pong}, opts) end
    snares = for beat <- [2, 6, 10, 14], do: {beat, sample({:sonic_pi, :sn_dub}, 1, amp: 0.7)}

    together(
      [
        part(:vinyl, hiss(32)),
        part(:drone, note(:a2, 16)),
        part(
          :space,
          at(
            [
              {0, sample({:sonic_pi, :ambi_haunted_hum}, 12, amp: 0.25, attack: 3, release: 4)},
              {16, sample({:sonic_pi, :misc_cineboom}, 8, amp: 0.4)},
              woosh(32)
            ],
            32
          )
        ),
        part(
          :dub_snare,
          together([
            at(snares, 16),
            at(
              [
                {0, snare_echo.(feedback: 0.85, feedback_slide: 4, mix: 0.6)},
                {10, snare_echo.(phase: 0.25, phase_slide: 4)},
                {16,
                 snare_echo.(
                   phase: 0.75,
                   phase_slide: 0,
                   feedback: 0.55,
                   feedback_slide: 0,
                   mix: 0.4
                 )}
              ],
              32
            )
          ])
        ),
        part(:kick, delay(seq(5..8, fn _ -> kick(:one_drop) end), 16)),
        part(:rimshot, delay(seq(5..8, &rimshot/1), 16)),
        part(:tom, delay(roll(), 28)),
        part(
          :hihat,
          together([
            seq(1..8, &hihat/1),
            at(
              [
                {0, change({:hihat, :flanger}, mix: 0.85, feedback: 0.6)},
                {16, change({:hihat, :flanger}, mix: 0.3, feedback: 0.4)}
              ],
              32
            )
          ])
        ),
        part(
          :vibes,
          vibes([{2, [:a4, :e5]}, {7, [:g4, :d5]}, {10.5, [:c5, :g5]}, {14, [:b4, :fs5]}], 32)
        ),
        part(:bass, delay(seq(5..8, &bass/1), 16)),
        part(:electric_bass, delay(seq(5..8, &bass/1), 16)),
        part(
          :organ,
          together([
            delay(seq(5..8, &note(voicing(&1), 4)), 16),
            at([{16, change({:organ, :slicer}, mix: 1)}], 32)
          ])
        ),
        part(
          :skank,
          together([delay(seq(7..8, &skank/1), 24), throw(:skank, 24, 31, 32)])
        ),
        part(:melodica, at([{24, legato(Enum.drop(phrase(:b), 12))}], 32)),
        part(:siren, at([{26, siren()}], 32))
      ] ++ hands(1..8)
    )
  end

  # The selector pulls the record back.
  defp section(:rewind) do
    together([
      part(:vinyl, sample({:sonic_pi, :vinyl_rewind}, 4, amp: 0.7)),
      part(:siren, note(:a4, 4, changes: [{0.1, note: :a6}, {2, note: :e6}]))
    ])
  end

  # Steppers from the top, the trombone under the melodica, the organ's bubble freed from the
  # slicer.
  defp section(:steppers) do
    lead = phrase(:a) ++ phrase(:b)

    together(
      drums(1..8, :steppers) ++
        hands(1..8) ++
        [
          part(:bass, seq(1..8, &bass/1)),
          part(:electric_bass, seq(1..8, &bass/1)),
          part(
            :skank,
            together([
              seq(1..8, &skank/1),
              throw(:skank, 14, 16, 32),
              throw(:skank, 30, 31.5, 32)
            ])
          ),
          part(
            :organ,
            together([seq(1..8, &bubble/1), at([{0, change({:organ, :slicer}, mix: 0)}], 32)])
          ),
          part(:melodica, legato(lead)),
          part(:trombone, legato(lead, -12)),
          part(:vibes, vibes([{15, [:e5, :a5]}, {30, [:a4, :c5, :e5]}], 32)),
          part(:siren, at([{24, siren()}], 32))
        ]
    )
  end

  # Two bars of the one drop, then everything thrown into the echo on a last chord of Am9, left to
  # fade into the hiss.
  defp section(:outro) do
    together([
      part(:vinyl, hiss(16)),
      part(:kick, seq([kick(:one_drop), kick(:one_drop), at([{0, hit()}], 8)])),
      part(
        :rimshot,
        together([
          seq([rimshot(1), rimshot(2), at([{0, hit()}], 8)]),
          throw(:rimshot, 8, 15, 16, 0.7)
        ])
      ),
      part(:hihat, seq([hihat(1), hihat(2), rest(8)])),
      part(:crash, at([{8, hit(vel: 0.6)}], 16)),
      part(:thunder, seq([thunder(), thunder(), at([{0, hit(vel: 0.6)}], 8)])),
      part(:funde, seq([funde(), funde(), rest(8)])),
      part(:bass, seq([bass(1), bass(2), note(:a1, 6)])),
      part(:electric_bass, seq([bass(1), bass(2), note(:a1, 6)])),
      part(
        :skank,
        together([
          seq([skank(1), skank(2), note([67, 71, 72, 76], 0.25), rest(7.75)]),
          throw(:skank, 8, 15, 16, 0.7)
        ])
      ),
      part(:organ, seq([bubble(1), bubble(2), rest(8)])),
      part(
        :melodica,
        together([delay(note(:a4, 4), 8), throw(:melodica, 8, 15, 16, 0.7)])
      ),
      part(:vibes, vibes([{8, [:a4, :c5, :e5, :g5, :b5]}], 16)),
      part(:drone, delay(note(:a2, 8), 8))
    ])
  end

  # A riddim bar's chord, its bars counted from 1 and wrapping every four.
  defp harmony(bar), do: ring(chords(), bar - 1)

  defp kick(:one_drop), do: steps(~MX"..x."s, 1)
  defp kick(:rockers), do: steps(~MX"x.x."s, 1)
  defp kick(:steppers), do: steps(~MX"xxxx"s, 1)

  # The rimshot on the drop, in sixteenths, with ghost strokes, g, around it that change from bar
  # to bar.
  defp rimshot(bar) do
    bars = [
      ~MX"....|....|x...|...g"s,
      ~MX"....|...g|x...|.g.."s,
      ~MX"...g|....|x...|...g"s,
      ~MX"....|.g..|x..g|..g."s
    ]

    steps(ring(bars, bar - 1), 0.25, strokes: [g: [amp: 0.15]])
  end

  # Swung sixteenths, each one off the eighths a little late, the beat loudest; every other bar
  # leaves the last eighth to the open hi-hat.
  defp hihat(bar) do
    steps = if rem(bar, 2) == 0, do: 0..13, else: 0..15

    entries =
      for step <- steps do
        late = if rem(step, 2) == 1, do: 0.04, else: 0
        {step * 0.25 + late, hit(amp: Enum.at([0.24, 0.1, 0.17, 0.11], rem(step, 4)))}
      end

    at(entries, 4)
  end

  defp open_hihat(bar), do: if(rem(bar, 2) == 0, do: at([{3.5, hit()}], 4), else: rest(4))

  # A snare pickup into the second half of the riddim, and in steppers the snare on the drop too.
  defp snare(bar, style) do
    drop = if style == :steppers, do: [{2, hit(vel: 0.5)}], else: []

    pickup =
      if rem(bar, 8) == 4 do
        [{3.25, hit(vel: 0.35)}, {3.5, hit(vel: 0.5)}, {3.75, hit(vel: 0.7)}]
      else
        []
      end

    at(drop ++ pickup, 4)
  end

  # The tom down the sixteenths of beats 3 and 4.
  defp roll, do: steps(~MX"....|....|1234|5678"s, 0.25, notes: [57, 55, 52, 50, 47, 45, 43, 40])

  defp tom(bar), do: if(rem(bar, 8) == 0, do: roll(), else: rest(4))

  # The low conga open on one and damped on three.
  defp thunder, do: steps(~MX"o.m."s, 1, strokes: [o: [vel: 0.55], m: [vel: 0.4, mute: 1]])

  # A damped stroke before 2 and 4 and an open one on them, in sixteenths.
  defp funde do
    steps(~MX"...m|o...|...m|o..."s, 0.25, strokes: [m: [vel: 0.3, mute: 1], o: [vel: 0.45]])
  end

  # The shaker on the sixteenths off the eighths, up and then down.
  defp shaker, do: steps(~MX".u.d|.u.d|.u.d|.u.d"s, 0.25, strokes: [u: [up: 1], d: [up: 0]])

  # Each bar's bass notes, a sixteenth to a step.
  defp bass(bar) do
    bars = [
      ~MX"a1:5 _ c2:2 _:2 e2:3 d2 c2:2",
      ~MX"d2:5 _ fs2:2 _:2 a2:2 fs2 _ e2:2",
      ~MX"a1:5 _ e2:2 _:2 a2 g2 e2:3 _",
      ~MX"g1:4 _:2 d2:2 _:2 g2:2 fs2 e2 b1:2"
    ]

    # A note of whole beats keeps its length as an integer, as the line was first written.
    held = fn _step, steps ->
      [sustain: if(rem(steps, 4) == 0, do: div(steps, 4), else: steps / 4)]
    end

    steps(ring(bars, bar - 1), 0.25, each: held)
  end

  defp voicing(bar) do
    {root, quality} = harmony(bar)
    voice(chord(root, quality), from: 62, to: 74, limit: 4)
  end

  # The skank on 2 and 4, chopped twice on the last bar of the riddim.
  defp skank(bar) do
    chord = voicing(bar)
    beats = if rem(bar, 4) == 0, do: [1, 3, 3.25], else: [1, 3]
    chords = for beat <- beats, do: {beat, note(chord, 0.25)}
    at(chords, 4)
  end

  # The bubble's left hand: the root and fifth on every offbeat, with the skank's chord on 2 and
  # 4.
  defp bubble(bar) do
    {root, _} = harmony(bar)
    root = pitch(root) - 12

    entries =
      for beat <- [0.5, 1.5, 2.5, 3.5] do
        {beat, note([root, root + 7], 0.3)}
      end

    together([
      at(entries, 4),
      at([{1, note(voicing(bar), 0.3)}, {3, note(voicing(bar), 0.3)}], 4)
    ])
  end

  # The melodica's two phrases over the four bars of the riddim.
  defp phrase(:a) do
    [e5: 1.5, d5: 0.5, c5: 0.5, b4: 0.25, a4: 1.25] ++
      [r: 0.5, a4: 0.5, c5: 0.5, d5: 0.5, fs5: 1, e5: 1] ++
      [e5: 0.75, g5: 0.25, e5: 0.5, d5: 0.5, c5: 0.5, d5: 0.5, a4: 1] ++
      [g4: 1.5, a4: 0.5, b4: 1, r: 1]
  end

  defp phrase(:b) do
    [a5: 2, g5: 0.5, e5: 0.5, d5: 0.5, e5: 0.5] ++
      [fs5: 1.5, e5: 0.5, d5: 1, b4: 1] ++
      [c5: 0.75, d5: 0.25, e5: 0.5, g5: 0.5, a5: 1.5, g5: 0.5] ++
      [e5: 1, d5: 0.5, b4: 0.5, a4: 2]
  end

  # Each run of different notes slurred into one held note that slides between them, moved by some
  # semitones.
  defp legato(notes, shift \\ 0) do
    {notes, _} =
      Enum.map_reduce(notes, 0, fn {name, beats}, onset ->
        {{name, beats, onset}, onset + beats}
      end)

    notes
    |> Enum.chunk_while([], &run/2, fn
      [] -> {:cont, []}
      run -> {:cont, Enum.reverse(run), []}
    end)
    |> seq(&held(&1, shift))
  end

  # A rest, a repeated note or a note on the beat starts a new note, as the player tongues it.
  defp run(item, []), do: {:cont, [item]}

  defp run({name, _, onset} = item, [{last, _, _} | _] = run) do
    if :r in [name, last] or name == last or onset == trunc(onset) do
      {:cont, Enum.reverse(run), [item]}
    else
      {:cont, [item | run]}
    end
  end

  defp held([{:r, length, _}], _shift), do: rest(length)

  defp held([{first, length, _} | others], shift) do
    {changes, total} =
      Enum.map_reduce(others, length, fn {name, beats, _}, beat ->
        {{beat, note: pitch(name) + shift}, beat + beats}
      end)

    note(pitch(first) + shift, total, changes: changes)
  end

  # The siren: a swoop up from A4 to A6, then a wail between A6 and E6, and down again.
  defp siren do
    wail =
      for {beat, index} <- Enum.with_index([1, 1.5, 2, 2.5, 3]),
          do: {beat, [note: if(rem(index, 2) == 0, do: :e6, else: :a6)]}

    note(:a4, 4, changes: [{0.1, note: :a6} | wail] ++ [{3.5, note: :a4}])
  end

  # The vibraphone's answers, as {beat, notes}, each left to ring under its motor.
  defp vibes(entries, length) do
    chords = for {beat, notes} <- entries, do: {beat, note(notes, 2)}
    at(chords, length)
  end

  defp hiss(length) do
    loops =
      for beat <- 0..(length - 8)//8,
          do: {beat, sample({:sonic_pi, :vinyl_hiss}, 8, amp: 0.35, sustain: 7, release: 2)}

    at(loops, length)
  end

  # The dark woosh backwards, swelling into the downbeat after the given beat.
  defp woosh(beat) do
    {beat - 4.5, sample({:sonic_pi, :ambi_dark_woosh}, 4, rate: -1, amp: 0.35)}
  end

  defp drums(range, style) do
    [
      part(:kick, seq(range, fn _ -> kick(style) end)),
      part(:rimshot, seq(range, &rimshot/1)),
      part(:snare, seq(range, &snare(&1, style))),
      part(:tom, seq(range, &tom/1)),
      part(:hihat, seq(range, &hihat/1)),
      part(:open_hihat, seq(range, &open_hihat/1)),
      part(:crash, at([{0, hit()}], 4 * Enum.count(range)))
    ]
  end

  defp hands(range) do
    [
      part(:thunder, seq(range, fn _ -> thunder() end)),
      part(:funde, seq(range, fn _ -> funde() end)),
      part(:shaker, seq(range, fn _ -> shaker() end))
    ]
  end

  defp band(range) do
    [
      part(:bass, seq(range, &bass/1)),
      part(:electric_bass, seq(range, &bass/1)),
      part(:skank, seq(range, &skank/1)),
      part(:organ, seq(range, &bubble/1))
    ]
  end

  # Each bar's chord, as its root and quality.
  defp chords, do: [{:a3, :minor7}, {:d3, :dom9}, {:a3, :minor7}, {:g3, :major}]
end
