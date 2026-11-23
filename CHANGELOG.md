# Changelog for mx v0.2

## Unreleased

### 1. Enhancements

  * [notes] `scale` takes `from:` and `to:` for every note of the scale in a range, and a kind given as its steps from the root, fractions among them; `degree(root, kind, number)` is the pitch so many steps of a scale from its root; `scale` refuses an option it does not take
  * [music] `slur` takes rests, each ending the note sounding and starting a new one after it, and `tongue:`, a function of the beat, the pitch before and the pitch that starts a new note where it returns true
  * [music] A note takes `held:`, the share of its length it sounds for, as its sustain: on a note, in a part's `defaults:`, in `each`, and in the options of `steps`, `kit` and `at`, each note in a pattern taking a share of its own length; a note's own `sustain:` is kept over a `held:` given around it, and a note given both, a `held:` not above 0 and a hit given one are refused
  * [music] `each` gives a note a `sustain:` it does not give, where before the note's length was kept
  * [music] `at` places a note written as `{beat, pitch, length}`, or `{beat, pitch, length, options}` with options of its own, and `at(entries, beats, options)` gives options to every such note; a note's own are kept over them, and music placed as `{beat, music}` takes none
  * [effects] Add `wah`, from the next mxs: a resonant low-pass that opens on each note, further the harder it is played, and closes as the note fades, between the notes `cutoff_min` and `cutoff_max`, with `sensitivity` in dB, `clamp_ms`, `relax_ms` and `res`; its song is `examples/effects/wah.exs`
  * [effects] Add `width`, from the next mxs: `side` narrows a part to mono at 0 and widens it up to 2, twice the difference between its sides, and `mono_below` puts everything below a MIDI note in the centre; its song is `examples/effects/width.exs`
  * [effects] `tremolo` and `slicer` take `spread`, from the next mxs: the right side's cycle runs that share of half a cycle after the left's, so at `spread: 1` a tremolo moves the sound from side to side and a slicer sounds on one side at a time
  * [effects] `distortion` adds only harmonics of the note, from the next mxs: a saw at C7 driven hard had energy 20 dB under it at pitches that are not its harmonics, and has it 50 dB under; it takes `curve: :hard`, which cuts the sound off flat, and `tone`, a MIDI note for a low-pass after it
  * [effects] `echo` and `ping_pong` take `high_cut`, `low_cut` and `drive`, from the next mxs: each echo is cut above and below the two notes and rounded off once more than the one before, as a tape echo's repeats grow duller, and `examples/dubwise.exs` wears its tape so
  * [effects] `phaser` given no `mix` is half dry, where its notches are deepest
  * [effects] Add `phaser`, from the next mxs: `stages` all-pass filters sweep one notch for every two between the notes `low` and `high` once every `phase`, deepest at `mix: 0.5`, with `feedback` and `stereo_invert_wave`; `examples/dubwise.exs` plays its hi-hat through it
  * [mix mx.play] A render reports the file's loudness beside its peak, as `peaking at -1.0 dB, loudness -14.2 LUFS`, the integrated loudness of ITU-R BS.1770, and `--loudness -14` scales the finished file to a loudness, no further than a peak of -1 dB
  * [effects] `reverb` is a new reverb, from the next mxs: a room of `size` metres whose sound fades 60 dB in `decay_seconds`, starts after `predelay_ms`, is cut below the note `low_cut` and dulled by `damp`, and is louder on the side its sound is on. The reverb it replaces and its `room` option are gone, and every example is rewritten to the new options
  * [effects] `compressor` takes `threshold` in dB, -18 unless given, `ratio`, 4 unless given, and `makeup` in dB, in place of a threshold as a plain level, `slope_above` and `slope_below`, from the next mxs; it follows the louder side and turns both down alike, lets go over 150 ms unless `relax_ms` says otherwise, and with `key: :kick` follows the level of another part or bus, so a pad drops under each kick
  * [mx] Add buses, chains of effects that parts share: a song declares them with `buses: [room: [reverb: [room: 0.7]]]`, or `bus :room, fx: [reverb: [room: 0.7]]` in a module, and a part sends into them with `send: [room: 0.2]`; a bus sends into other buses, `change(:tom, send: [tape: 1])` moves a send while the song plays, over `send_slide:` beats when given, `change({:room, :reverb}, room: 0.9)` reaches an effect of a bus, `mx print` lists buses and sends, and a render's ring-out counts them
  * [examples] `examples/dubwise.exs` shares one room and one tape echo between its parts through buses, at the levels it had
  * [mx] A song takes `fx:`, as in `song(tempo: 104, fx: [limiter: [ceiling: -1]], music: music)` and `use Mx.Song, tempo: 104, fx: [limiter: []]`: every part and live audio plays through those effects after its own, `change({:song, :limiter}, ceiling: -3)` changes one of them, a render's ring-out counts them, and a part can no longer be named `song`
  * [mx] Add the effect `limiter`, from the next mxs, which holds every peak under `ceiling`, in dB below full scale, and lets the sound back up over `relax_ms`; it delays its sound by 5 ms, and its song is `examples/effects/limiter.exs`
  * [mx] Add the effect `eq`, an equaliser of three bands, each a list of its own options, as in `fx: [eq: [low: [at: 48, gain: -6], mid: [at: 72, gain: 4, q: 2]]]`: `low` and `high` raise or lower everything below or above `at`, a MIDI note number, by `gain` in dB, and `mid` a peak around it as narrow as `q` says; a change names the band the same way, and `examples/effects/eq.exs` is its song
  * [mx] `defeffect` takes both sides as `{left, right}` and returns both, so one side can reach the other; `tail/1` says how long an effect sounds on after its input stops, in seconds or as long as one of its options says; and `sweep/1`, `follower/2`, `allpass/2` and `lag/2` join the nodes of a `defeffect` and a `defsynth`
  * [effects] An effect's time that is not in beats names its unit, from the next mxs: slicer's `smooth` is `smooth_ms`, flanger's `delay`, `depth` and `max_delay` are `delay_ms`, `depth_ms` and `max_delay_ms`, and compressor's `clamp_time` and `relax_time` are `clamp_ms` and `relax_ms`, all in milliseconds; a `defeffect` declares such an option with `attr :gap_ms, :ms`
  * [examples] Add `examples/effects`, a short song for each effect that plays one phrase dry, then through the effect as it comes, then with one option moved at a time, and `order.exs`, which plays two effects in both orders
  * [synths] Add `deep_bass`, a darker bass played with the fingers, from mxs 0.1.2, with its solo `examples/solo/deep_bass.exs`
  * [synths] Add alpha versions of `electric_piano` and `electric_guitar`, from mxs 0.1.2, with their solos; both will be refitted
  * [mix mx.measure] Measure in native code, with the same figures in a tenth of the processor time or less, and strokes in a twentieth of the memory; `mix mx.fit` and `mix mx.hum` measure the same way
  * [mix mx.measure] Add `--partials` for plucked and struck notes, following each partial, harmonic or not, every 2.5 ms, printing how it falls and naming the lines left out as not the instrument's
  * [mix mx.fit] Add `--struck`, which fits a folder of struck notes partial by partial into figures for mxs with `--out`, and with `--check` compares a synth with each recording partial by partial and in ERB bands
  * [mix mx.fit] `--struck` takes a list of recordings with their notes and velocities, splits runs of notes into single notes, leaves out notes that sound away from their names, fits a drum given in Hz, follows each note for as long as it rings up to 28 seconds, and can be given more than once
  * [mix mx.fit] Add `--tour`, which writes each of a spread of recordings followed by the synth, for listening, and `--check` prints each velocity's loudness for recordings that keep their levels
  * [mix mx.import] A MIDI file's tempo changes play in the song at their beats, instead of being left out; `--tempo` still keeps one tempo, naming each change left out
  * [mix mx.export] A MIDI file written holds the song's tempo changes
  * [mix mx.import] Count what an import leaves out: a score's syllables of text, slurs, trills and other ornaments, fermatas, grace notes and articulations, and a MIDI file's drum notes, presses of the sustain pedal and other controller messages; `Mx.Score` gives the same as `left_out_counts`
  * [mix mx.play] `--render` prints its progress about four times a second, as the seconds of music rendered and the seconds it renders in all
  * [mx] `song/1` takes `meter:`, the whole beats to a bar, 4 unless given; the page data holds it and `mix mx.export` writes it as the time signature when `--time` is not given
  * [mx] `Mx.Session.play_recording/4` plays a range of a recording on a part that plays, through its effects, without writing anything, and `Mx.Engine.Mxs.play_recording/2` plays one with no song
  * [mx] `mix mx.play` takes `--output`, `--input`, `--rate` and `--buffer`, also set by `config :mx`, and `mix mx.devices` lists the devices and what each takes
  * [mx] `Mx.MIDI.played/1` gives a MIDI file's notes as they were played, part by part, each with its beat and length in quarter notes unmoved by any grid
  * [mx] `Mx.Score.about/1` says what a score or a MIDI file holds besides its notes: a score's meter as written, key, tempo marking, upbeat, bars, staves and marks such as a segno or "Fine", and a MIDI file's tracks, tracks with notes, ticks to a quarter note, meter, key and each tempo with its bar
  * [mx] A `defsynth` saturates, clips and folds a sound with `saturate/2`, `clip/2` and `fold/2`, filters it through a four-pole `ladder/2`, glides a filter's `q:`, and takes `dc_block/2`'s `hz:`
  * [mx] `mx play` plays or renders a score, a MIDI file or an ABC tune as the song `mx import` would write, without writing it, and `Mx.Import.load/2` gives that song to a session
  * [mx] `mx play --render` takes `--no-ring-out`, which ends the file where the music ends
  * [mx] `mx play --render` takes `--mute` and `--solo`, each naming a part, and `Mx.Render.render/3` takes `mute:` and `solo:`, so a render holds what a session that mutes and solos those parts plays
  * [mx] A render says which part's effect it cuts short as the last notes fade, `--ring-out` keeps that ring, and `Mx.Render.ring_out/2` says how long it lasts before a render starts
  * [mx] `mix mx.measure --hits` splits a file of several hits given its first note into the notes of its run, as `mix mx.fit` does, names each hit by its note, and with `--synth` renders the synth at each of them
  * [mx] A sampled instrument of a list of files is named by the folder its files share, and the page data names a part that plays only samples by its samples
  * [Mx.Synths] `family/1` and `range/1` give each synth's family, such as `:winds`, and the lowest and highest notes it is meant to play, from mxs 0.3.0
  * [mx] `song/1` and `use Mx.Song` take `key:`, such as `:em`, which the page data holds and `mix mx.export` writes the score in when `--key` is not given
  * [mx] The Hex package holds THIRD_PARTY_NOTICES.md, the Rust crates built into mxs_nif and the Elixir packages mx runs with, each with its version and licence, and the licence texts; each release attaches it too
  * [mx] `seq/2` and `together/2` take a collection and a function that makes each item, and `at/3` a list of `{beat, value}` and a function that makes the music at each beat
  * [mx] In a module that uses `Mx.Song`, `together/1` takes declared parts by name, as `together(lead: tune(), bass: bass())`
  * [mx] `form/3` plays a song's sections from a list of names and counts, giving the function each section's name, or its name with its `pass`, `time` and `coming`
  * [mx] `without/2` and `only/2` leave parts out of some music, each as long a silence as it played, its tempo changes kept
  * [mx] A `~MX` pattern accents a word with `>`, which `steps/3` plays as its `accent:` says, takes a length as a fraction such as `g4:1/3`, and plays a word after `^` as a grace note `grace:` beats before the next
  * [mx] `steps/3` takes `words:`, which gives words their pitches, and `pitch/1` takes a note's name as text
  * [mx] In a module that uses `Mx.Song`, `kit/2` declares a kit of strokes, each played by a declared part, and `kit/3` and `kit/4` play one pattern on all of them
  * [mx] `each/2` gives every note and hit of some music options it does not give itself, or those a function of its beat returns
  * [mx] `feel/2` plays a groove's feel as tables of how late and how loud each step comes, with `loose:` and `touch:` for a little randomness that is the same on every load
  * [mx] `slur/2` plays notes one after another as one note whose pitch changes while it sounds, as `~` writes in a pattern, gliding over `slide:` beats or what a function of the two pitches returns
  * [mx] `chord_at/3` reads a chart, a `~MX` pattern of chord names such as `"D7 G Am:1/2 C#dim7:1/2"`, at a beat, going round past its end, and `chord/2` takes a chord's name with `from:`, its root the lowest of its letter at or above that pitch
  * [mx] A song that defines a function of its own named `seq`, `together`, `at`, `form`, `without`, `only`, `kit`, `each`, `feel`, `slur` or `chord_at`, at the arity of one of those above, no longer compiles, and must rename it; four examples renamed a `kit` helper to `drums`, and four a `slur` helper to `legato` or `in_slur`
  * [measure] `mx measure --hits` prints how bright the hits are over time: the sound above 1, 2, 4 and 8 kHz in dB under the whole sound, from 0 to 20, 20 to 80 and 80 to 200 ms after the hit starts, and when the sound above 4 kHz is loudest, beside the synth's with `--synth`; then that sound's level at seven times from 5 to 320 ms after the hit starts, under its loudest; `Mx.Measure.Hits` gives them as `brightness`, `highs_peak` and `highs`
  * [fit] `mx fit --struck` takes `--top`, a frequency in Hz up to which it follows the partials and fits the strike's noise, where it stops at 8 kHz without it
  * [fit] `mx fit --check` names the 50 ms furthest off in ERB bands, the note it is in and where it starts, for `--struck` and `--held`

