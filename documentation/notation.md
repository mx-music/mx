# The notation

A song is music built from plain functions, each returning a value and recording nothing on the side.
The file starts with `import Mx`, keeps its helpers in modules it defines with `defmodule`, and ends with `song`:

```elixir
import Mx

defmodule Chorale do
  import Mx

  def soprano, do: seq(c5: 1, d5: 1, e5: 2, d5: 1, c5: 1, b4: 2)
  def bass, do: seq(c3: 2, g2: 2, a2: 2, g2: 2)
end

song(
  tempo: 72,
  music:
    together([
      part(:soprano, Chorale.soprano(), synth: :oboe),
      part(:bass, Chorale.bass(), synth: :bassoon)
    ])
)
```

`import Mx` comes first because Elixir expands it before the file runs, so a song file cannot install mx with `Mix.install` itself; the `mx` command does that.

## Notes and music

- `note(:a4, 1.5)` is a note of A4 lasting 1.5 beats, and `note(:a4, 1.5, vel: 0.8)` gives it options for the part's synth, such as `amp`, `pan`, `attack` and `release`. An option the synth does not have is refused with its line.
- A pitch is a MIDI note number, where 60 is middle C, or a name: a letter from `a` to `g`, an optional `s` for sharp or `b` for flat, and an optional octave that defaults to 4. `:c4` is 60, `:fs3` is 54 and `:eb3` is 51. An unknown name is refused with its line.
- A note's pitch can be a list played together, so `note(chord(:c4, :major), 2)` is a chord.
- `strum:` spreads a chord's notes like a strum on strings: `note(chord(:e3, :minor), 1, strum: 0.05)` starts each note 0.05 beats after the one below it, and a negative strum goes from the highest note down.
- A chord takes a list for any of its options, one value per note in the order the notes are written, so `note([40, 47, 52, 56], 1, strum: 0.04, vel: [0.8, 0.6, 0.5, 0.45])` hits the low string hardest, whatever order the strum plays the notes in. A single value still applies to every note, and a list with the wrong number of values, or a list for a single note, is refused with its line.
- A note lasts its length: on a synth that takes `sustain`, the length is the note's sustain unless the note or the part's `defaults:` give one; a note of 0 beats, such as `hit(vel: 0.5)`, keeps the synth's own sustain.
- `attack`, `decay`, `sustain`, `release` and every option ending in `_slide` are measured in beats, so `release: 1` lasts one beat at any tempo. A synth's own defaults for them are in beats too.
- `hit(vel: 0.5)` is one hit of a drum at its own pitch, taking no time, for placing with `at`.
- `rest(1)` is silence lasting a beat.
- `seq` plays its items one after another, and also takes note names and lengths as a keyword list, `r` being a rest: `seq(a4: 1.5, a4: 0.5, c5: 1, r: 1)`.
- `together` starts its items at once, and lasts as long as the longest; two parts of one name in it are refused.
- `repeat(music, 4)` plays the music four times in a row, and `repeat(music)` plays it until mx stops; repeat without a count can only hold the whole of the song's music.
- `transpose(music, 12)` moves every note an octave up.
- `at([{0.5, music}, {1.5, music}], 2)` is music of 2 beats that starts each item at its beat, so strokes at known beats need no rests between them; an item at or past the length is refused.
- `swing(music, fun)` starts each note at the beat the function returns for the beat it was written on, so some notes can be pushed late and others early.
- `steps("x..x x.x.", 0.25)` is hits of a drum, one for each x, each character lasting a quarter of a beat, a dot being silence and spaces left out; options given after the step go to every hit.
- `beats(music)` is the length of music in beats.
- Every function refuses what cannot play as soon as it is called, and mx prints the refusal with the line of the song file that was running: an unknown note in `note`, an option the synth does not have in `part`, a note outside any part in `song`.

## Parts and the song

