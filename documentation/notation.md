# The notation

A song is an Elixir file that starts with `import Mx` and ends with `song`.
Between the two, plain functions build the music: each returns a value, and `song` plays the value it is given.

```elixir
import Mx

melody = seq(e4: 1, g4: 1, a4: 2, g4: 1, e4: 1, d4: 2)
bass = seq(a2: 4, e2: 4)

song(
  tempo: 90,
  music:
    together([
      part(:flute, melody, synth: :flute, fx: :reverb),
      part(:bass, bass, synth: :double_bass)
    ])
)
```

`mx song.exs` plays the file, and `mix mx.print song.exs` prints each part's notes with their beats instead of playing them.
A function refuses what cannot play, such as an unknown note name or an option the synth does not have, and mx prints the refusal with the line of the song file.

## Notes

`note(:a4, 1.5)` is the note A4 lasting 1.5 beats, and `rest(1)` is a beat of silence.

A pitch is a name or a MIDI note number, where 60 is middle C.
A name is a letter from `a` to `g`, an optional `s` for sharp or `b` for flat, and an optional octave that defaults to 4: `:c4` is 60, `:fs3` is 54 and `:eb3` is 51.

Options after the length go to the part's synth:

```elixir
note(:a4, 1.5, amp: 0.8, release: 2)
```

Each synth has its own options, which [Instruments](instruments.md) lists.
`attack`, `decay`, `sustain`, `release` and every option ending in `_slide` are measured in beats, so `release: 1` lasts one beat at any tempo.

A list of pitches is a chord:

```elixir
note(chord(:c4, :major), 2)
note(chord(:e3, :minor), 1, strum: 0.05)
note([40, 47, 52, 56], 1, vel: [0.8, 0.6, 0.5, 0.45])
```

`strum:` starts each note of the chord that many beats after the one below it, and a negative strum goes from the highest note down.
An option given as a list has one value for each note of the chord.

## Putting music together

```elixir
verse = seq(c4: 1, e4: 1, g4: 2)
chorus = together([seq(c5: 2, b4: 2), seq(e4: 4)])

seq([verse, transpose(verse, 5), repeat(chorus, 2)])
```

- `seq` plays its items one after another. It takes a list of music, or note names and lengths as a keyword list where `r` is a rest: `seq(a4: 1.5, a4: 0.5, c5: 1, r: 1)`.
- `together` starts its items at once, and lasts as long as the longest.
- `repeat(music, 4)` plays the music four times. `repeat(music)` plays it until mx stops, and can only hold the whole of a song's music.
- `transpose(music, 12)` moves every note an octave up.
- `beats(music)` is the length of music in beats.

## Rhythm

```elixir
part(:kick, steps("x... x... x... x.x.", 0.25), synth: :kick)
part(:cajon, at([{0, hit(slap: 1, vel: 0.8)}, {1.5, hit(vel: 0.5)}], 2), synth: :cajon)
```

- `steps("x..x x.x.", 0.25)` is one drum hit for each `x`. Each character lasts a quarter of a beat, a dot is silence, and spaces are left out.
- `hit(vel: 0.5)` is one hit of a drum at its own pitch, taking no time.
- `at([{0.5, music}, {1.5, music}], 2)` is music of 2 beats that starts each item at its beat, so hits at known beats need no rests between them.
- `swing(music, fun)` starts each note at the beat the function returns for the beat it was written on, so some notes can be pushed late and others early.

## Parts

`part(:soprano, music, synth: :oboe)` is music played by one player.
The synth defaults to `:tri`.
A part of one name is the same player wherever it appears in the song, so it must have the same options each time.

`fx:` sends the part through an effect, or through a list of effects in order, each with its options:

```elixir
part(:keys, music, synth: :piano, fx: :reverb)
part(:keys, music, synth: :piano, fx: [echo: [phase: 0.75], reverb: [room: 0.8]])
```

`defaults:` gives every note of the part options it takes unless the note gives its own:

```elixir
part(:guitar, music, synth: :guitar, defaults: [amp: 0.55])
```

## The song

`song(tempo: 72, music: music)` is the song.
The tempo defaults to 60 beats per minute.

The items of the song's outermost `seq` are its sections, also when the `seq` is inside `repeat`.
A part plays only in the sections that hold it, so instruments can take turns:

