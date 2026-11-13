import Mx

# Sombras, the pasillo Carlos Brito Benavides of Quito wrote in 1930 to Rosario Sansores' poem, played without its words by a requinto, a first guitar and a guitar that accompanies.
# This is examples/sombras.exs stroke for stroke on mx's guitar, the nylon-string guitar measured from recordings, in place of the recorded one, to hear one beside the other; the requinto is the same guitar in its upper octave, made brighter.
# The pasillo is in 3/4 and A minor: an estribillo of nine bars that the requinto plays in thirds, the part A of sixteen bars, the estribillo, the part B of twenty, and the estribillo again.
# The estribillo, the sung melody, the chords and the bass are read from the score for voice and piano in Boris Mora's thesis, Universidad de Cuenca, 2020, the estribillo an octave below the piano's; the second voice under the melody, the requinto's answers, the breath at the end of each phrase and who plays what are this file's own.
# The first time the first guitar sings the melody alone and the requinto answers its long notes; the second time the two sing it as a duo does, the requinto above and the first guitar a third or a sixth below.
defmodule SombrasSynths do
  import Mx

  @room [room: 0.6, damp: 0.5, mix: 0.22]

  @parts [
    requinto: [
      synth: :guitar,
      fx: [
        hpf: [cutoff: 93, mix: 0.5],
        lpf: [cutoff: 114],
        level: [amp: 4.94],
        reverb: @room,
        pan: [pan: 0.3]
      ]
    ],
    primera: [
      synth: :guitar,
      fx: [lpf: [cutoff: 114], level: [amp: 2.59], reverb: @room, pan: [pan: 0.05]]
    ],
    guitarra: [
      synth: :guitar,
      fx: [lpf: [cutoff: 114], level: [amp: 1.71], reverb: @room, pan: [pan: -0.3]]
    ]
  ]

  @tempo 90

  # The tune as words: the melody's note, the notes under it after slashes, and a length in beats after a colon, an eighth unless given; r is a rest and a bar line is only for reading.
  def tune(:opening), do: "r c5/a4:0.25 cs5/a4:0.25"

  # The three sixteenths that lead into the estribillo from the last beat of a part.
  def tune(:lead_in), do: "b4/gs4:0.25 c5/a4:0.25 cs5/a4:0.25"

  def tune(:estribillo) do
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

  def tune(:a) do
    "e4/c4 e4/c4 c5/a4:1 b4/gs4 d5/b4 | c5/a4:1 a4/e4:2 | r e4/c4 a4/e4 b4/gs4 c5/a4 d5/b4 | c5/a4:1 b4/gs4:2 | " <>
      "e4/b3 e4/b3 d5/b4:1 cs5/a4 e5/gs4 | d5/b4:1 b4/gs4:2 | r e4/b3 gs4/e4 b4/gs4 d5/b4 e5/gs4 | c5/a4:1 a4/e4:2 | " <>
      "r a4/e4 a4/e4 a4/e4 cs5/a4 a4/e4 | bb4/g4:1 a4/e4:2 | r a4/e4 a4/e4 a4/e4 cs5/a4 a4/e4 | bb4/g4:1 a4/f4:2 | " <>
      tune(:refrain)
  end

  def tune(:b) do
    "e4/c4:1 e4/c4 e4/c4 gs4/e4 b4/gs4 | d5/b4:1 b4/gs4:2 | e4/b3:1 e4/b3 e4/b3 a4/e4 c5/a4 | e5/c5:1 c5/a4:2 | " <>
      "g4/d4:1 g4/d4 g4/d4 b4/g4 d5/b4 | f5/d5:1 d5/b4:2 | g4/e4:1 g4/e4 g4/e4 c5/g4 e5/c5 | g5/e5:1 e5/c5:2 | " <>
      "r d5/b4 f5/d5 e5/c5 f5/d5 d5/b4 | e5/gs4:1 b4/gs4:2 | r b4/gs4 d5/b4 d5/b4 e5/b4 d5/b4 | c5/a4:1 a4/e4:2 | " <>
      "r a4/e4 a4/e4 a4/e4 a4/e4 g4/e4 | g4/e4:1 f4/d4:2 | r a4/f4 a4/f4 b4/g4 c5/a4 a4/f4 | g4/e4:1 e4/c4:2 | " <>
      tune(:refrain)
  end

  # The four bars that end both parts, on the poem's first line again.
  def tune(:refrain) do
    "e4/b3 e4/b3 b4/gs4:1 as4/e4 b4/gs4 | d5/b4 b4/gs4 e5/gs4:2 | r e5/b4 d5/b4 b4/gs4 gs4/e4 e5/b4 | d5/b4:1 c5/a4:2"
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

  # A line on one player, as {part, {beat, sound}}: each note rings until the next is plucked, the second voice softer and a moment before the melody as the thumb leads a double stop.
  # `voices` is :both or :melody, and `shift` moves the line by semitones.
  def line(part, notes, vel, opts \\ []) do
    voices = Keyword.get(opts, :voices, :both)
    shift = Keyword.get(opts, :shift, 0)
    middle = Enum.sum(for({_, [note | _], _} <- notes, do: note)) / max(length(notes), 1)

    for {beat, [melody | second], held} <- notes do
      at = placed(beat, 0.012)
      loud = plucked(vel, beat, melody, middle)
      rings = [sustain: held + 0.3, release: 0.6]

      under =
        for note <- second, voices == :both do
          {part, {at, pluck(note + shift, [vel: loud * 0.72] ++ rings)}}
        end

      late = if under == [], do: 0, else: 0.018
      [{part, {at + late, pluck(melody + shift, [vel: loud] ++ rings)}} | under]
    end
    |> List.flatten()
  end

  # Each chord's bass, the bass that alternates with it, and its notes on the top strings.
  @chords %{
    am: {:a2, :e2, [:a3, :c4, :e4]},
    e7: {:e2, :b2, [:gs3, :b3, :d4, :e4]},
    a7: {:a2, :e2, [:g3, :cs4, :e4]},
    dm: {:d3, :a2, [:a3, :d4, :f4]},
    g: {:g2, :d3, [:g3, :b3, :d4]},
    g7: {:g2, :d3, [:g3, :b3, :f4]},
    c: {:c3, :g2, [:g3, :c4, :e4]}
  }

  # The accompaniment of each bar: a chord's name for the pasillo's pattern, {chord, :again} for the pattern on the alternate bass, {:run, notes} for six eighths in the bass where r is a rest, {:walk, notes} for three quarters, {:held, chord} for a chord that rings through the bar, and :rest.
  def bars(:estribillo) do
    [:e7, :am, {:e7, :again}, {:run, ~w(c3 c3 r e2 e3 r)a}, {:run, ~w(a2 a3 r e3 c3 a2)a}] ++
      [:e7, :am, {:run, ~w(d3 d3 r e2 e3 r)a}, {:held, :am}]
  end

  def bars(:a) do
    [:rest, :am, {:am, :again}, {:run, ~w(e2 b2 r b2 a2 gs2)a}, :e7, {:e7, :again}, :e7, :am] ++
      [{:am, :again}, :a7, {:a7, :again}, {:run, ~w(d3 d3 r f3 e3 ds3)a}] ++ bars(:refrain)
  end

  def bars(:b) do
    [{:walk, [[:a2, :a3], [:g2, :g3], [:f2, :f3]]}, :e7, {:e7, :again}, :am, :g, :g7, :c] ++
      [{:c, :again}, {:held, :c}, :e7, {:e7, :again}, :am, :a7, :dm, :g, :c] ++ bars(:refrain)
  end

  def bars(:refrain), do: [{:held, :e7}, :e7, {:e7, :again}, {:run, ~w(a2 a2 r e3 c3 e3)a}]

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

  defp bar({:held, chord}, vel) do
    {name, _, chord} = @chords[chord]
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

  # The fermata on the estribillo's last chord, from the beat its last bar of sixteenths starts on: they slow, the chord waits, and the tempo comes back with the part that follows.
  def fermata(beat), do: [{beat, 74, 3}, {beat + 4, 54}, {beat + 6, @tempo}]

  # The two sixteenths that lead into the first estribillo.
  def opening, do: section(1, line(:requinto, notes(tune(:opening)), 0.75))

  # The estribillo: the requinto in thirds over the pasillo's pattern.
  def estribillo(vel) do
    section(
      27,
      [line(:requinto, notes(tune(:estribillo)), vel), accompany(bars(:estribillo), vel - 0.2)],
      fermata(21)
    )
  end

  # The requinto's answers to each part: the bar they fall in, counted from the part's first, and a run of sixteenths in thirds and sixths through the bar's chord, from the middle of the bar, under or over the melody's long note.
  def answers(:a) do
    [
      {3, "gs4/e4:0.25 b4/gs4:0.25 d5/b4:0.25 f5/d5:0.25 e5/gs4"},
      {7, "a4/e4:0.25 c5/a4:0.25 e5/c5:0.25 a5/e5:0.25 e5/c5"},
      {11, "a4/f4:0.25 d5/a4:0.25 f5/d5:0.25 e5/c5:0.25 d5/a4"}
    ]
  end

  def answers(:b) do
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

  # The breath of each phrase of four bars but those from `last` on: the tempo gives way over the long note that ends it and is back before the next begins.
  def breath(beats, last \\ 1000) do
    for phrase <- 0..(div(beats, 12) - 1),
        phrase < last,
        change <- [{phrase * 12 + 9, @tempo - 9, 1.5}, {phrase * 12 + 10.75, @tempo, 1}],
        do: change
  end

  # A part sung by the first guitar alone, the requinto answering, and the requinto's three sixteenths into the estribillo.
  def sung(part, vel) do
    tune = notes(tune(part))
    beats = length(bars(part)) * 3

    section(
      beats,
      [
        line(:primera, tune, vel, voices: :melody),
        for({bar, words} <- answers(part), do: answer(bar, words, vel - 0.22)),
        lead_in(beats, vel - 0.1),
        accompany(bars(part), vel - 0.2)
      ],
      breath(beats)
    )
  end

  # A part sung as a duo: the requinto the melody and the first guitar the voice under it; `ending` is :on for the three sixteenths into the estribillo, or :last to slow into the last chords.
  def duo(part, vel, ending) do
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

  defp lead_in(beats, vel) do
    for {beat, notes, held} <- notes(tune(:lead_in)),
        sound <- line(:requinto, [{beats - 0.75 + beat, notes, held}], vel),
        do: sound
  end

  # The last two chords: A minor from all three, damped, and once more left to ring.
  def last_chords do
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
end

song(tempo: 90, music: SombrasSynths.music())