- `part(:soprano, music, synth: :oboe)` is music played by one player. Its synth defaults to `:tri`, and a synth mx does not have is refused. A part of one name plays as one player wherever it appears, and is refused if it appears with other options.
- `fx:` sends every note and sample of a part through an effect, or through a list of effects in order, each with its options: `fx: :reverb`, or `fx: [echo: [phase: 0.75], reverb: [room: 0.8]]`. The effects keep running from pass to pass, so a reverb tail carries into the next pass. An effect's `phase`, `max_phase`, `decay` and slides are measured in beats. Changed effects take over at the end of the part's pass, and the old ones are removed once their last sound has ended. An effect mx does not have, or an option the effect does not have, is refused.
- `defaults:` gives every note of a part options it takes unless the note gives its own: in `part(:guitar, music, synth: :guitar, defaults: [amp: 0.55])`, `note(40, 1)` sends amp 0.55 and `note(47, 1, amp: 0.45)` sends 0.45. Defaults are checked against the part's synth when the song loads, their time options are measured in beats, and they reach every note of a chord. They do not apply to samples or MIDI.
- `midi:` names the MIDI output port a part's MIDI goes to, such as `midi: "IAC Driver Bus 1"`; without it MIDI goes to every connected port. A port that is not connected prints one warning naming it, and the part plays on.
- `song(tempo: 72, music: music)` is the song; the tempo defaults to 60 beats per minute.
- `tempo(140)` changes the song's tempo on its beat, for every part at once, and takes no time; `tempo(130, over: 16)` gets there evenly over 16 beats, each beat a little shorter than the one before. Write it in the song's music, inside a part or between sections: `seq([verse, tempo(140), chorus])` plays the chorus at 140 bpm from its first beat. A loop's function cannot return one. In music that repeats, a change comes round again each time, so give the first section its tempo too: `repeat(seq([tempo(100), verse, tempo(140), chorus]))`. Release, sustain and the other times in beats last that many beats at the tempo when the note starts, and `mix mx.print` names the tempos each pass plays at.
- `live_audio: [mic: []]` plays the sound card's first input through the speakers from when the song loads until it is taken out of the file or mx stops. `input: 2` reads another input, `stereo: true` reads that input and the next as left and right, and it takes `amp`, `pan` and their slides, and `fx:` as a part does. Saving changed options changes the level or pan without a gap; changed inputs or effects start it anew, and taking it out of the file stops it at once.
- `osc_to: {"127.0.0.1", 9000}` names where `osc` sends its messages, and `osc_from: 9001` the port OSC inputs arrive on.

The items of the song's outermost `seq` are its sections, looking through `repeat`, so `repeat(seq([verse, chorus]))` is two sections played again and again.
A part plays only in the sections that hold it, so instruments can take turns without counting passes:

```elixir
import Mx

melody = seq(c4: 1, e4: 1, g4: 2)
answer = seq(r: 2, g5: 1, e5: 1)

first = together([part(:trombone, melody, synth: :trombone), part(:flute, answer, synth: :flute)])
second = together([part(:cello, melody, synth: :cello), part(:tenor_sax, answer, synth: :tenor_sax)])

song(tempo: 72, music: repeat(seq([first, second])))
```

Saving the song while it plays makes the new version take over at the end of the current section; a song whose music is not a seq is one section.
A song whose music ends stops by itself once its last note has played, and mx prints "The song ended."
`mix mx.print` prints each part's notes with their beats from the start of the song.

## Loops

`loop(4, fn pass, inputs -> music end)` is music that runs the function again every 4 beats and plays the music it returns, so a part can vary from pass to pass:

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

- `pass` counts the passes the part's loop has played in the song so far, from 0, carrying on from one section into the next, and `ring(list, pass)` steps through a list one item per pass.
- Beside other music a loop plays until the longest of the rest ends, its last pass cut there; alone, or beside only loops, it plays until mx stops, unless `times: 4` gives its number of passes.
- Music longer than the loop is refused, naming the part and the line; shorter music is followed by silence until the next pass.
- A pass that raises prints the error with the part's name and the line, and the loop plays its next pass; the other parts never stop.
- `inputs.cc`, `inputs.notes`, `inputs.osc` and `inputs.values` hold the latest value of each MIDI controller, the velocity of the latest note on for each note, 0 once it is off, the arguments of the latest message to each OSC address, and each shared value, nil for what nothing has sent. MIDI comes from every input port connected when mx starts, whatever its port or channel, and OSC from the song's `osc_from:` port:

```elixir
part(:bass, loop(1, fn _, inputs -> note(:c2, 1, cutoff: (inputs.cc[74] || 64) * 50) end), synth: :saw)
```

