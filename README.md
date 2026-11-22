# mx

mx is a library for writing music in Elixir.
You write a song as a file, and mx plays it and applies your changes each time you save.
It makes sound with mxs, its own sound engine in Rust.

## A song

A song is an Elixir file that starts with `import Mx` and ends with `song`:

```elixir
import Mx

bar = fn bass, chord -> together([note(bass, 3), delay(note(chord, 2), 1)]) end
left = seq([bar.(:g2, [:b3, :d4, :fs4]), bar.(:d2, [:a3, :cs4, :fs4])])

melody = seq(r: 1, fs5: 1, a5: 1, g5: 1, fs5: 1, cs5: 1, b4: 1, cs5: 1, d5: 1, a4: 3, fs4: 12)

room = [reverb: [decay_seconds: 1.2, mix: 0.15]]

song(
  tempo: 72,
  music:
    repeat(
      together([
        part(:right, melody, synth: :piano, fx: room, defaults: [vel: 0.5, pedal: 1]),
        part(:left, repeat(left, 4), synth: :piano, fx: room, defaults: [vel: 0.3, pedal: 1])
      ])
    )
)
```

It sounds like this:

https://github.com/user-attachments/assets/805f6f99-ce9b-4ed4-ad7e-0418e647a440

It is the opening of Erik Satie's first Gymnopédie, of 1888.
`note` plays a pitch or a chord for a number of beats, `seq` plays notes one after another, and `together` starts its items at once.
In each bar of the left hand, `delay` starts the chord a beat after the bass note.
`part` gives music to a synth, through effects, and `repeat` plays the whole again until mx stops.
[From a note to a song](documentation/first_song.md) builds a first song in eight steps, and [the cheatsheet](documentation/cheatsheet.cheatmd) shows everything a song can say on one page.

