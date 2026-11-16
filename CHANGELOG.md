# Changelog for mx v0.2

## v0.2.1 (2026-11-16)

### 1. Enhancements

  * [mx] Download mxs already built for macOS, Linux and Windows, so installing mx from Hex no longer needs Rust
  * [mx] Add the `mx` command as an escript, installed with `mix escript.install hex mx`

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