- A pass reads MIDI and OSC inputs as they are when mx works it out, half a second before it plays, so a change shows from the next pass on, and a pass plays the same way every time for the same inputs.
- `loop(fn trigger, inputs -> music end, on: :midi_note)` plays a pass each time a MIDI note on arrives, as soon as possible instead of half a second ahead, for playing live; `on: :midi_cc` waits for controller changes and `on: {:osc, "/hit"}` for messages to that address. `trigger` is what arrived: `%{note: 60, velocity: 100}`, `%{number: 74, value: 64}`, or `%{address: "/hit", args: [1]}`.
- `mix mx.print song.exs --pass 4` prints the fifth pass of each part, a pass being a section, or the length of the longest loop in music that plays until mx stops; `--cc 74=64 --note 60=100 --osc /trigger=1,a --get root=40` prints it as if those inputs had arrived and that value had been set.

## Samples, MIDI, OSC, shared values and changes

These are music too, placed like notes:

- `sample(:bd_haus, 1)` plays a sample of the pack by name, and `sample("kick.wav", 1)` a WAV, AIFF or FLAC file by path, then a beat passes. It takes `amp`, `pan`, `rate`, `start`, `finish`, `attack`, `decay`, `sustain`, `release`, `attack_level`, `decay_level` and `sustain_level`, and slides for `amp`, `pan` and `rate`: `rate: 0.5` plays at half speed an octave lower, a negative rate plays backwards, and `start` and `finish` pick a part of the sound from 0 to 1.
- `from` and `to` cut a sample at seconds into its file, whatever its rate, in place of `start` and `finish`: `sample(:loop_amen, 1, from: 0.5, to: 1.0)` plays half a second of the loop from 0.5 seconds in, and a negative `rate` plays that half second backwards. `beats: 4` plays the sample, or the part of it cut, faster or slower so it lasts 4 beats at the tempo where it starts, changing its pitch with its speed as `rate` does, in place of `rate`: `sample(:loop_amen, 4, beats: 4)` fits the loop to a bar at any tempo. `slices: 8, slice: 3` plays the fourth of eight equal pieces, counted from 0, and with `beats` each piece lasts its share. `mix mx.print` shows them as written, with the rate `beats` works out.
- `normalize: true` scales a sample so the loudest moment of its whole file reaches full scale, before `amp`, so `amp` sets its level from the same starting point for every file, from collections recorded at very different levels; a mono file reaches full scale in both channels at the centre. A file whose loudest moment is more than 40 dB below full scale, played without it, makes mx print one line when the song loads, naming the file and its peak, and a silent file is named as silent and plays silence.
- A `from` or `to` outside the file, naming its length in seconds, a `start` or `finish` outside 0 to 1, a `slice` outside 0 to `slices` minus 1, and a sample given both `start` or `finish` and `from` or `to`, or both `beats` and `rate`, are refused when the song loads, with the line.
- `sample({:github, "sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e", "Idiophones/Struck Idiophones/Agogo Bells/Agogo_High_v1_rr1_Mid.wav"}, 1)` plays a file of a public GitHub repository at a commit, tag or branch, here an agogô of Versilian Studios' VCSL, under Creative Commons 0. mx downloads it into your cache when the song loads, printing a line naming it, so no pass waits for the network, and plays it from the cache with no network access after that. Each repository and ref has its own folder in the cache. A file that cannot be downloaded is refused when the song loads, naming the loop, the repository, the path and the reason, and the previous version keeps playing.
- `mx samples download SOURCE` downloads a whole collection ahead of time into the same cache, so songs play it with no network access, and `mix mx.samples.download SOURCE` does the same in a clone of mx. SOURCE is `sonic_pi` for Sonic Pi's pack, or a GitHub repository as `owner/repo@ref`, optionally followed by `:folder` for only that folder. It prints how many files it downloaded, skips those it has, and names a file that fails; run it again to finish. GitHub lists a folder's files only so many times an hour without a login, and mx says when that limit resets:

  ```sh
  mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones/Struck Idiophones/Agogo Bells"
  ```