Play the file with the `mx` command, which [Install](#install) sets up:

```sh
mx song.exs
```

mx plays the song until it ends or you press Enter.
Save the file while it plays and the new version takes over at the end of the section playing.
A version that does not load prints its error, and the previous version keeps playing.

`--record session.wav` records what you play to a WAV file, and `--render song.wav` writes the song to a WAV file without playing it.
[Playing, recording and rendering](documentation/playing.md) describes both.

## Longer pieces

The same notation writes whole pieces.
Each video plays a song in `examples` from start to end, as mx renders it, over its spectrogram.

Debussy's Clair de lune on mx's piano, a synth, from [examples/piano/clair_de_lune.exs](https://github.com/mx-music/mx/blob/main/examples/piano/clair_de_lune.exs):

https://github.com/user-attachments/assets/e2256f68-cba3-40c1-8166-ebf1c1a65c81

An afrobeat groove mixed as a dub, with a sampled drum kit and keyboard over mx's double bass, from [examples/afrobeat.exs](https://github.com/mx-music/mx/blob/main/examples/afrobeat.exs):

https://github.com/user-attachments/assets/be2f2355-f117-4eef-b5e1-bc5c2be42f02

## Install

mx needs Elixir 1.20 or later, installed as https://elixir-lang.org/install.html describes.
Then install the `mx` command:

```sh
mix escript.install hex mx
```

Mix installs it in `~/.mix/escripts`, which needs to be on your `PATH`.
It downloads mxs already built for macOS, for Linux on x86_64 or ARM64, and for Windows on x86_64; elsewhere it needs Rust, which compiles mxs the first time mx is built.

```sh
mx song.exs
mx export song.exs
mx help export
```

`mx song.exs` is short for `mx play song.exs`, `mx` alone lists the commands, and `mx help NAME` prints a command's documentation.

## Instruments

mx's synths and effects are its own designs.
Beside the basic waveforms, most synths imitate a real instrument and were fitted to recordings of it: piano, guitar, the bowed strings, the winds, mallet instruments, and percussion.
[Instruments](documentation/instruments.md) lists every synth and effect with its options, and shows how to write a synth.

A song also plays recordings: single sound files, and sampled instruments made from folders of recordings, one file for each key.
A recording is a file of your own, or comes from a collection mx knows by name and downloads into your cache:

```elixir
sample({:sonic_pi, :loop_amen}, 4, beats: 4)
sampled({:vcsl, "Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B"})
```

The collections are Sonic Pi's sample pack, the Versilian Community Sample Library, VSCO 2, the Salamander piano, Virtuosity Drums, a mridangam, and instruments of FreePats and Karoryfer.
Any other public GitHub repository of recordings plays the same way, named by its repository.
[The notation](documentation/notation.md#collections) lists the collections, and the songs in `examples/sample_packs` play them.

Sonic Pi's pack, of 35 MB, is downloaded once before a song plays it:

```sh
mx samples download sonic_pi
```

## Scores and hums

mx can start a song from music that already exists.
`mx import` turns a MusicXML score into a song, `mx export` writes a song as one, and `mx hum` turns a recording of a melody you hum, sing or whistle into a song:

```sh
mx import score.mxl --tempo 72 --part "Soprano=oboe"
mx import score.mxl --recording performance.wav --part "Soprano=oboe"
mx export song.exs --time 6/8 --key d
mx hum hum.wav --tempo 90
```

`--recording` takes the timing and loudness of a recording of the score, as Marian Anderson's recording of Bach's "Erbarme dich" does for the aria in `examples/erbarme_dich`.
[Scores and hums](documentation/scores.md) describes the four commands.

## Live input and output

A song reads MIDI and OSC inputs, sends MIDI and OSC, and plays live audio through its effects.
A `loop` works its music out again on every pass, so what it plays can follow an input.
[The notation](documentation/notation.md) describes each.

## Examples

The folder `examples` in the repository holds more songs: pieces for a band, such as a salsa, a choro, a dub and three ragas, and solos for single instruments.
`examples/ambient.exs` is a demo to start from.
[Examples](documentation/examples.md) describes each one.

## In a Mix project

To use mx from Elixir code, add it to the dependencies in your Mix project's `mix.exs`:

```elixir
{:mx, "~> 0.2.2"}
```

Each `mx NAME` command is then also the Mix task `mix mx.NAME`, with a dot for each space, such as `mix mx.samples.download` for `mx samples download`, and takes the same arguments: `mix mx.export song.exs` writes what `mx export song.exs` writes.

A checkout of mx always compiles mxs with Rust, and `mix mx.play path/to/song.exs` run in it plays a song with the checkout's code.

## Guides

Read the first two to start, and the others when you need them.

- [From a note to a song](documentation/first_song.md): one song built in eight steps, each a file to play.
- [Cheatsheet](documentation/cheatsheet.cheatmd): everything the notation can do, a line of code for each.
- [Playing, recording and rendering](documentation/playing.md): `mx play` and its options.
- [The notation](documentation/notation.md): every function a song is written with.
- [Instruments](documentation/instruments.md): the synths and effects with their options, how to write a synth, and how to measure one against recordings.
- [Scores and hums](documentation/scores.md): importing a MusicXML score, and turning a hummed melody into a song.
- [Examples](documentation/examples.md): the songs in `examples`.
- [Architecture](documentation/architecture.md): how a song file becomes sound.
- [Working on mx](documentation/development.md): the tests and the lint script.

## License

mx is under the MIT License, in [LICENSE](https://github.com/mx-music/mx/blob/main/LICENSE).
[LICENSE-designs.md](https://github.com/mx-music/mx/blob/main/LICENSE-designs.md) names the recordings each synth was measured from, the two effects that follow Airwindows, and the recordings the examples play, with their terms.
Sample packs are not part of mx: Sonic Pi's samples, under Creative Commons 0, and the others are downloaded from their own sources, under their own licenses.

## Acknowledgements

Mx's early design was inspired by [Sonic Pi](https://sonic-pi.net) by Sam Aaron and contributors.
Mx's API has since evolved in its own direction, but the debt is real — thank you.
The recordings mx's synths are measured from are credited in [LICENSE-designs.md](https://github.com/mx-music/mx/blob/main/LICENSE-designs.md).
