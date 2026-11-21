# Changelog for mx v0.2

## Unreleased

### 1. Enhancements

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
