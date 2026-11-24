# Changelog for mx v0.2

## Unreleased

### 1. Enhancements

  * [songs] Add buses, effect chains that parts share: declare them with `buses:` or `bus/2`, send into them with `send: [room: 0.2]`, and move a send with `change/2`
  * [songs] `song/1` and `use Mx.Song` take `fx:`, effects every part plays through after its own, and `meter:` and `key:`, which `mix mx.export` writes into the score
  * [songs] Add `form/3` to play sections by name and count, `without/2` and `only/2` to leave parts out, and `seq/2`, `together/2` and `at/3` forms that build music from a collection and a function
  * [songs] Add `slur/2` for notes joined into one gliding note, `held:` for the share of a note that sounds, `each/2` for options on every note, and `feel/2` for a groove's timing and accents
  * [songs] Add `kit/2` to declare a drum kit of named parts in a module that uses `Mx.Song`, and `chord_at/3` to read a chord chart such as `"D7 G Am:1/2"`
  * [songs] `~MX` patterns take accents with `>`, lengths as fractions such as `g4:1/3`, and grace notes with `^`; `at` takes notes as `{beat, pitch, length}`; `scale` takes `from:` and `to:`, and `degree/3` gives a scale degree
  * [effects] Add `eq`, `limiter`, `phaser`, `wah` and `width`, and a new `reverb` that models a room by its size and decay time
  * [effects] `compressor` works in dB and follows another part with `key:`, so a pad can duck under the kick
  * [effects] `echo` and `ping_pong` dull each repeat as tape does, `distortion` adds only harmonics of the note, and `tremolo` and `slicer` move across the stereo field with `spread`
  * [effects] `defeffect` processes both stereo sides together and declares its tail with `tail/1`, and `defsynth` gains `saturate/2`, `clip/2`, `fold/2` and `ladder/2`
  * [instruments] `envelope` in a `defsynth` takes `every:`, the seconds after which it starts over, so a tremolo picks a note again without building its fades from arithmetic
  * [examples] Add `examples/effects`, a short song for each effect that plays a phrase dry, then through the effect, then with one option moved at a time
  * [synths] Add `deep_bass`, and alpha versions of `electric_piano` and `electric_guitar` that will be refitted
  * [synths] `pandeiro` is refitted to recordings of its thumb, heel and slap, with jingles that answer the hand, `muted` strokes that sound as its pressed head does, lighter and drier fingertips, a quieter heel and no two strokes alike, and its solo plays the choro's pandeiro line; `ganza`, `clave`, `guiro`, `berimbau`, `cuica`, `triangle` and the tabla's tas stroke sound closer to their recordings
  * [synths] `Mx.Synths.family/1` and `range/1` give each synth's family and playable range
  * [mix mx.play] Play or render a score, a MIDI file or an ABC tune directly, without importing it first
  * [mix mx.play] A render reports its loudness in LUFS, and `--loudness` scales it to a target
  * [mix mx.play] `--render` takes `--mute`, `--solo`, `--ring-out` and `--no-ring-out`, and prints its progress
  * [mix mx.play] Choose the audio device with `--output`, `--input`, `--rate` and `--buffer`, and list devices with `mix mx.devices`
  * [mix mx.import] MIDI tempo changes import into the song and export back out, and an import counts what it left out, such as ornaments, lyrics and pedal presses
  * [mix mx.measure] Measure in native code, about ten times faster; `--partials` follows each partial of a struck note, and `--hits` splits a run of hits and reports how bright each one is over time
  * [mix mx.fit] Add `--struck` to fit a synth to recordings of struck notes, `--check` to compare the synth with them and name the 50 ms furthest off, `--top` to fit above 8 kHz, and `--tour` to write recordings and synth side by side for listening
  * [package] The Hex package and each release include THIRD_PARTY_NOTICES.md with every bundled dependency's licence

