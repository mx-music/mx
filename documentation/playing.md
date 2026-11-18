# Playing, recording and rendering

`mx play` plays a song file, and can record what it plays or render the song to a file without playing it.
`mx video` turns a render into a video.

## Play a song

```sh
mx play song.exs
```

mx plays the song until it ends or you press Enter.
Save the file and the new version takes over at the end of the section playing.
A part added to the file joins at the next section, and a part removed from it stops at the end of its pass.
A version that does not load prints its error with the line, and the previous version keeps playing.

## Record what you play

To keep what you play, record it to a stereo WAV file:

```sh
mx play song.exs --record session.wav
```

Recording starts before the first note, carries on without a gap when you save the song, and ends when you press Enter, once the notes still sounding have faded or after four seconds at most.
mx then prints where it wrote the recording, how long it is, and its peak in dB below full scale.
The recording is 32-bit floating point, which keeps a sound louder than full scale, but it distorts once played or converted; when that happens mx says how many times the recording clipped and when it first did, and lowering the amp of the loudest parts records it cleanly.
A file that already exists is refused unless you add `--force`, and so is a path mx cannot write; both are checked before anything plays.

## Render a song to a file

To hear what a song does without playing it aloud, render it to a stereo WAV file instead:

```sh
mx play song.exs --render song.wav
```

The render holds what `--record` would, as fast as the machine renders it and with no sound: it starts at the song's first beat and ends once the music has ended and the notes still sounding have faded, or after four seconds at most.
Music that plays until mx stops needs `--seconds`, the length to render, such as `--seconds 60`.
Rendering a song twice writes the same file.
mx prints the same report as for a recording, and refuses a file that exists unless you add `--force`.
A render sends no MIDI or OSC and has no input, so mx names each part that sends MIDI or OSC, or waits for input, and leaves it out.
`--render` cannot go with `--record`, nor with a song that has `live_audio`.

## Change the tempo by hand

To practise a song slower, or play it faster, give it a share of its own tempo, from 0.25 to 4:

```sh
mx play song.exs --share 0.5
mx play song.exs --render slow.wav --share 0.5
```

Every tempo of the song is played times the share, its own and those its music writes, and the file is not changed.
A program that drives a session changes the share while the song plays with `Mx.Session.scale_tempo(session, 0.75)`, heard within 200 ms on every part at once, or `Mx.Session.scale_tempo(session, 0.75, 4)` to move there evenly over 4 beats.
The share holds through every save of the file until another is given, 1 brings back the song's own tempo, and stopping the song clears it.

## Make a video of a render

GitHub plays no sound in a README, only video, so a song is heard there as a video of its render.
`mx video` makes an MP4 that plays a WAV or AIFF recording over its waveform, with a playhead that crosses the picture once as the recording plays:

```sh
mx play song.exs --render song.wav
mx video song.wav
```

The waveform is a row of bars, each as tall as its slice of the recording is loud, in amber once the playhead has passed and in grey before.
`--picture spectrogram` plays the recording over its spectrogram instead, with a thin white line as the playhead.
The video is written beside the recording with the extension .mp4 unless `--out` names it, and mx refuses a file that exists unless you add `--force`.
Its sound is the recording at one gain, which brings its loudest sample to 1.5 dB below full scale, so the recording's dynamics are kept.
mx prints the video's length and size, and warns when it is over the 10 MB GitHub allows for a video on its free plan; `--bitrate`, the sound's kbit/s, 256 unless given, makes it smaller.
The task needs [ffmpeg](https://ffmpeg.org) installed.
To put the video in a README, drop the file into a comment box on GitHub and paste the link it gives on a line of its own.

`mx waveform` draws the waveform alone into a PNG image, 1500 pixels wide and 150 high unless `--width` and `--height` give another size, and `mx spectrogram` draws the spectrogram, as [the guide to instruments](instruments.md#spectrograms) describes.

```sh
mx waveform song.wav --out bars.png
```

## Print a song

To see what each part plays without hearing it, from a clone of mx:

```sh
mx print song.exs
```
