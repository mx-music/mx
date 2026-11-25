defmodule Vassourinhas do
  @moduledoc """
  Vassourinhas, the frevo de rua Matias da Rocha and Joana Batista Ramos wrote in Recife in 1909,
  in the public domain, in an arrangement written for mx's nine winds.
  A beat is a quarter note of 2/4, so a bar is two beats and each part of the tune is 32.
  The first part is the brass's fanfare and the second the reeds' tune, as a frevo de rua has them
  ask and answer.
  The form is an opening on the caixa, the first part, the second part twice, the first part
  handed from wind to wind, then both parts a tone higher with every wind playing, and a last
  chord.
  """

  use Mx.Song, tempo: 148

  @hall [reverb: [decay_seconds: 1.3, mix: 0.18]]

  # The nine winds, each placed and levelled in the band.
  part :flute, synth: :flute, defaults: [pan: -0.5, amp: 0.66], fx: @hall
  part :oboe, synth: :oboe, defaults: [pan: -0.3, amp: 0.48], fx: @hall
  part :clarinet, synth: :clarinet, defaults: [pan: -0.15, amp: 0.54], fx: @hall
  part :tenor_sax, synth: :tenor_sax, defaults: [pan: 0.15, amp: 0.54], fx: @hall
  part :trumpet, synth: :trumpet, defaults: [pan: 0.35, amp: 0.6], fx: @hall
  part :horn, synth: :horn, defaults: [pan: -0.4, amp: 0.48], fx: @hall
  part :trombone, synth: :trombone, defaults: [pan: 0.5, amp: 0.54], fx: @hall
  part :bassoon, synth: :bassoon, defaults: [pan: 0.2, amp: 0.54], fx: @hall
  part :tuba, synth: :tuba, defaults: [pan: 0, amp: 0.66], fx: @hall

  part :caixa, synth: :snare, defaults: [amp: 0.65]
  part :surdo, synth: :surdo, defaults: [amp: 0.8]
  part :pandeiro_thumb, synth: :pandeiro_thumb, defaults: [amp: 0.5]
  part :pandeiro_jingles, synth: :pandeiro_jingles, defaults: [amp: 0.5]

  def song do
    :rand.seed(:exsss, {1909, 1, 6})

    seq([
      opening(),
      fanfare(:on, 0, 0.8),
      tune(:on, 0, 0.7),
      wind(:back, 0, 0.8),
      handed_round(:higher),
      everyone(:back, 2, 0.9),
      fanfare(:last, 2, 0.95),
      last_chord(2)
    ])
  end

  # The opening: the caixa alone, then the surdo, pandeiro and bass on the dominant, the brass's
  # chords over them, and the tune's first notes from every wind.
  defp opening do
    dominant = List.duplicate(:G7, 4)
    line = for {beat, note, held} <- bass(dominant, 0, 38), do: {beat + 4, note, held}

    call = fn place, around ->
      for {beat, note, held} <- stabs([:G7, :G7], 0, place, around, [1.5, 2.5, 3.5]),
          do: {beat + 8, note, held}
    end

    pickup = for {beat, note, held} <- notes(lead_in()), do: {beat + 12, note, held}
    drums = percussion(8)
    later = fn hits -> Enum.filter(hits, fn {beat, _} -> beat >= 4 end) end

    section(
      16,
      %{
        tuba: tongued(line, 0, 0.7),
        bassoon: tongued(line, 12, 0.6),
        trumpet: tongued(call.(1, 74), 0, 0.6) ++ slurred(pickup, 0, 0.85, 2),
        horn: tongued(call.(3, 65), 0, 0.6) ++ slurred(pickup, -12, 0.8, 2),
        trombone: tongued(call.(2, 58), 0, 0.6) ++ slurred(pickup, -12, 0.85, 2),
        flute: slurred(pickup, 12, 0.8, 2),
        oboe: slurred(pickup, 0, 0.75, 2),
        clarinet: slurred(pickup, 0, 0.75, 2),
        tenor_sax: slurred(pickup, -12, 0.8, 2)
      },
      %{
        drums
        | surdo: later.(drums.surdo),
          pandeiro_thumb: later.(drums.pandeiro_thumb),
          pandeiro_jingles: later.(drums.pandeiro_jingles)
      }
    )
  end

  # The first part as a frevo de rua plays it: the trumpet's fanfare with the trombone an octave
  # under it and the horn between them, the reeds answering.
  defp fanfare(ending, key, vel) do
    chords = chords(:first) ++ chords(ending)
    tune = notes(first_part() <> " " <> ending(ending))
    last = if ending == :last, do: [{30, near(74, 1), 0.5}, {31, near(74, 1), 0.5}], else: []

    winds =
      %{
        trumpet: slurred(tune ++ last, key, vel, 2),
        trombone: slurred(tune ++ last, key - 12, vel, 2),
        horn: tongued(stabs(chords, key, 1, 64, [0, 2]), 0, vel - 0.2, sustain: 1.6)
      }
      |> Map.merge(reeds_answer(chords, key, vel - 0.1))
      |> Map.merge(low(chords, key, vel - 0.05))

    section(32, winds, percussion(16))
  end

  # The second part: the clarinet and tenor sax sing the tune in octaves, and the brass answer
  # with chords off the beat.
  defp tune(ending, key, vel) do
    chords = chords(:second) ++ chords(ending)
    melody = notes(second_part() <> " " <> ending(ending))
    brass = [trumpet: {1, 74}, horn: {3, 65}, trombone: {2, 58}]

    answers =
      for {wind, {place, around}} <- brass, into: %{} do
        {wind, tongued(stabs(chords, key, place, around, [1.5, 2.5, 3.5]), 0, vel - 0.15)}
      end

    winds =
      %{clarinet: sung(melody, key, vel), tenor_sax: sung(melody, key - 12, vel)}
      |> Map.merge(answers)
      |> Map.merge(low(chords, key, vel - 0.1))

    section(32, winds, percussion(16))
  end

  # The second part again as a frevo-ventania: the flute and clarinet run it in sixteenths, the
  # oboe, tenor sax and horn sing it, and the brass's chords grow louder.
  defp wind(ending, key, vel) do
    chords = chords(:second) ++ chords(ending)
    melody = notes(second_part() <> " " <> ending(ending))
    close = Enum.filter(melody, fn {beat, _, _} -> beat >= 28 end)
    running = ventania(melody, chords)

    winds =
      Map.merge(
        %{
          flute: slurred(running, key + 12, vel - 0.1, 1) ++ slurred(close, key + 12, vel, 2),
          clarinet: slurred(running, key, vel - 0.1, 1) ++ slurred(close, key, vel, 2),
          oboe: sung(melody, key, vel),
          tenor_sax: sung(melody, key - 12, vel),
          horn: sung(melody, key - 12, vel - 0.1),
          trumpet:
            tongued(stabs(chords, key, 1, 74, [1.5, 2.5, 3.5]), 0, vel) ++
              slurred(close, key, vel, 2),
          trombone:
            tongued(stabs(chords, key, 3, 60, [1.5, 2.5, 3.5]), 0, vel) ++
              slurred(close, key - 12, vel, 2)
        },
        low(chords, key, vel - 0.05)
      )

    section(32, winds, percussion(16))
  end

  # The first part handed round: two bars to each wind in turn over the bass and a quieter caixa,
  # and its ending from them all.
  defp handed_round(ending) do
    chords = chords(:first) ++ chords(ending)
    tune = notes(first_part() <> " " <> ending(ending))
    turns = [trumpet: 0, clarinet: 0, oboe: 0, tenor_sax: -12, flute: 12, horn: -12, bassoon: -24]

    together_at_the_end = [
      flute: 12,
      oboe: 0,
      clarinet: 0,
      tenor_sax: -12,
      trumpet: 0,
      horn: -12,
      trombone: -12
    ]

    solos =
      for {{wind, shift}, turn} <- Enum.with_index(turns), into: %{} do
        mine = Enum.filter(tune, fn {beat, _, _} -> div(trunc(beat), 4) == turn end)
        {wind, slurred(mine, shift, 0.7, 2)}
      end

    closing = Enum.filter(tune, fn {beat, _, _} -> beat >= 28 end)

    tutti =
      for {wind, shift} <- together_at_the_end, into: %{} do
        {wind, slurred(closing, shift, 0.85, 2)}
      end

    line = bass(chords, 0, 38)
    bassoon_bass = Enum.reject(line, fn {beat, _, _} -> beat >= 24 end)

    winds =
      solos
      |> Map.merge(tutti, fn _wind, solo, all -> solo ++ all end)
      |> Map.put(:tuba, tongued(line, 0, 0.65))
      |> Map.update!(:bassoon, &(&1 ++ tongued(bassoon_bass, 12, 0.5)))

    section(32, winds, percussion(16, 0.75))
  end

  # The second part from the whole band a tone up: the brass and the oboe play it syncopated, and
  # the flute, clarinet and tenor sax run under them.
  defp everyone(ending, key, vel) do
    chords = chords(:second) ++ chords(ending)
    melody = notes(second_part() <> " " <> ending(ending))
    close = Enum.filter(melody, fn {beat, _, _} -> beat >= 28 end)
    pushed = syncopated(melody)
    running = ventania(melody, chords)

    winds =
      Map.merge(
        %{
          trumpet: slurred(pushed, key, vel, 2),
          oboe: slurred(pushed, key, vel - 0.1, 2),
          horn: slurred(pushed, key - 12, vel - 0.1, 2),
          trombone: slurred(pushed, key - 12, vel, 2),
          flute:
            slurred(folded(running, key + 12, 96), 0, vel - 0.1, 1) ++
              slurred(close, key + 12, vel, 2),
          clarinet: slurred(running, key, vel - 0.1, 1) ++ slurred(close, key, vel, 2),
          tenor_sax: slurred(running, key - 12, vel - 0.1, 1) ++ slurred(close, key - 12, vel, 2)
        },
        low(chords, key, vel - 0.05)
      )

    section(32, winds, percussion(16))
  end

  # The last chord: the tonic with its sixth and ninth from every wind over a roll on the caixa,
  # and one short chord to close.
  defp last_chord(key) do
    voices = [
      flute: {2, 88},
      oboe: {9, 81},
      clarinet: {4, 76},
      trumpet: {7, 79},
      horn: {4, 64},
      tenor_sax: {9, 62},
      trombone: {7, 57},
      bassoon: {0, 48},
      tuba: {0, 38}
    ]

    winds =
      for {wind, {tone, around}} <- voices, into: %{} do
        note = near(around, tone + key)

        {wind,
         [
           {0, note(note, 0, vel: 0.9, sustain: 2.6, release: 0.1)},
           {3, note(note, 0, vel: 1, sustain: 0.3, release: 0.1)}
         ]}
      end

    roll = for step <- 0..23, do: {step * 0.125, hit(vel: 0.35 + step * 0.02)}
    jingles = for step <- 0..11, do: {step * 0.25, hit(vel: 0.5)}

    section(6, winds, %{
      caixa: roll ++ [{3, hit(vel: 0.95)}],
      surdo: [{0, hit(vel: 0.85)}, {3, hit(vel: 0.95)}],
      pandeiro_thumb: [{3, hit(vel: 0.9)}],
      pandeiro_jingles: jingles
    })
  end

  # The reeds under the fanfare: chords on the off-beats, a run up under its long note, and a run
  # down into its ending.
  defp reeds_answer(chords, key, vel) do
    voices = [flute: {3, 84}, oboe: {1, 77}, clarinet: {2, 70}, tenor_sax: {3, 62}]

    for {wind, {place, around}} <- voices, into: %{} do
      offs = stabs(chords, key, place, around, [0.5, 1.5, 2.5, 3.5])
      offs = Enum.reject(offs, fn {beat, _, _} -> trunc(beat) in [20, 21, 28, 29] end)
      up = run(near(around - 5, 2 + key), 6, 1, key, 20.5)
      down = run(near(around + 7, 7 + key), 8, -1, key, 28)
      {wind, tongued(offs, 0, vel - 0.15) ++ slurred(up ++ down, 0, vel, 1)}
    end
  end

  # The low winds under everything: the tuba's bass and the bassoon an octave over it.
  defp low(chords, key, vel) do
    line = bass(chords, key, 38)
    %{tuba: tongued(line, 0, vel), bassoon: tongued(line, 12, vel - 0.1)}
  end

  # A section of some beats as its parts: each wind's notes, and the percussion's hits.
  defp section(beats, winds, percussion) do
    wind_parts =
      for wind <- [
            :flute,
            :oboe,
            :clarinet,
            :tenor_sax,
            :trumpet,
            :horn,
            :trombone,
            :bassoon,
            :tuba
          ] do
        notes = Map.get(winds, wind, [])
        part(wind, at(notes, beats))
      end

    drum_parts =
      for name <- [:caixa, :surdo, :pandeiro_thumb, :pandeiro_jingles] do
        strokes = Map.get(percussion, name, [])
        part(name, at(strokes, beats))
      end

    together(wind_parts ++ drum_parts)
  end

  defp percussion(bars, level \\ 1) do
    %{
      caixa: caixa(bars, level),
      surdo: surdo(bars),
      pandeiro_thumb: pandeiro(bars, :thumb),
      pandeiro_jingles: pandeiro(bars, :jingles)
    }
  end

  # The tune in C as note names, an eighth each unless a length in beats follows the colon; r is a
  # rest.
  defp lead_in, do: "r:1 g5 fs5 g5 fs5 g5 a5"

  defp first_part do
    "g5:1 c5 c5 c5 c5 b4 c5 d5:1 f5 e5 f5 e5 f5 g5 f5:1 d5 d5 d5 d5 c5 d5 e5:1 g5 fs5 g5 fs5 g5 a5 " <>
      "g5 f5 e5 d5 cs5 as4 a4 g4 f4:1.5 a4 a4 f5 e5 d5 d5 c5 g4 c5 c5 b4 a4 b4"
  end

  defp second_part do
    "f5:1 b4:1 e5:1 d5:1 c5:1 g4:1 d5:1 c5:1 b4:1 d5:1 g5:1 fs5:1 g5:1 e5:1 f5:1 e5:1 " <>
      "a4:1 d5:1 e5:1 d5:1 g4:1 c5:1 d5:1 c5:1 b4:1 a5:1 g5:1 b4:1"
  end

  # How a part ends: on into the second part, on into it a tone higher, back to the first part, or
  # for good.
  defp ending(:on), do: "c5:1 a5:2 g5:1"
  defp ending(:higher), do: "c5:1 b5:2 a5:1"
  defp ending(:back), do: "c5 g5:1 fs5 g5 fs5 g5 a5"
  defp ending(:last), do: "c5:1 c5:1 r:2"

  # The chord of each bar of a part, and of the two bars each ending takes.
  defp chords(:first), do: ~w(C C G7 G7 G7 G7 C C C A7 Dm G7 C G7)a
  defp chords(:second), do: ~w(G7 G7 C C G7 G7 C C F F C C G7 G7)a
  defp chords(:on), do: [:C, :C]
  defp chords(:higher), do: [:C, :A7]
  defp chords(:back), do: [:C, :C]
  defp chords(:last), do: [:C, :Db7]

  # A chord's tones as semitones above C: its root, third, fifth, and the sixth or seventh that
  # colours it.
  defp tones(:C), do: [0, 4, 7, 9]
  defp tones(:F), do: [5, 9, 0, 2]
  defp tones(:G7), do: [7, 11, 2, 5]
  defp tones(:A7), do: [9, 1, 4, 7]
  defp tones(:Dm), do: [2, 5, 9, 0]
  defp tones(:Db7), do: [1, 5, 8, 11]

  # The tune's notes as {beat, note, beats}.
  defp notes(words) do
    {notes, _} =
      words
      |> String.split()
      |> Enum.flat_map_reduce(0, fn word, beat ->
        {name, held} =
          case String.split(word, ":") do
            [name] -> {name, 0.5}
            [name, held] -> {name, held |> Float.parse() |> elem(0)}
          end

        if name == "r" do
          {[], beat + held}
        else
          {[{beat, pitch(name), held}], beat + held}
        end
      end)

    notes
  end

  # The note nearest `around` that is `tone` semitones above some C.
  defp near(around, tone), do: around + Integer.mod(tone - around + 6, 12) - 6

  # A chord's tone by its place, 0 the root, in `key` semitones above C.
  defp tone(chord, place, key), do: Enum.at(tones(chord), place) + key

  # Where a player puts a note written at `beat`: the sixteenth after the beat a little late and
  # the one before the next a little early, as the caixa leans, and never quite where another
  # player puts it.
  defp placed(beat, loose) do
    lean =
      case Float.round(beat - Float.floor(beat * 1.0), 2) do
        0.25 -> 0.012
        0.75 -> -0.02
        _ -> 0
      end

    max(beat + lean + (:rand.uniform() - 0.5) * 2 * loose, 0)
  end

  # How hard a note is played: around `vel`, a little harder the higher it is in its line.
  defp played(vel, note, notes) do
    pitches = for {_, pitch, _} <- notes, do: pitch
    middle = Enum.sum(pitches) / length(notes)
    lift = (note - middle) / 12 * 0.08
    min(max(vel + lift + (:rand.uniform() - 0.5) * 0.08, 0.1), 1)
  end

  # A line played tongued: eighths short, longer notes held to just before the next.
  defp tongued(notes, shift, vel, opts \\ []) do
    for {beat, note, held} <- notes do
      sustain = if held <= 0.5, do: held * 0.55, else: held - 0.2
      opts = Keyword.merge([vel: played(vel, note, notes), sustain: sustain, release: 0.08], opts)
      {placed(beat, 0.012), note(note + shift, 0, opts)}
    end
  end

  # A line played slurred: the notes that follow one another within each `span` beats are one
  # breath, tongued at its first note and fingered to the others, and a note repeated is tongued
  # again.
  defp slurred(notes, shift, vel, span, opts \\ []) do
    notes
    |> Enum.chunk_while(
      [],
      fn
        note, [] ->
          {:cont, [note]}

        {beat, pitch, _} = note, [{before, last, held} | _] = breath ->
          joined = pitch != last and abs(before + held - beat) < 0.01 and held < 1.5
          {first, _, _} = List.last(breath)
          same_span = trunc(beat / span) == trunc(first / span)

          if joined and same_span do
            {:cont, [note | breath]}
          else
            {:cont, Enum.reverse(breath), [note]}
          end
      end,
      fn breath -> {:cont, Enum.reverse(breath), []} end
    )
    |> Enum.reject(&(&1 == []))
    |> Enum.map(fn [{beat, first, _} | rest] = breath ->
      {last_beat, _, last_held} = List.last(breath)
      start = placed(beat, 0.012)
      sustain = last_beat + last_held - beat - min(0.15, last_held * 0.35)

      changes =
        for {at, pitch, _} <- rest,
            do: {max(placed(at, 0.008) - start, 0.05), note: pitch + shift, note_slide: 0}

      opts =
        Keyword.merge(
          [vel: played(vel, first, notes), sustain: sustain, release: 0.08, changes: changes],
          opts
        )

      {start, note(first + shift, 0, opts)}
    end)
  end

  # The same in long breaths with a little vibrato, as the reeds sing the second part.
  defp sung(notes, shift, vel), do: slurred(notes, shift, vel, 4, vibrato: 0.08, release: 0.1)

  # The second part with the second note of each bar come an eighth early, the sincopada
  # brasileira.
  defp syncopated(notes) do
    for {beat, note, held} <- notes do
      cond do
        held == 1 and Integer.mod(trunc(beat), 2) == 0 and beat < 28 -> {beat, note, 0.5}
        held == 1 and Integer.mod(trunc(beat), 2) == 1 and beat < 28 -> {beat - 0.5, note, 1.5}
        true -> {beat, note, held}
      end
    end
  end

  # The frevo-ventania: each quarter of the second part as four sixteenths, the note, the chord's
  # tone under it, the note and the scale's step over it.
  defp ventania(notes, chords) do
    scale = [0, 2, 4, 5, 7, 9, 11]

    for {beat, note, held} <- notes, held == 1, beat < 28 do
      chord = Enum.at(chords, div(trunc(beat), 2))
      unders = for tone <- tones(chord), under = near(note - 4, tone), under < note, do: under
      under = Enum.max(unders)
      over = Enum.find((note + 1)..(note + 3), &(Integer.mod(&1, 12) in scale))

      for {step, sixteenth} <- Enum.with_index([note, under, note, over]) do
        {beat + sixteenth * 0.25, step, 0.25}
      end
    end
    |> List.flatten()
  end

  # A line moved by `shift` semitones, a note that would pass `top` played an octave lower.
  defp folded(notes, shift, top) do
    for {beat, note, held} <- notes do
      moved = note + shift
      {beat, if(moved > top, do: moved - 12, else: moved), held}
    end
  end

  # A run of sixteenths up or down the key's scale from a note.
  defp run(from, count, direction, key, beat) do
    scale = for step <- [0, 2, 4, 5, 7, 9, 11], do: Integer.mod(step + key, 12)

    from
    |> Stream.iterate(&(&1 + direction))
    |> Stream.filter(&(Integer.mod(&1, 12) in scale))
    |> Enum.take(count)
    |> Enum.with_index(fn note, i -> {beat + i * 0.25, note, 0.25} end)
  end

  # The bass, the root on the first beat of the bar and the fifth on the second, stepping up a
  # semitone into each new chord.
  defp bass(chords, key, around) do
    roots = for chord <- chords, do: near(around, tone(chord, 0, key))

    roots
    |> Enum.zip(tl(roots) ++ [List.last(roots)])
    |> Enum.with_index()
    |> Enum.flat_map(fn {{root, coming}, bar} ->
      fifth = if root + 7 <= around + 7, do: root + 7, else: root - 5

      if coming == root do
        [{bar * 2, root, 0.5}, {bar * 2 + 1, fifth, 0.5}]
      else
        [{bar * 2, root, 0.5}, {bar * 2 + 1, fifth, 0.25}, {bar * 2 + 1.5, coming - 1, 0.25}]
      end
    end)
  end

  # Short chords off the beat, one voice of them: the chord's tone at `place` nearest `around`, on
  # the beats given of every two bars, the last already in the chord to come.
  defp stabs(chords, key, place, around, beats) do
    for unit <- 0..(div(length(chords), 2) - 1), beat <- beats do
      at = unit * 4 + beat

      bar =
        min(
          if(beat >= 3.5, do: div(trunc(at), 2) + 1, else: div(trunc(at), 2)),
          length(chords) - 1
        )

      chord = Enum.at(chords, bar)
      {at, near(around, tone(chord, place, key)), 0.25}
    end
  end

  # The caixa's two bars: twelve sixteenths, the first, fourth and seventh accented and then the
  # eleventh, and a buzz roll through the last beat that grows into the next bar; every fourth
  # time the second bar is accents alone.
  defp caixa(bars, level) do
    for unit <- 0..(div(bars, 2) - 1) do
      accents = if rem(unit, 4) == 3, do: [0, 3, 6, 8, 10], else: [0, 3, 6, 10]

      strokes =
        for step <- 0..11 do
          vel = if step in accents, do: 0.85, else: 0.4 - rem(step, 2) * 0.06
          {step * 0.25, vel + (:rand.uniform() - 0.5) * 0.06}
        end

      rolled = for step <- 1..11, do: {3 + step / 12, 0.28 + step * 0.035}
      roll = [{3, 0.7} | rolled]

      for {beat, vel} <- strokes ++ roll,
          do: {unit * 4 + placed(beat, 0.006), hit(vel: vel * level)}
    end
    |> List.flatten()
  end

  # The surdo, muted on the first beat of the bar and open on the second, with a stroke more into
  # every eighth bar.
  defp surdo(bars) do
    for bar <- 0..(bars - 1),
        more = if(rem(bar, 8) == 7, do: [{1.5, [vel: 0.7]}], else: []),
        {beat, opts} <- [{0, [muted: 1, vel: 0.5]}, {1, [vel: 0.8]}] ++ more do
      opts = Keyword.update!(opts, :vel, &(&1 + (:rand.uniform() - 0.5) * 0.08))
      {bar * 2 + placed(beat, 0.008), hit(opts)}
    end
  end

  # The pandeiro's gallop, the thumb on each beat and the jingles on the two sixteenths that end
  # it.
  defp pandeiro(bars, :thumb) do
    for beat <- 0..(bars * 2 - 1), do: {placed(beat, 0.008), hit(vel: 0.7 - rem(beat, 2) * 0.1)}
  end

  defp pandeiro(bars, :jingles) do
    for beat <- 0..(bars * 2 - 1), {late, vel} <- [{0.5, 0.55}, {0.75, 0.45}] do
      {placed(beat + late, 0.008), hit(vel: vel + (:rand.uniform() - 0.5) * 0.08)}
    end
  end
end
