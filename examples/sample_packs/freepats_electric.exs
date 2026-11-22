defmodule NightService do
  @moduledoc """
  Night Service, a house track at 122 bpm for FreePats' electric and synthesizer instruments, each
  under Creative Commons 0.
  The synthesizer percussion plays four on the floor with a clap on two and four and an open
  hi-hat on every off-beat; Lately Bass, the FM bass of late 1980s house, jumps between octaves.
  The FM piano holds the chords under a tremolo and then plays them as stabs, the clean electric
  guitar plays arpeggios into an echo three sixteenths long, the synth strings and the choir pad
  hold the harmony, the synth brass answers, and the synth square plays the tune.
  It goes round Cm7, A flat major 7, B flat and Gm7, a bar each.
  Download each instrument with mx samples download
  "freepats_lately_bass:samples", and the same for the
  other repositories and commits named below; the guitar's folder is samples/bridge.
  """

  use Mx.Song, tempo: 122

  @collections %{
    percussion: :freepats_synth_percussion,
    bass: :freepats_lately_bass,
    piano: :freepats_fm_piano,
    strings: :freepats_synth_strings,
    brass: :freepats_synth_brass,
    lead: :freepats_synth_square,
    choir: :freepats_synth_choir,
    guitar: :freepats_electric_guitar
  }

  file = fn name, path -> {@collections[name], path} end

  key = fn name -> name |> String.downcase() |> String.replace("#", "s") |> pitch() end

  drum = fn names ->
    for {name, take} <- Enum.with_index(names, 1),
        do: {file.(:percussion, "samples/#{name}.flac"), take: take}
  end

  # The piano was recorded at three strengths on every sixth key.
  @piano for name <- ~w(F#1 C2 F#2 C3 F#3 C4 F#4 C5 F#5 C6 F#6 C7),
             {layer, strength} <- [{60, 1}, {80, 2}, {100, 3}],
             do:
               {file.(:piano, "samples/#{name}v#{layer}.flac"),
                note: key.(name), strength: strength}

  # The guitar's bridge pickup: each note and the string it was played on, in three takes.
  @guitar for name <-
                ~w(C2_s1 E2_s1 F2_s1 A2_s2 C3_s2 D3_s3 E3_s3 G3_s4 B3_s5 C#4_s5 E4_s6 G4_s6 B4_s6 C5_s6 D5_s6 F5_s6 G#5_s6 A#5_s6 C#6_s6),
              take <- 1..3,
              do:
                {file.(:guitar, "samples/bridge/#{name}_0#{take}.flac"),
                 note: name |> String.split("_") |> hd() |> key.(), take: take}

  part :kick, synth: sampled(drum.(["Kick06"])), defaults: [amp: 0.55]

  part :snare,
    synth: sampled(drum.(["Snare14"])),
    defaults: [amp: 0.35],
    fx: [reverb: [decay_seconds: 1.2, mix: 0.2]]

  part :clap,
    synth: sampled(drum.(["Clap01"])),
    defaults: [amp: 0.4],
    fx: [reverb: [decay_seconds: 1.5, mix: 0.25]]

  part :hat,
    synth: sampled(drum.(["ClosedHiHat01-01", "ClosedHiHat02-01"])),
    defaults: [amp: 0.3],
    fx: [pan: [pan: 0.2]]

  part :open_hat,
    synth: sampled(drum.(["OpenHiHat02-01"])),
    defaults: [amp: 0.3],
    fx: [pan: [pan: 0.2]]

  part :shaker, synth: sampled(drum.(["Shaker04"])), defaults: [amp: 0.3], fx: [pan: [pan: -0.4]]

  part :claves,
    synth: sampled(drum.(["Claves01"])),
    defaults: [amp: 0.3],
    fx: [pan: [pan: -0.3], reverb: [decay_seconds: 1.5, mix: 0.3]]

  part :high_tom,
    synth: sampled(drum.(["HighTom02-01", "HighTom02-02"])),
    defaults: [amp: 0.45],
    fx: [pan: [pan: -0.4]]

  part :mid_tom, synth: sampled(drum.(["MidTom02-01", "MidTom02-02"])), defaults: [amp: 0.45]

  part :low_tom,
    synth: sampled(drum.(["LowTom02-01", "LowTom02-02"])),
    defaults: [amp: 0.45],
    fx: [pan: [pan: 0.4]]

  part :cymbal,
    synth: sampled(drum.(["Cymbal01-01"])),
    defaults: [amp: 0.3],
    fx: [reverb: [decay_seconds: 1.8, mix: 0.3]]

  part :bass, synth: sampled(file.(:bass, "samples")), defaults: [amp: 0.38, release: 0.1]

  part :piano,
    synth: sampled(@piano),
    defaults: [amp: 0.42, release: 0.5],
    fx: [tremolo: [phase: 0.5, depth: 0.4, wave: 3], reverb: [decay_seconds: 1.5, mix: 0.2]]

  part :guitar,
    synth: sampled(@guitar),
    defaults: [amp: 0.3, release: 1],
    fx: [
      ping_pong: [phase: 0.75, feedback: 0.45, mix: 0.35],
      reverb: [decay_seconds: 1.5, mix: 0.15]
    ]

  part :strings,
    synth: sampled(file.(:strings, "samples")),
    defaults: [amp: 0.12, attack: 0.5, release: 1.5],
    fx: [chorus: [mix: 0.3], reverb: [decay_seconds: 2.3, mix: 0.3]]

  part :choir,
    synth: sampled(file.(:choir, "samples")),
    defaults: [amp: 0.12, attack: 1, release: 2],
    fx: [reverb: [decay_seconds: 3.2, mix: 0.4]]

  part :brass,
    synth: sampled(file.(:brass, "samples")),
    defaults: [amp: 0.16, attack: 0.02, release: 0.25],
    fx: [pan: [pan: 0.25], reverb: [decay_seconds: 1.5, mix: 0.25]]

  part :lead,
    synth: sampled(file.(:lead, "samples")),
    defaults: [amp: 0.2, attack: 0.03, release: 0.3],
    fx: [echo: [phase: 0.75, decay: 3, mix: 0.25], reverb: [decay_seconds: 1.8, mix: 0.25]]

  # Each chord's bass note and its notes around middle C.
  @chords [
    {:c2, [:bb3, :c4, :eb4, :g4]},
    {:ab1, [:ab3, :c4, :eb4, :g4]},
    {:bb1, [:bb3, :d4, :f4, :a4]},
    {:g1, [:bb3, :d4, :f4, :g4]}
  ]

  @tune [
    [r: 0.5, g4: 0.5, bb4: 0.5, c5: 1, eb5: 1, d5: 0.5],
    [c5: 2, r: 0.5, ab4: 0.5, c5: 0.5, eb5: 0.5],
    [d5: 1.5, f5: 1, d5: 0.5, bb4: 1],
    [g4: 2.5, r: 0.5, f4: 0.5, g4: 0.5],
    [r: 0.5, g4: 0.5, bb4: 0.5, c5: 1, eb5: 1, g5: 0.5],
    [f5: 1.5, eb5: 1, c5: 1.5],
    [d5: 1, f5: 0.5, g5: 1, f5: 0.5, d5: 1],
    [d5: 2, bb4: 1, r: 1]
  ]

  @kick "9...9...9...9..."
  @backbeat "....9.......9..."
  @hats "7.354.357.354.35"
  @open "..6...6...6...6."
  @shaker "5343534353435343"
  @clave "7..7..7...7.7..."

  def song do
    seq([intro(), beat_in(), guitar_in(), verse(), breakdown(), chorus(), outro()])
  end

  # The piano alone under its tremolo, with the shaker.
  defp intro, do: together(piano: held(1), shaker: drum(@shaker, 4))

  defp beat_in do
    together(
      [cymbal: drum("8"), piano: held(1), shaker: drum(@shaker, 4), bass: bass(1)] ++ beat(4)
    )
  end

  defp guitar_in do
    together(
      [
        piano: held(1),
        shaker: drum(@shaker, 4),
        bass: bass(1),
        guitar: arpeggio(1),
        strings: held(1, up: 12)
      ] ++ beat(4)
    )
  end

  # The tune on the synth square, the brass answering at the end of every second bar.
  defp verse do
    together(
      [
        cymbal: drum("8"),
        lead: tune(),
        brass: answers(),
        piano: held(2),
        shaker: drum(@shaker, 8),
        bass: bass(2),
        guitar: arpeggio(2),
        strings: held(2, up: 12)
      ] ++ beat(8)
    )
  end

  # The drums drop to the kick, the choir holds the chords, and the toms run down into the chorus.
  defp breakdown do
    together(
      kick: drum(@kick, 4),
      shaker: drum(@shaker, 4),
      choir: held(1, up: 12),
      strings: held(1),
      guitar: arpeggio(1),
      high_tom: drum([String.duplicate(".", 48), "........79......"]),
      mid_tom: drum([String.duplicate(".", 48), "..........79...."]),
      low_tom: drum([String.duplicate(".", 48), "............789."]),
      snare: drum([String.duplicate(".", 48), "........3.4.5.68"])
    )
  end

  # Everything: the piano and the brass play the chords as stabs on the clave's rhythm, and the
  # tune goes up an octave.
  defp chorus do
    together(
      [
        cymbal: drum("9"),
        lead: tune(12),
        brass: stabs("8..7..8.........", 2, up: 12),
        piano: stabs(@clave, 2),
        claves: drum(@clave, 8),
        shaker: drum(@shaker, 8),
        bass: bass(2),
        guitar: arpeggio(2),
        strings: held(2, up: 12),
        choir: held(2, up: 12)
      ] ++ beat(8)
    )
  end

  # The beat and the guitar go on for four bars, and the last chord is left to ring.
  defp outro do
    last = fn notes, opts -> seq([rest(16), note(notes, 8, opts)]) end

    together(
      [
        cymbal: seq([drum("8"), rest(15.75), drum("9")]),
        bass: seq([bass(1), note(:c2, 8, sustain: 3, release: 2)]),
        guitar: seq([arpeggio(1), note([:c3, :g3, :c4, :eb4, :g4], 8, strum: 0.08, release: 6)]),
        piano: seq([held(1), note([:bb3, :c4, :eb4, :g4], 8, vel: 0.8, release: 6)]),
        strings: last.([:c4, :eb4, :g4, :c5], sustain: 4, release: 4),
        kick: seq([drum(@kick, 4), drum("9")]),
        shaker: drum(@shaker, 4)
      ] ++ Keyword.delete(beat(4), :kick)
    )
  end

  defp held(cycles, opts \\ []) do
    up = Keyword.get(opts, :up, 0)

    seq(
      for _ <- 1..cycles,
          {_, notes} <- @chords,
          do: note(Enum.map(notes, &(pitch(&1) + up)), 4, vel: 0.7)
    )
  end

  # Bars of a drum, a character to each sixteenth: a digit from 1 to 9 is how hard, a dot is
  # silence.
  defp drum(patterns, bars \\ 1) do
    pattern = patterns |> List.wrap() |> Enum.join() |> String.replace(" ", "")

    hits =
      for {cell, index} <- Enum.with_index(String.graphemes(pattern)),
          cell != ".",
          do: {index / 4, hit(vel: String.to_integer(cell) / 9)}

    repeat(at(hits, String.length(pattern) / 4), bars)
  end

  # Lately Bass between the root, L, and its octave, H.
  defp bass(cycles) do
    figure("L..H..L.L.H..HL.", cycles, fn {root, _}, cell ->
      octave = if cell == "H", do: 12, else: 0
      note(pitch(root) + octave, 0.25, vel: if(cell == "L", do: 1, else: 0.75), sustain: 0.22)
    end)
  end

  defp beat(bars) do
    [
      kick: drum(@kick, bars),
      clap: drum(@backbeat, bars),
      snare: drum(@backbeat, bars),
      hat: drum(@hats, bars),
      open_hat: drum(@open, bars)
    ]
  end

  # The guitar's arpeggio: up the chord from its lowest note and back, in eighths.
  defp arpeggio(cycles) do
    figure("1.2.3.4.5.4.3.2.", cycles, fn {_, [first, second, third | _]}, cell ->
      notes = [pitch(first), pitch(second), pitch(third), pitch(first) + 12, pitch(second) + 12]
      index = String.to_integer(cell) - 1
      note(Enum.at(notes, index), 0.5, vel: if(index == 0, do: 0.9, else: 0.7))
    end)
  end

  defp tune(up \\ 0) do
    seq(
      for bar <- @tune, {name, beats} <- bar do
        if name == :r, do: rest(beats), else: note(pitch(name) + up, beats, vel: 0.8)
      end
    )
  end

  # Two brass chords at the end of each second and fourth bar.
  defp answers do
    bars =
      for {{_, notes}, index} <- Enum.with_index(@chords) do
        if rem(index, 2) == 1 do
          chord = Enum.map(notes, &(pitch(&1) + 12))

          seq([
            rest(2.5),
            note(chord, 0.5, vel: 0.7, sustain: 0.3),
            note(chord, 1, vel: 0.9, sustain: 0.6)
          ])
        else
          rest(4)
        end
      end

    repeat(seq(bars), 2)
  end

  defp stabs(pattern, cycles, opts \\ []) do
    up = Keyword.get(opts, :up, 0)

    figure(pattern, cycles, fn {_, notes}, cell ->
      note(Enum.map(notes, &(pitch(&1) + up)), 0.25,
        vel: String.to_integer(cell) / 9,
        sustain: 0.3
      )
    end)
  end

  # A figure on each chord in turn, a character to each sixteenth: the function turns a chord and
  # a character into a note.
  defp figure(pattern, cycles, fun) do
    cells = pattern |> String.replace(" ", "") |> String.graphemes()

    bars =
      for chord <- @chords do
        notes =
          for {cell, index} <- Enum.with_index(cells),
              cell != ".",
              do: {index / 4, fun.(chord, cell)}

        at(notes, 4)
      end

    repeat(seq(bars), cycles)
  end
end