- mx reads WAV files as 8, 16, 24 and 32-bit PCM and 32 and 64-bit float, AIFF and AIFF-C files as 8, 16, 24 and 32-bit PCM and 32 and 64-bit float, and FLAC files, mono or stereo at any sample rate; it knows each by its contents, not its name.
- `synth: sampled(folder)` plays a part on a sampled instrument, recorded one key at a time, with `note` and `hit` as on a synth. mx reads each file's note, strength and take from its name, as Versilian Studios' VCSL names them: a note such as `C#3` or `Bb2`, a strength as `v` or `vl` and a number, and a take as `rr` and a number, so `MBira4_pluck_Main_E4_19_50_100_rr2.wav` is the mbira's E4, take 2. VCSL is under Creative Commons 0, at https://github.com/sgossner/VCSL:

  ```elixir
  mbira = sampled("VCSL/Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B")
  part(:mbira, seq([note(:e4, 1), note(:fs4, 1), note(chord(:e3, :major), 2, strum: 0.05)]), synth: mbira)
  ```

- A note plays the recorded key nearest to it, the lower one on a tie, sped up or slowed down to sound at its pitch, cents included. `vel` from 0 to 1 picks a strength, the softest at 0 and the hardest at 1, spread evenly over the strengths recorded, and also scales the level as `amp` does; it is 1 unless given.
- Repeated notes on one key and strength play its takes in turn, starting again after the last. Each pass carries on the count as though the passes before it played the key as often, so a pass plays the same takes every time and `mix mx.print` shows the ones that play. Files of one note and strength are the takes of one key, in the order of their take and then their name.
- An instrument with no notes in its file names, such as a drum, plays with `hit`, choosing strength and take the same way.
- A note lasts its length, then fades over its `release`, and a note longer than its recording ends with the recording. A sampled instrument takes `vel`, `amp`, `pan`, `attack`, `decay`, `sustain`, `release` and the levels, and slides for `amp` and `pan`, and plays in chords, with `strum`, `defaults:` and `fx:`; it works out `rate`, `start` and `finish` itself.
- `sampled([{"low.wav", note: :c2}, {"high.wav", note: :c3, strength: 2, take: 1}])` lists the files of a collection named otherwise, each with its note, strength and take, and reads what a file does not give from its name. `sampled({:github, repo, ref, folder})` plays a folder of a GitHub repository, downloaded when the song loads if it is not in the cache yet, and a listed file can be `{:github, repo, ref, path}` too.
- A folder with no files whose names carry a note, a strength or a take, and a listed file that does not exist, are refused when the song loads, naming the part and the folder or file.
- The samples a song's music names are checked and loaded before it plays, so the first note is on time, and an unknown name, a missing file or a file mx cannot read is refused with its line and the reason; a sample a loop names only while a pass runs is loaded then, and plays from its next pass.
- `midi(60, 1, velocity: 90, channel: 2)` sends a note on and, a beat later, its note off, to the port the part's `midi:` names; `velocity` goes from 0 to 127 and is 100 by default, and `channel` from 1 to 16 and is 1 by default.
- `midi_cc(74, 64)` sends a controller change on `channel`, and `osc("/hello", [1, "a"])` an OSC message to the song's `osc_to:`, its arguments numbers and strings; neither takes time. A destination that cannot be reached prints one warning.
- MIDI and OSC have no timestamps, so mx sends them at the moment: each leaves within 2 ms of its beat, and on this project's measurements 99 in 100 reach a program on the same machine within 2 ms. Stopping mx sends note off for every MIDI note still sounding.
- `set(:root, 40)` shares a value every loop reads as `inputs.values[:root]`, and takes no time; values stay until they are set again or mx stops.
- A pass reads each shared value as the last `set` before the pass's first beat left it, so a `set` on that beat, its own included, reaches it from its next pass on. mx works out the loops ahead in no fixed order, so a pass waits for the other loops to work out up to its first beat, and a song reads the same values on every run.
- `change(:lead, cutoff: 80, cutoff_slide: 2)` changes every sound of the part lead still playing, at its beat, wherever it is written; `change({:lead, :reverb}, mix: 0)` changes the part's reverb. A part or effect the song does not have is refused with the line.
- A note carries its own later changes, so a held note can glide to the next one without a new attack:

```elixir
part(:lead, note(:a4, 4, changes: [{1, note: :c5, note_slide: 0.1}]), synth: :flute)
```