### 2. Bug fixes

  * [songs] A song file loaded twice at once loads both times, where the second could fail saying its module "is currently being defined", or warn that it redefined the module
  * [effects] A sweep stays on the beat for as long as it runs, from mxs 0.6.4: `slicer`, `tremolo`, `wobble`, `flanger` and `phaser` fell 4 ms behind for every minute they ran at a cycle of half a second, and a slicer's pulse is now on its beat after four minutes; a render with a sweep has other samples than before
  * [instruments] A `defsynth`, `defeffect` or `defsound` below `import Mx`, or in a module that uses `Mx.Song`, calls the `delay` and `clamp` nodes, where the file stopped with "conflicting delay/2 import"; outside them the names keep Mx's meaning
  * [instruments] A `defeffect` whose input is multiplied by 0, as in `sound * opts.wet + sound` at a `wet` of 0, or is in the side a `select` leaves out, plays the rest, where the part failed and started again without end
  * [effects] A change to slicer's `smooth_ms`, to flanger's `invert_flange` and `stereo_invert_wave`, to wobble's `filter`, to ping_pong's `pan_start`, or to the `phase_offset` of slicer, tremolo, flanger and wobble is heard from where it is written, where the song loaded and the sound stayed as it was
  * [render] A render whose part cannot start its effects ends with an error naming the part and the effect, where it started the part again without end

