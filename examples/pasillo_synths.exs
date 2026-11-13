import Mx

# Vamos linda, a pasillo by Francisco Paredes Herrera of Cuenca, who died in 1952, played as a serenade plays one: a requinto, a first guitar and a guitar that accompanies.
# This is examples/pasillo.exs stroke for stroke on mx's guitar, the nylon-string guitar measured from recordings, in place of the recorded one, to hear one beside the other; the requinto is the same guitar in its upper octave, made brighter.
# The pasillo is in 3/4 and E minor: an introduction, then the parts A, B and C of sixteen bars each, and C ends on the introduction again, the estribillo.
# The melody, its second voice in thirds and sixths, the chords and the bass runs are read from the piano score and the guitar transcription in Cristhian Morocho's thesis, Universidad de Cuenca, 2017; who plays what is this file's own.
# The accompaniment is the pasillo's: two eighths in the bass, an eighth's rest, a chord on the next eighth and a chord on the third beat, and it stops where the melody leads into a phrase alone.
# The form is played twice: the requinto alone, then in two voices; the second time the first guitar sings the opening an octave lower and the requinto answers, and the two play C in octaves.
defmodule PasilloSynths do
  import Mx

  @room [room: 0.6, damp: 0.5, mix: 0.22]

  @parts [
    requinto: [
      synth: :guitar,
      fx: [
        hpf: [cutoff: 93, mix: 0.5],
        level: [amp: 6.61],
        reverb: @room,
        pan: [pan: 0.3]
      ]
    ],
    primera: [
      synth: :guitar,
      fx: [level: [amp: 3.14], reverb: @room, pan: [pan: 0.05]]
    ],
    guitarra: [
      synth: :guitar,
      fx: [level: [amp: 2.31], reverb: @room, pan: [pan: -0.3]]
    ]
  ]

  @tempo 100

  # The tune as words: the melody's note, the second voice's after a slash, and a length in beats after a colon, an eighth unless given; r is a rest and a bar line is only for reading.
  def tune(:intro) do
    "r:1.5 g5/b4 fs5/a4 e5/g4 | g5/b4:1.5 fs5/a4 fs5/a4:1.5 fs5/a4 g5/b4 fs5/a4 e5/g4 ds5/fs4 | " <>
      "e5/g4:4 e5/g4:1.5 ds5/fs4"
  end

  def tune(:a) do
    question =
      "b4/fs4 b4/fs4 a4/fs4 fs4/ds4 ds5/b4:1 | r fs4/ds4 b4/fs4:1.5 fs4/ds4 | a4/fs4 g4/e4 fs4/ds4 g4/e4 e4/b3:1 | "

    question <>
      "r g5/e5 e5/b4:1 ds5/b4:1 | " <>
      question <>
      "r b4/gs4 e5/b4:1.5 d5/b4 | d5/b4 c5/a4 b4/gs4 c5/a4 a4/e4:1 | " <>
      "r a4/fs4 fs5/d5:1.5 e5/c5 | e5/c5 d5/b4 cs5/as4 d5/b4 b4/g4:1 | " <>
      "r g5/e5 e5/b4:1.5 ds5/b4 | " <>
      question <>
      "r:1 e5/c5:1 fs5/d5:1"
  end

  def tune(:b) do
    "g5/e5 fs5/ds5 g5/e5 fs5/ds5 g5/e5 fs5/ds5 | g5/e5 fs5/ds5 g5/e5:1.5 fs5/d5 | " <>
      "e5/c5:1 d5/b4:3 fs5/d5:1.5 e5/c5 | " <>
      "c5/a4 b4/g4 c5/a4 b4/g4 c5/a4 b4/g4 | c5/a4 d5/b4 e5/c5:1.5 g5/e5 | " <>
      "e5/b4:1 d5/b4:2.5 b4/g4 fs5/d5:1.5 e5/c5 | " <>
      "ds5/b4 e5/b4 ds5/b4 e5/b4 ds5/b4:1 | r a4/e4 c5/a4:1.5 c5/a4 | " <>
      "c5/a4 b4/g4:1 b4/g4:0.25 as4/fs4:0.25 b4/g4:1 | r g4/e4 b4/g4:1.5 b4/g4 | " <>
      "a4/fs4 b4/fs4 a4/fs4 b4/fs4 a4/fs4:1 | fs4/ds4 g4/e4 a4/fs4 b4/fs4 a4/fs4 b4/fs4 | " <>
      "g4/e4:4 b3:1 b3:1"
  end

  def tune(:c), do: tune(:c_opening) <> " | " <> tune(:estribillo)

  def tune(:c_opening) do
    "b4/g4:1 a4/fs4:2.5 a4/fs4 b4/g4 a4/fs4 g4/e4 a4/fs4 | b4/g4:1 b4/g4:2 | " <>
      "r b4/g4 e5/b4:1.5 ds5/b4 | fs5/b4:1.5 e5/b4 ds5/b4:1 | " <>
      "r b4/fs4 fs5/b4:1.5 fs5/b4 | g5/b4:1.5 fs5/a4 e5/g4:1 | " <>
      "r:1 b4/g4:1 d5/b4:1 | a4/fs4:1 b4/fs4:2 | r a4/fs4 b4/g4 a4/fs4 g4/e4 a4/fs4 | " <>
      "b4/g4:1 b4/g4:2"
  end

  def tune(:estribillo) do
    "r g5/b4 fs5/a4:1.5 e5/g4 | g5/b4:1.5 fs5/a4 fs5/a4:1 | r fs5/a4 g5/b4 fs5/a4 e5/g4 ds5/fs4 | " <>
      "e5/g4:4 e5/g4:1.5 ds5/fs4"
  end

  # The last estribillo ends on the tonic and stays there.
  def tune(:last_estribillo) do
    "r g5/b4 fs5/a4:1.5 e5/g4 | g5/b4:1.5 fs5/a4 fs5/a4:1 | r fs5/a4 g5/b4 fs5/a4 e5/g4 ds5/fs4 | " <>
      "e5/g4:3"
  end

  # The words as {beat, [melody, second voice], beats}.
  def notes(words) do
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
          pitches = for name <- String.split(names, "/"), do: pitch(String.to_atom(name))
          {[{beat, pitches, held}], beat + held}
        end
      end)

    notes
  end

  def from(notes, first, last \\ 1000) do
    Enum.filter(notes, fn {beat, _, _} -> beat >= first and beat < last end)
  end

  # The level that brings a note level with the low strings: mx's guitar, measured over a note's first half second, falls half a dB a semitone from A2 to B3 and a dB a semitone above.
  # It starts 12 dB down, which the parts' levels give back, to keep the highest notes within the guitar's amp.
  def level(note) do
    db = max(note - 45, 0) * 0.5 + max(note - 59, 0) * 0.5 - 12
    :math.pow(10, db / 20)
  end

  # One or more notes plucked at once, each at its note's level.
  def pluck(notes, opts) do
    notes = for name <- List.wrap(notes), do: pitch(name)
    amp = for note <- notes, do: level(note)

    case notes do
      [one] -> note(one, 0, [amp: hd(amp)] ++ opts)
      many -> note(many, 0, [amp: amp] ++ opts)
    end
  end

  # Where a player puts a note written at `beat`, never quite on it.
  def placed(beat, loose), do: max(beat + (:rand.uniform() - 0.5) * 2 * loose, 0)

  # How hard a note is plucked: around `vel`, harder the higher it stands in its line and on the first beat of a bar, softer on the eighths between beats, and swelling towards the third bar of each phrase of four.
  def plucked(vel, beat, note, middle) do
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

  # A line on one player, as {part, {beat, sound}}: the second voice softer and a moment before the melody as the thumb leads a double stop.
  # `voices` is :both or :melody, and `shift` moves the line by semitones.
  def line(part, notes, vel, opts \\ []) do
    voices = Keyword.get(opts, :voices, :both)
    shift = Keyword.get(opts, :shift, 0)
    middle = Enum.sum(for({_, [note | _], _} <- notes, do: note)) / max(length(notes), 1)

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

  # How long a note rings: on past the notes plucked next, unless one of them is the same note or a step away, which would beat against it.
  defp rings(held, note, following) do
    if Enum.any?(following, &(abs(&1 - note) <= 2)) do
      [sustain: held, release: 0.06]
    else
      [sustain: held + 0.1, release: 0.35]
    end
  end

  # Each chord's bass, the bass that alternates with it, and its notes on the top strings.
  @chords %{
    em: {:e2, :b2, [:g3, :b3, :e4]},
    b7: {:b2, :fs2, [:a3, :b3, :ds4, :fs4]},
    e7: {:e2, :b2, [:gs3, :b3, :d4, :e4]},
    am: {:a2, :e2, [:a3, :c4, :e4]},
    d7: {:d3, :a2, [:a3, :c4, :fs4]},
    g: {:g2, :d3, [:g3, :b3, :d4]},
    c: {:c3, :g2, [:g3, :c4, :e4]}
  }

  # The accompaniment of each bar: a chord's name for the pasillo's pattern, {chord, :again} for the pattern on the alternate bass, {:run, notes} for six eighths in the bass where r is a rest, {:walk, notes} for three quarters, {:stop, note} for one bass note and silence, {:held, note} for one that rings under a fermata, and :rest.
  def bars(:intro) do
    [:rest, :b7, {:b7, :again}, {:run, ~w(e3 e3 ds3 e3 g3 b3)a}, {:held, :e2}]
  end

  def bars(:a) do
    [:b7, {:b7, :again}, :em, {:em, :again}, :b7, {:b7, :again}, :em, :e7, :am, :d7] ++
      [{:run, ~w(g2 g2 r g2 b2 d3)a}, {:stop, :g3}, :b7, {:b7, :again}] ++
      [{:run, ~w(e2 e2 r e2 g2 b2)a}, {:stop, :e3}]
  end

  def bars(:b) do
    [:c, {:c, :again}, :g, {:walk, ~w(g3 fs3 e3)a}, :d7, {:d7, :again}] ++
      [{:run, ~w(g2 g2 r g2 b2 d3)a}, {:stop, :g3}, :b7, :am, :em, {:em, :again}] ++
      [:b7, {:b7, :again}, {:walk, ~w(e3 b3 g3)a}, {:stop, :e2}]
  end

  def bars(:c) do
    [:b7, {:b7, :again}, :em, {:em, :again}, :b7, {:b7, :again}] ++
      [{:run, ~w(e2 e2 r b2 g2 b2)a}, {:stop, :e3}, :b7, {:b7, :again}, :em] ++ bars(:estribillo)
  end

  def bars(:estribillo) do
    [{:walk, ~w(e3 d3 c3)a}, :b7, {:b7, :again}, {:run, ~w(e2 e2 r b2 g2 b2)a}, {:held, :e2}]
  end

  def bars(:last_estribillo) do
    [{:walk, ~w(e3 d3 c3)a}, :b7, {:b7, :again}, {:run, ~w(e2 fs2 g2 a2 b2 ds3)a}]
  end

  # The accompanying guitar's sounds for bars, at `vel`.
  def accompany(bars, vel) do
    for {bar, index} <- Enum.with_index(bars), sound <- bar(bar, vel) do
      {beat, music} = sound
      {:guitarra, {index * 3 + placed(beat, 0.008), music}}
    end
  end

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

  defp bar({:held, name}, vel) do
    {_, _, chord} = @chords.em
    low = pluck(name, vel: min(vel + 0.1, 1), sustain: 3, release: 1.5)
    over = pluck(chord, vel: vel * 0.6, strum: 0.06, sustain: 3, release: 1.5)
    [{0.001, low}, {0.03, over}]
  end

  # Two eighths in the bass, the second softer, then the chord short on the eighth before the third beat and ringing on it.
  defp pattern(chord, which, vel) do
    {root, other, notes} = @chords[chord]
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

  # A section as its length in beats, its sounds, and the tempo changes within it as {beat, tempo} or {beat, tempo, beats to get there}.
  def section(beats, sounds, tempos \\ []), do: {beats, List.flatten(sounds), tempos}

  # The fermata that ends the introduction and each estribillo, from the beat its long note starts on: the bar slows, the chord waits, and the two notes that lead on take their time.
  def fermata(beat) do
    [{beat, 84, 3}, {beat + 3, 60}, {beat + 4, 80}, {beat + 6, @tempo}]
  end

  def intro do
    tune = notes(tune(:intro))

    section(
      15,
      [line(:requinto, tune, 0.8), accompany(bars(:intro), 0.6)],
      fermata(9)
    )
  end

  # A the first time: the requinto alone, one voice, and the second voice joins where the harmony turns to A minor.
  def a_alone do
    tune = notes(tune(:a))

    section(
      48,
      [
        line(:requinto, from(tune, 0, 21), 0.66, voices: :melody),
        line(:requinto, from(tune, 21), 0.74),
        accompany(bars(:a), 0.55)
      ],
      [{44, 90, 4}]
    )
  end

  # A the second time: the first guitar sings the opening an octave lower, the requinto answers each of its phrases from above, and takes the tune back in two voices.
  def a_answered do
    tune = notes(tune(:a))

    section(
      48,
      [
        line(:primera, from(tune, 0, 9), 0.85, voices: :melody, shift: -12),
        line(:requinto, from(tune, 9, 12), 0.7),
        line(:primera, from(tune, 12, 21), 0.85, voices: :melody, shift: -12),
        line(:requinto, from(tune, 21), 0.82),
        accompany(bars(:a), 0.6)
      ],
      [{44, 90, 4}]
    )
  end

  # B: the requinto in thirds, and the second time the first guitar under its first long note with the chord's notes one by one.
  def b(vel, filled) do
    tune = notes(tune(:b))

    fills = if filled, do: fill(:primera, 7, ~w(b3 d4 g4 d4)a, vel - 0.25), else: []

    section(
      48,
      [line(:requinto, tune, vel), fills, accompany(bars(:b), vel - 0.2)],
      [{42, 84, 5}, {47.5, @tempo}]
    )
  end

  # Eighths on one player from a beat.
  def fill(part, beat, names, vel) do
    for {name, eighth} <- Enum.with_index(names) do
      at = placed(beat + eighth * 0.5, 0.01)
      loud = vel + (:rand.uniform() - 0.5) * 0.05
      {part, {at, pluck(name, vel: loud, sustain: 1.5, release: 0.5)}}
    end
  end

  # C: the requinto in thirds and the estribillo in sixths; the last time the first guitar plays the melody an octave under it, and the estribillo slows into its last chord.
  def c(vel, :first) do
    tune = notes(tune(:c))
    section(48, [line(:requinto, tune, vel), accompany(bars(:c), vel - 0.2)], fermata(42))
  end

  def c(vel, :last) do
    tune = notes(tune(:c_opening) <> " | " <> tune(:last_estribillo))
    bars = Enum.take(bars(:c), 11) ++ bars(:last_estribillo)

    section(
      45,
      [
        line(:requinto, tune, vel),
        line(:primera, tune, vel - 0.1, voices: :melody, shift: -12),
        accompany(bars, vel - 0.2)
      ],
      [{39, 92, 3}, {42, 60, 3}]
    )
  end

  # The last two chords, as the score ends: E minor from all three, damped, and the open strings' harmonics at the twelfth fret left to ring.
  def last_chords do
    chord = fn part, names, at, vel, rings ->
      {part, {at, pluck(names, [vel: vel, strum: 0.04] ++ rings)}}
    end

    short = [sustain: 0.7, release: 0.2]
    long = [sustain: 6, release: 2]

    section(
      8,
      [
        chord.(:guitarra, ~w(e2 b2 e3 g3 b3 e4)a, 0, 0.85, short),
        chord.(:primera, ~w(e3 b3 e4 g4)a, 0.02, 0.7, short),
        chord.(:requinto, ~w(g4 b4 e5)a, 0.04, 0.8, short),
        chord.(:guitarra, ~w(e2 e3)a, 1, 0.6, long),
        chord.(:requinto, ~w(g4 b4 e5)a, 1.02, 0.5, long)
      ],
      [{0, 72}]
    )
  end

  # The sections one after another, each part playing its sounds of every section, with the tempo's changes beside them.
  def band(sections) do
    {starts, total} =
      Enum.map_reduce(sections, 0, fn {beats, _, _}, start -> {start, start + beats} end)

    players =
      for {name, opts} <- @parts do
        sounds =
          for {{_, sounds, _}, start} <- Enum.zip(sections, starts),
              {^name, {beat, sound}} <- sounds,
              do: {start + beat, sound}

        part(name, at(sounds, total), opts)
      end

    changes =
      for {{_, _, tempos}, start} <- Enum.zip(sections, starts), change <- tempos do
        case change do
          {beat, bpm} -> {start + beat, tempo(bpm)}
          {beat, bpm, over} -> {start + beat, tempo(bpm, over: over)}
        end
      end

    together(players ++ [part(:tempo, at(changes, total))])
  end

  def music do
    :rand.seed(:exsss, {1891, 11, 8})

    band([
      intro(),
      a_alone(),
      b(0.8, false),
      c(0.76, :first),
      a_answered(),
      b(0.9, true),
      c(0.88, :last),
      last_chords()
    ])
  end
end

song(tempo: 100, music: PasilloSynths.music())