```elixir
import Mx

melody = seq(c4: 1, e4: 1, g4: 2)
answer = seq(r: 2, g5: 1, e5: 1)

first = together([part(:trombone, melody, synth: :trombone), part(:flute, answer, synth: :flute)])
second = together([part(:cello, melody, synth: :cello), part(:tenor_sax, answer, synth: :tenor_sax)])

song(tempo: 72, music: repeat(seq([first, second])))
```

When you save the file while the song plays, the new version takes over at the end of the current section.
A song whose music is not a `seq` is one section.

`tempo(140)` changes the tempo for every part from the beat where it is written, and takes no time.
`tempo(130, over: 16)` gets there evenly over 16 beats.
In music that repeats, give the first section its tempo too, since each change comes round again:

```elixir
repeat(seq([tempo(100), verse, tempo(140), chorus]))
```

## Loops

`loop(4, fn pass, inputs -> music end)` runs the function again every 4 beats and plays the music it returns, so a part can vary from pass to pass:

```elixir
import Mx

drums =
  loop(16, fn pass, _ ->
    last_bar = if rem(pass, 4) == 3, do: "x.x.xxxx", else: "x...x..."
    steps("x...x... x...x... x...x... " <> last_bar, 0.5)
  end)

song(tempo: 96, music: together([
  part(:bass, repeat(seq(c2: 4, g2: 4), 8), synth: :saw),
  part(:drums, drums, synth: :kick)
]))
```

- `pass` counts the passes the loop has played, from 0, and `ring(list, pass)` steps through a list one item per pass.
- Beside other music a loop plays until the longest of the rest ends. Alone, or beside only loops, it plays until mx stops, unless `times: 4` gives its number of passes.
- Music shorter than the loop is followed by silence until the next pass, and music longer than the loop is refused.
- A pass that raises prints its error, and the loop plays its next pass.
- `mix mx.print song.exs --pass 4` prints the fifth pass.

`inputs` holds what has arrived from outside: `inputs.cc` the latest value of each MIDI controller, `inputs.notes` the velocity of the latest note on for each note, `inputs.osc` the arguments of the latest message to each OSC address, and `inputs.values` each shared value.
An entry is nil until something has sent it.

```elixir
part(:bass, loop(1, fn _, inputs -> note(:c2, 1, cutoff: (inputs.cc[74] || 64) * 50) end), synth: :saw)
```

mx works a pass out half a second before it plays, so an input that changes shows from the next pass on.

A loop can also play a pass each time something arrives, as soon as possible, for playing live:

```elixir
loop(fn trigger, _ -> note(trigger.note, 1) end, on: :midi_note)
```

`on: :midi_cc` waits for controller changes and `on: {:osc, "/hit"}` for messages to that address.
`trigger` is what arrived: `%{note: 60, velocity: 100}`, `%{number: 74, value: 64}`, or `%{address: "/hit", args: [1]}`.

## Samples