## v0.2.2 (2026-11-16)

### 1. Enhancements

  * [mx] Download mxs already built for macOS, Linux and Windows, so installing mx from Hex no longer needs Rust
  * [mx] Add the `mx` command as an escript, installed with `mix escript.install hex mx`

### 2. Backwards incompatible changes

  * [mix mx.scan] Remove reading a scanned score, with `Mx.Scan`, `Mx.Transcriber`, `Mx.Audiveris`, `Mx.ABC` and the optional vix and pythonx dependencies

## v0.2.0 (2026-11-16)

### 1. Enhancements

  * [Mx.Collections] Add the collections of recordings mx knows by name, such as `:sonic_pi`, `:vcsl` and each of Karoryfer's and FreePats' instruments
  * [Mx.Levels] Add a recording's levels over time, by octave and brightness, and its strokes
  * [Mx.Pass] Accept one written length per note of a chord in `record_play/3`
  * [Mx.Piano] Add what a note of the piano is made of, worked out without playing it
  * [Mx.Score] Keep the grace notes that lead into a note as its `graces`
  * [Mx.Score] Keep the `staff` each note is written on
  * [mix mx.export] Add a task that writes a song as a MusicXML score
  * [mix mx.levels] Add a task that prints a recording's levels over time, or its strokes, as comma-separated values
  * [mix mx.parts] Add a task that prints what a note of the piano is made of
  * [mix mx.samples.download] Accept a collection mx knows by name as the source, as in `vcsl:Idiophones/Struck Idiophones/Agogo Bells`
  * [mix mx.spectrogram] Add `--width` and `--no-seconds`, and work out the columns in native code
  * [mix mx.video] Add a task that makes a video of a recording over its waveform or spectrogram
  * [mix mx.waveform] Add a task that draws the waveform of a recording into an image

### 2. Bug fixes

  * [mx] `change/2` moves an effect's `decay`, as of an echo; before, it was refused as a note's `decay` is, with "decay cannot change once a sound plays"
  * [docs] The guide Instruments lists `pitch_shift`, which it left out
  * [mx] A song file that defines an effect with `defeffect` renders with `mx play --render`; before, the render stopped with "no effect named" it
  * [mx] An option of a note, an effect or a change given a value it cannot take is refused when the song loads, naming the part and what the option takes: a name or a string where it takes a number, or a number outside an effect's range; before, such a song rendered silence, never finished, or stopped with no line
  * [mix mx.import] Join a tie between voices to the note it ties into
  * [mix mx.import] Write a long order of bars in full

### 3. Backwards incompatible changes

  * [Mx.Music] Name a sample as `{collection, name}`, as in `sample({:sonic_pi, :bd_haus}, 1)`, instead of by its name alone
  * [Mx] Name a sampled instrument as `{collection, path}`, as in `sampled({:vcsl, "Idiophones/Plucked Idiophones/..."})`, instead of by a path that starts with the collection's folder

## v0.1.0 (2026-11-14)

Initial release.