- An option's `_slide` partner, such as `note_slide: 1`, makes later changes to that option glide over that many beats instead of jumping. Envelope options, such as `attack` and `release`, cannot change once a sound plays and are refused, and a change after the sound has ended does nothing.
- `mix mx.print` shows each of these with its beat.

## Helpers

- `pitch(:e5)` is 76, the number of a note name, and `pitch(76)` is 76.
- `chord(:a3, :minor7)` and `scale(:e3, :minor_pentatonic, octaves: 2)` return lists of note numbers, from a root given as a name or a number. A scale ends on the octave above its root, and works with `ring` like any list. An unknown chord or scale is refused with its line.
- Chords: aug, dim, dim7, dom7, dom7_flat9, dom9, half_dim7, major, major6, major7, minor, minor6, minor7, sus2, sus4.
- Scales: blues, chromatic, dorian, harmonic_minor, major, major_pentatonic, minor, minor_pentatonic, mixolydian.
- `intervals([60, 64, 67])` is the step from each note to the next, `[4, 3]`, and `melody(60, [4, 3, -2])` is the notes reached by taking those steps, `[60, 64, 67, 65]`. Together they move a motif to another starting note: `melody(:d4, intervals(motif))` plays the motif again from D4. Both take note names as well as numbers.
- `nearest(65, chord(:c4, :major))` is 64, the note of the chord in any octave closest to 65, the lower on a tie; `nearest(64, chord(:c4, :major), except: 64)` leaves 64 out and is 67, so a line can move off a repeated note.
- `below(76, chord(:a4, :minor7))` is 72, the note of the chord closest below 76, which stacks a voice under a melody.
- `voice(chord(:g2, :major6), from: 62, to: 73)` places each note of the chord once from 62 up, `[62, 64, 67, 71]`, as four strings reach; `limit: 4` leaves out the root of a chord of five notes, and a range that cannot hold every note is refused.
- `fit(scale(:a4, :minor), chord(:e4, :dom7))` bends the scale to the chord: each chord tone missing from the scale takes the place of the scale note a semitone below it, or a semitone above when there is none below, so G becomes G sharp.
- A chord here is any list of notes, as `chord` gives it or as a song writes it out.
- `ring([60, 64, 67], 4)` is 64, the item at an index, wrapping round.
- `pick([60, 63, 67])` is one item of a list or a range.
- `chance(0.45)` is true about 45 times in 100.
- `between(0.6, 0.95)` is a number from 0.6 up to 0.95, rounded to two decimals so `mx.print` stays readable.
- `clamp(12, 2, 11)` keeps a number from 2 up to 11, so it is 11.
- `cents(386)` is an interval in cents as semitones, 3.86.
- `ratio(5 / 4)` is the interval of a frequency ratio in semitones, also 3.86, so `note(60 + ratio(5 / 4), 1)` sounds a just major third above middle C, at 327.0 Hz, and `ratio(2)` is 12. Cents and ratios come from sapf, the sound language by SuperCollider's author, which writes `386c` and `5/4` as numbers.
- Random numbers drawn while the music is built are seeded from the song file, so it plays the same notes on every load, and random numbers in a loop's pass are seeded from the part's name and the pass number, so a pass plays the same notes every time it runs.

## Timing

Every part starts on the same beat when mx starts, and all parts share one tempo.
Each part plays in its own process.
A pass works out its notes before they play, and mx sends them to mxs half a second ahead, stamped with the time of their beat.
The time of each beat is counted from the start of playing, so parts never drift from the tempo or from each other.
A tempo change written in the music starts on its beat, for every part at once.
Saving the song with a new `song(tempo:)` starts that tempo on the first whole beat after the notes already sent; saving it with the same one keeps the tempo the music has changed to.
A pass that takes longer than that half second to work out is late: mx drops its notes that are more than a quarter of a beat late, sends the rest, and prints a warning naming the part and how many notes it dropped. The part plays on, and its next pass is on time once it catches up.

## Live audio and sample rates

mx reads the sound card's input only when the song it starts with has `live_audio`, so other songs never touch the microphone; a `live_audio` added while playing needs mx restarted.
mxs cannot start with input on when the input and output devices run at different sample rates, as Bluetooth headphones at 24 kHz beside speakers at 48 kHz do.
mx then stops with a message naming the device and the rates it runs at; set both to the same rate in Audio MIDI Setup, or use other devices.
macOS may ask once whether the terminal can use the microphone.

