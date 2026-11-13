# mx

Music written as Elixir code, and changed while it plays.
mx is inspired by Sonic Pi, and makes sound with mxs, its own sound engine in Rust.

## Guides

- [The notation](documentation/notation.md): every function a song is written with, and the names of Sonic Pi's samples.
- [Instruments](documentation/instruments.md): the synths and effects with their options, how to write a synth, and how to measure one against recordings.
- [Scores and hums](documentation/scores.md): importing a MusicXML score, scanning a printed one, and turning a hummed melody into a song.
- [Examples](documentation/examples.md): the songs in `examples`.
- [Architecture](documentation/architecture.md): how a song file becomes sound.
- [Setting up Audiveris](documentation/audiveris.md), for `mix mx.scan`.

## Install

mx needs Elixir and Rust, and a clone of mxs, https://github.com/rodrigues/mxs, in a folder beside mx's:

```sh
git clone https://github.com/rodrigues/mxs ../mxs
```

mx builds mxs into itself when it compiles.
After changing mxs, `mix compile --force` builds it again, since mx does not watch mxs's files.

The `mx` command plays a song file with nothing else installed.
It is the script `bin/mx` in this repository; copy it onto your `PATH`:

```sh
cp bin/mx ~/.local/bin/mx
```

The first time it runs, it installs mx with `Mix.install`, and after that it uses Mix's cache.
Give it a clone of mx, with mxs beside it, as `MX_PATH=~/code/mx mx song.exs`; mx installed from GitHub cannot find mxs.
To play Sonic Pi's samples, download its sample pack once:

```sh
mx samples download sonic_pi
```

The pack is 35 MB, under Creative Commons 0, and goes to your cache folder rather than the repository.
Run the command again to finish an interrupted download.
In a clone of mx, `mix mx.samples.download sonic_pi` does the same.

## Play a song

```sh
mx song.exs
```

mx plays the song until it ends or you press Enter.
Save the file and the new version takes over at the end of the section playing.
A part added to the file joins at the next section, and a part removed from it stops at the end of its pass.
A version that does not load prints its error with the line, and the previous version keeps playing.
`mx` with no song file prints how to use it.
In a clone of mx, `mix mx.play song.exs` does the same, taking the same options.

To keep what you play, record it to a stereo WAV file:

```sh
mx song.exs --record session.wav
```

Recording starts before the first note, carries on without a gap when you save the song, and ends when you press Enter, once the notes still sounding have faded or after four seconds at most.
mx then prints where it wrote the recording, how long it is, and its peak in dB below full scale.
The recording is 32-bit floating point, which keeps a sound louder than full scale, but it distorts once played or converted; when that happens mx says how many times the recording clipped and when it first did, and lowering the amp of the loudest parts records it cleanly.
A file that already exists is refused unless you add `--force`, and so is a path mx cannot write; both are checked before anything plays.

To hear what a song does without playing it aloud, render it to a stereo WAV file instead:

```sh
mx song.exs --render song.wav
```

The render holds what `--record` would, as fast as the machine renders it and with no sound: it starts at the song's first beat and ends once the music has ended and the notes still sounding have faded, or after four seconds at most.
Music that plays until mx stops needs `--seconds`, the length to render, such as `--seconds 60`.
Rendering a song twice writes the same file.
mx prints the same report as for a recording, and refuses a file that exists unless you add `--force`.
A render sends no MIDI or OSC and has no input, so mx names each part that sends MIDI or OSC, or waits for input, and leaves it out.
`--render` cannot go with `--record`, nor with a song that has `live_audio`.

`examples/ambient.exs` is a demo to start from, a slow ambient piece of pads, keys, bells and samples through reverb and echo:

```sh
mx examples/ambient.exs
```

The folder `examples` holds more songs: pieces for a band, such as a salsa, a choro, a dub and three ragas, and solos for single instruments.
[documentation/examples.md](documentation/examples.md) describes each one.

To see what each part plays without hearing it, from a clone of mx:

```sh
mix mx.print song.exs
```

## Write a song

A song is an Elixir file that starts with `import Mx` and ends with `song`:

```elixir
import Mx

melody = seq(e4: 1, g4: 1, a4: 2, g4: 1, e4: 1, d4: 2)
bass = seq(a2: 4, e2: 4)

song(
  tempo: 90,
  music:
    repeat(
      together([
        part(:flute, melody, synth: :flute, fx: :reverb),
        part(:bass, bass, synth: :double_bass)
      ])
    )
)
```

`seq` plays notes one after another and `together` starts its items at once.
`part` gives music to a synth, through effects, and `loop` works its music out again on every pass, from MIDI and OSC inputs if the song reads them.
A song also plays samples and sends MIDI and OSC.
[documentation/notation.md](documentation/notation.md) describes every function.

## Start from a score or a hum

`mix mx.import` turns a MusicXML score into a song, `mix mx.scan` reads a scanned score into MusicXML, and `mix mx.hum` turns a recording of a melody you hum, sing or whistle into a song:

```sh
mix mx.import score.mxl --tempo 72 --part "Soprano=oboe"
mix mx.scan page.pdf
mix mx.hum hum.wav --tempo 90
```

`mix mx.scan` runs Audiveris, which is installed apart from mx.
[documentation/scores.md](documentation/scores.md) describes the three commands.

## Synths, effects and samples

mx's synths and effects are its own designs, in mxs; it ships none of Sonic Pi's.
Beside the basic waveforms, most synths imitate a real instrument and were fitted to recordings of it: piano, guitar, the bowed strings, the winds, mallet instruments, and percussion.
A song also plays the samples of Sonic Pi's pack, sound files, and sampled instruments made from folders of recordings.
[documentation/instruments.md](documentation/instruments.md) lists every synth and effect with its options.

## Tests

```sh
mix test
mix test --only engine
```

The tests tagged `engine` play or render sound through mxs, the design tests among them, and are left out of a plain `mix test`.
The test tagged `timing` sends MIDI and OSC for a minute and checks when they arrive; run it with `mix test --only timing`.
The tests tagged `iowa` measure the University of Iowa's guitar recordings; download the mono guitar files from https://theremin.music.uiowa.edu/MISguitar.html, unzip them, and run `MX_IOWA_GUITAR=folder mix test --only iowa`.
The tests tagged `iowa` also measure the Iowa flute played mf, with and without vibrato, from https://theremin.music.uiowa.edu/MISflute.html, in the folder `MX_IOWA_FLUTE` names, and render mx's flute.
They also fit mx's clarinet to the Iowa Bb clarinet, from https://theremin.music.uiowa.edu/MISBbclarinet.html, in the folder `MX_IOWA_CLARINET` names.
The tests tagged `vsco` measure the cowbell hits of the VSCO 2 Community Edition percussion, from https://github.com/sgossner/VSCO-2-CE; run them with `MX_VSCO_PERCUSSION=folder mix test --only vsco`.
The tests tagged `vcsl` measure the Versilian Community Sample Library, from https://github.com/sgossner/VCSL; run them with `MX_VCSL=folder mix test --only vcsl`, where the folder is the library's root, and they render mx's synths.
The tests tagged `audiveris` scan pages of the Bach-Gesellschaft's St Matthew Passion with Audiveris and take two to three minutes; set it up as documentation/audiveris.md describes and run them with `mix test --only audiveris`.
`scripts/lint.sh` runs credo, the project's style rules, the formatter, ex_dna's check for duplicated code, a check that every public function has a `@doc`, and a check for compile-time cycles; it needs ripgrep.
