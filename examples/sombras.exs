defmodule Sombras do
  @moduledoc """
  Sombras, the pasillo Carlos Brito Benavides of Quito wrote in 1930 to Rosario Sansores' poem,
  played without its words by a requinto, a first guitar and a guitar that accompanies.
  All three are FreePats' Spanish classical guitar, under Creative Commons 0; the requinto is the
  same recordings in the guitar's upper octave, made brighter.
  The pasillo is in 3/4 and A minor: an estribillo of nine bars that the requinto plays in thirds,
  the part A of sixteen bars, the estribillo, the part B of twenty, and the estribillo again.
  The estribillo, the sung melody, the chords and the bass are read from the score for voice and
  piano in Boris Mora's thesis, Universidad de Cuenca, 2020, the estribillo an octave below the
  piano's; the second voice under the melody, the requinto's answers, the breath at the end of
  each phrase and who plays what are this file's own.
  The first time the first guitar sings the melody alone and the requinto answers its long notes;
  the second time the two sing it as a duo does, the requinto above and the first guitar a third
  or a sixth below.
  The files are fetched as the song loads, about 20 MB.
  """

  use Mx.Song, tempo: 90

  # Each recorded key with the dB that bring its first half second level with the others, and the
  # cents it was measured sharp of its note.
  @keys Enum.map(
          ~w(G1:-2:14 G#1:-3:3 A1:-6:3 A#1:-3:1 B1:-2:5 C2:0:3 C#2:-1:-5 D2:0:0 D#2:-2:7 E2:-2:2 F2:0:8 G2:0:9 A2:0:5 B2:1:5 C3:0:5 D3:0:9 E3:0:7 F3:-1:4 F#3:-4:7 G3:1:4 G#3:-3:8 A3:-1:6 A#3:-2:8 B3:-2:14 C4:2:8 C#4:0:18 D4:0:8 D#4:-2:7 E4:1:-1 F4:1:3 F#4:-1:3 G4:0:4 A4:-4:6 A#4:5:1 B4:0:14 C5:5:10 C#5:-1:9 D5:0:12 D#5:5:6 E5:5:5 F5:2:-1 F#5:2:1 G5:-1:-2 G#5:0:-3 A5:0:11 A#5:2:3 B5:5:5 C6:7:8),
          fn word ->
            [name, db, cents] = String.split(word, ":")
            key = name |> String.downcase() |> String.replace("#", "s") |> pitch()
            {name, pitch(key), String.to_integer(db), String.to_integer(cents)}
          end
        )

  # A file declared as many cents above its key as it sounds plays every note in tune.
  @guitar for {name, key, _, cents} <- @keys,
              do: {{:freepats_spanish_guitar, "samples/#{name}.flac"}, note: key + cents / 100}

  @levels for {_, key, db, _} <- @keys, do: {key, db}

  @room [decay_seconds: 1.8, damp: 0.5, mix: 0.22]

  @tempo 90

  part :requinto,
    synth: sampled(@guitar),
    fx: [hpf: [cutoff: 93, mix: 0.5], level: [amp: 1.0], reverb: @room, pan: [pan: 0.3]]

  part :primera,
    synth: sampled(@guitar),
    fx: [level: [amp: 0.55], reverb: @room, pan: [pan: 0.05]]

  part :guitarra,
    synth: sampled(@guitar),
    fx: [level: [amp: 0.36], reverb: @room, pan: [pan: -0.3]]

  part :tempo, []

  def song do
    :rand.seed(:exsss, {1891, 11, 12})

    band([
      opening(),
      estribillo(0.78),
      sung(:a, 0.78),
      estribillo(0.8),
      sung(:b, 0.82),
      estribillo(0.84),
      duo(:a, 0.84, :on),
      estribillo(0.84),
      duo(:b, 0.9, :last),
      last_chords()
    ])
  end

  # The two sixteenths that lead into the first estribillo.
  defp opening, do: section(1, line(:requinto, notes(tune(:opening)), 0.75))

  # The estribillo: the requinto in thirds over the pasillo's pattern.
  defp estribillo(vel) do
    section(
      27,
      [line(:requinto, notes(tune(:estribillo)), vel), accompany(bars(:estribillo), vel - 0.2)],
      fermata(21)
    )
  end

  # A part sung by the first guitar alone, the requinto answering, and the requinto's three
  # sixteenths into the estribillo.
  defp sung(part, vel) do
    tune = notes(tune(part))
    beats = length(bars(part)) * 3
    sung = line(:primera, tune, vel, voices: :melody)
    answered = for {bar, words} <- answers(part), do: answer(bar, words, vel - 0.22)

    section(
      beats,
      [
        sung,
        answered,
        lead_in(beats, vel - 0.1),
        accompany(bars(part), vel - 0.2)
      ],
      breath(beats)
    )
  end

  # A part sung as a duo: the requinto the melody and the first guitar the voice under it;
  # `ending` is :on for the three sixteenths into the estribillo, or :last to slow into the last
  # chords.
  defp duo(part, vel, ending) do
    tune = notes(tune(part))
    beats = length(bars(part)) * 3
    under = for {beat, [_ | second], held} <- tune, do: {beat, second, held}

    {lead, tempos} =
      case ending do
        :on -> {lead_in(beats, vel - 0.1), breath(beats)}
        :last -> {[], breath(beats, div(beats, 12) - 1) ++ [{beats - 6, 62, 6}]}
      end

    section(
      beats,
      [
        line(:requinto, tune, vel, voices: :melody),
        line(:primera, under, vel - 0.12),
        lead,
        accompany(bars(part), vel - 0.2)
      ],
      tempos
    )
  end

  # The last two chords: A minor from all three, damped, and once more left to ring.
  defp last_chords do
    chord = fn part, names, at, vel, rings ->
      {part, {at, pluck(names, [vel: vel, strum: 0.04] ++ rings)}}
    end

    short = [sustain: 0.7, release: 0.2]
    long = [sustain: 6, release: 2]

    section(
      8,
      [
        chord.(:guitarra, ~w(a2 e3 a3 c4 e4)a, 0, 0.85, short),
        chord.(:primera, ~w(a3 c4 e4 a4)a, 0.02, 0.7, short),
        chord.(:requinto, ~w(c5 e5 a5)a, 0.04, 0.8, short),
        chord.(:guitarra, ~w(a2 e3 a3 c4 e4)a, 1, 0.6, long),
        chord.(:primera, ~w(e4 a4)a, 1.02, 0.5, long),
        chord.(:requinto, ~w(c5 e5 a5)a, 1.04, 0.5, long)
      ],
      [{0, 66}]
    )
  end

  # The sections one after another, each part playing its sounds of every section, with the
  # tempo's changes beside them.
  defp band(sections) do
    {starts, total} =
      Enum.map_reduce(sections, 0, fn {beats, _, _}, start -> {start, start + beats} end)

    sounds = fn name ->
      for {{_, sounds, _}, start} <- Enum.zip(sections, starts),
          {^name, {beat, sound}} <- sounds,
          do: {start + beat, sound}
    end

    changes =
      for {{_, _, tempos}, start} <- Enum.zip(sections, starts), change <- tempos do
        case change do
          {beat, bpm} -> {start + beat, tempo(bpm)}
          {beat, bpm, over} -> {start + beat, tempo(bpm, over: over)}
        end
      end

    together([
      part(:requinto, at(sounds.(:requinto), total)),
      part(:primera, at(sounds.(:primera), total)),
      part(:guitarra, at(sounds.(:guitarra), total)),
      part(:tempo, at(changes, total))
    ])
  end

  # The tune as words: the melody's note, the notes under it after slashes, and a length in beats
  # after a colon, an eighth unless given; r is a rest and a bar line is only for reading.
  defp tune(:opening), do: "r c5/a4:0.25 cs5/a4:0.25"

  # The three sixteenths that lead into the estribillo from the last beat of a part.
  defp tune(:lead_in), do: "b4/gs4:0.25 c5/a4:0.25 cs5/a4:0.25"

  defp tune(:estribillo) do
    dominant = "d5/b4 b4/gs4 gs4/e4 e4/b3 r:0.25 d4/b3:0.25 ds4/b3:0.25 e4/c4:0.25 | "
    tonic = "e5/c5 c5/a4 a4/e4 e4/c4 r:0.25 " <> tune(:lead_in) <> " | "

    turns =
      for beat <- [
            "d5/a4 d5/a4 f5/d5 d5/a4",
            "b4/gs4 b4/gs4 d5/b4 b4/gs4",
            "gs4/e4 gs4/e4 b4/gs4 gs4/e4"
          ],
          word <- String.split(beat),
          do: word <> ":0.25"

    dominant <>
      tonic <>
      dominant <>
      "e5/c5 ds5/c5 e5/c5 cs5/as4 d5/b4 b4/gs4 | c5/a4:1 a4/e4:1 r:0.25 " <>
      tune(:lead_in) <>
      " | " <>
      dominant <> tonic <> Enum.join(turns, " ") <> " | a5/c5/a4:1 a5/c5/a4:2"
  end

  defp tune(:a) do
    "e4/c4 e4/c4 c5/a4:1 b4/gs4 d5/b4 | c5/a4:1 a4/e4:2 | r e4/c4 a4/e4 b4/gs4 c5/a4 d5/b4 | c5/a4:1 b4/gs4:2 | " <>
      "e4/b3 e4/b3 d5/b4:1 cs5/a4 e5/gs4 | d5/b4:1 b4/gs4:2 | r e4/b3 gs4/e4 b4/gs4 d5/b4 e5/gs4 | c5/a4:1 a4/e4:2 | " <>
      "r a4/e4 a4/e4 a4/e4 cs5/a4 a4/e4 | bb4/g4:1 a4/e4:2 | r a4/e4 a4/e4 a4/e4 cs5/a4 a4/e4 | bb4/g4:1 a4/f4:2 | " <>
      tune(:refrain)
  end

  defp tune(:b) do
    "e4/c4:1 e4/c4 e4/c4 gs4/e4 b4/gs4 | d5/b4:1 b4/gs4:2 | e4/b3:1 e4/b3 e4/b3 a4/e4 c5/a4 | e5/c5:1 c5/a4:2 | " <>
      "g4/d4:1 g4/d4 g4/d4 b4/g4 d5/b4 | f5/d5:1 d5/b4:2 | g4/e4:1 g4/e4 g4/e4 c5/g4 e5/c5 | g5/e5:1 e5/c5:2 | " <>
      "r d5/b4 f5/d5 e5/c5 f5/d5 d5/b4 | e5/gs4:1 b4/gs4:2 | r b4/gs4 d5/b4 d5/b4 e5/b4 d5/b4 | c5/a4:1 a4/e4:2 | " <>
      "r a4/e4 a4/e4 a4/e4 a4/e4 g4/e4 | g4/e4:1 f4/d4:2 | r a4/f4 a4/f4 b4/g4 c5/a4 a4/f4 | g4/e4:1 e4/c4:2 | " <>
      tune(:refrain)
  end

  # The four bars that end both parts, on the poem's first line again.
  defp tune(:refrain) do
    "e4/b3 e4/b3 b4/gs4:1 as4/e4 b4/gs4 | d5/b4 b4/gs4 e5/gs4:2 | r e5/b4 d5/b4 b4/gs4 gs4/e4 e5/b4 | d5/b4:1 c5/a4:2"
  end

  # The words as {beat, [melody, second voice], beats}.
  defp notes(words) do
    {notes, _} =
      words
      |> String.split()
      |> Enum.reject(&(&1 == "|"))
      |> Enum.flat_map_reduce(0, fn word, beat ->
        {names, held} =
          case String.split(word, ":") do
            [names] -> {names, 0.5}
            [names, held] -> {names, elem(Float.parse(held), 0)}
          end

        if names == "r" do
          {[], beat + held}
        else
          pitches = for name <- String.split(names, "/"), do: pitch(name)
          {[{beat, pitches, held}], beat + held}
        end
      end)

    notes
  end

  # A section as its length in beats, its sounds, and the tempo changes within it as {beat, tempo}
  # or {beat, tempo, beats to get there}.
  defp section(beats, sounds, tempos \\ []), do: {beats, List.flatten(sounds), tempos}

  # A line on one player, as {part, {beat, sound}}: the second voice softer and a moment before
  # the melody as the thumb leads a double stop.
  # `voices` is :both or :melody, and `shift` moves the line by semitones.
  defp line(part, notes, vel, opts \\ []) do
    voices = Keyword.get(opts, :voices, :both)
    shift = Keyword.get(opts, :shift, 0)
    melody = for {_, [note | _], _} <- notes, do: note
    middle = Enum.sum(melody) / max(length(notes), 1)

    for {{beat, [melody | second], held}, next} <- Enum.zip(notes, tl(notes) ++ [nil]) do
      at = placed(beat, 0.012)
      loud = plucked(vel, beat, melody, middle)

      following =
        case next do
          {next_beat, pitches, _} when next_beat - (beat + held) < 0.01 -> pitches
          _ -> []
        end

      under =
        for note <- second, voices == :both do
          rings = rings(held, note, following)
          {part, {at, pluck(note + shift, [vel: loud * 0.72] ++ rings)}}
        end

      late = if under == [], do: 0, else: 0.018
      rings = rings(held, melody, following)
      [{part, {at + late, pluck(melody + shift, [vel: loud] ++ rings)}} | under]
    end
    |> List.flatten()
  end

  # How hard a note is plucked: around `vel`, harder the higher it stands in its line and on the
  # first beat of a bar, softer on the eighths between beats, and swelling towards the third bar
  # of each phrase of four.
  defp plucked(vel, beat, note, middle) do
    lift = (note - middle) / 12 * 0.12
    swell = :math.sin(:math.pi() * (beat - Float.floor(beat / 12) * 12) / 9.0) * 0.08 - 0.03

    weight =
      cond do
        Float.round(beat - Float.floor(beat / 3) * 3, 2) == 0.0 -> 0.05
        beat == Float.floor(beat) -> 0
        true -> -0.05
      end

    min(max(vel + lift + weight + swell + (:rand.uniform() - 0.5) * 0.06, 0.1), 1)
  end

  # How long a note rings: on past the notes plucked next, unless one of them is the same note or
  # a step away, which would beat against it.
  defp rings(held, note, following) do
    if Enum.any?(following, &(abs(&1 - note) <= 2)) do
      [sustain: held, release: 0.06]
    else
      [sustain: held + 0.3, release: 0.6]
    end
  end

  # The accompanying guitar's sounds for bars, at `vel`.
  defp accompany(bars, vel) do
    for {bar, index} <- Enum.with_index(bars), sound <- bar(bar, vel) do
      {beat, music} = sound
      {:guitarra, {index * 3 + placed(beat, 0.008), music}}
    end
  end

  # The accompaniment of each bar: a chord's name for the pasillo's pattern, {chord, :again} for
  # the pattern on the alternate bass, {:run, notes} for six eighths in the bass where r is a
  # rest, {:walk, notes} for three quarters, {:held, chord} for a chord that rings through the
  # bar, and :rest.
  defp bars(:estribillo) do
    [:e7, :am, {:e7, :again}, {:run, ~w(c3 c3 r e2 e3 r)a}, {:run, ~w(a2 a3 r e3 c3 a2)a}] ++
      [:e7, :am, {:run, ~w(d3 d3 r e2 e3 r)a}, {:held, :am}]
  end

  defp bars(:a) do
    [:rest, :am, {:am, :again}, {:run, ~w(e2 b2 r b2 a2 gs2)a}, :e7, {:e7, :again}, :e7, :am] ++
      [{:am, :again}, :a7, {:a7, :again}, {:run, ~w(d3 d3 r f3 e3 ds3)a}] ++ bars(:refrain)
  end

  defp bars(:b) do
    [{:walk, [[:a2, :a3], [:g2, :g3], [:f2, :f3]]}, :e7, {:e7, :again}, :am, :g, :g7, :c] ++
      [{:c, :again}, {:held, :c}, :e7, {:e7, :again}, :am, :a7, :dm, :g, :c] ++ bars(:refrain)
  end

  defp bars(:refrain), do: [{:held, :e7}, :e7, {:e7, :again}, {:run, ~w(a2 a2 r e3 c3 e3)a}]

  defp bar(:rest, _vel), do: []
  defp bar(chord, vel) when is_atom(chord), do: pattern(chord, 0, vel)
  defp bar({chord, :again}, vel), do: pattern(chord, 1, vel)

  defp bar({:run, names}, vel) do
    for {name, eighth} <- Enum.with_index(names), name != :r do
      loud = vel + 0.1 + eighth * 0.02 + (:rand.uniform() - 0.5) * 0.05

      {eighth * 0.5 + 0.001, pluck(name, vel: min(loud, 1), sustain: 0.6, release: 0.4)}
    end
  end

  defp bar({:walk, names}, vel) do
    for {name, beat} <- Enum.with_index(names) do
      {beat + 0.001, pluck(name, vel: min(vel + 0.12, 1), sustain: 1.0, release: 0.4)}
    end
  end

  defp bar({:stop, name}, vel) do
    [{0.001, pluck(name, vel: min(vel + 0.1, 1), sustain: 0.6, release: 0.5)}]
  end

  defp bar({:held, chord}, vel) do
    {name, _, chord} = chords()[chord]
    low = pluck(name, vel: min(vel + 0.1, 1), sustain: 3, release: 1.5)
    over = pluck(chord, vel: vel * 0.6, strum: 0.06, sustain: 3, release: 1.5)
    [{0.001, low}, {0.03, over}]
  end

  # Two eighths in the bass, the second softer, then the chord short on the eighth before the
  # third beat and ringing on it.
  defp pattern(chord, which, vel) do
    {root, other, notes} = chords()[chord]
    bass = if which == 0, do: root, else: other
    jitter = fn -> (:rand.uniform() - 0.5) * 0.05 end

    [
      {0.001, pluck(bass, vel: min(vel + 0.15 + jitter.(), 1), sustain: 0.55, release: 0.3)},
      {0.5, pluck(bass, vel: vel + jitter.(), sustain: 0.9, release: 0.4)},
      {1.5,
       pluck(notes,
         vel: vel * 0.62 + jitter.(),
         strum: 0.02,
         sustain: 0.38,
         release: 0.12
       )},
      {2.0,
       pluck(notes,
         vel: vel * 0.74 + jitter.(),
         strum: 0.03,
         sustain: 0.85,
         release: 0.3
       )}
    ]
  end

  # The fermata on the estribillo's last chord, from the beat its last bar of sixteenths starts
  # on: they slow, the chord waits, and the tempo comes back with the part that follows.
  defp fermata(beat), do: [{beat, 74, 3}, {beat + 4, 54}, {beat + 6, @tempo}]

  # The requinto's answers to each part: the bar they fall in, counted from the part's first, and
  # a run of sixteenths in thirds and sixths through the bar's chord, from the middle of the bar,
  # under or over the melody's long note.
  defp answers(:a) do
    [
      {3, "gs4/e4:0.25 b4/gs4:0.25 d5/b4:0.25 f5/d5:0.25 e5/gs4"},
      {7, "a4/e4:0.25 c5/a4:0.25 e5/c5:0.25 a5/e5:0.25 e5/c5"},
      {11, "a4/f4:0.25 d5/a4:0.25 f5/d5:0.25 e5/c5:0.25 d5/a4"}
    ]
  end

  defp answers(:b) do
    [
      {3, "c5/a4:0.25 e5/c5:0.25 a5/e5:0.25 e5/c5:0.25 c5/a4"},
      {7, "e4/c4:0.25 g4/e4:0.25 c5/g4:0.25 e5/c5:0.25 c5/g4"},
      {11, "a4/e4:0.25 b4/gs4:0.25 c5/a4:0.25 d5/b4:0.25 e5/c5"},
      {15, "g4/e4:0.25 c5/g4:0.25 e5/c5:0.25 g5/e5:0.25 e5/c5"}
    ]
  end

  defp answer(bar, words, vel) do
    run = for {beat, notes, held} <- notes(words), do: {bar * 3 + 1.5 + beat, notes, held}
    line(:requinto, run, vel)
  end

  # The breath of each phrase of four bars but those from `last` on: the tempo gives way over the
  # long note that ends it and is back before the next begins.
  defp breath(beats, last \\ 1000) do
    for phrase <- 0..(div(beats, 12) - 1),
        phrase < last,
        change <- [{phrase * 12 + 9, @tempo - 9, 1.5}, {phrase * 12 + 10.75, @tempo, 1}],
        do: change
  end

  defp lead_in(beats, vel) do
    run = for {beat, notes, held} <- notes(tune(:lead_in)), do: {beats - 0.75 + beat, notes, held}
    line(:requinto, run, vel)
  end

  # Where a player puts a note written at `beat`, never quite on it.
  defp placed(beat, loose), do: max(beat + (:rand.uniform() - 0.5) * 2 * loose, 0)

  # One or more notes plucked at once, each at its key's level.
  defp pluck(notes, opts) do
    notes = for name <- List.wrap(notes), do: pitch(name)
    amp = for note <- notes, do: level(note)

    case notes do
      [one] -> note(one, 0, [amp: hd(amp)] ++ opts)
      many -> note(many, 0, [amp: amp] ++ opts)
    end
  end

  # The level that brings a note level with the others: that of the recorded key it plays, the
  # nearest and the lower of two as near.
  defp level(note) do
    {_, db} = Enum.min_by(@levels, fn {key, _} -> {abs(key - note), key} end)
    :math.pow(10, db / 20)
  end

  # Each chord's bass, the bass that alternates with it, and its notes on the top strings.
  defp chords do
    %{
      am: {:a2, :e2, [:a3, :c4, :e4]},
      e7: {:e2, :b2, [:gs3, :b3, :d4, :e4]},
      a7: {:a2, :e2, [:g3, :cs4, :e4]},
      dm: {:d3, :a2, [:a3, :d4, :f4]},
      g: {:g2, :d3, [:g3, :b3, :d4]},
      g7: {:g2, :d3, [:g3, :b3, :f4]},
      c: {:c3, :g2, [:g3, :c4, :e4]}
    }
  end
end
