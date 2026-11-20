defmodule Mx do
  @moduledoc """
  Music written as Elixir code.

  A song file starts with `import Mx` and ends with the song, its music built from plain functions:

      import Mx

      song(tempo: 120, music: part(:melody, seq([note(:c4, 1), note(:e4, 1), note(:g4, 1)]), synth: :tri))
  """

  @doc """
  A note of a pitch, given as a name, a number or a list of them played together, lasting some beats, with options for the part's synth.

      note(:a4, 1.5)
      note(:a4, 1.5, vel: 0.8, sustain: 1)
      note(chord(:c4, :major), 2, strum: 0.05)
      note([40, 47, 52], 1, vel: [0.8, 0.6, 0.5])

      iex> beats(note(:a4, 1.5))
      1.5
  """
  defdelegate note(pitch, beats, opts \\ []), to: Mx.Music

  @doc """
  Silence lasting some beats.

      seq([note(:c4, 1), rest(1), note(:e4, 1)])

      iex> beats(rest(2))
      2
  """
  defdelegate rest(beats), to: Mx.Music

  @doc """
  Music played one item after another, as long as all of them.
  An item given as `{name, beats}` is a note, and `{:r, beats}` a rest, so a melody can be written as a keyword list.

      seq([note(:c4, 1), note(:e4, 1)])
      seq(a4: 1.5, a4: 0.5, c5: 1, r: 1)
      seq([intro(), verse(), verse()])

      iex> beats(seq(a4: 1.5, r: 1, c5: 1))
      3.5
  """
  defdelegate seq(items), to: Mx.Music

  @doc """
  Music whose items all start at once, as long as the longest.

      together([
        part(:soprano, soprano(), synth: :oboe),
        part(:bass, bass(), synth: :bassoon)
      ])

      iex> beats(together([seq(c4: 4), seq(e4: 1, f4: 1)]))
      4
  """
  defdelegate together(items), to: Mx.Music

  @doc """
  The music after some beats of silence, so it starts that many beats into the music it plays together with.

      together([part(:kick, kick()), part(:tom, delay(roll(), 7))])

      iex> beats(delay(seq(c4: 1), 7))
      8
  """
  defdelegate delay(music, beats), to: Mx.Music

  @doc """
  Music played again and again until mx stops.
  It can only hold the whole of a song's music, so a song of sections that goes round is `repeat(seq([a, b]))`.

      song(music: repeat(seq([verse(), chorus()])))
  """
  defdelegate repeat(music), to: Mx.Music

  @doc """
  Music played a number of times in a row.

      repeat(seq(c4: 1, g4: 1), 4)

      iex> beats(repeat(seq(c4: 1, g4: 1), 4))
      8
  """
  defdelegate repeat(music, times), to: Mx.Music

  @doc """
  The music moved by a number of semitones, every note moved and nothing else changed.

      transpose(theme(), 12)
      transpose(seq(c4: 1, e4: 1), -5)
  """
  defdelegate transpose(music, semitones), to: Mx.Music

  @doc """
  Music lasting some beats whose items start at their beats from its start, given as `{beat, music}`, so strokes at known beats need no rests between them.
  An item placed at or past the length is refused.

      # The son clave, 3-2, over two bars of four beats.
      clave = for beat <- [0, 1.5, 3, 5, 6], do: {beat, steps("x", 0)}
      at(clave, 8)
      at([{0.5, note(:c4, 0.5)}, {1.5, note(:e4, 0.5)}], 2)

      iex> beats(at([{0.5, note(:c4, 0.5)}], 2))
      2
  """
  defdelegate at(entries, beats), to: Mx.Music

  @doc """
  The music with each note started at the beat the function returns for the beat it was written on, its length unchanged, so some notes can be pushed late and others early.

      # The second sixteenth of each beat a little late, the fourth a little early.
      swing(line(), fn beat -> beat + Enum.at([0, 0.02, 0, -0.02], rem(round(beat * 4), 4)) end)
  """
  defdelegate swing(music, fun), to: Mx.Music

  @doc """
  The sounds of a pattern, each character lasting a step of beats; spaces are left out, and a list of patterns is one bar after another.
  An x is a hit of a drum at its own pitch, a dot is silence, and a digit is a hit of that level, 9 the loudest.
  The other options go to every sound.

      part(:kick, steps("x... x... x... x.x.", 0.25), synth: :kick)
      part(:hats, steps("x.x.x.x.", 0.5, vel: 0.3), synth: :closed_hihat)
      part(:snare, steps(["..3. 9...", "..3. 9.69"], 0.25), synth: :snare)

  A digit sets `vel:`, or the option `digit:` names.
  `sample:` plays each hit as that sample, where a digit sets `amp:`.
  `strokes:` gives the options of other characters, and `notes:` makes a digit a hit tuned to that note of a list, counted from 1.
  `each:` is a function of the step a sound starts on, counted from 0, that returns more options for it.

      steps("9...9..5", 0.25, sample: "kick.wav", release: 0.1)
      steps("ccoc", 0.25, strokes: [o: [vel: 0.75, sustain: 0.2], c: [vel: 0.5]])
      steps("..1..5.3", 0.25, notes: [:g4, :a4, :bb4, :c5, :d5])
      steps("x.xx", 0.25, each: fn step -> [vel: if(step == 0, do: 0.9, else: 0.5)] end)

  A function of two for `each:` takes the length of the sound in steps as well.

  A pattern of `sigil_MX/2` is read a word to a step, and a word that is no stroke is a note's name.
  A word after `~` is the note the one before it glides to, which `slide:` gives the beats to get there.

      part(:lead, steps(~MX"g4:2 _ g4 bb4:2 _ a4", 0.25, vel: 0.8))
      part(:bass, steps(~MX"eb2:2 ~g2:2 d2:4", 0.25, slide: 0.3), synth: :fm)

      iex> beats(steps("x..x", 0.25))
      1.0

      iex> beats(steps(~MX"g4:2 _ g4 [a4 bb4]", 0.5))
      2.5
  """
  defdelegate steps(pattern, step, opts \\ []), to: Mx.Music

  @doc """
  A hit of a drum at its own pitch, taking no time, with options for the part's synth, for placing at a beat with `at`.

      part(:cajon, at([{0, hit(slap: 1, vel: 0.8)}, {1.5, hit(vel: 0.5)}], 2), synth: :cajon)

      iex> beats(hit(vel: 0.5))
      0
  """
  defdelegate hit(opts \\ []), to: Mx.Music

  @doc """
  A recording of a collection as `{collection, name}`, or a WAV, AIFF or FLAC file by path, then some beats of time, with the options samples take.
  A sample mx cannot find is refused when it is named.

      part(:drums, seq([sample({:sonic_pi, :bd_haus}, 1), sample({:sonic_pi, :sn_dolf}, 1)]))
      part(:bell, sample({:vcsl, "Idiophones/Struck Idiophones/Agogo Bells/Agogo_High_v3_rr1_Mid.wav"}, 1))
      part(:voice, sample("samples/hello.wav", 4, amp: 0.8))

      iex> beats(seq([sample({:sonic_pi, :bd_haus}, 1), sample({:sonic_pi, :bd_haus}, 0.5)]))
      1.5
  """
  defdelegate sample(ref, beats, opts \\ []), to: Mx.Music

  @doc """
  A MIDI note on, and its note off after some beats, taking `velocity:` and `channel:`; a part's `midi:` names the output it goes to.

      part(:synth, seq([midi(:c4, 1, velocity: 90), midi(:e4, 1)]), midi: "IAC Driver Bus 1")
  """
  defdelegate midi(note, beats, opts \\ []), to: Mx.Music

  @doc """
  A MIDI controller change, taking `channel:` and no time.

      part(:synth, seq([midi_cc(74, 64), midi(:c4, 4)]), midi: "IAC Driver Bus 1")
  """
  defdelegate midi_cc(number, value, opts \\ []), to: Mx.Music

  @doc """
  An OSC message to the song's `osc_to`, taking no time.

      part(:lights, seq([osc("/scene", [1]), rest(4), osc("/scene", [2])]))
  """
  defdelegate osc(address, args \\ []), to: Mx.Music

  @doc """
  A value shared with every loop from its next pass, read there as `inputs.values[name]`, taking no time.

      part(:conductor, loop(16, fn pass, _ -> seq([set(:root, Enum.at([:c3, :f3], rem(pass, 2))), rest(16)]) end))
  """
  defdelegate set(name, value), to: Mx.Music

  @doc """
  A change to every sound of a part still playing, or, given `{part, effect}`, to one of the part's effects, at its beat, taking no time.
  It takes the options the synth or effect takes, and slides as control does; envelope options such as `release` are refused.
  A note changes itself with `changes:`, as `note(:a4, 4, changes: [{1, note: :c5, note_slide: 0.1}])` glides to C5 a beat in.

      seq([rest(8), change(:pads, cutoff: 80, cutoff_slide: 2)])
      seq([rest(16), change({:lead, :reverb}, mix: 0)])
  """
  defdelegate change(target, opts), to: Mx.Music

  @doc """
  A change of the whole song's tempo, at its beat, taking no time: at once, or with `over:` evenly over that many beats.
  Every part follows it together, and a section that starts with it plays at the new tempo from its first beat.
  It is written in the song's music, not returned by a loop.

      song(tempo: 100, music: seq([part(:a, seq(c4: 4)), tempo(140), part(:a, seq(e4: 4))]))
      part(:drums, seq([tempo(130, over: 16), repeat(steps("x.x.", 1), 4)]), synth: :kick)
  """
  defdelegate tempo(bpm, opts \\ []), to: Mx.Music

  @doc """
  Music that runs the function every `beats` beats, with the pass number and the inputs, and plays the music it returns.
  Beside other music it plays until the longest of the rest ends; alone, it plays until mx stops, or `times:` passes.
  Given `on:` instead of a length, it plays a pass each time that input arrives, with what arrived in place of the pass number.
  The inputs are `inputs.cc`, `inputs.notes`, `inputs.osc` and `inputs.values`, each a map from number, address or name to its latest value.

      part(:hats, loop(4, fn pass, _ -> steps(if(rem(pass, 4) == 3, do: "xxxxxxxx", else: "x.x.x.x."), 0.5) end), synth: :closed_hihat)
      part(:bass, loop(1, fn _, inputs -> note(:c2, 1, cutoff: (inputs.cc[74] || 64) * 50) end), synth: :saw)
      part(:pads, loop(fn trigger, _ -> note(trigger.note, 1) end, on: :midi_note), synth: :tri)

      iex> beats(loop(16, fn _, _ -> rest(16) end, times: 4))
      64
  """
  defdelegate loop(beats, fun, opts \\ []), to: Mx.Music

  @doc """
  Music played by one player: `synth:` names its synth, `:tri` by default, and `fx:`, `defaults:` and `midi:` are taken as a loop takes them.
  A part of one name plays as one player wherever it appears in the song.

      part(:soprano, seq(c4: 1, d4: 1, e4: 2), synth: :oboe)
      part(:guitar, comping(), synth: :guitar, defaults: [amp: 0.5], fx: [reverb: [mix: 0.2]])
  """
  defdelegate part(name, music, opts \\ []), to: Mx.Music

  @doc """
  A sampled instrument, for a part's `synth:`: a folder of recordings whose names carry their note, strength and take, as VCSL names them, or a list of files, each with its own.

      part(:mbira, seq(e4: 1, fs4: 1), synth: sampled({:vcsl, "Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B"}))
      part(:kick, steps("x.x.", 1), synth: sampled([{"kick_soft.wav", strength: 1}, {"kick_hard.wav", strength: 2}]))
  """
  defdelegate sampled(source), to: Mx.Sampled, as: :new

  @doc """
  The song, which a song file ends with: its `music:`, its `tempo:`, 60 by default, its `meter:`, the whole beats to a bar, 4 by default, its `key:`, such as `:em`, none by default, and `live_audio:`, `osc_to:` and `osc_from:`.

      import Mx

      song(tempo: 72, music: part(:soprano, seq(c4: 1, d4: 1, e4: 2), synth: :oboe))

      song(
        tempo: 120,
        music: repeat(seq([verse(), chorus()])),
        live_audio: [mic: [input: 1]],
        osc_to: {"127.0.0.1", 9000}
      )
  """
  defdelegate song(opts), to: Mx.Music

  @doc """
  A pattern written as words, read when the song compiles, for `steps/3` to play.
  Each word lasts one step: `_` is silence, `-` holds the word before it a step longer, and a number after a colon is a length in steps.
  Words joined by a slash sound together, the words in brackets share one step, and a bar line is only for reading.
  A word after `~` is not struck: the note before it glides to it and lasts through it.
  Patterns join with `++`.
  With the modifier `s` each character lasts one step instead, a dot is silence, and spaces and bar lines are left out.

      ~MX"g5/b4:3 fs5/a4 | e5/g4:2 - _"
      ~MX"T f h [f f]"
      ~MX"9... 9..5 | x.x. x..."s

      iex> ~MX"9. x"s
      [%{tokens: ["9"], steps: 1}, %{tokens: [], steps: 1}, %{tokens: ["x"], steps: 1}]

      iex> ~MX"g4:2 _ [f f]"
      [
        %{tokens: ["g4"], steps: 2},
        %{tokens: [], steps: 1},
        %{tokens: ["f"], steps: 0.5},
        %{tokens: ["f"], steps: 0.5}
      ]
  """
  defmacro sigil_MX({:<<>>, _meta, [text]}, modifiers) when is_binary(text) do
    case modifiers do
      [] -> Macro.escape(Mx.Pattern.parse(text))
      ~c"s" -> Macro.escape(Mx.Pattern.parse_steps(text))
      _ -> raise ArgumentError, "it takes no modifier but s, a character to a step"
    end
  rescue
    error in ArgumentError ->
      description = "~MX: " <> error.message

      reraise CompileError,
              [file: __CALLER__.file, line: __CALLER__.line, description: description],
              __STACKTRACE__
  end

  @doc """
  The length of music in beats, or `:infinity` for music that plays until mx stops.

      seq([rest(beats(intro())), melody()])

      iex> beats(seq(a4: 1.5, r: 1, c5: 1))
      3.5
      iex> beats(repeat(seq(c4: 1)))
      :infinity
  """
  defdelegate beats(music), to: Mx.Music

  @doc """
  The number of a note name, or the number itself.

      iex> pitch(:e5)
      76
      iex> pitch(:fs3)
      54
      iex> pitch(60)
      60
  """
  defdelegate pitch(pitch), to: Mx.Music

  @doc """
  The notes of a chord, from a root note given as a name or a number.

      iex> chord(:c4, :major)
      [60, 64, 67]
  """
  defdelegate chord(root, name), to: Mx.Notes

  @doc """
  The notes of a scale, from a root note up to its octave, over `octaves:` octaves.

      iex> scale(:c4, :major_pentatonic)
      [60, 62, 64, 67, 69, 72]
  """
  defdelegate scale(root, name, opts \\ []), to: Mx.Notes

  @doc """
  The notes reached by taking each step in turn from a start note.

      iex> melody(60, [4, 3, -2])
      [60, 64, 67, 65]
  """
  defdelegate melody(start, steps), to: Mx.Notes

  @doc """
  The step from each note to the next.

      iex> intervals([60, 64, 67])
      [4, 3]
  """
  defdelegate intervals(notes), to: Mx.Notes

  @doc """
  The note of a chord, in any octave, closest to a note, the lower on a tie; `except:` leaves a note out.

      iex> nearest(65, chord(:c4, :major))
      64
      iex> nearest(64, chord(:c4, :major), except: 64)
      67
  """
  defdelegate nearest(note, chord, opts \\ []), to: Mx.Notes

  @doc """
  The note of a chord closest below a note.

      iex> below(76, chord(:a4, :minor7))
      72
  """
  defdelegate below(note, chord), to: Mx.Notes

  @doc """
  Each note of a chord placed once between two notes.

      iex> voice(chord(:g2, :major6), from: 62, to: 73)
      [62, 64, 67, 71]
  """
  defdelegate voice(chord, opts), to: Mx.Notes

  @doc """
  A scale bent to the notes of a chord: each chord tone missing from the scale takes the place of the scale note a semitone from it.

      iex> fit(scale(:a4, :minor), chord(:e4, :dom7))
      [69, 71, 72, 74, 76, 77, 80, 81]
  """
  defdelegate fit(scale, chord), to: Mx.Notes

  @doc """
  The item of a list at an index, wrapping round.

      iex> ring([60, 62, 64], 4)
      62
  """
  defdelegate ring(list, index), to: Mx.Notation

  @doc """
  An interval in cents as semitones, rounded to two decimals.

      iex> cents(386)
      3.86
  """
  defdelegate cents(cents), to: Mx.Notation

  @doc """
  The interval of a frequency ratio in semitones, rounded to two decimals.

      iex> ratio(5 / 4)
      3.86
      iex> ratio(2)
      12.0
  """
  defdelegate ratio(ratio), to: Mx.Notation

  @doc """
  A number kept from `low` up to `high`.

      iex> clamp(12, 2, 11)
      11
  """
  defdelegate clamp(value, low, high), to: Mx.Notation

  @doc """
  One item of a list or a range, from the seeded random numbers, so the same song plays the same notes every time.

      note(pick([:c4, :e4, :g4]), 1)
  """
  defdelegate pick(items), to: Mx.Notation

  @doc """
  True about `probability` times in 1, from the seeded random numbers.

      if chance(0.3), do: steps("xxxx", 0.25), else: steps("x.x.", 0.25)
  """
  defdelegate chance(probability), to: Mx.Notation

  @doc """
  A number from `low` up to `high`, rounded to two decimals, from the seeded random numbers.

      note(:c4, 1, vel: between(0.3, 0.4))
  """
  defdelegate between(low, high), to: Mx.Notation
end