### 2. Bug fixes

  * [songs] A song file loaded twice at once no longer fails with "is currently being defined"
  * [effects] `slicer`, `tremolo`, `wobble`, `flanger` and `phaser` stay on the beat, where they drifted 4 ms a minute; renders that use them change
  * [effects] A change to a handful of effect options that were ignored mid-song is now heard
  * [instruments] `delay` and `clamp` work inside a `defsynth`, `defeffect` or `defsound` in a song module, where they failed with "conflicting delay/2 import"
  * [instruments] A `defeffect` whose input is multiplied by 0 plays, where the part restarted without end
  * [render] A part whose effects cannot start ends the render with an error naming them, where it restarted without end

### 3. Backwards incompatible changes

  * [effects] `reverb` is replaced and its `room` option is gone; it takes `size`, `decay_seconds`, `predelay_ms`, `low_cut` and `damp`
  * [effects] `compressor` takes `threshold` and `makeup` in dB and a `ratio`, in place of `slope_above` and `slope_below`
  * [effects] Times in milliseconds name their unit: `smooth_ms`, `delay_ms`, `depth_ms`, `max_delay_ms`, `clamp_ms` and `relax_ms`
  * [songs] `each/2` gives a note a `sustain:` from its options, where the note's length was kept
  * [songs] A song can no longer define its own `seq`, `together`, `at`, `form`, `without`, `only`, `kit`, `each`, `feel`, `slur` or `chord_at` at the same arity, and no part can be named `song`
  * [samples] A sampled instrument made from a list of files is named after their shared folder

## v0.2.2 (2026-11-16)

### 1. Enhancements

  * [package] Download mxs already built for macOS, Linux and Windows, so installing mx from Hex no longer needs Rust
  * [package] Add the `mx` command as an escript, installed with `mix escript.install hex mx`

### 2. Backwards incompatible changes

  * [mix mx.scan] Remove reading a scanned score, with `Mx.Scan`, `Mx.Transcriber`, `Mx.Audiveris`, `Mx.ABC` and the optional vix and pythonx dependencies

## v0.2.0 (2026-11-16)

### 1. Enhancements

  * [songs] Accept one written length per note of a chord in `record_play/3`
  * [samples] Add the collections of recordings mx knows by name, such as `:sonic_pi`, `:vcsl` and each of Karoryfer's and FreePats' instruments
  * [mix mx.export] Add a task that writes a song as a MusicXML score
  * [mix mx.import] Keep the grace notes that lead into a note as its `graces`
  * [mix mx.import] Keep the `staff` each note is written on
  * [mix mx.levels] Add a recording's levels over time, by octave and brightness, and its strokes
  * [mix mx.levels] Add a task that prints a recording's levels over time, or its strokes, as comma-separated values
  * [mix mx.parts] Add what a note of the piano is made of, worked out without playing it
  * [mix mx.parts] Add a task that prints what a note of the piano is made of
  * [mix mx.samples.download] Accept a collection mx knows by name as the source, as in `vcsl:Idiophones/Struck Idiophones/Agogo Bells`
  * [mix mx.spectrogram] Add `--width` and `--no-seconds`, and work out the columns in native code
  * [mix mx.video] Add a task that makes a video of a recording over its waveform or spectrogram
  * [mix mx.waveform] Add a task that draws the waveform of a recording into an image

### 2. Bug fixes

  * [songs] An option of a note, an effect or a change given a value it cannot take is refused when the song loads, naming the part and what the option takes: a name or a string where it takes a number, or a number outside an effect's range; before, such a song rendered silence, never finished, or stopped with no line
  * [effects] `change/2` moves an effect's `decay`, as of an echo; before, it was refused as a note's `decay` is, with "decay cannot change once a sound plays"
  * [render] A song file that defines an effect with `defeffect` renders with `mx play --render`; before, the render stopped with "no effect named" it
  * [mix mx.import] Join a tie between voices to the note it ties into
  * [mix mx.import] Write a long order of bars in full
  * [docs] The guide Instruments lists `pitch_shift`, which it left out

### 3. Backwards incompatible changes

  * [samples] Name a sample as `{collection, name}`, as in `sample({:sonic_pi, :bd_haus}, 1)`, instead of by its name alone
  * [samples] Name a sampled instrument as `{collection, path}`, as in `sampled({:vcsl, "Idiophones/Plucked Idiophones/..."})`, instead of by a path that starts with the collection's folder

## v0.1.0 (2026-11-14)

Initial release.
