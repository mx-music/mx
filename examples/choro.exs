import Mx

defmodule Choro do
  import Mx

  # Every player reads the same chart: a chord per bar, or two chords in a bar written as a pair.
  # A is in G major, B in its relative minor, E minor, and C in its subdominant, C major.
  def chart(:a) do
    [
      {:g2, :major6},
      {:gs2, :dim7},
      {:a2, :minor7},
      {:d2, :dom7},
      {:b2, :minor7},
      {:e2, :dom7_flat9},
      [{:a2, :minor7}, {:d2, :dom7}],
      {:g2, :major6}
    ]
  end

  def chart(:b) do
    [
      {:e2, :minor},
      {:b2, :dom7_flat9},
      {:e2, :minor},
      {:e2, :dom7},
      {:a2, :minor6},
      {:e2, :minor},
      [{:fs2, :half_dim7}, {:b2, :dom7}],
      {:e2, :minor}
    ]
  end

  def chart(:c) do
    [
      {:c2, :major6},
      {:cs2, :dim7},
      [{:d2, :minor7}, {:g2, :dom7}],
      {:c2, :major6},
      {:c2, :dom7},
      {:f2, :major6},
      {:f2, :minor6},
      {:d2, :dom7}
    ]
  end

  # The chord on each of a section's sixteen beats.
  def chords(section) do
    Enum.flat_map(chart(section), fn
      {_, _} = chord -> [chord, chord]
      pair -> pair
    end)
  end

  def flute(section) do
    keys = %{a: scale(:g3, :major), b: scale(:e3, :harmonic_minor), c: scale(:c3, :major)}
    beats = chords(section)

    # A strain plays the same melody every time it comes round.
    :rand.seed(:exsss, {Enum.find_index([:a, :b, :c], &(&1 == section)), 22, 9})

    classes = fn {root, quality} -> Enum.map(chord(root, quality), &rem(&1, 12)) end
    key = Enum.uniq(Enum.map(keys[section], &rem(&1, 12)))

    # The notes to run through over a chord: the key, bent to the chord where they clash with it.
    line = fn chord ->
      tones = classes.(chord)
      outside = tones -- key
      kept = Enum.reject(key, fn pc -> Enum.any?(outside, &(abs(&1 - pc) in [1, 11])) end)
      Enum.filter(64..96, &(rem(&1, 12) in (kept ++ tones)))
    end

    Enum.map_reduce(0..15, 76, fn beat, current ->
      chord = Enum.at(beats, beat)
      arpeggio = Enum.filter(64..96, &(rem(&1, 12) in classes.(chord)))
      near = Enum.min_by(arpeggio -- [current], &abs(&1 - current))
      run = line.(chord)
      cell = cell(beat, current)
      notes = cell_notes(cell, near, arpeggio, run)
      notes = if length(notes) < 4 and cell != :land, do: falling(run, near), else: notes
      {cell_music(cell, near, notes), List.last(notes)}
    end)
    |> elem(0)
    |> seq()
  end

  def cell(beat, _current) when beat in [7, 15], do: :land
  def cell(_beat, current) when current > 86, do: pick([:run_down, :arpeggio_down, :neighbour])
  def cell(_beat, current) when current < 70, do: pick([:arpeggio_up, :run_up, :neighbour])

  def cell(_beat, _current) do
    pick([:arpeggio_up, :arpeggio_down, :run_down, :run_down, :run_up, :neighbour])
  end

  def cell_notes(:land, near, _arpeggio, _run), do: [near]
  def cell_notes(:arpeggio_up, near, arpeggio, _run), do: rising(arpeggio, near)
  def cell_notes(:arpeggio_down, near, arpeggio, _run), do: falling(arpeggio, near)
  def cell_notes(:run_up, near, _arpeggio, run), do: rising(run, near)
  def cell_notes(:run_down, near, _arpeggio, run), do: falling(run, near)

  def cell_notes(:neighbour, near, arpeggio, _run) do
    [near, near - 1, near, Enum.find(arpeggio, near, &(&1 > near))]
  end

  def rising(notes, from), do: notes |> Enum.filter(&(&1 >= from)) |> Enum.take(4)

  def falling(notes, from) do
    notes |> Enum.filter(&(&1 <= from)) |> Enum.reverse() |> Enum.take(4)
  end

  def cell_music(:land, near, _notes), do: note(near, 1, vel: 0.7, sustain: 0.75, release: 0.2)

  def cell_music(_cell, _near, notes) do
    sixteenths =
      Enum.with_index(notes, fn note, index ->
        vel = if index == 0, do: 0.75, else: 0.55
        {index * 0.25, note(note, 0.25, vel: vel, sustain: 0.17, release: 0.08)}
      end)

    at(sixteenths, 1)
  end

  # The cavaquinho keeps the rhythm: close four-note chords strummed down on the beat and up off it.
  def cavaquinho(section) do
    beats = chords(section)

    # Each tone of the chord placed between D4 and C#5, as the four strings reach; a five-note chord leaves out its root.
    voicing = fn {root, quality} -> voice(chord(root, quality), from: 62, to: 73, limit: 4) end

    pattern = [
      {0, 0.025, 0.7, 0.3},
      {0.5, -0.02, 0.45, 0.12},
      {0.75, 0.025, 0.6, 0.25},
      {1.25, -0.02, 0.45, 0.12},
      {1.5, 0.025, 0.65, 0.3}
    ]

    strums =
      for bar <- 0..7,
          {offset, strum, vel, length} <- pattern,
          do: {bar * 2 + offset, strum, vel, length}

    strums =
      for {beat, strum, vel, length} <- strums do
        notes = voicing.(Enum.at(beats, trunc(beat)))

        # The first string the pick meets sounds loudest: the lowest going down, the highest coming up.
        down = Enum.map(Enum.take([1, 0.9, 0.85, 0.8], length(notes)), &Float.round(&1 * vel, 2))
        vels = if strum > 0, do: down, else: Enum.reverse(down)

        {beat,
         note(notes, length, strum: strum, vel: vels, sustain: length, release: 0.06, amp: 0.22)}
      end

    at(strums, 16)
  end

  # The 7-string guitar: the root on the beat and a note leading to the next chord, and a run down to it at the end of each phrase.
  def guitar(section, coming) do
    keys = %{
      a: scale(:g1, :major, octaves: 3),
      b: scale(:e1, :harmonic_minor, octaves: 3),
      c: scale(:c1, :major, octaves: 3)
    }

    beats = chords(section)
    following = chords(coming)

    # The root between B1 and A#2, so the low B string of the 7-string guitar gets used.
    low = fn {root, quality} -> 35 + rem(hd(chord(root, quality)) - 35 + 120, 12) end

    bars =
      for bar <- 0..7 do
        chord = Enum.at(beats, bar * 2)
        next = Enum.at(beats ++ following, bar * 2 + 2)
        root = low.(chord)
        target = low.(next)

        if bar in [3, 7] do
          # A baixaria: the root, then sixteenths down the key towards the next chord's root.
          steps =
            keys[section]
            |> Enum.filter(&(&1 > target and &1 < root + 12))
            |> Enum.reverse()
            |> Enum.take(-6)

          steps =
            if length(steps) < 6, do: Enum.to_list((target + 6)..(target + 1)//-1), else: steps

          seq([
            note(root, 0.5, vel: 0.75, sustain: 0.4, release: 0.1)
            | Enum.map(steps, &note(&1, 0.25, vel: 0.6, sustain: 0.18, release: 0.06))
          ])
        else
          second = low.(Enum.at(beats, bar * 2 + 1))
          leading = target + if(rem(bar, 2) == 0, do: -1, else: 1)

          seq([
            note(root, 1, vel: 0.7, sustain: 0.8, release: 0.1),
            note(second + 7, 0.5, vel: 0.5, sustain: 0.35, release: 0.08, amp: 0.45),
            note(leading, 0.5, vel: 0.55, sustain: 0.35, release: 0.08, amp: 0.45)
          ])
        end
      end

    seq(bars)
  end

  # The pandeiro in sixteenths: thumb, fingertips, heel, fingertips, its bass closed on each bar's first beat and open on its second.
  # mx's thumb has no closed bass, so the first beat is the thumb played softly.
  def pandeiro_thumb do
    items =
      for _ <- 1..8,
          do: seq([hit(vel: 0.4, amp: 0.45), rest(1), hit(vel: 0.75, amp: 0.45), rest(1)])

    seq(items)
  end

  def pandeiro_jingles do
    items = for _ <- 1..32, do: seq([rest(0.25), hit(amp: 0.25), rest(0.25)])
    seq(items)
  end

  def pandeiro_heel do
    items = for _ <- 1..16, do: seq([rest(0.5), hit(amp: 0.35), rest(0.5)])
    seq(items)
  end

  # A choro in 2/4: each pass plays one section of eight bars, in the order of the form.
  def form do
    sections = for {section, count} <- [a: 2, b: 2, a: 1, c: 2, a: 1], _ <- 1..count, do: section

    sections
    |> Enum.zip(tl(sections) ++ [hd(sections)])
    |> Enum.map(fn {section, coming} ->
      together([
        part(:flute, flute(section),
          synth: :flute,
          defaults: [amp: 1.13],
          fx: [reverb: [room: 0.45, mix: 0.25]]
        ),
        part(:cavaquinho, cavaquinho(section),
          synth: :cavaquinho,
          fx: [reverb: [room: 0.3, mix: 0.15]]
        ),
        part(:guitar, guitar(section, coming),
          synth: :guitar,
          defaults: [amp: 0.55],
          fx: [reverb: [room: 0.3, mix: 0.15]]
        ),
        part(:pandeiro_thumb, pandeiro_thumb(), synth: :pandeiro_thumb),
        part(:pandeiro_jingles, pandeiro_jingles(), synth: :pandeiro_jingles),
        part(:pandeiro_heel, pandeiro_heel(), synth: :pandeiro_heel)
      ])
    end)
  end
end

song(tempo: 88, music: repeat(seq(Choro.form())))