`sample(:bd_haus, 1)` plays a sample of Sonic Pi's pack by name, then a beat passes.
[Sample names](#sample-names) lists the pack.
`sample("kick.wav", 1)` plays a WAV, AIFF or FLAC file by path.

```elixir
sample(:loop_amen, 4, beats: 4)
sample(:loop_amen, 1, from: 0.5, to: 1.0)
sample(:loop_amen, 0.5, slices: 8, slice: 3)
sample(:ambi_choir, 4, rate: 0.5, amp: 0.6)
```

- `rate: 0.5` plays at half speed an octave lower, and a negative rate plays backwards.
- `beats: 4` plays the sample faster or slower so it lasts 4 beats at the tempo, in place of `rate`.
- `from` and `to` cut the sample at seconds into its file, and `start` and `finish` cut it at positions from 0 to 1.
- `slices: 8, slice: 3` plays the fourth of eight equal pieces, counted from 0.
- `normalize: true` scales the sample so its loudest moment reaches full scale before `amp`, for files recorded at very different levels.
- A sample also takes `amp`, `pan` and the envelope options `attack`, `decay`, `sustain` and `release`.

A sample can come from a public GitHub repository, at a commit, tag or branch:

```elixir
sample({:github, "sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e", "Idiophones/Struck Idiophones/Agogo Bells/Agogo_High_v1_rr1_Mid.wav"}, 1)
```

mx downloads the file into your cache when the song loads, and plays it from the cache after that.
`mx samples download SOURCE` downloads a whole collection ahead of time, where SOURCE is `sonic_pi` or a repository as `owner/repo@ref`, optionally followed by `:folder`:

```sh
mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones/Struck Idiophones/Agogo Bells"
```

## Sampled instruments

`sampled(folder)` makes an instrument from a folder of recordings, one file for each key, and a part plays it with `note` and `hit` as it plays a synth:

```elixir
mbira = sampled("VCSL/Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B")
part(:mbira, seq([note(:e4, 1), note(:fs4, 1), note(chord(:e3, :major), 2, strum: 0.05)]), synth: mbira)
```

mx reads each file's note, strength and take from its name, as the VCSL library names them: `MBira4_pluck_Main_E4_19_50_100_rr2.wav` is the mbira's E4, take 2.
A note plays the recorded key nearest to it, sped up or slowed down to its pitch.
`vel` from 0 to 1 picks among the recorded strengths, and repeated notes play the takes in turn.

For files named another way, list them with what each one is:

```elixir
sampled([{"low.wav", note: :c2}, {"high.wav", note: :c3, strength: 2, take: 1}])
```

`sampled({:github, repo, ref, folder})` plays a folder of a GitHub repository.

## MIDI and OSC

A song sends MIDI and OSC as it plays notes, placed in the music the same way:

```elixir
part(:synth, seq([midi(60, 1, velocity: 90), midi_cc(74, 64), midi(64, 1)]), midi: "IAC Driver Bus 1")
part(:lights, seq([osc("/flash", [1]), rest(4)]))
```

- `midi(60, 1)` sends a note on and, a beat later, its note off. `velocity` is 100 and `channel` is 1 unless given.
- `midi_cc(74, 64)` sends a controller change, and takes no time.
- `osc("/hello", [1, "a"])` sends an OSC message with numbers and strings as its arguments, and takes no time.
- A part's `midi:` names the output port its MIDI goes to. Without it, MIDI goes to every connected port.
- The song's `osc_to: {"127.0.0.1", 9000}` names where OSC goes, and `osc_from: 9001` the port a loop's `inputs.osc` arrive on.

## Shared values and changes

`set(:root, 40)` shares a value that every loop reads as `inputs.values[:root]`, from its next pass on.

`change` changes the sounds of a part that are still playing, or one of its effects:

```elixir
change(:lead, cutoff: 80, cutoff_slide: 2)
change({:lead, :reverb}, mix: 0)
```

An option's `_slide` partner makes the change glide over that many beats instead of jumping.
A note can also carry its own later changes, so a held note glides to the next pitch without a new attack:

```elixir
part(:lead, note(:a4, 4, changes: [{1, note: :c5, note_slide: 0.1}]), synth: :flute)
```

## Live audio

`live_audio: [mic: []]` in `song` plays the sound card's first input through the speakers while the song plays.
It takes `input: 2` for another input, `stereo: true`, `amp`, `pan` and `fx:`.
mx must start with a song that has `live_audio` to read the input.

## Helpers

Pitches and chords:

- `pitch(:e5)` is 76, the number of a note name.
- `chord(:a3, :minor7)` and `scale(:e3, :minor_pentatonic, octaves: 2)` are lists of note numbers.
- Chords: aug, dim, dim7, dom7, dom7_flat9, dom9, half_dim7, major, major6, major7, minor, minor6, minor7, sus2, sus4.
- Scales: blues, chromatic, dorian, harmonic_minor, major, major_pentatonic, minor, minor_pentatonic, mixolydian.
- `intervals([60, 64, 67])` is the step from each note to the next, `[4, 3]`.
- `melody(60, [4, 3, -2])` is the notes reached by taking those steps, `[60, 64, 67, 65]`, so `melody(:d4, intervals(motif))` plays a motif again from D4.
- `nearest(65, chord(:c4, :major))` is 64, the note of the chord in any octave closest to 65.
- `below(76, chord(:a4, :minor7))` is 72, the note of the chord closest below 76.
- `voice(chord(:g2, :major6), from: 62, to: 73)` places each note of the chord once in that range, `[62, 64, 67, 71]`.
- `fit(scale(:a4, :minor), chord(:e4, :dom7))` moves the scale's notes a semitone to hold the chord's notes, so G becomes G sharp.
- `cents(386)` is an interval in cents as semitones, 3.86, and `ratio(5 / 4)` is the interval of a frequency ratio, also 3.86.

Lists and numbers:

- `ring([60, 64, 67], 4)` is 64, the item at an index, wrapping round.
- `clamp(12, 2, 11)` keeps a number from 2 up to 11, so it is 11.

Chance:

- `pick([60, 63, 67])` is one item of a list or a range.
- `chance(0.45)` is true about 45 times in 100.
- `between(0.6, 0.95)` is a number from 0.6 up to 0.95.

Random numbers are seeded from the song file, and in a loop from the part's name and the pass number, so a song plays the same notes each time it loads.

## Sample names

These are the names of the samples in Sonic Pi's pack, from release v5.0.0; see the pack's README.md in its folder for where each comes from.

ambi_choir, ambi_dark_woosh, ambi_drone, ambi_glass_hum, ambi_glass_rub, ambi_haunted_hum, ambi_lunar_land, ambi_piano, ambi_sauna, ambi_soft_buzz, ambi_swoosh, arovane_beat_a, arovane_beat_b, arovane_beat_c, arovane_beat_d, arovane_beat_e, bass_dnb_f, bass_drop_c, bass_hard_c, bass_hit_c, bass_thick_c, bass_trance_c, bass_voxy_c, bass_voxy_hit_c, bass_woodsy_c, bd_808, bd_ada, bd_boom, bd_chip, bd_fat, bd_gas, bd_haus, bd_jazz, bd_klub, bd_mehackit, bd_pure, bd_sone, bd_tek, bd_zome, bd_zum, drum_bass_hard, drum_bass_soft, drum_cowbell, drum_cymbal_closed, drum_cymbal_hard, drum_cymbal_open, drum_cymbal_pedal, drum_cymbal_soft, drum_heavy_kick, drum_roll, drum_snare_hard, drum_snare_soft, drum_splash_hard, drum_splash_soft, drum_tom_hi_hard, drum_tom_hi_soft, drum_tom_lo_hard, drum_tom_lo_soft, drum_tom_mid_hard, drum_tom_mid_soft, elec_beep, elec_bell, elec_blip, elec_blip2, elec_blup, elec_bong, elec_chime, elec_cymbal, elec_filt_snare, elec_flip, elec_fuzz_tom, elec_hi_snare, elec_hollow_kick, elec_lo_snare, elec_mid_snare, elec_ping, elec_plip, elec_pop, elec_snare, elec_soft_kick, elec_tick, elec_triangle, elec_twang, elec_twip, elec_wood, glitch_bass_g, glitch_perc1, glitch_perc2, glitch_perc3, glitch_perc4, glitch_perc5, glitch_robot1, glitch_robot2, guit_e_fifths, guit_e_slide, guit_em9, guit_harmonics, hat_bdu, hat_cab, hat_cats, hat_gem, hat_gnu, hat_gump, hat_hier, hat_len, hat_mess, hat_metal, hat_noiz, hat_psych, hat_raw, hat_sci, hat_snap, hat_star, hat_tap, hat_yosh, hat_zan, hat_zap, hat_zild, loop_3d_printer, loop_amen, loop_amen_full, loop_breakbeat, loop_compus, loop_drone_g_97, loop_electric, loop_garzul, loop_industrial, loop_mehackit1, loop_mehackit2, loop_mika, loop_perc1, loop_perc2, loop_safari, loop_tabla, loop_weirdo, mehackit_phone1, mehackit_phone2, mehackit_phone3, mehackit_phone4, mehackit_robot1, mehackit_robot2, mehackit_robot3, mehackit_robot4, mehackit_robot5, mehackit_robot6, mehackit_robot7, misc_burp, misc_cineboom, misc_crow, perc_bell, perc_bell2, perc_door, perc_impact1, perc_impact2, perc_snap, perc_snap2, perc_swash, perc_swoosh, perc_till, ride_tri, ride_via, sn_dolf, sn_dub, sn_generic, sn_zome, tabla_dhec, tabla_ghe1, tabla_ghe2, tabla_ghe3, tabla_ghe4, tabla_ghe5, tabla_ghe6, tabla_ghe7, tabla_ghe8, tabla_ke1, tabla_ke2, tabla_ke3, tabla_na, tabla_na_o, tabla_na_s, tabla_re, tabla_tas1, tabla_tas2, tabla_tas3, tabla_te1, tabla_te2, tabla_te_m, tabla_te_ne, tabla_tun1, tabla_tun2, tabla_tun3, tbd_fxbed_loop, tbd_highkey_c4, tbd_pad_1, tbd_pad_2, tbd_pad_3, tbd_pad_4, tbd_perc_blip, tbd_perc_hat, tbd_perc_tap_1, tbd_perc_tap_2, tbd_voctone, vinyl_backspin, vinyl_hiss, vinyl_rewind, vinyl_scratch.
