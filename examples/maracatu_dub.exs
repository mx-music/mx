defmodule MaracatuDub do
  @moduledoc """
  A dub of examples/maracatu.exs in D minor: the same batuque, slower and without the tarol, under
  a double bass, a guitar skank and a trombone.
  The bass plays where the alfaias' marcação strikes, and the mix pulls parts out and throws them
  into echo, as a dub is mixed.
  The riddim, Dm7, Dm7, Gm7 and Am7, and the trombone's tune are mx's own.
  """

  use Mx.Song, tempo: 96

  @room [reverb: [room: 0.6, damp: 0.5, mix: 0.2]]
  @tape [echo: [phase: 0.75, decay: 4, max_phase: 2, mix: 0.15]]
  @cross [ping_pong: [phase: 0.75, feedback: 0.5, max_phase: 2, mix: 0.08]]

  part :gongue, synth: :cowbell, defaults: [amp: 0.4, pan: 0.15, note: 65], fx: @cross ++ @room

  part :mineiro,
    synth: :ganza,
    defaults: [amp: 0.55, pan: -0.4],
    fx: [hpf: [cutoff: 0]] ++ @room

  part :agbe,
    synth: :cabasa,
    defaults: [amp: 0.3, pan: 0.4],
    fx: [flanger: [phase: 16, feedback: 0.4, mix: 0.2]] ++ @room

  part :caixa,
    synth: :snare,
    defaults: [amp: 0.7, pan: -0.2],
    fx: @cross ++ [reverb: [room: 0.8, damp: 0.4, mix: 0.3]]

  part :low_alfaia,
    synth: :surdo,
    defaults: [amp: 0.6, pan: -0.15, note: 33, muted: 0.6],
    fx: [reverb: [room: 0.4, damp: 0.6, mix: 0.1]]

  part :high_alfaia,
    synth: :surdo,
    defaults: [amp: 0.5, pan: 0.15, note: 38, muted: 0.6],
    fx: [reverb: [room: 0.4, damp: 0.6, mix: 0.1]]

  part :bass, synth: :double_bass, defaults: [pizz: 1, vel: 0.8], fx: [lpf: [cutoff: 76]]

  part :sub,
    synth: :saw,
    defaults: [amp: 0.3, cutoff: 62, res: 0.1, attack: 0.02, release: 0.15]

  part :skank,
    synth: :guitar,
    defaults: [vel: 0.5, amp: 1.3, pan: 0.35, release: 0.1],
    fx: [hpf: [cutoff: 0]] ++ @tape ++ @room

  part :trombone,
    synth: :trombone,
    defaults: [vel: 0.6, amp: 0.8, note_slide: 0.06, pan: -0.1],
    fx: @tape ++ [reverb: [room: 0.8, mix: 0.3]]

  def song do
    [:call, :riddim, :dub, :martelo]
    |> Enum.map(&section/1)
    |> seq()
    |> repeat()
  end

  # The gonguê in its echo, the mineiro opening through the filter and the trombone's first two
  # bars thrown into the tape; then the bass and the low alfaia on the marcação, and the virada.
  defp section(:call) do
    together([
      part(:gongue, together([gongue(1, 8), throw(:gongue, :ping_pong, 0, 14, 0.4, 0.08)])),
      part(
        :mineiro,
        together([
          mineiro(8),
          at(
            [
              {0, change({:mineiro, :hpf}, cutoff: 112, cutoff_slide: 0)},
              {0.5, change({:mineiro, :hpf}, cutoff: 0, cutoff_slide: 15)}
            ],
            32
          )
        ])
      ),
      part(:agbe, at([{0, change({:agbe, :flanger}, mix: 0.2, feedback: 0.4)}], 32)),
      part(
        :caixa,
        together([
          delay(caixa(:accents, 4), 16),
          at([{14, change({:caixa, :ping_pong}, mix: 0.08)}], 32)
        ])
      ),
      part(
        :trombone,
        together([
          seq([legato(Enum.take(phrase(:a), 10)), rest(24)]),
          throw(:trombone, :echo, 0, 12, 0.5, 0.15)
        ])
      ),
      part(:skank, at([{0, change({:skank, :echo}, mix: 0.15)}], 32)),
      part(:bass, delay(bass(1..4), 16)),
      part(:sub, delay(bass(1..4), 16)),
      part(:low_alfaia, delay(alfaia([:marcacao, :marcacao, :marcacao, :virada]), 16)),
      part(:high_alfaia, delay(alfaia([:virada]), 28))
    ])
  end

  # Everyone on the arrasto, the skank on two and four, and the trombone's two phrases.
  defp section(:riddim) do
    together([
      part(:gongue, gongue(1, 8)),
      part(:mineiro, mineiro(8)),
      part(:agbe, agbe(8)),
      part(:caixa, caixa(:whole, 8)),
      part(:low_alfaia, alfaia(baque(:arrasto))),
      part(:high_alfaia, alfaia(baque(:arrasto))),
      part(:bass, bass(1..8)),
      part(:sub, bass(1..8)),
      part(:skank, together([skank(1..8), throw(:skank, :echo, 12, 17, 0.5, 0.15)])),
      part(:trombone, legato(phrase(:a) ++ phrase(:b)))
    ])
  end

  # Drums and bass on the imalê, the caixa's accents crossing in the echo and the skank swept up
  # through the filter; then two bars without alfaias or bass, the shakers in the flanger and a
  # piece of the tune whose echo bends; the alfaias come back for the virada.
  defp section(:dub) do
    out = fn music -> seq([music.(1..4), rest(8), music.(7..8)]) end

    together([
      part(:gongue, together([gongue(2, 8), throw(:gongue, :ping_pong, 16, 24, 0.4, 0.08)])),
      part(:mineiro, delay(mineiro(4), 16)),
      part(
        :agbe,
        together([
          delay(agbe(4), 16),
          at(
            [
              {16, change({:agbe, :flanger}, mix: 0.7, feedback: 0.6)},
              {30, change({:agbe, :flanger}, mix: 0.2, feedback: 0.4)}
            ],
            32
          )
        ])
      ),
      part(
        :caixa,
        together([
          seq([caixa(:accents, 4), rest(12), caixa(:whole, 1)]),
          throw(:caixa, :ping_pong, 0, 28, 0.45, 0.08)
        ])
      ),
      part(
        :low_alfaia,
        seq([alfaia(List.duplicate(:imale, 4)), rest(8), alfaia([:imale, :virada])])
      ),
      part(:high_alfaia, seq([alfaia(List.duplicate(:imale, 4)), rest(12), alfaia([:virada])])),
      part(:bass, out.(&bass/1)),
      part(:sub, out.(&bass/1)),
      part(
        :skank,
        together([
          delay(skank(3..6), 8),
          throw(:skank, :echo, 8, 26, 0.55, 0.15),
          at(
            [
              {8, change({:skank, :hpf}, cutoff: 96, cutoff_slide: 12)},
              {26, change({:skank, :hpf}, cutoff: 0, cutoff_slide: 2)}
            ],
            32
          )
        ])
      ),
      part(
        :trombone,
        together([
          at([{16, legato(Enum.take(phrase(:a), 6))}], 32),
          throw(:trombone, :echo, 16, 30, 0.6, 0.15),
          at(
            [
              {20, change({:trombone, :echo}, phase: 0.5, phase_slide: 3)},
              {24, change({:trombone, :echo}, phase: 0.75, phase_slide: 2)}
            ],
            32
          )
        ])
      )
    ])
  end

  # Everyone on the martelo, the trombone's phrases in the other order, and the last bar thrown
  # into the echoes, which ring over the gonguê as the piece comes round.
  defp section(:martelo) do
    together([
      part(:gongue, gongue(2, 8)),
      part(:mineiro, mineiro(8)),
      part(:agbe, agbe(8)),
      part(
        :caixa,
        together([caixa(:whole, 8), at([{28, change({:caixa, :ping_pong}, mix: 0.4)}], 32)])
      ),
      part(:low_alfaia, alfaia(baque(:martelo))),
      part(:high_alfaia, alfaia(baque(:martelo))),
      part(:bass, bass(1..8)),
      part(:sub, bass(1..8)),
      part(
        :skank,
        together([
          skank(1..8),
          throw(:skank, :echo, 14, 16, 0.5, 0.15),
          at([{28, change({:skank, :echo}, mix: 0.55)}], 32)
        ])
      ),
      part(:trombone, legato(phrase(:b) ++ phrase(:a)))
    ])
  end

  # The part's effect opened to a mix at one beat and brought back to its own at another, within
  # a section.
  defp throw(name, effect, from, back, mix, own) do
    entries =
      for {beat, mix} <- [{from, mix}, {back, own}], do: {beat, change({name, effect}, mix: mix)}

    at(entries, 32)
  end

  # Bars of the gonguê in sixteenths: its first pattern starts a sixteenth after the beat, and its
  # second fills the beats in.
  defp gongue(pattern, bars) do
    bar = if pattern == 1, do: ~MX".x..x.x..x..x.x."s, else: ~MX"x.xxx.x.xx.xx.x."s
    steps(List.duplicate(bar, bars), 0.25, vel: 0.7)
  end

  # The mineiro shakes sixteenths with the third of each beat accented: d is down and u is up, in
  # capitals where accented.
  defp mineiro(bars) do
    strokes = [d: [vel: 0.45, up: 0], u: [vel: 0.45, up: 1], D: [vel: 0.85, up: 0]]
    steps(List.duplicate(~MX"duDu"s, 4 * bars), 0.25, strokes: strokes)
  end

  # The agbê plays an eighth and two sixteenths to a beat.
  defp agbe(bars) do
    strokes = [X: [vel: 0.8], x: [vel: 0.55]]
    steps(List.duplicate(~MX"X.xx"s, 4 * bars), 0.25, strokes: strokes)
  end

  # Bars of the caixa in sixteenths: A is an accent, g a soft stroke between accents and B an
  # accent the stick buzzes after.
  # Its accents alone are the same bar with the soft strokes left out.
  defp caixa(:whole, bars), do: caixa(~MX"AggAAgBgAAgAAgBg"s, bars)
  defp caixa(:accents, bars), do: caixa(~MX"A..AA.B.AA.AA.B."s, bars)

  defp caixa(bar, bars) do
    strokes = [A: [vel: 0.85], B: [vel: 0.85, buzz: 1], g: [vel: 0.3]]
    steps(List.duplicate(bar, bars), 0.25, strokes: strokes)
  end

  # Eight bars of a baque: seven of its bar and the virada.
  defp baque(baque), do: List.duplicate(baque, 7) ++ [:virada]

  # Bars on the alfaia: D is the right hand, which holds the heavy stick, and E the left, which
  # holds the thin one; a capital is an accent.
  defp alfaia(bars) do
    strokes = [D: [vel: 0.95], d: [vel: 0.8], E: [vel: 0.7], e: [vel: 0.45]]
    steps(Enum.map(bars, &bar/1), 0.25, strokes: strokes)
  end

  defp bar(:marcacao), do: ~MX"D.......eD..eD.."s
  defp bar(:arrasto), do: ~MX"D...eD..eD..eD.."s
  defp bar(:imale), do: ~MX"D...E.D.eD..eD.."s
  defp bar(:martelo), do: ~MX"ed.de.d.ed.de..."s
  defp bar(:virada), do: ~MX"e.D.e.D.eD.De.D."s

  # Bars of the bass, counted from 1 and wrapping every four, a sixteenth to a step: each bar
  # starts on its chord's root and answers on the second sixteenth of beats three and four.
  # Each note stops a little before its length is up.
  defp bass(bars) do
    riddim = [
      ~MX"d2:5 _:4 d2:3 _ f2:2 e2",
      ~MX"d2:5 _:4 a1:3 _ c2:3",
      ~MX"g1:5 _:4 g1:3 _ bb1:2 a1",
      ~MX"a1:5 _:4 a1:2 c2:2 e2:2 cs2"
    ]

    short = fn _step, steps -> [sustain: steps / 4 - 0.05] end
    steps(Enum.map(bars, &ring(riddim, &1 - 1)), 0.25, each: short)
  end

  # The skank on two and four, chopped twice on the last bar of the riddim.
  defp skank(bars) do
    seq(bars, fn bar ->
      chord =
        voice(chord(chord_at(chart(), 4, (bar - 1) * 4), from: :d3), from: 62, to: 74, limit: 4)

      beats = if rem(bar, 4) == 0, do: [1, 3, 3.25], else: [1, 3]
      hits = for beat <- beats, do: {beat, note(chord, 0.25)}
      at(hits, 4)
    end)
  end

  # The chart, a chord to each bar of four beats, played round.
  defp chart, do: ~MX"Dm7 Dm7 Gm7 Am7"

  # The trombone's two phrases over the four bars of the riddim, each note with its beats.
  # The first and the third bar come in on the second sixteenth, as the alfaias' accents do.
  defp phrase(:a) do
    [r: 0.25, a3: 0.75, d4: 1, c4: 0.5, a3: 0.5, f3: 1] ++
      [g3: 1, a3: 0.5, d3: 1.5, r: 1] ++
      [r: 0.25, bb3: 0.75, d4: 1, c4: 0.5, bb3: 0.5, g3: 1] ++
      [a3: 1, g3: 0.5, e3: 0.5, a3: 1.5, r: 0.5]
  end

  defp phrase(:b) do
    [d4: 1.5, f4: 0.5, e4: 0.5, d4: 0.5, c4: 1] ++
      [a3: 1, c4: 0.5, d4: 1.5, r: 1] ++
      [r: 0.25, g4: 0.75, f4: 0.5, d4: 0.5, bb3: 1, c4: 0.5, d4: 0.5] ++
      [e4: 1, d4: 0.5, c4: 0.5, a3: 1.5, r: 0.5]
  end

  # Each run of different notes slurred into one held note that slides between them.
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
    |> Enum.map(&held/1)
    |> seq()
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

  defp held([{:r, length, _}]), do: rest(length)

  defp held([{first, length, _} | others]) do
    {changes, total} =
      Enum.map_reduce(others, length, fn {name, beats, _}, beat ->
        {{beat, note: pitch(name)}, beat + beats}
      end)

    note(first, total, changes: changes)
  end
end
