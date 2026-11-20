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
`--no-ring-out` leaves out the notes still sounding when the music ends, so the file ends where the music ends, as long as the seconds the progress line gives.
Otherwise the render ends as those notes fade, which cuts short the effects that ring on after them, and mx says so, naming the part whose effects ring longest, such as `cutting short the reverb of part flute, which rings 5.5 seconds on`.
`--ring-out` keeps that ring, for as long as the part's effects ring.
Rendering a song twice writes the same file.
While it renders, mx prints its progress about four times a second, as a line such as `rendered 37.5 of 148.0 seconds`: the seconds of music rendered, and the seconds it renders in all, until the music ends or for `--seconds`, the fade after it left out.
A last line gives all of them once the music has rendered, such as `rendered 148.0 of 148.0 seconds`, and a render that fails prints none.
A program that runs the render reads each line as it is printed, and tells them from the report by their start.
mx then prints the same report as for a recording, and refuses a file that exists unless you add `--force`.
A render sends no MIDI or OSC and has no input, so mx names each part that sends MIDI or OSC, or waits for input, and leaves it out.
`--render` cannot go with `--record`, nor with a song that has `live_audio`.

## Choose the sound devices

mx plays through the system's default output, at that device's default sample rate and buffer size, unless told otherwise.
To play through an audio interface while the system's default stays the speakers, name it:

```sh
mx devices
mx play song.exs --output "Scarlett 2i2"
mx play song.exs --buffer 64
```

`mx devices` lists each output and input by the name the options take, with the channel counts, sample rates and buffer sizes it supports, and marks the defaults.
`--output` names the device to play through, and `--input` the one a song with `live_audio` reads.
`--rate` sets the sample rate in Hz, and a recording is written at the rate mx plays at.
`--buffer` sets the frames the device asks for at a time; a smaller buffer brings a saved change and a key's sound sooner, and asks more of the machine.
A setting the device cannot take stops mx before any sound, with a message such as "Scarlett 2i2 runs at 44100 or 48000 Hz, not 22050".
To set them once for a project, put them in its config, and an option given to `mx play` overrides them:

```elixir
config :mx, output: "Scarlett 2i2", buffer: 128
```

A render runs at 48000 Hz on no device, so `--rate` and `--buffer` do not apply to it, and mx says so.

## Change the tempo by hand

To practise a song slower, or play it faster, give it a share of its own tempo, from 0.25 to 4:

```sh
mx play song.exs --share 0.5
mx play song.exs --render slow.wav --share 0.5
```

Every tempo of the song is played times the share, its own and those its music writes, and the file is not changed.
A program that drives a session changes the share while the song plays with `Mx.Session.scale_tempo(session, 0.75)`, heard within 200 ms on every part at once, or `Mx.Session.scale_tempo(session, 0.75, 4)` to move there evenly over 4 beats.
The share holds through every save of the file until another is given, 1 brings back the song's own tempo, and stopping the song clears it.

## Try a sound on a part

A program that drives a session can play a part with another synth, or with other options of its synth, while the file stays as it is:

```elixir
Mx.Session.try_part(session, :flute, synth: :clarinet)
Mx.Session.try_part(session, :flute, vel: 0.8)
Mx.Session.stop_trying(session, :flute)
```

The part plays what is tried from the first whole beat 150 ms away, so it is heard from its next note within a bar, and it keeps its place, its notes, its other options and its effects.
What is tried adds to what was tried on the part before, and an option the song gives that the tried synth does not take is left out, and named once.
A part, synth or option that does not exist is refused with a message that names it.
What is tried lasts while the session plays, through every save of the file, until `stop_trying` plays the part as the song gives it again.

## Play a recording on a part

A program that drives a session can play a range of a recording on a part, to hear it through the part's effects before writing a sample line for it:

```elixir
Mx.Session.play_recording(session, :voice, "examples/tranquility_base/a11step.aiff", from: 2.447, to: 3.4)
Mx.Session.stop_recording(session, :voice)
```

The recording sounds from the first whole beat 150 ms away, through the part's effects and at its place in the mix, while the part plays on, and it takes the options a sample line takes.
Nothing is written to the song's file, and saving the file while it sounds does not stop it.
Another recording on the same part stops the first, and muting the part mutes it.
A part the song does not have, a file that cannot play and a range outside the recording are refused with a message that names them.
`Mx.Engine.Mxs.play_recording/2` plays a recording alone, with no song, and `Mx.Engine.Mxs.stop_sounds/1` stops it.

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
