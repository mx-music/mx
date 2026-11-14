defmodule ValseDuZinc do
  @moduledoc """
  Valse du Zinc, a valse musette for three FreePats instruments, each under Creative Commons 0:
  the Hohner button accordion, the Spanish classical guitar and the upright piano.
  A valse musette is the Paris dance-hall waltz: the accordion runs in eighths over the pompe, a
  bass note on one and the chord on two and three.
  The guitar opens alone, the accordion plays the tune in A minor, the guitar takes the second
  strain in C over the piano's pompe, the piano plays the tune back in octaves, and the trio turns
  to A major and slows into its last chord.
  The accordion's recordings last a second and a half, so its longest note is a bar, and each is
  listed with the pitch it was measured at, a third of a semitone above its name and an octave
  below it.
  Download them with mx samples download
  "freepats/button-accordion-HN@d70d16456fd99305d1c24c612b205ab38846eb0f", and the same for
  "freepats/spanish-classical-guitar@6f4eb1b092acc88f5448cea1a0001bd07b971af8:samples" and
  "freepats/upright-piano-KW@570f6c60ed2eff67accad3b85d5b452e57a3ad28:samples".
  """

  use Mx.Song, tempo: 168

  @accordion_repo {"freepats/button-accordion-HN", "d70d16456fd99305d1c24c612b205ab38846eb0f"}
  @guitar_repo {"freepats/spanish-classical-guitar", "6f4eb1b092acc88f5448cea1a0001bd07b971af8"}
  @piano_repo {"freepats/upright-piano-KW", "570f6c60ed2eff67accad3b85d5b452e57a3ad28"}

  file = fn {repo, commit}, path -> {:github, repo, commit, path} end

  # Each accordion file with the key its bank plays it on and the cents the bank lowers it by.
  @accordion for {name, key, cents} <- [
                   {"B3", 47, 34},
                   {"D4", 50, 38},
                   {"F#4", 54, 23},
                   {"G4", 55, 30},
                   {"A4", 57, 32},
                   {"B4", 59, 19},
                   {"C5", 60, 28},
                   {"D5", 62, 26},
                   {"E5", 64, 30},
                   {"F#5", 66, 26},
                   {"G5", 67, 29},
                   {"A5", 69, 20},
                   {"B5", 71, 7},
                   {"C6", 72, 26},
                   {"D6", 74, 16},
                   {"E6", 76, 22},
                   {"G6", 79, 10}
                 ],
                 do:
                   {file.(@accordion_repo, "Button Accordion HN #{name}.flac"),
                    note: key + cents / 100}

  @guitar file.(@guitar_repo, "samples")

  # The piano was recorded soft, L, and hard, H, on every third key, and a few keys in one
  # strength only.
  @piano for {layer, strength, names} <- [
               {"L", 1,
                ~w(A0 C1 D#1 F#1 A1 C2 D#2 F#2 A2 C3 D#3 F#3 A3 C4 D#4 F#4 A4 C5 D#5 F#5 A5 C6 D#6 F#6 A6 C7 D#7 F#7 A7 C8)},
               {"H", 2,
                ~w(A0 B0 C1 D#1 F#1 A1 B1 C2 D#2 F#2 B2 C3 D#3 F#3 A3 B3 D#4 F#4 A4 B4 C5 D#5 F#5 A5 B5 C6 D#6 F#6 A6 B6 C7 D#7 F#7 A7 B7 C8)}
             ],
             name <- names,
             do:
               {file.(@piano_repo, "samples/#{name}v#{layer}.flac"),
                note: name |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse(),
                strength: strength}

  # Each chord's bass notes, the root and the note that alternates with it, and its three notes on
  # the guitar's top strings.
  @chords %{
    am: {[:a2, :e2], [:a3, :c4, :e4]},
    e7: {[:e2, :b2], [:gs3, :d4, :e4]},
    a7: {[:a2, :e2], [:g3, :cs4, :e4]},
    dm: {[:d3, :a2], [:a3, :d4, :f4]},
    c: {[:c3, :g2], [:g3, :c4, :e4]},
    g7: {[:g2, :d3], [:g3, :b3, :f4]},
    c7: {[:c3, :g2], [:g3, :bb3, :e4]},
    f: {[:f2, :c3], [:a3, :c4, :f4]},
    fm: {[:f2, :c3], [:ab3, :c4, :f4]},
    a: {[:a2, :e2], [:a3, :cs4, :e4]},
    d: {[:d3, :a2], [:a3, :d4, :fs4]}
  }

  @minor ~w(am am e7 e7 e7 e7 am am am a7 dm dm am e7 am am)a
  @second ~w(c c g7 g7 g7 g7 c c c c7 f fm c g7 c e7)a
  @major ~w(a a e7 e7 e7 e7 a a a a7 d dm a e7 a a)a

  # A pair of the chord's notes held for each bar, the higher pair when the chord stays.
  @pairs %{
    am: [[:c4, :e4], [:e4, :a4]],
    e7: [[:b3, :d4], [:d4, :gs4]],
    a7: [[:cs4, :g4], [:cs4, :g4]],
    dm: [[:d4, :f4], [:f4, :a4]],
    c: [[:e4, :g4], [:g4, :c5]],
    g7: [[:d4, :f4], [:f4, :b4]],
    c7: [[:e4, :bb4], [:e4, :bb4]],
    f: [[:f4, :a4], [:f4, :a4]],
    fm: [[:f4, :ab4], [:f4, :ab4]]
  }

  @tune [
    [a4: 1, c5: 0.5, b4: 0.5, a4: 0.5, gs4: 0.5],
    [a4: 2, e4: 1],
    [gs4: 1, b4: 0.5, a4: 0.5, gs4: 0.5, f4: 0.5],
    [e4: 2, b3: 1],
    [d4: 1, f4: 0.5, e4: 0.5, d4: 0.5, b3: 0.5],
    [gs3: 1, b3: 1, e4: 1],
    [c4: 0.5, e4: 0.5, a4: 0.5, c5: 0.5, b4: 0.5, a4: 0.5],
    [a4: 3],
    [e5: 1, c5: 0.5, a4: 0.5, e4: 0.5, a4: 0.5],
    [cs5: 1, e5: 0.5, cs5: 0.5, a4: 0.5, g4: 0.5],
    [f4: 1, a4: 0.5, d5: 0.5, f5: 0.5, e5: 0.5],
    [d5: 2, a4: 1],
    [c5: 0.5, b4: 0.5, a4: 0.5, e4: 0.5, c4: 0.5, e4: 0.5],
    [gs4: 0.5, e4: 0.5, b3: 0.5, d4: 0.5, gs3: 0.5, b3: 0.5],
    [a3: 1, c4: 0.5, e4: 0.5, a4: 0.5, c5: 0.5],
    [a4: 2, r: 1]
  ]

  @second_strain [
    [e5: 1, g5: 1, e5: 1],
    [c5: 2, e5: 1],
    [d5: 1, f5: 1, d5: 1],
    [b4: 2, d5: 1],
    [f5: 0.5, e5: 0.5, d5: 0.5, b4: 0.5, g4: 0.5, b4: 0.5],
    [d5: 1, f5: 1, a5: 1],
    [g5: 2, e5: 1],
    [c5: 3],
    [e5: 1, g5: 1, c6: 1],
    [bb5: 2, g5: 1],
    [a5: 1, c6: 0.5, a5: 0.5, f5: 0.5, a5: 0.5],
    [ab5: 2, f5: 1],
    [g5: 0.5, e5: 0.5, c5: 0.5, e5: 0.5, g5: 0.5, c6: 0.5],
    [b5: 1, a5: 0.5, g5: 0.5, f5: 0.5, d5: 0.5],
    [c5: 2, r: 1],
    [e5: 1, gs5: 1, b5: 1]
  ]

  @trio [
    [cs5: 1, e5: 0.5, cs5: 0.5, a4: 0.5, cs5: 0.5],
    [e5: 2, cs5: 1],
    [d5: 1, e5: 0.5, d5: 0.5, b4: 0.5, gs4: 0.5],
    [b4: 2, e4: 1],
    [gs4: 0.5, b4: 0.5, d5: 0.5, e5: 0.5, d5: 0.5, b4: 0.5],
    [gs4: 1, e4: 1, d4: 1],
    [cs4: 0.5, e4: 0.5, a4: 0.5, cs5: 0.5, e5: 0.5, cs5: 0.5],
    [a4: 3],
    [e5: 1, cs5: 0.5, a4: 0.5, e4: 0.5, a4: 0.5],
    [g4: 1, a4: 0.5, cs5: 0.5, e5: 0.5, g5: 0.5],
    [fs5: 1, d5: 0.5, a4: 0.5, fs4: 0.5, a4: 0.5],
    [f5: 2, d5: 1],
    [e5: 0.5, cs5: 0.5, a4: 0.5, e4: 0.5, cs4: 0.5, e4: 0.5],
    [gs4: 0.5, b4: 0.5, d5: 0.5, e5: 0.5, gs4: 0.5, b4: 0.5],
    [a4: 1, cs5: 1, e5: 1],
    [a4: 3]
  ]

  part :accordion,
    synth: sampled(@accordion),
    defaults: [amp: 0.4, attack: 0.03, release: 0.2],
    fx: [reverb: [room: 0.5, mix: 0.2]]

  part :guitar,
    synth: sampled(@guitar),
    defaults: [amp: 0.6, release: 1.5],
    fx: [pan: [pan: -0.3], reverb: [room: 0.5, mix: 0.2]]

  part :piano,
    synth: sampled(@piano),
    defaults: [amp: 0.45, release: 0.8],
    fx: [pan: [pan: 0.3], reverb: [room: 0.5, mix: 0.2]]

  part :slowing, []

  def song do
    seq([intro(), tune(), second_strain(), tune_on_piano(), trio()])
  end

  # The guitar alone: Am and E7 as arpeggios across its strings.
  defp intro do
    part(
      :guitar,
      seq([
        seq(a2: 0.5, e3: 0.5, a3: 0.5, c4: 0.5, e4: 0.5, a4: 0.5),
        seq(e2: 0.5, b2: 0.5, e3: 0.5, gs3: 0.5, d4: 0.5, e4: 0.5),
        seq(a2: 0.5, e3: 0.5, a3: 0.5, c4: 0.5, e4: 0.5, c5: 0.5),
        note([:e2, :b2, :e3, :gs3, :d4, :e4], 3, vel: 0.6, strum: 0.12)
      ])
    )
  end

  defp tune do
    together([
      part(:accordion, line(@tune)),
      part(:guitar, pompe(@minor)),
      part(:piano, basses(@minor))
    ])
  end

  defp second_strain do
    together([
      part(:guitar, line(@second_strain, vel: 0.95)),
      part(:piano, pompe(@second, octaves: true, strum: 0)),
      part(:accordion, pairs(@second))
    ])
  end

  defp tune_on_piano do
    together([
      part(:piano, line(@tune, octaves: [0, 12], vel: 0.9)),
      part(:guitar, pompe(@minor)),
      part(:accordion, pairs(@minor))
    ])
  end

  # The trio, slowing over its last two bars into a chord from all three.
  defp trio do
    together([
      part(
        :accordion,
        seq([
          line(@trio),
          note([:a4, :cs5, :e5], 6, vel: 0.7, attack: 0.1, sustain: 2, release: 0.6)
        ])
      ),
      part(
        :guitar,
        seq([
          pompe(@major, strum: 0.05),
          note([:a2, :e3, :a3, :cs4, :e4, :a4], 6, vel: 0.7, strum: 0.15, release: 6)
        ])
      ),
      part(
        :piano,
        seq([
          pompe(@major, octaves: true, high: 12, strum: 0),
          note([:a1, :a2, :e3, :a3, :cs4, :e4], 6, vel: 0.6, release: 6)
        ])
      ),
      part(:slowing, seq([rest(42), tempo(110, over: 6)]))
    ])
  end

  # A tune's bars as one line, the first note of each bar a little harder.
  defp line(bars, opts \\ []) do
    octaves = Keyword.get(opts, :octaves, [0])
    vel = Keyword.get(opts, :vel, 0.8)

    seq(
      for bar <- bars, {{name, beats}, index} <- Enum.with_index(bar) do
        if name == :r do
          rest(beats)
        else
          pitches = for octave <- octaves, do: pitch(name) + octave
          note(pitches, beats, vel: if(index == 0, do: vel, else: vel - 0.15))
        end
      end
    )
  end

  # The pompe: the bass on one and the chord on two and three, the bass moved by `low` semitones
  # and the chord by `high`.
  defp pompe(chords, opts \\ []) do
    low = Keyword.get(opts, :low, 0)
    high = Keyword.get(opts, :high, 0)
    strum = Keyword.get(opts, :strum, 0.03)

    seq(
      for {bass, notes} <- bars(chords) do
        chord = Enum.map(notes, &(&1 + high))
        bass = if Keyword.get(opts, :octaves), do: [bass + low - 12, bass + low], else: bass + low

        seq([
          note(bass, 1, vel: 0.9, release: 2),
          note(chord, 1, vel: 0.5, strum: strum),
          note(chord, 1, vel: 0.45, strum: strum)
        ])
      end
    )
  end

  # Only the pompe's bass, in octaves, a bar long.
  defp basses(chords) do
    seq(for {bass, _} <- bars(chords), do: note([bass - 12, bass], 3, vel: 0.7, release: 1))
  end

  defp pairs(chords) do
    chords
    |> Enum.chunk_by(& &1)
    |> Enum.flat_map(fn run ->
      for {chord, index} <- Enum.with_index(run) do
        note(Enum.at(@pairs[chord], rem(index, 2)), 3, vel: 0.45, attack: 0.3, release: 0.4)
      end
    end)
    |> seq()
  end

  # Each bar's chord with its bass note: the root, then the other note when the chord stays for
  # another bar.
  defp bars(chords) do
    chords
    |> Enum.chunk_by(& &1)
    |> Enum.flat_map(fn run ->
      for {chord, index} <- Enum.with_index(run) do
        {basses, notes} = @chords[chord]
        {pitch(Enum.at(basses, rem(index, 2))), Enum.map(notes, &pitch/1)}
      end
    end)
  end
end
