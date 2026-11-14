# Playing, recording and rendering

`mix mx.play` plays a song file, and can record what it plays or render the song to a file without playing it.

## Play a song

```sh
mix mx.play song.exs
```

mx plays the song until it ends or you press Enter.
Save the file and the new version takes over at the end of the section playing.
A part added to the file joins at the next section, and a part removed from it stops at the end of its pass.
A version that does not load prints its error with the line, and the previous version keeps playing.

## Record what you play

To keep what you play, record it to a stereo WAV file:

```sh
mix mx.play song.exs --record session.wav
```

Recording starts before the first note, carries on without a gap when you save the song, and ends when you press Enter, once the notes still sounding have faded or after four seconds at most.
mx then prints where it wrote the recording, how long it is, and its peak in dB below full scale.
The recording is 32-bit floating point, which keeps a sound louder than full scale, but it distorts once played or converted; when that happens mx says how many times the recording clipped and when it first did, and lowering the amp of the loudest parts records it cleanly.
A file that already exists is refused unless you add `--force`, and so is a path mx cannot write; both are checked before anything plays.

## Render a song to a file

To hear what a song does without playing it aloud, render it to a stereo WAV file instead:

```sh
mix mx.play song.exs --render song.wav
```

The render holds what `--record` would, as fast as the machine renders it and with no sound: it starts at the song's first beat and ends once the music has ended and the notes still sounding have faded, or after four seconds at most.
Music that plays until mx stops needs `--seconds`, the length to render, such as `--seconds 60`.
Rendering a song twice writes the same file.
mx prints the same report as for a recording, and refuses a file that exists unless you add `--force`.
A render sends no MIDI or OSC and has no input, so mx names each part that sends MIDI or OSC, or waits for input, and leaves it out.
`--render` cannot go with `--record`, nor with a song that has `live_audio`.

## Print a song

To see what each part plays without hearing it, from a clone of mx:

```sh
mix mx.print song.exs
```
