defmodule Mx do
  @moduledoc """
  Music written as Elixir code.

  A song file starts with `import Mx` and ends with the song, its music built from plain functions:

      import Mx

      song(tempo: 120, music: part(:melody, seq([note(:c4, 1), note(:e4, 1), note(:g4, 1)]), synth: :tri))
  """

  @doc """
  A note of a pitch, given as a name, a number or a list of them played together, lasting some beats, with options for the part's synth.
  `held:` is the share of its length the note sounds for, taken as its `sustain`; a note given both is refused.

      note(:a4, 1.5)
      note(:a4, 1.5, vel: 0.8, sustain: 1)
      note(:a4, 2, held: 0.9)
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
  Music played one item after another, each the music the function returns for an item of the collection, a list, a range or any other enumerable.
  It is `seq(Enum.map(collection, fun))`, so the function may return a `{name, beats}` note.

      seq(1..72, &bar/1)
      seq(@tune, fn {name, beats} -> note(name, beats, vel: 0.6) end)

      iex> beats(seq(1..3, fn n -> note(60 + n, 1) end))
      3
  """
  defdelegate seq(collection, fun), to: Mx.Music

  @doc """
  A song's form: one section after another, each the music the function returns for it, so each is a section of the song as an item of its outermost `seq` is.
  The sections are a list of names, or of names and counts, so `[a: 2, b: 1]` plays a, a and b.
  A function of one argument takes the section's name; one of two takes the name and a map of `pass`, the sections played before it from 0, `time`, the times a section of its name played before from 0, and `coming`, the name of the section that follows, nil for the last.
  `round: true` gives the last section the first one's name as `coming`, for a form that repeats.

      repeat(form([a: 2, b: 2, a: 1], fn section, %{coming: coming} -> strain(section, coming) end, round: true))

      iex> beats(form([a: 2, b: 1], fn _section -> rest(4) end))
      12
  """
  defdelegate form(sections, fun, opts \\ []), to: Mx.Music

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
  Music whose items all start at once, each the music the function returns for an item of the collection.

      together([:c4, :e4, :g4], fn name -> note(name, 2) end)

      iex> beats(together([:c4, :e4], fn name -> note(name, 2) end))
      2
  """
  defdelegate together(collection, fun), to: Mx.Music

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
  The music with each of its notes and hits taking the options given, where the note gives none of its own, or those a function returns for the beat the note starts on, counted from the start of the music.
  Samples, MIDI notes, messages, changes and rests are left as they are, and the music a loop returns takes the options as well, each pass counted from its own start.
  An option the part's synth does not take is refused when the song loads.

      each(seq(e5: 0.5, a5: 0.5, c6: 1), vel: 0.8)
      each(melody(), fn beat -> [vel: if(rem(trunc(beat), 4) == 0, do: 0.9, else: 0.6)] end)

      iex> beats(each(seq(c4: 1, e4: 2), vel: 0.5))
      3
  """
  defdelegate each(music, opts), to: Mx.Music

  @doc """
  Notes one after another as one note whose pitch changes while it sounds, as `~` writes in a pattern: it starts on the first note, with its options, lasts as long as all of them, and changes to each later note's pitch at the beat that note starts.
  A note that repeats the pitch before it is held on, with no change, and a later note's options are left out.
  `slide:` glides each change over that many beats, or over what a function of the pitch left and the pitch reached returns; every other option goes to the note, and `changes:` are kept beside the slur's own.
  The music is notes and rests in a seq, with seqs and repeats inside it.
  A rest ends the note sounding and lasts as silence, and the note after it starts a new slurred note, so a slur with rests is several notes and silences one after another.
  `tongue:` takes a function of the beat a note starts on, counted from the start of the music, the pitch before it and its own, and the note starts a new slurred note where it returns true, as a player tongues it.

      slur(seq(g4: 0.5, bb4: 0.5, c5: 1), slide: 0.05, vibrato: 0.08)
      slur(seq(a4: 0.5, c5: 0.5, r: 0.5, e5: 1.5), tongue: fn beat, _from, _to -> beat == trunc(beat) end)

      iex> slur(seq(c4: 1, e4: 1))
      %Mx.Music.Note{pitch: 60, beats: 2, opts: [changes: [{1, [note: 64]}]]}
  """
  defdelegate slur(music, opts \\ []), to: Mx.Music

  @doc """
  The music played with a feel: a note that starts on a step of `step:` beats, counted from the start of the music, comes later by its step's number in `push:`, or earlier by a number below 0, and its vel is multiplied by its step's number in `lean:`.
  The tables go round, so four numbers with a step of 0.25 cover a beat, and a note between two steps is left as it is.
  `loose:` moves every start by a random amount of at most that many beats either way, and `touch:` multiplies every vel by a random number from 1 less it to 1 more, the same on every load.
  A vel changed is the note's own, or else its part's, kept from 0 to 1; no note starts before the music does, and the music lasts as long as before.

      feel(groove(), step: 0.25, push: [0, 0.035, 0, 0.035], lean: [1, 0.7, 0.85, 0.7])

      iex> beats(feel(seq(c4: 1, e4: 2), step: 0.25, push: [0, 0.03]))
      3
  """
  defdelegate feel(music, opts), to: Mx.Music

  @doc """
  The music with the parts named left out, one name or a list: each plays nothing there, and leaves a silence as long as it played, so every other part plays as before.
  A tempo change written in a part left out stays, and a part that plays a loop until the music beside it ends is left out with its loop.
  A name that no part of the music has is refused.

      # The mambo without the cáscara, which the bell takes over.
      without(band(), :cascara)

      iex> beats(without(together([part(:kick, steps("x...", 1)), part(:bass, note(:c2, 4))]), :kick))
      4
  """
  defdelegate without(music, names), to: Mx.Music

  @doc """
  The music with every part but those named left out, one name or a list, as `without/2` leaves them out.

      only(band(), [:kick, :bass])

      iex> beats(only(together([part(:kick, steps("x...", 1)), part(:bass, note(:c2, 4))]), :kick))
      4
  """
  defdelegate only(music, names), to: Mx.Music

  @doc """
  Music lasting some beats whose items start at their beats from its start, given as `{beat, music}`, so strokes at known beats need no rests between them.
  A note can be written as `{beat, pitch, length}`, the pitch anything `note/3` takes, or as `{beat, pitch, length, options}` with options of its own.
  A note of length 0 is struck: it takes no time and rings out by its own sustain, as `note/3` plays it.
  An item placed at or past the length is refused, and so is a note of a length below 0.

      # The son clave, 3-2, over two bars of four beats.
      clave = for beat <- [0, 1.5, 3, 5, 6], do: {beat, steps("x", 0)}
      at(clave, 8)
      at([{0.5, note(:c4, 0.5)}, {1.5, note(:e4, 0.5)}], 2)
      at([{0.5, :c4, 0.5}, {1.5, :e4, 0.5, vel: 0.9}], 2)

      iex> beats(at([{0.5, note(:c4, 0.5)}], 2))
      2
  """
  defdelegate at(entries, beats), to: Mx.Music

  @doc """
  Music lasting some beats with, at each beat of the entries given as `{beat, value}`, the music the function returns for the value.
  Given options instead of a function, it gives them to each note written as `{beat, pitch, length}`; a note's own options are kept over them, and music placed as `{beat, music}` takes none.

      # A fill, each stroke at its beat and its level.
      at([{0, 0.4}, {1.5, 0.8}, {3, 1}], 4, fn vel -> hit(vel: vel) end)

      # A line at one level, its last note louder.
      at([{0, :c4, 1}, {1, :e4, 1}, {2, :g4, 2, vel: 0.9}], 4, vel: 0.6)

      iex> beats(at([{0, 0.4}, {1.5, 0.8}], 4, fn vel -> hit(vel: vel) end))
      4
  """
  defdelegate at(entries, beats, fun_or_options), to: Mx.Music

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

  A word after `>` is accented by `accent:`: a number is added to the sound's vel, up to 1, and a list of options takes the place of the sound's options of the same names.

      steps(~MX"f >f f f", 0.25, strokes: [f: [vel: 0.5]], accent: 0.3)

  `words:` gives words their pitches, as `words: [S: :d4, R: :e4]`; such a word is a note, looked up after `strokes:` and before a note's name.

  A word after `^` is a grace note, which takes no step and starts `grace:` beats before the word after it, 0.06 unless given; a pattern with one is the words together with its grace notes.

      steps(~MX"b5 ^d6 c6 b5", 0.5, grace: 0.08)

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
  A change to every sound of a part still playing, or, given `{part, effect}`, to one of the part's effects, or, given `{:song, effect}`, to one of the song's own, at its beat, taking no time; `{bus, effect}` reaches an effect of a bus, and `send: [tape: 1]` moves the part's send into a bus, over `send_slide:` beats when given.
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
  Music played by one player: `synth:` names its synth, `:tri` by default, `fx:`, `defaults:` and `midi:` are taken as a loop takes them, and `send:` gives the level it sends at into each of the song's buses, as `send: [room: 0.2]`.
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
  The song, which a song file ends with: its `music:`, its `tempo:`, 60 by default, its `meter:`, the whole beats to a bar, 4 by default, its `key:`, such as `:em`, none by default, its `fx:`, the effects every part plays through after its own, written as a part's, its `buses:`, the chains of effects its parts send into, as `buses: [room: [reverb: [decay_seconds: 2.3]]]`, and `live_audio:`, `osc_to:` and `osc_from:`.

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
      [
        %{tokens: ["9"], steps: 1, char: true},
        %{tokens: [], steps: 1, char: true},
        %{tokens: ["x"], steps: 1, char: true}
      ]

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
  The number of a note name, given as an atom or as text, or the number itself.

      iex> pitch(:e5)
      76
      iex> pitch("c4")
      60
      iex> pitch(:fs3)
      54
      iex> pitch(60)
      60
  """
  defdelegate pitch(pitch), to: Mx.Music

  @doc """
  The notes of a chord, from a root note given as a name or a number, or from a chord's name as a chart writes it, such as `"C#dim7"`, its root the lowest of its letter at or above `from:`.

      iex> chord(:c4, :major)
      [60, 64, 67]
  """
  defdelegate chord(root, name), to: Mx.Notes

  @doc """
  The chord written at a beat of a chart, a `~MX` pattern of chord names read a word to every `step` beats; a beat past the chart's end goes round to its start, and two charts joined with `++` read as one.

      iex> chord_at(~MX"D7 G Am:1/2 C#dim7:1/2", 2, 5)
      "C#dim7"
  """
  defdelegate chord_at(chart, step, beat), to: Mx.Notes

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
