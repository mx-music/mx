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
  * [mx] `mx play` plays or renders a score, a MIDI file or an ABC tune as the song `mx import` would write, without writing it, and `Mx.Import.load/2` gives that song to a session
  * [mx] `mx play --render` takes `--no-ring-out`, which ends the file where the music ends
  * [mx] `mix mx.measure --hits` splits a file of several hits given its first note into the notes of its run, as `mix mx.fit` does, names each hit by its note, and with `--synth` renders the synth at each of them
  * [mx] A sampled instrument of a list of files is named by the folder its files share, and the page data names a part that plays only samples by its samples

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

  * [mix mx.import] Join a tie between voices to the note it ties into
  * [mix mx.import] Write a long order of bars in full

### 3. Backwards incompatible changes

  * [Mx.Music] Name a sample as `{collection, name}`, as in `sample({:sonic_pi, :bd_haus}, 1)`, instead of by its name alone
  * [Mx] Name a sampled instrument as `{collection, path}`, as in `sampled({:vcsl, "Idiophones/Plucked Idiophones/..."})`, instead of by a path that starts with the collection's folder

## v0.1.0 (2026-11-14)

Initial release.
