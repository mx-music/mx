Code.require_file("score.exs", __DIR__)

defmodule ErbarmeDich.Paraphrase do
  @moduledoc """
  Bach's aria "Erbarme dich, mein Gott", BWV 244/39, as a concert pianist's free interpretation
  on mx's piano, in the line of Busoni's Bach transcriptions: the aria's music, reshaped and
  played for its feeling rather than read from the score.
  A prelude states the violin's opening sigh alone, high and slow over the bass's deep octaves.
  The ritornello follows with the continuo's knocking eighths, then the alto's "Erbarme dich"
  sings in the middle of the keyboard while the violin's answers sparkle an octave higher.
  The forte ritornello thunders in octaves, the melody doubled over full chords and the bass in
  octaves; the second part flows over broken chords, rises to the return of the opening theme as
  the climax, and breaks into a cadenza on F sharp that climbs the keyboard and falls back to the
  sigh.
  The alto's last phrase follows softly, and a coda recalls the opening sigh twice, slower each
  time, before ending on B major, the mercy the aria asks for.
  The notes are those of score.exs beside this song, the cadenza and the coda written for it.
  """

  @tempo 50

  use Mx.Song, tempo: @tempo

  part :piano,
    synth: :piano,
    defaults: [release: 0.4, amp: 1.7],
    fx: [reverb: [room: 0.9, damp: 0.45, mix: 0.35]]

  def song do
    part(:piano, at(piano(), beats()))
  end

  defp piano do
    for {beat, note, vel, sustain, pedal} <- strokes(),
        do: {beat, note(note, sustain, vel: vel, pedal: pedal)}
  end

  # The sections in the order they play, each placed after the one before.
  defp sections do
    [
      prelude(),
      passage(:ritornello, {0, 0}, {8, 11},
        loudness: [{0, 0.36}, {0.3, 0.46}, {0.5, 0.4}, {0.85, 0.56}, {1, 0.42}],
        hold: 2
      ),
      passage(:song, {8, 11}, {22, 11},
        loudness: [{0, 0.38}, {0.4, 0.46}, {0.75, 0.52}, {1, 0.46}]
      ),
      passage(:grand, {22, 11}, {26, 9},
        loudness: [{0, 0.64}, {0.6, 0.76}, {1, 0.58}],
        pace: [{0, 1.0}, {1, 1.0}]
      ),
      passage(:flowing, {26, 9}, {35, 0},
        loudness: [{0, 0.38}, {0.5, 0.48}, {1, 0.62}],
        pace: [{0, 1.04}, {0.5, 0.97}, {1, 1.0}],
        hold: 1
      ),
      passage(:grand, {39, 0}, {43, 0},
        loudness: [{0, 0.7}, {0.55, 0.88}, {1, 0.74}],
        pace: [{0, 1.2}, {0.08, 1.02}, {0.8, 1.0}, {1, 1.15}]
      ),
      cadenza(),
      passage(:song, {44, 0}, {46, 9},
        loudness: [{0, 0.4}, {0.5, 0.36}, {1, 0.28}],
        pace: [{0, 1.08}, {1, 1.12}],
        hold: 5
      ),
      coda()
    ]
  end

  # Every stroke as {beat, note, velocity, sustain, pedal}, from the first note.
  defp strokes do
    {notes, _} =
      Enum.flat_map_reduce(sections(), 0, fn section, start ->
        notes = for note <- section.notes, do: Map.merge(note, place(section, note, start))
        {notes, start + section.length}
      end)

    clock = clock(notes)
    lines = Enum.group_by(notes, &{&1.section, &1.kind})
    keys = Enum.group_by(notes, & &1.note)

    notes
    |> Enum.map(&stroke(&1, lines, keys, clock))
    |> Enum.sort()
  end

  defp place(section, note, start) do
    %{
      at: start + note.at,
      local: note.at / section.length,
      section: start,
      loudness: section.loudness,
      pace: section.pace,
      pedal: section.pedal,
      ending: start + section.length
    }
  end

  # How many beats the performance lasts, with the last chord and its reverb.
  defp beats do
    strokes()
    |> Enum.map(fn {beat, _note, _vel, sustain, _pedal} -> beat + sustain end)
    |> Enum.max()
    |> Kernel.+(4)
    |> Float.round(3)
  end

  # The violin's first two bars an octave up and alone, each harmony a deep octave in the bass
  # and a soft chord, slow and free.
  defp prelude do
    notes = written({0, 0}, {2, 10})

    melody =
      for %{voice: :violin} = note <- notes, do: %{note | note: note.note + 12, kind: :melody}

    under =
      for %{voice: :bass, eighth: eighth} = note <- notes,
          eighth in [0, 6],
          low = deep(note.note),
          {pitch, kind} <- [{low, :bass}, {low + 12, :bass_octave}],
          do: %{note | note: pitch, kind: kind, length: 6}

    chords =
      for %{voice: :inner, eighth: eighth} = note <- notes,
          eighth in [0, 6],
          do: %{note | kind: :harmony, length: 6}

    section(melody ++ under ++ chords, 24,
      loudness: [{0, 0.24}, {0.5, 0.32}, {1, 0.22}],
      pace: [{0, 1.4}, {0.3, 1.18}, {0.85, 1.25}, {1, 1.7}],
      pedal: 1,
      hold: 3
    )
  end

  # A stretch of the aria from one {bar, eighth} to another, in one of the textures.
  defp passage(style, from, to, opts) do
    notes = written(from, to)
    length = position(to) - position(from)
    pedal = %{ritornello: 0.5, song: 0.75, flowing: 0.9, grand: 0.9}[style]

    style
    |> texture(notes)
    |> section(length, [pedal: pedal] ++ opts)
  end

  # The ritornello as written: the violin leads over the organ's harmony and the knocking bass,
  # each bar's first note doubled an octave down.
  defp texture(:ritornello, notes) do
    lead(notes, :violin) ++ harmony(notes) ++ knocking(notes, [0])
  end

  # The alto sings in the middle of the keyboard and the violin answers an octave higher, over
  # the knocking bass.
  defp texture(:song, notes) do
    {alto, violin} = sung(notes)
    alto ++ violin ++ harmony(notes) ++ knocking(notes, [0])
  end

  # The alto and the violin over the harmony broken into sixteenths, as Liszt's accompaniments
  # flow, and the bass held on each beat.
  defp texture(:flowing, notes) do
    {alto, violin} = sung(notes)
    alto ++ violin ++ broken(notes) ++ held_bass(notes)
  end

  # The violin's line in octaves over full chords on each beat, the alto answering inside them,
  # and the bass's eighths in octaves.
  defp texture(:grand, notes) do
    melody = lead(notes, :violin)

    octaves =
      for note <- melody do
        pitch = if note.note < 80, do: note.note + 12, else: note.note - 12
        %{note | note: pitch, kind: :melody_octave}
      end

    answer = for %{voice: :alto} = note <- notes, do: %{note | kind: :answer}

    melody ++
      octaves ++
      answer ++ struck(notes) ++ knocking(notes, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  end

  defp lead(notes, voice),
    do: for(%{voice: ^voice} = note <- notes, do: %{note | kind: :melody})

  # The alto leads while it sings, the violin answering an octave up; the violin leads when it
  # is silent.
  defp sung(notes) do
    alto = lead(notes, :alto)

    violin =
      for %{voice: :violin} = note <- notes do
        if singing?(note.at, alto),
          do: %{note | note: note.note + 12, kind: :answer},
          else: %{note | kind: :melody}
      end

    {alto, violin}
  end

  defp singing?(at, alto), do: Enum.any?(alto, &(at >= &1.at - 2 and at < &1.at + &1.length + 2))

  # The organ's voices below the lowest melody note sounding, so the melodies stand clear.
  defp harmony(notes) do
    for %{voice: :inner} = note <- notes,
        note.note < lowest(notes, note.at),
        do: %{note | kind: :harmony}
  end

  defp lowest(notes, at) do
    notes
    |> Enum.filter(&(&1.voice in [:violin, :alto] and at >= &1.at and at < &1.at + &1.length))
    |> Enum.map(& &1.note)
    |> Enum.min(fn -> 128 end)
  end

  # The continuo's repeated eighths, a bar sitting high taken an octave down, and the eighths
  # named doubled an octave below.
  defp knocking(notes, doubled) do
    for %{voice: :bass} = note <- notes,
        pitch = note.note + shift(notes, note),
        {pitch, kind} <- [{pitch, :bass}] ++ octave_below(pitch, note.eighth in doubled),
        do: %{note | note: pitch, kind: kind}
  end

  defp octave_below(pitch, true) when pitch - 12 >= 24, do: [{pitch - 12, :bass_octave}]
  defp octave_below(_pitch, _doubled), do: []

  defp shift(notes, note) do
    bar = Enum.filter(notes, &(&1.voice == :bass and &1.bar == note.bar))
    if mean(bar) >= 50, do: -12, else: 0
  end

  # The bass note on each beat, held through it, deep, with an octave under each bar's first.
  defp held_bass(notes) do
    for %{voice: :bass} = note <- notes,
        beat?(note.eighth),
        low = deep(note.note) + 12,
        {pitch, kind} <- [{low, :bass}] ++ octave_below(low, note.eighth == 0),
        do: %{note | note: pitch, kind: kind, length: 3}
  end

  # The harmony on each beat broken into six sixteenths, up and down through its notes below
  # the melodies.
  defp broken(notes) do
    for %{voice: :bass} = bass <- notes, beat?(bass.eighth) do
      tones = tones(notes, bass.at)
      ceiling = min(lowest(notes, bass.at), 68)
      range = for pitch <- 48..(ceiling - 1)//1, rem(pitch, 12) in tones, do: pitch
      figure(bass, Enum.take(range, -4))
    end
    |> Enum.concat()
  end

  defp figure(_bass, tones) when length(tones) < 3, do: []

  defp figure(bass, tones) do
    pattern = tones ++ (tones |> Enum.reverse() |> tl() |> Enum.drop(-1))

    for {pitch, step} <- Enum.with_index(Stream.cycle(pattern) |> Enum.take(6)),
        do: %{
          bass
          | at: bass.at + step * 0.5,
            note: pitch,
            length: 1.5,
            kind: :figure,
            eighth: bass.eighth + step * 0.5
        }
  end

  # The pitch classes sounding at a moment in the organ and the bass.
  defp tones(notes, at) do
    notes
    |> Enum.filter(&(&1.voice in [:inner, :bass] and at >= &1.at and at < &1.at + &1.length))
    |> Enum.map(&rem(&1.note, 12))
    |> Enum.uniq()
  end

  # The organ's chord on each beat, struck whole and doubled an octave down.
  defp struck(notes) do
    for %{voice: :inner} = note <- notes,
        beat?(note.eighth) or (note.eighth == trunc(note.eighth) and note.length >= 3),
        note.note < lowest(notes, note.at) or note.note < 76,
        {pitch, kind} <-
          [{note.note, :chord}] ++
            if(note.note - 12 >= 50, do: [{note.note - 12, :chord}], else: []),
        do: %{note | note: pitch, kind: kind, length: max(note.length, 3)}
  end

  # The cadenza in place of bar 43: from the bass's F sharp an arpeggio of F sharp seven climbs
  # to the top of the keyboard, quickening, trills on its peak, and falls back down B minor's
  # harmonic scale in octaves, slowing, to the sigh of D on C sharp over the F sharp.
  defp cadenza do
    rising = for pitch <- 42..90, rem(pitch, 12) in [6, 10, 1, 4], do: pitch
    {up, top} = climb(rising, 1, 0.55, 0.2)

    trill =
      for step <- 0..13,
          do: %{at: top + 0.75 + step * 0.17, note: 91 - rem(step, 2), length: 0.2, kind: :run}

    falling = for pitch <- 88..62//-1, rem(pitch, 12) in [11, 1, 2, 4, 6, 7, 10], do: pitch
    {down, bottom} = climb(falling, top + 4.5, 0.16, 0.42)
    octaves = for note <- down, do: %{note | note: note.note - 12}

    notes =
      [
        %{at: 0, note: 30, length: 12, kind: :bass},
        %{at: 0, note: 42, length: 12, kind: :bass_octave},
        %{at: top, note: 90, length: 0.75, kind: :melody},
        %{at: top, note: 78, length: 0.75, kind: :melody_octave},
        %{at: top + 3.2, note: 90, length: 1.3, kind: :melody},
        %{at: top + 4.5, note: 30, length: 10, kind: :bass},
        %{at: top + 4.5, note: 42, length: 10, kind: :bass_octave},
        %{at: bottom + 0.5, note: 74, length: 2, kind: :melody},
        %{at: bottom + 2.5, note: 73, length: 3, kind: :melody},
        %{at: bottom + 2.5, note: 54, length: 3, kind: :harmony},
        %{at: bottom + 2.5, note: 58, length: 3, kind: :harmony},
        %{at: bottom + 2.5, note: 64, length: 3, kind: :harmony}
      ] ++ up ++ trill ++ down ++ octaves

    length = bottom + 6

    section(Enum.map(notes, &Map.merge(%{eighth: 0.5, bar: 43, voice: :cadenza}, &1)), length,
      loudness: [{0, 0.6}, {0.28, 0.88}, {0.45, 0.8}, {0.78, 0.42}, {1, 0.32}],
      pace: [
        {0, 1.0},
        {0.28, 0.92},
        {0.3, 1.5},
        {0.33, 1.1},
        {0.45, 1.4},
        {0.5, 1.0},
        {0.75, 1.15},
        {1, 1.6}
      ],
      pedal: 1
    )
  end

  # A run through the pitches, its notes spaced from one gap to another, and the eighth it ends on.
  defp climb(pitches, start, first, last) do
    count = length(pitches)

    {notes, ending} =
      pitches
      |> Enum.with_index()
      |> Enum.map_reduce(start, fn {pitch, index}, at ->
        gap = first + (last - first) * index / max(count - 1, 1)
        {%{at: at, note: pitch, length: 0.6, kind: :run}, at + gap}
      end)

    {notes, ending}
  end

  # The opening sigh an octave up over the deep B, again where it was written, slower, and the
  # last chord, B major, rolled slowly from the bottom.
  defp coda do
    sigh = [{0, 74, 1.5}, {1.5, 73, 0.5}, {2, 71, 1}, {3, 71, 1.5}, {4.5, 70, 0.5}, {5, 71, 3}]

    first =
      for {at, pitch, length} <- sigh,
          do: %{at: at, note: pitch + 12, length: length, kind: :melody}

    again =
      for {at, pitch, length} <- Enum.take(sigh, 3),
          do: %{at: 9 + at, note: pitch, length: length, kind: :melody}

    last =
      for pitch <- [35, 47, 54, 59, 63, 66, 71, 75],
          do: %{at: 15, note: pitch, length: 10, kind: :final}

    deep = [
      %{at: 0, note: 35, length: 9, kind: :bass},
      %{at: 0, note: 47, length: 9, kind: :bass_octave},
      %{at: 9, note: 43, length: 6, kind: :bass},
      %{at: 9, note: 55, length: 6, kind: :harmony},
      %{at: 9, note: 64, length: 6, kind: :harmony}
    ]

    notes =
      Enum.map(
        first ++ again ++ deep ++ last,
        &Map.merge(%{eighth: 0, bar: 47, voice: :coda}, &1)
      )

    section(notes, 16,
      loudness: [{0, 0.3}, {0.55, 0.24}, {1, 0.22}],
      pace: [{0, 1.3}, {0.5, 1.5}, {0.85, 1.9}, {1, 2.2}],
      pedal: 1
    )
  end

  # A section as its notes, counted in eighths from its start, and how it is played; a hold
  # lets what sounds at its end ring for more eighths before the next section.
  defp section(notes, length, opts) do
    hold = Keyword.get(opts, :hold, 0)

    notes =
      for note <- notes do
        if note.at + note.length >= length - 0.01 and hold > 0,
          do: %{note | length: length + hold - note.at},
          else: note
      end

    %{
      notes: notes,
      length: length + hold,
      loudness: Keyword.fetch!(opts, :loudness),
      pace: Keyword.get(opts, :pace, [{0, 1.0}, {1, 1.0}]),
      pedal: Keyword.get(opts, :pedal, 0.8)
    }
  end

  # The notes of the score from one {bar, eighth} up to another, counted in eighths from the
  # first.
  defp written(from, to) do
    first = position(from)
    last = position(to)

    for bar <- elem(from, 0)..elem(to, 0),
        {^bar, violin, alto, inner, bass} = ErbarmeDich.Score.bar(bar),
        {voice, notes} <- [violin: violin, alto: alto, inner: inner, bass: bass],
        {eighth, note, length} <- notes,
        at = position({bar, eighth}),
        at >= first and at < last do
      %{
        voice: voice,
        at: at - first,
        note: note,
        length: length,
        eighth: eighth,
        bar: bar,
        kind: voice
      }
    end
    |> Enum.uniq_by(&{&1.at, &1.note})
  end

  defp position({0, eighth}), do: eighth
  defp position({bar, eighth}), do: 1 + (bar - 1) * 12 + eighth

  defp beat?(eighth), do: eighth == trunc(eighth) and rem(trunc(eighth), 3) == 0

  defp deep(pitch) when pitch > 40, do: deep(pitch - 12)
  defp deep(pitch), do: pitch

  defp mean([]), do: 0
  defp mean(notes), do: Enum.sum(Enum.map(notes, & &1.note)) / length(notes)

  defp stroke(note, lines, keys, clock) do
    start = max(time(clock, note.at) + offset(note) * @tempo / 60, 0.0)
    sustain = time(clock, release(note, lines, keys)) - start

    {Float.round(start, 3), note.note, velocity(note, lines), Float.round(max(sustain, 0.05), 3),
     note.pedal}
  end

  # When a key is let go, in eighths: the melodies bind each note into the next and lift before a
  # breath, the knocking bass is detached, and a key struck again lets go first.
  defp release(note, lines, keys) do
    finish = note.at + note.length

    held =
      cond do
        note.kind in [:melody, :melody_octave, :answer] ->
          case after_note(note, lines) do
            %{at: at} when at <= finish -> finish + 0.15
            _ -> note.at + note.length * 0.85
          end

        note.kind in [:bass, :bass_octave] and note.length <= 1 ->
          note.at + 0.55

        note.kind == :harmony ->
          note.at + note.length * 0.95

        true ->
          finish
      end

    again =
      keys[note.note]
      |> Enum.filter(&(&1.at > note.at))
      |> Enum.map(&(&1.at - 0.05))
      |> Enum.min(fn -> held end)

    min(held, again)
  end

  # How early or late a key goes down, in seconds: the melody ahead, the chords rolled up from
  # below, the last chord slowly, and no two strokes exactly together.
  defp offset(note) do
    unsteady = (:erlang.phash2({note.at, note.note}, 1000) / 1000 - 0.5) * 0.012

    case note.kind do
      :final -> (note.note - 35) * 0.012
      :melody -> -0.015 + unsteady
      :answer -> -0.005 + unsteady
      :chord -> (note.note - 40) * 0.0012 + unsteady
      :harmony -> 0.012 + unsteady
      _ -> unsteady
    end
  end

  # How hard a key is struck: the section's loudness at that moment, the melody over all else,
  # and a melody's notes louder as they rise and as they last, leaning on the strong beats.
  defp velocity(note, lines) do
    loudness = along(note.loudness, note.local)

    weight =
      %{
        melody: 1,
        melody_octave: 0.78,
        answer: 0.66,
        harmony: 0.42,
        figure: 0.32,
        chord: 0.52,
        bass: 0.58,
        bass_octave: 0.5,
        run: 0.72,
        final: 0.6
      }[note.kind]

    vel = loudness * weight * (1 + shape(note, lines))
    Float.round(min(max(vel, 0.04), 0.98), 2)
  end

  defp shape(%{kind: kind} = note, lines) when kind in [:melody, :melody_octave, :answer] do
    breath =
      case after_note(note, lines) do
        %{at: at} when at <= note.at + note.length -> 0
        _ -> -0.06
      end

    length = min(max(0.07 * :math.log2(note.length), -0.12), 0.1)
    (note.note - 72) * 0.008 + length + stress(note.eighth) * 0.025 + breath
  end

  defp shape(%{kind: :bass, length: length} = note, _lines) when length <= 1 do
    if beat?(note.eighth), do: 0, else: -0.15
  end

  defp shape(%{kind: :run, note: pitch}, _lines), do: (pitch - 66) * 0.006
  defp shape(note, _lines), do: stress(note.eighth) * 0.02

  defp stress(eighth) when eighth == 0, do: 2
  defp stress(eighth) when eighth == trunc(eighth) and rem(trunc(eighth), 3) == 0, do: 1.5
  defp stress(eighth) when eighth == trunc(eighth), do: 0.5
  defp stress(_eighth), do: 0

  defp after_note(note, lines) do
    lines[{note.section, note.kind}]
    |> Enum.filter(&(&1.at > note.at))
    |> Enum.min_by(& &1.at, fn -> nil end)
  end

  # The beat each eighth of the performance starts on, as a tuple, each eighth stretched by its
  # section's pace, lingering on each downbeat and slowing into each section's end.
  defp clock(notes) do
    count = notes |> Enum.map(& &1.at) |> Enum.max() |> trunc() |> Kernel.+(40)
    places = notes |> Enum.uniq_by(& &1.section) |> Enum.sort_by(& &1.section)

    downbeats =
      for %{eighth: eighth, voice: voice} = note <- notes,
          eighth == 0 and voice in [:violin, :alto, :inner, :bass],
          into: MapSet.new(),
          do: trunc(note.at)

    0..count
    |> Enum.map(&stretch(&1, places, downbeats))
    |> Enum.scan(0, &(&1 * 0.5 + &2))
    |> then(&List.to_tuple([0 | &1]))
  end

  defp stretch(eighth, places, downbeats) do
    section = places |> Enum.filter(&(&1.section <= eighth)) |> List.last()
    length = section.ending - section.section
    into = eighth - section.section
    pace = along(section.pace, into / length)
    linger = if eighth in downbeats, do: 0.05, else: 0
    left = section.ending - eighth
    slowing = if left >= 0 and left <= 4, do: 0.35 * ((5 - left) / 4) ** 2, else: 0
    pace + linger + slowing
  end

  defp time(clock, eighth) do
    whole = trunc(eighth)
    from = elem(clock, whole)
    from + (elem(clock, whole + 1) - from) * (eighth - whole)
  end

  # The value at a place of a curve given as keys, straight between them.
  defp along(keys, at) do
    span =
      keys
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.find(fn [{from, _}, {to, _}] -> at >= from and at < to end)

    case span do
      [{from, a}, {to, b}] -> a + (b - a) * (at - from) / (to - from)
      nil -> keys |> List.last() |> elem(1)
    end
  end
end