## Sample names

These are the names of the samples in Sonic Pi's pack, from release v5.0.0; see the pack's README.md in its folder for where each comes from.

ambi_choir, ambi_dark_woosh, ambi_drone, ambi_glass_hum, ambi_glass_rub, ambi_haunted_hum, ambi_lunar_land, ambi_piano, ambi_sauna, ambi_soft_buzz, ambi_swoosh, arovane_beat_a, arovane_beat_b, arovane_beat_c, arovane_beat_d, arovane_beat_e, bass_dnb_f, bass_drop_c, bass_hard_c, bass_hit_c, bass_thick_c, bass_trance_c, bass_voxy_c, bass_voxy_hit_c, bass_woodsy_c, bd_808, bd_ada, bd_boom, bd_chip, bd_fat, bd_gas, bd_haus, bd_jazz, bd_klub, bd_mehackit, bd_pure, bd_sone, bd_tek, bd_zome, bd_zum, drum_bass_hard, drum_bass_soft, drum_cowbell, drum_cymbal_closed, drum_cymbal_hard, drum_cymbal_open, drum_cymbal_pedal, drum_cymbal_soft, drum_heavy_kick, drum_roll, drum_snare_hard, drum_snare_soft, drum_splash_hard, drum_splash_soft, drum_tom_hi_hard, drum_tom_hi_soft, drum_tom_lo_hard, drum_tom_lo_soft, drum_tom_mid_hard, drum_tom_mid_soft, elec_beep, elec_bell, elec_blip, elec_blip2, elec_blup, elec_bong, elec_chime, elec_cymbal, elec_filt_snare, elec_flip, elec_fuzz_tom, elec_hi_snare, elec_hollow_kick, elec_lo_snare, elec_mid_snare, elec_ping, elec_plip, elec_pop, elec_snare, elec_soft_kick, elec_tick, elec_triangle, elec_twang, elec_twip, elec_wood, glitch_bass_g, glitch_perc1, glitch_perc2, glitch_perc3, glitch_perc4, glitch_perc5, glitch_robot1, glitch_robot2, guit_e_fifths, guit_e_slide, guit_em9, guit_harmonics, hat_bdu, hat_cab, hat_cats, hat_gem, hat_gnu, hat_gump, hat_hier, hat_len, hat_mess, hat_metal, hat_noiz, hat_psych, hat_raw, hat_sci, hat_snap, hat_star, hat_tap, hat_yosh, hat_zan, hat_zap, hat_zild, loop_3d_printer, loop_amen, loop_amen_full, loop_breakbeat, loop_compus, loop_drone_g_97, loop_electric, loop_garzul, loop_industrial, loop_mehackit1, loop_mehackit2, loop_mika, loop_perc1, loop_perc2, loop_safari, loop_tabla, loop_weirdo, mehackit_phone1, mehackit_phone2, mehackit_phone3, mehackit_phone4, mehackit_robot1, mehackit_robot2, mehackit_robot3, mehackit_robot4, mehackit_robot5, mehackit_robot6, mehackit_robot7, misc_burp, misc_cineboom, misc_crow, perc_bell, perc_bell2, perc_door, perc_impact1, perc_impact2, perc_snap, perc_snap2, perc_swash, perc_swoosh, perc_till, ride_tri, ride_via, sn_dolf, sn_dub, sn_generic, sn_zome, tabla_dhec, tabla_ghe1, tabla_ghe2, tabla_ghe3, tabla_ghe4, tabla_ghe5, tabla_ghe6, tabla_ghe7, tabla_ghe8, tabla_ke1, tabla_ke2, tabla_ke3, tabla_na, tabla_na_o, tabla_na_s, tabla_re, tabla_tas1, tabla_tas2, tabla_tas3, tabla_te1, tabla_te2, tabla_te_m, tabla_te_ne, tabla_tun1, tabla_tun2, tabla_tun3, tbd_fxbed_loop, tbd_highkey_c4, tbd_pad_1, tbd_pad_2, tbd_pad_3, tbd_pad_4, tbd_perc_blip, tbd_perc_hat, tbd_perc_tap_1, tbd_perc_tap_2, tbd_voctone, vinyl_backspin, vinyl_hiss, vinyl_rewind, vinyl_scratch.
