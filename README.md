# mx

Music written as Elixir code, and changed while it plays.
mx is inspired by Sonic Pi, and makes sound with mxs, its own sound engine in Rust.

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

`examples/tranquility_base.exs` is made only of public recordings, with no synth: VCSL's drums play as sampled instruments, choosing strengths and alternating takes, its ocean drum and wine glasses play normalized underneath, and NASA's Apollo and Sputnik recordings are cut at seconds, stuttered, reversed and fitted to the beat over it. It needs two of VCSL's folders downloaded once, 1.5 GB together, and NASA's recordings ship beside it:

```sh
mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones"
mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Membranophones"
mx examples/tranquility_base.exs
```

`examples/ambient.exs` is a demo to start from, a slow ambient piece of pads, keys, bells and samples through reverb and echo:

```sh
mx examples/ambient.exs
```

`examples/salsa.exs` is a salsa band played only on mx's own synths: son clave, a tumbao on bass and congas, a piano montuno, cáscara and cowbell, a horn section on filtered supersaws, and solos by the piano and the horns.

```sh
mx examples/salsa.exs
```

`examples/choro.exs` is a Brazilian choro in 2/4, in the form A A B B A C C A: a flute running in sixteenths, cavaquinho strumming, the 7-string guitar's bass lines, and pandeiro.

```sh
mx examples/choro.exs
```

`examples/odeon.exs` is the first strain of Ernesto Nazareth's Odeon, a tango brasileiro of 1909 in the public domain, played slowly by a choro regional on mx's measured synths: the trombone sings the pianist's low left-hand melody and the flute answers, then the cello and the tenor saxophone repeat it, over the 7-string guitar, cavaquinho, pandeiro and shaker, every stroke swinging a little off the beat.

```sh
mx examples/odeon.exs
```

`examples/caboclinho.exs` is a caboclinho of Pernambuco in 2/4 on mx's measured synths: the toques guerra, perré, baião and macumba do índio in turn, with the flute as the gaita on a neutral third, the ganzá and the shaker as the caracaxás, the bongos as the tarol and the preacas, and the cajón as the atabaque.

```sh
mx examples/caboclinho.exs
```

`examples/caboclinho_modern.exs` makes it a bit more modern, as Recife's mangue beat did with its folk rhythms: the same gaita and terno over a drum kit and a saw bass, the gaita through a chorus and a ping-pong echo, the preacas through a bitcrusher, a ganzá band-passed and the shaker flanged, and in macumba do índio the kit drops out under a wobbling bass and an atabaque bouncing between the sides.

```sh
mx examples/caboclinho_modern.exs
```

`examples/meditation.exs` is a slow meditation in raga Bhupali, tuned to Sa as just intervals, on mx's measured synths: the harp plucking a tanpura's drone, the organ breathing Sa and Pa, and the flute through alap, jor and a gat in teentaal with the bongos as tabla and the ganzá as ankle bells, ending on a tihai.

```sh
mx examples/meditation.exs
```

`examples/raga.exs` is raga Yaman on the tanpura, the sitar and the tabla, laid out as a Hindustani recital: one drone held from the first beat to the last, a slow alap with meend, a jor to a steady pulse, and a gat with the tabla's theka in teentaal. The gat is a composition V. N. Bhatkhande notated in his Kramik Pustak Malika, "Yaman–Trital (Madhyalay)" on page 33 of the second book, played as the book writes it, from khali, with its grace notes and its meend, and tuned to Sa in cents. The sitar plays it as a sitarist would: each pluck rings until the next, the other notes of a matra and its glides are fingered on the ringing string, and the chikari strings strike Sa between the notes.

```sh
mx examples/raga.exs
```

`examples/midnight.exs` is a hypnotic piece in raga Darbari Kanada, the grave raga of midnight, on mx's measured synths: the tanpura and the organ's stopped flute drone under the oboe, which plays as a shehnai with meend, kan and andolan on Ga and Dha, while the harmonium answers its phrases plainly. In the gat the tabla plays teentaal with its dayan tuned to Sa, the güiro scrapes and then plays the cha-cha-chá, the claves play son clave, and two pianos phase as in Steve Reich's Piano Phase, one drifting a sixteenth ahead each pass until they meet again in unison as the tihai lands on the sam of shanti.

```sh
mx examples/midnight.exs
```

`examples/solo/piano.exs` is the piano on its own: a sweep from its lowest note to its highest, chords played softly and then hard, runs over a bass, and its lowest and highest notes at the hardest and the softest.

```sh
mx examples/solo/piano.exs
```

`examples/piano/clair_de_lune.exs` is Debussy's Clair de lune of 1905, in the public domain, played whole on the piano from the Mutopia Project's engraving: the melody voiced over the inner notes, the pedal changing with the bass, and the bars stretched and pressed by the rubato its markings ask for, from pianissimo to the forte of bar 41 and back to a morendo.

```sh
mx examples/piano/clair_de_lune.exs
```

`examples/solo/marimba.exs` is the marimba on its own: a sweep from its lowest bar to its highest, a melody rolled by two mallets over ringing bass bars, the same arpeggio on its low bars and its high ones, and a last chord.

```sh
mx examples/solo/marimba.exs
```

`examples/solo/vibraphone.exs` is the vibraphone on its own: chords left to ring with the pedal, the same chords with the motor turning, a line of short damped notes, and a last chord.

```sh
mx examples/solo/vibraphone.exs
```

`examples/solo/xylophone.exs` is the xylophone on its own: runs over two octaves in sixteenths, a note struck every sixteenth as a melody moves under it, a melody on its brightest bars, and a run up to its top bar.

```sh
mx examples/solo/xylophone.exs
```

`examples/solo/glockenspiel.exs` is the glockenspiel on its own: a melody high in its range, each note damped as the next one comes, then a chord struck one bar at a time and left to ring, and an arpeggio up to its top bar.

```sh
mx examples/solo/glockenspiel.exs
```

`examples/solo/harp.exs` is the harp on its own: a joropo in A minor, the bass in 3/4 under arpeggios in 6/8, then chords left to ring, and a last arpeggio.

```sh
mx examples/solo/harp.exs
```

`examples/solo/violin.exs` is the violin on its own, in D minor: a cantabile slurred in groups whose long notes swell and ease, bariolage against the open A string as in the Preludio of Bach's Partita No. 3, the melodic minor slurred eight notes to a bow and arpeggios in short notes, chords plucked down to the open G, and a climb on audible shifts to a long D7 with vibrato.

```sh
mx examples/solo/violin.exs
```

`examples/solo/viola.exs` is the viola on its own, in C minor: a cantabile low on its C and G strings whose long notes swell and ease, measured tremolo growing from soft to loud, arpeggios from the low C slurred four notes to a bow across the strings, plucked chords, and the melody an octave higher settling on the low C.

```sh
mx examples/solo/viola.exs
```

`examples/solo/bassoon.exs` is the bassoon on its own: a song-like melody in B flat in its tenor register, a walking bass line low in its range, a comic tune in short detached notes, and the melody again, closing on its low B flat.

```sh
mx examples/solo/bassoon.exs
```

`examples/solo/cello.exs` is the cello on its own, in G major: the opening bars of the Prelude of Bach's Cello Suite No. 1 broken across the strings, a cantabile climbing to the A string on audible shifts with its long notes swelled, a plucked walking bass, and a climb to a long high D falling back to the low G.

```sh
mx examples/solo/cello.exs
```

`examples/solo/double_bass.exs` is the double bass on its own: a plucked walking line through a twelve-bar blues in F, then a slow melody over its low strings slurred in swelled bows, and a last walk down to its low F, bowed, held and swelled.

```sh
mx examples/solo/double_bass.exs
```

`examples/solo/flute.exs` is the flute on its own: Debussy's Syrinx, from its first edition of 1927, each breath of the score one held note that its later notes move, and the notes that start a slur tongued.

```sh
mx examples/solo/flute.exs
```

`examples/solo/clarinet.exs` is the clarinet on its own: a dark melody in G minor low in its range, fast arpeggios through its registers, the melody again higher up, and a last phrase high in its range, loud.

```sh
mx examples/solo/clarinet.exs
```

`examples/solo/oboe.exs` is the oboe on its own: a pastoral melody in F major, a dance in short detached notes, a climb through its range from its low B flat to F6, and the melody again an octave up.

```sh
mx examples/solo/oboe.exs
```

`examples/solo/tenor_sax.exs` is the tenor saxophone on its own: a choro melody in F major with its runs in sixteenths, a slow phrase with vibrato, the same phrase at its softest and then its loudest, and a last run down to its low A flat.

```sh
mx examples/solo/tenor_sax.exs
```

`examples/solo/trumpet.exs` is the trumpet on its own: a fanfare call in Bb major, tongued short and answered, then a fourth higher, a lyrical phrase with vibrato, the call at its loudest with a soft echo, and a last climb to a held Bb5.

```sh
mx examples/solo/trumpet.exs
```

`examples/solo/trombone.exs` is the trombone on its own: a legato melody in F major whose notes glide into each other as the slide moves, then a fourth lower, a march in short notes, a long note at its softest and then its loudest, and a last glide from F2 up to F4.

```sh
mx examples/solo/trombone.exs
```

`examples/solo/horn.exs` is the French horn on its own: a broad melody in Eb major, then again an octave lower, hunting calls answered a fourth lower, a long note at its softest and then its loudest, and a run down to a held low Eb2.

```sh
mx examples/solo/horn.exs
```

`examples/solo/tuba.exs` is the tuba on its own: an oom-pah bass in Bb major in short notes, then a walking bass under the same chords, a melody high in its range, a long note at its softest and then its loudest, and a run down to a held low F1.

```sh
mx examples/solo/tuba.exs
```

`examples/solo/organ.exs` is the organ on its own: chords held over a walking bass on its quiet set, then on its loud set, and a last chord on both.

```sh
mx examples/solo/organ.exs
```

`examples/solo/agogo.exs` is the agogô on its own: a samba bell pattern, a partido alto one, a maracatu figure, eighths across both bells with accents, and four more samba patterns.

```sh
mx examples/solo/agogo.exs
```

`examples/solo/ganza.exs` is the ganzá in four samba patterns of sixteenths, down and up strokes, with the large shaker in eighths under it.

```sh
mx examples/solo/ganza.exs
```

`examples/solo/pandeiro.exs` is the pandeiro on its own, in choro, samba de roda, baião, forró and coco de embolada.

```sh
mx examples/solo/pandeiro.exs
```

`examples/pandeiro/virtuoso.exs` is a pandeiro solo whose hand never stops rocking: a coco groove and its ruffs, then accents every three and every five sixteenths that cross the bar line, and every fourth stroke of sextuplets.

```sh
mx examples/pandeiro/virtuoso.exs
```

`examples/solo/cabasa.exs` is the cabasa on its own, in the steady sixteenths of bossa nova, accenting each beat, then the bossa nova figure, then turning the beads on it.

```sh
mx examples/solo/cabasa.exs
```

`examples/solo/bongos.exs` is the bongos on their own: the martillo, with the hembra's open tone on its seventh stroke, then with heel-tip strokes, and a fill across both drums.

```sh
mx examples/solo/bongos.exs
```

`examples/surdo/solo.exs` is the three surdos of a samba bateria on their own, in 2/4: the surdo de primeira holds the marcação, muted on the first beat of each bar and open on the second, the surdo de segunda answers it open on the first beat, and the surdo de terceira cuts across them in sixteenths.

```sh
mx examples/surdo/solo.exs
```

`examples/cuica/solo.exs` is the cuíca on its own, its part in a samba batucada in 2/4: strokes on sixteenths accented off the beat, the accents then raised a fourth as the thumb presses the head, and runs of seven sixteenths that swell into a raised accent.

```sh
mx examples/cuica/solo.exs
```

`examples/tamborim/solo.exs` is the tamborim on its own, its parts in a samba batucada in 2/4: the teleco-teco, a two-bar figure of sixteenths off the beat, the carreteiro striking every sixteenth with the teleco-teco's strokes accented, and a virada that closes a phrase with a run of thirty-seconds swelling into an accent.

```sh
mx examples/tamborim/solo.exs
```

`examples/caxixi/solo.exs` is the caxixi on its own, shaken with each of the berimbau's strokes in two of capoeira's toques: in angola it leans on the open note after two buzzes, and in são bento grande on the first buzz of each pair and the open note that closes the phrase.

```sh
mx examples/caxixi/solo.exs
```

`examples/solo/cajon.exs` is the cajón on its own in a festejo of mx's own in 12/8, with bass tones, slaps and ghost strokes.

```sh
mx examples/solo/cajon.exs
```

`examples/solo/timpani.exs` is the timpani on its own: a roll on A2 that swells from soft to loud, the tonic and dominant pounded in turn, a melody on five drums tuned to D major, the same melody at its softest, and a roll on D3 that ends on a loud stroke left to ring.

```sh
mx examples/solo/timpani.exs
```

`examples/solo/congas.exs` is the three congas on their own: a tumbao on the conga and the tumba, the same with a slap answered on the quinto, a solo on the quinto over muted strokes, the tumbao at its softest, and a run down the three drums to a last slap.

```sh
mx examples/solo/congas.exs
```

`examples/solo/tambourine.exs` is the tambourine on its own, played its standard ways: a shake roll that starts and ends on a stroke, the pop and soul backbeat shaken in eighths and struck on two and four, a tarantella in continuous 6/8 triplets, soft fingertip strokes, and a roll that grows into a last stroke.

```sh
mx examples/solo/tambourine.exs
```

`examples/solo/triangle.exs` is the triangle on its own, played its standard ways: single strokes left to ring, strokes the hand damps at once, a roll inside one corner, and the forró triangle of the baião, open on the third sixteenth of each beat and closed on the others.

```sh
mx examples/solo/triangle.exs
```

`examples/solo/claves.exs` is the claves on their own, playing the standard clave patterns: son clave 3-2 and 2-3, rumba clave, the bossa nova clave, and the 6/8 standard bell of bembé.

```sh
mx examples/solo/claves.exs
```

`examples/solo/cowbell.exs` is the cowbell on its own, playing the campana, the bongocero's bell in salsa, in its two 2:3 patterns: the second gear, with the 3 side's first two strokes open and hard, and the standard third gear, open on each half bar and closed between.

```sh
mx examples/solo/cowbell.exs
```

`examples/solo/guiro.exs` is the güiro on its own: long, slow scrapes, the cha-cha-chá's long scrape and two short ones, son's long-short-short-long, Puerto Rican bomba's three short scrapes before a long one, and a last long scrape.

```sh
mx examples/solo/guiro.exs
```

`examples/solo/tanpura.exs` is the tanpura on its own: Pa, Sa, Sa and the low Sa plucked in turn, the first and the last given two beats, in a slow drone on C sharp, the same drone plucked quicker, two short drones on a low E, and a long, slow drone on C sharp.

```sh
mx examples/solo/tanpura.exs
```

`examples/solo/tabla.exs` is the tabla on its own in teentaal: its theka, with the khali, beats 9 to 12, played without the bayan, a faster variation splitting each beat in two, and the theka with the bayan bent upwards while it rings.

```sh
mx examples/solo/tabla.exs
```

`examples/solo/berimbau.exs` is the berimbau on its own as a capoeira roda plays it: the toque of Angola with three of its variations, São Bento Pequeno, São Bento Grande speeding up from 150 to 172 bpm, and Benguela to calm the game, each toque ending its bar on two quick buzzed strokes, at the tempo and spacing of a public-domain recording of Angola.
Its strokes move a little off the beat and in strength from bar to bar, as much as that recording's do.

```sh
mx examples/solo/berimbau.exs
```

`examples/solo/sitar.exs` is the sitar on its own in raga Yaman, tuned to Sa C sharp in cents: a slow alap that glides between notes on one pluck, then a gat in teentaal, low and high on the string, with long notes and quick runs.

```sh
mx examples/solo/sitar.exs
```

`examples/solo/harmonium.exs` is the harmonium on its own in raga Bhairav, tuned to Sa G in cents: the left hand holds Sa an octave down while the right plays the ascent and descent, the pakad, a phrase dipping below Sa, one high in the upper octave, and an ending on Sa.

```sh
mx examples/solo/harmonium.exs
```

`examples/solo/accordion.exs` is the accordion's right hand on its own, a bal-musette waltz in A minor: a low theme with the musette reeds beating, the theme an octave up played short and dry on one reed, the waltz's chords struck on the first beat and short on the second and third, and the theme again with an ending on a long A.

```sh
mx examples/solo/accordion.exs
```

`examples/solo/drums.exs` is the drum kit on its own: a rock beat that opens on a crash, the hi-hat opening and the pedal closing it, ghost notes on the snare between its hardest strokes, a fill down the toms, and a crash that is choked.

```sh
mx examples/solo/drums.exs
```

`examples/guitar/` shows the guitar on its own: `fingerpicking.exs` lets each string ring until it is plucked again, `bass_line.exs` walks the low strings of a 7-string guitar, and `soft_and_hard.exs` plays one phrase softly, normally and hard.

```sh
mx examples/guitar/fingerpicking.exs
```

To see what each part plays without hearing it, from a clone of mx:

```sh
mix mx.print song.exs
```

## Import a score

`mix mx.import` turns a MusicXML score into a song, so a piece need not be typed in by hand.
MusicXML is the file format notation programs such as MuseScore, Sibelius and Finale export, and collections such as music21's corpus ship.
`examples/wachet_auf/bwv140.7.mxl` is Bach's chorale "Wachet auf, ruft uns die Stimme", BWV 140/7, from music21's corpus:

```sh
mix mx.import examples/wachet_auf/bwv140.7.mxl --tempo 72 --part "Soprano=oboe" --part "Alto=clarinet" --part "Tenor=viola" --part "Bass=bassoon" --out examples/wachet_auf/chorale.exs
mx examples/wachet_auf/chorale.exs
```

It reads compressed `.mxl` files and uncompressed `.musicxml` and `.xml` files, and writes the song beside the score, or to `--out`; a song that exists is refused unless you add `--force`.
Each part becomes a part of the song named after it, `--part "Soprano=oboe"` plays a part on a synth, and a part without one plays on tri.
mx prints each part's synth, how many notes it has, and its lowest and highest note.
`--tempo` sets the beats per minute, and without it the song takes the score's first metronome mark; a score without one needs `--tempo`.
A beat is a quarter note whatever the time signature, so a dotted quarter in 6/8 lasts 1.5 beats.

The song plays the score once, and ends.
Each part's bars are written in a module of their own, one to a line, as the bar's number and its music: `def bar(1), do: seq(eb4: 1, g4: 1, bb4: 1.5, bb4: 0.5)` is the soprano's first bar, and a bar of several voices plays them `together`.
Its modules are named after the song file and the part, such as `Chorale.Soprano`, so two imported songs with parts of one name load side by side.
A note tied over a bar line sounds for the whole tie, given as its sustain, and the note it ties into is a rest.
Notes play at vel 0.6, and a dynamic such as f sets how hard the notes after it in its voice play: pp at vel 0.3, p 0.45, mp 0.5, mf 0.6, f 0.8 and ff 1.
`order` lists the bars in the order the score plays them, its repeats and first and second endings taken, so the chorale plays bars 1 to 8 twice and then bars 9 to 18, and a bar that differs between its times through is written once for each.
Notes sound at the pitch they sound in the score, so a clarinet in Bb written on D5 plays C5.
A part whose bar is written shorter than the others' rests to the end of it, and notes written past the end of the time signature's bar are cut there, so the parts stay in time.
Grace notes, ornaments, articulations, fermatas, lyrics and tempo changes after the first are left out.

The song is ordinary mx code, so it is a place to start: give the bass a second part an octave down, add reverb, or hand it to an agent to arrange.

`examples/erbarme_dich/bwv244.39.mxl` is Bach's aria "Erbarme dich, mein Gott", BWV 244/39, from MuseScore, and takes its tempo from the score:

```sh
mix mx.import examples/erbarme_dich/bwv244.39.mxl --part "Violin=violin" --part "Alto=oboe" --part "Organo a canne=organ" --out examples/erbarme_dich/aria.exs
mx examples/erbarme_dich/aria.exs
```

Its D.S. al Fine is not taken, so the aria ends at bar 46 without going back to the opening ritornello.

`examples/erbarme_dich/dub.exs` turns the aria into a roots dub: a dub siren and the hand drums open it and the horns state its opening sigh, then the ritornello is the riddim, the drum kit leading with the one drop, ghost strokes and rolls over the congas playing Nyabinghi drums, the shaker and the güiro, the harp's skank and the organ's bubble over the continuo's bass; a trombone leads with the ritornello, slurring its runs, the harmonium and the horns sing the alto's phrase, and in the dubs the parts drop out into echo and filter sweeps, the tabla's bayan and the tanpura's drone:

```sh
mx examples/erbarme_dich/dub.exs
```

## Scan a score

`mix mx.scan` reads the music on a scanned score into MusicXML, ready for `mix mx.import`.
It runs Audiveris, an open source optical music recognition program, which is installed apart from mx as [documentation/audiveris.md](documentation/audiveris.md) describes, along with poppler for PDFs.
`examples/bin_ich_gleich/page.pdf` is a page of the Bach-Gesellschaft's edition of the St Matthew Passion, scanned from print, holding the chorale "Bin ich gleich von dir gewichen":

```sh
mix mx.scan examples/bin_ich_gleich/page.pdf --out examples/bin_ich_gleich/chorale.mxl
mix mx.import examples/bin_ich_gleich/chorale.mxl --tempo 72 --part "Flauto trawrso 1.11=flute" --part "Voice=violin" --part "Tenore=viola" --part "Basso=bassoon" --part "Orgnno e Continue=cello"
mx examples/bin_ich_gleich/chorale.exs
```

It reads a PDF, or a single page as a PNG, JPEG or TIFF image, and writes the MusicXML beside it, or to `--out`; a file that exists is refused unless you add `--force`.
`--pages 3-4` reads only those pages of a PDF, numbered as the PDF numbers them, and `--pages 5` reads one.

Before recognition it prepares each page the way Audiveris asks:

- It renders a PDF page at the resolution that puts its staff lines 20 pixels apart, measured on the page, and scales an image to the same.
- It turns the page to grayscale and leaves black and white to Audiveris.
- It crops the scanner bed and a neighbouring page off, and evens yellowed or unevenly lit paper to white.
- On paper still gray after that, as where ink shows through from the other side, it fades what is paler than the ink, keeping the thin sharp strokes such as faint staff lines.
- It turns a tilted page until its staff lines are level.

The prepared pages go in a folder beside the MusicXML, here `examples/bin_ich_gleich/chorale-pages`, with Audiveris's book of each page and its logs, so you can see what recognition was given, and open a book in Audiveris to correct it.
`--raw` gives Audiveris the pages as they are, to compare.
mx prints each page's staff line spacing before and after, how many degrees it was turned, and how many bars Audiveris read on it, names a page it read no music on, and prints the `mix mx.import` command with a `--part` for each part found.
The parts of every page are joined in page order, a page's parts matched to the first page's in order.

Recognition is not exact, so listen to the song against the page.
On the chorale, Audiveris finds the bass and tenor's notes nine times in ten and eight in ten, but misses the key signature after the soprano clef, so the flute plays naturals where the score has sharps; the part names are as it read them, misspellings included.
It reads no handwritten scores, such as Bach's autographs.

`--model` reads the music with a transcription model instead of Audiveris, which suits printed piano music, and photographs and photocopies of it, far better:

```sh
mix mx.scan rag.pdf --model
```

It cuts each prepared page into its systems, the staves a bar line joins, writes each 1400 pixels wide to the pages folder, transcribes them one by one into ABC notation, kept beside each system, and joins them into one score.
mx prints how many systems it found on each page, in place of the bars.
The model is rokot-omr-2b, free for non-commercial use under CC BY-NC 4.0, and reads a system of one part, of up to two staves, so it does not suit choral or orchestral scores such as the chorale.
It runs in Python inside mx through Pythonx: the first run installs Python and its packages with uv and downloads the model's 4.3 GB from Hugging Face, and needs no Audiveris.
`MX_TRANSCRIBER_MODEL` names another Hugging Face model or a local folder to use instead.
It takes about 7 seconds a system on an Apple silicon GPU.
On three pages of the Maple Leaf Rag it finds 94 notes in 100 both on the clean engraving and on a photograph of it, where Audiveris finds 97 and 23, and on a bad photocopy it finds 43.
`--raw` does not go with `--model`, which cuts the systems out of prepared pages.

## Turn a hum into a song

`mix mx.hum` turns a recording of a melody you hum, sing or whistle into a song, so a tune you can't name the notes of can still get into mx:

```sh
mix mx.hum hum.wav --tempo 90
mx hum.exs
```

It reads WAV and AIFF files, mono or stereo, at any sample rate, and writes the song beside the recording, or to `--out`; a song that exists is refused unless you add `--force`.
`--tempo` is the tempo you hummed at, and is needed, since mx doesn't work out the tempo: hum against a click or a song you know, and give its tempo.
mx prints where it wrote the song, how many notes it found, and their lowest and highest note.

The song has one part, hum, on tri, playing the melody again and again as a `seq` of note names and rests, such as `seq(c3: 1, c3: 1, g3: 1, g3: 1, a3: 1, a3: 1, g3: 2)`.
Each note is the semitone nearest the pitch you held, in the octave you hummed it: a note held with vibrato or a wobble is one note, at the pitch it centres on, and a slide is the note it starts on and the note it lands on.
A break in the voice between two notes at one pitch makes them two notes; breath, clicks and noise are not notes.
The first note starts on beat 0, and every note starts and lasts a whole number of quarter beats.
A sound shorter than an eighth of a beat is left out, a silence of a quarter beat or less before the next note is a breath and joins the notes, and a longer one is a rest.
The melody lasts until the end of the bar of 4 beats its last note ends in.
It follows pitch from 60 Hz to 2500 Hz, from a low hum to a high whistle, and one voice at a time; words, chords and the key are left out.

`mix mx.hum --record hum.wav --tempo 90` records the hum for you, against a click:

```sh
mix mx.hum --record hum.wav --tempo 90
```

It plays a click at the tempo, a bar of 4 beats to count you in and then every beat, louder on the first beat of each bar, and records the sound card's first input until you press Enter; `--input 2` records another input.
It then prints how long the recording is and turns it into `hum.exs` as above, with beat 0 on the first beat after the count-in, so a melody you start on beat 1 begins with a rest of a beat.
A note you hum during the count-in is left out, and mx says how many were.
Use headphones, so the click stays out of the microphone; the click has no pitch, so a click the microphone picks up from speakers is not a note, but it can hide a quiet one.
A recording or song that exists is refused before the first click unless you add `--force`, and so is a folder that does not exist, and an input that runs at another sample rate than the output, such as Bluetooth headphones' microphone, naming both devices and their rates.

The song is text, so it is a way to hand a tune to an agent: hum the idea, run `mix mx.hum`, and ask an agent to build on `hum.exs`, harmonizing the melody, giving it a bass line and drums, or setting it on another synth.
The agent reads and writes the notes as mx code, and `mix mx.print hum.exs` shows them with their beats.

## The notation

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

### Notes and music

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

### Parts and the song

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

### Loops

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

### Samples, MIDI, OSC, shared values and changes

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

### Helpers

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

### Timing

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

## Synths

accordion, acid, bandolim, bassoon, berimbau, brass, cabasa, cajon, cavaquinho, caxixi, cello, clap, clarinet, clave, closed_hihat, cowbell, crash, cuica, double_bass, flute, fm, ganza, glockenspiel, guiro, guitar, harmonium, harp, high_agogo, high_bongo, high_conga, high_timbale, high_tom, horn, kick, low_agogo, low_bongo, low_conga, low_timbale, low_tom, marimba, mid_conga, mid_tom, noise, oboe, open_hihat, organ, pandeiro, pandeiro_heel, pandeiro_jingles, pandeiro_slap, pandeiro_thumb, piano, pluck, pulse, rimshot, saw, shaker, sitar, snare, square, supersaw, surdo, tabla, tabla_ghe, tabla_ke, tabla_na, tabla_tas, tabla_te, tabla_tun, tamborim, tambourine, tambourine_shake, tanpura, tenor_sax, timbale_shell, timpani, tri, triangle, trombone, trumpet, tuba, vibraphone, viola, violin, xylophone.

They are mx's own designs, in mxs's `src/synths`.
mx ships none of Sonic Pi's synths, its sc808 drum kit or its effects.

mx's own synths take `note`, `amp`, `pan`, `attack`, `decay`, `sustain`, `release`, `attack_level`, `decay_level` and `sustain_level`, and slides for `note`, `amp` and `pan`.
- `saw`, `square`, `tri`, `pulse`, `noise`, `supersaw` and `acid` take `cutoff`, a MIDI note number, and `res`, the filter's resonance from 0 to 1, with slides.
- `pulse` takes `pulse_width`, `fm` takes `divisor`, which sets the modulator to the note's frequency divided by it, and `depth`, and `supersaw` takes `detune` in semitones, each with a slide.
- `pluck` takes `ring`, how many seconds the string rings, and `coef`, from -1 to 1, where higher is duller.
- `piano`, `brass`, `flute`, `guitar`, `cavaquinho` and `bandolim` take `vel`, from 0 to 1, how hard the note is played: harder is louder and brighter. A piano note rings on for its `sustain` and fades over its `release`, like a held key; the piano is measured from the Steinway B grand of the Versilian Community Sample Library, from A0 to C8. The piano's `pedal: 1` plays a note with the sustain pedal down, so the strings that share its harmonics ring with it, as on the Steinway's recordings with the pedal; `pedal` defaults to 0 and can differ per note of a chord.
- `marimba` takes `vel`, from 0 to 1: harder is louder, and brings out the overtones the bars are tuned to. A note rings until it fades by itself, the low bars for seconds and the high ones for a fraction of one, unless `sustain` and `release` damp it; the marimba is measured from the University of Iowa's marimba struck with yarn mallets, from F1 to C7.
- `vibraphone` takes `vel` as the marimba does, and `motor`, how many times per beat the motor's pulse comes round, 0 by default, which stops it. A note rings for many seconds unless `sustain` and `release` damp it, as the pedal does; the vibraphone is measured from the University of Iowa's vibraphone, from C3 to F6, played with the motor off.
- `xylophone` takes `vel` as the marimba does. A note is short and bright, and fades by itself in about a second at the bottom and a tenth of a second at the top; the xylophone is measured from the University of Iowa's xylophone struck with rosewood mallets, from F4 to C8.
- `glockenspiel` takes `vel` as the marimba does. A note rings for many seconds unless `sustain` and `release` damp it; the glockenspiel is measured from the University of Iowa's orchestral bells struck with plastic mallets, from C5 to E8.
- `harp` is a folk harp, the kind the Paraguayan and llanera harps are; it takes `vel` as the guitar does. A string rings for many seconds unless `sustain` and `release` damp it; the harp is measured from the folk harp of the Versilian Community Sample Library, from C2 to G#6.
- `violin` takes `vel` as the guitar does, `vibrato` as the flute does, 0.25 by default, and `pizz: 1` to pluck the string instead of bowing it. A bowed note swells in over a fraction of a second, slower the softer it is played, and holds for its `sustain`; a plucked note rings until it fades by itself, unless `sustain` and `release` damp it. A bowed note is a model of a bowed string, a waveguide after McIntyre, Schumacher and Woodhouse (1983) and Julius O. Smith III's digital waveguides, and follows its note as it changes, so notes slurred in one bow are one note whose `note` changes. `legato: 1` changes bow from a note still sounding, so the string speaks at once instead of swelling in. `bow_speed` and `bow_force` scale the bow's speed and force at the note's vel, 1 by default, and `bow_position` is where the bow meets the string, as a fraction of its length from the bridge, 0.12 by default. The violin is measured from the University of Iowa's violin, bowed and plucked, from G3 to B7, and VSCO 2's solo violin.
- `viola` takes the same options as `violin`, and is measured from the University of Iowa's viola, bowed and plucked, from C3 to Bb6.
- `cello` takes the same options as `violin`, and is measured from the University of Iowa's cello, bowed and plucked, from C2 to Bb5. At pp and ff a bowed note starts with the first quarter second of one of Iowa's bowed notes under its swell, from the nearest of the six notes recorded at that dynamic, played faster or slower to sound at its pitch; `onset` sets how loud it is against the level its recorded note holds, and 0 leaves it out. mix mx.fit found the onset made the mf notes worse, so at mf it is left out unless `onset` is given. The bow's hiss passes through the cello body's response, measured from the noise Iowa's notes hold between their harmonics.
- `double_bass` takes the same options as `violin`, and is measured from the University of Iowa's double bass, bowed and plucked, from E1 to G4, at the pitch it sounds.
- `organ` is a pipe organ measured from VSCO 2's organ: it takes `loud: 1` for its loud set, a principal chorus, instead of its quiet one, a stopped flute, and no `vel`, since a pipe sounds the same however hard its key is struck; a note holds one level for its `sustain`.
- The winds, `flute`, `clarinet`, `oboe`, `bassoon`, `tenor_sax`, `trumpet`, `trombone`, `horn` and `tuba`, are physical models: the breath drives an air jet, a reed or the lips at the end of a bore as long as the note's period. A change of `note` while a note holds slurs to the new pitch on the same breath, so a phrase written as one note with changes plays legato, and `note_slide` sets how long each slur takes. A change of `vel` while a note holds swells or fades it, louder and brighter as the breath grows, over `vel_slide`: `note(:c5, 4, changes: [{1, note: :d5}, {2, note: :e5, vel: 1, vel_slide: 2}])` slurs C5, D5 and E5 and swells on E5.
- `flute` takes `vibrato`, the depth of the vibrato that grows as a note holds, in semitones, 0.25 by default and shallower the softer the note; 0 turns it off. The flute is measured from the University of Iowa's flute, from B3 to Db7, and VSCO 2's flute.
- `tanpura` plays a drone with its note as Sa: four strings plucked in turn, Pa a fourth below, Sa twice and Sa an octave below, on beats 0, 2, 3 and 4 of a cycle of six gaps, as the Hindustani pattern goes. `gap` is the time between plucks in beats, 0.8 by default; the drone holds for its `sustain`, 16 beats by default, and the strings then ring out over its `release`. `vel` sets how hard the strings are plucked, and it has no vibrato. Each pluck brings the higher harmonics in over the next second, as the jawari, the strings buzzing on the bridge, does. The tanpura is measured from "Tanpura 10" by sankalp on Freesound, a big tanpura on Db3, with each band's harmonics and the noise between them within 6 dB of the recording's from 80 Hz to 16 kHz. Its body is lower the lower its Sa, as a bigger tanpura's is, but it is still 13 to 20 dB brighter than "Tanpura in E" by iluppai, a flat tanpura on E2, from 160 Hz to 1.6 kHz:

```
$ mix mx.measure --held --drone "Tanpura in E.wav:E2" --synth tanpura
band               level     noise     level     noise     level     noise
80-160 Hz        +0.0 dB   -0.1 dB   +0.0 dB   -2.0 dB   +0.0 dB   -1.9 dB
160-250 Hz       -6.7 dB  -22.0 dB   +5.9 dB   +7.9 dB  +12.7 dB  +29.9 dB
250-400 Hz       -3.9 dB   -3.6 dB  +13.0 dB  +21.9 dB  +16.9 dB  +25.5 dB
400-630 Hz      +15.7 dB   +8.1 dB  +10.7 dB   +8.1 dB   -5.0 dB   -0.0 dB
630-1000 Hz      -4.6 dB   +4.8 dB  +10.5 dB  +16.6 dB  +15.2 dB  +11.9 dB
1000-1600 Hz    -12.2 dB   -1.3 dB   +7.4 dB   +7.3 dB  +19.6 dB   +8.6 dB
1600-2500 Hz    -10.5 dB   -7.4 dB  -10.6 dB   +1.3 dB   -0.1 dB   +8.7 dB
2500-4000 Hz    -15.6 dB   +0.4 dB   -8.2 dB   +6.0 dB   +7.4 dB   +5.6 dB
4000-6300 Hz    -22.1 dB   +0.8 dB  -13.5 dB   +3.4 dB   +8.6 dB   +2.6 dB
6300-10000 Hz   -24.9 dB   -0.4 dB  -23.2 dB   +8.2 dB   +1.7 dB   +8.7 dB
10000-16000 Hz  -28.8 dB  -11.9 dB  -28.7 dB   +1.3 dB   +0.0 dB  +13.2 dB
```
- `sitar` plays a plucked sitar note, which rings until it fades by itself, the lowest harmonics for over ten seconds, unless `sustain` and `release` damp it. Its harmonics reach up to 16 kHz at once and the upper ones fade first, as the jawari, the string buzzing on the bridge, makes them. `sa` is the note its sympathetic strings are tuned to, Sa and its octave, C#3 by default; they ring on quietly after a note on Sa or its octave, and much less after other notes. `note_slide` glides from one note to the next on the same pluck, as meend does, and `vel` sets how hard the string is plucked, harder being louder and brighter. The sitar is measured from "sitar01.flac" on Freesound, its first main string plucked from E3 to G#3, with each band from 160 Hz to 4 kHz within 2 dB of the recording's level and fade. Beside "sitar j" by JOHNWALLY, a different sitar struck hard on G4, its harmonics ring for about half as long:

```
$ mix mx.measure "sitar j.wav:G4" --synth sitar
band          recordings          sitar at vel 0.6    difference
250-400 Hz     22.96 s   +0.0 dB   11.16 s   +0.0 dB    -51%   +0.0 dB
630-1000 Hz    24.28 s   -2.7 dB    9.87 s   +5.1 dB    -59%   +7.9 dB
1000-1600 Hz   16.92 s  -12.3 dB    8.47 s   -4.9 dB    -50%   +7.5 dB
1600-2500 Hz    8.31 s   -6.8 dB    5.35 s  -13.2 dB    -36%   -6.5 dB
2500-4000 Hz    6.96 s  -13.3 dB    3.96 s  -12.2 dB    -43%   +1.1 dB
4000-6300 Hz    5.29 s  -20.2 dB    3.61 s  -29.0 dB    -32%   -8.8 dB
6300-10000 Hz   8.94 s  -32.2 dB    2.44 s  -39.2 dB    -73%   -7.0 dB
10000-16000 Hz       -  -39.7 dB
```
- `harmonium` is the reed organ pumped by hand that accompanies Hindustani singing, and takes `vel` as the guitar does; it has no vibrato and holds its note for its `sustain`. Its harmonics stand within 7 dB of the fundamental up to 2.5 kHz and fall away above, with the reeds' breathy noise between them about 27 dB below, and it speaks in about a quarter of a second. It is measured from the "Harmonium" pack by cabled_mess on Freesound, cut from "Harmonium Samples - All Keys and Drones" by donyaquick, at C2, C3, A3, C4 and D5, with every band of harmonics and of noise from 80 Hz to 4 kHz within 1 dB of the recordings', as `mix mx.fit --check` scores it.
- `accordion` is an accordion's right hand, the free reeds pressed by bellows that carry the melody in tango, musette and forró, and takes `vel` as the guitar does; it holds its note for its `sustain`. Each note sounds two reeds, the second `detune` Hz above the first, 4 by default, so they beat about four times a second; `detune: 0` sounds one reed, dry. Its harmonics stand up to 9 dB above the fundamental from 250 Hz to 1 kHz and fall away above 1.6 kHz, with the reeds' noise between them 23 to 37 dB below, and it speaks in about 0.05 seconds. It is measured from "Accordeon master" by hammondman on Freesound, at C3, E3, G3, C4, E4, G4, B4 and D5, with every band of harmonics and of noise from 130 Hz to 4 kHz within 4 dB of the recordings' and its attack within 20 percent, as `mix mx.fit --check` scores it, and its beating compared with "Accordion wav samples" by hammondman.
- `clarinet` is a Bb clarinet at the pitch it sounds, and takes `vel` as the guitar does and `vibrato` as the flute does, 0 by default. Its low notes are hollow, strong in the odd harmonics, and its notes from A4 up are brighter and louder; a soft note is almost a pure tone. The clarinet is measured from the University of Iowa's Bb clarinet, from D3 to C7, and compared with VSCO 2's clarinet.
- `oboe` takes `vel` as the guitar does and `vibrato` as the clarinet does, 0 by default. Its harmonics are loudest around 1.3 kHz whatever the note, which gives it its nasal sound; the oboe is measured from the University of Iowa's oboe, from Bb3 to Ab6, and compared with VSCO 2's oboe.
- `bassoon` takes `vel` as the guitar does and `vibrato` as the clarinet does, 0 by default. Its harmonics are loudest from 400 to 630 Hz whatever the note; the bassoon is measured from the University of Iowa's bassoon, from Bb1 to D5, and its vibrato from VSCO 2's bassoon.
- `tenor_sax` takes `vel` as the guitar does, and `vibrato`, how deep the vibrato that grows as a note holds is, where 1 is the depth of the recordings played with vibrato and 0, the default, plays without it. It is measured from the tenor saxophone of the Versilian Community Sample Library, from Ab2 to E5, at the pitch it sounds; the recordings reach E6, but the design follows the notes below the altissimo register.
- `trumpet` is a Bb trumpet at the pitch it sounds, and takes `vel` as the guitar does and `vibrato` as the flute does, 0 by default. Its harmonics are loudest around 1.2 kHz, and the harder it is played the more its harmonics above 2 kHz come through; it is measured from the University of Iowa's Bb trumpet, from E3 to Eb6, and compared with VSCO 2's trumpet.
- `trombone` is a tenor trombone, and takes `vel` as the guitar does and `vibrato` as the flute does, 0 by default; `note_slide` glides between notes as the slide does. Played soft it is dark and round, and played hard its harmonics above 1 kHz come through; it is measured from the University of Iowa's tenor trombone, from E2 to C5, and its vibrato from VSCO 2's tenor trombone.
- `horn` is a French horn, and takes `vel` as the guitar does and `vibrato` as the flute does, 0 by default. Its harmonics are loudest from 250 to 630 Hz and fall away fast above 1 kHz, so it is round and dark, and played hard it brightens up to about 1.7 kHz; it is measured from VSCO 2's F horn, from C2 to F5, with how loud each note is following the University of Iowa's horn.
- `tuba` takes `vel` as the guitar does and `vibrato` as the flute does, 0 by default. Its harmonics are loudest from 90 to 250 Hz, soft notes are dark and speak quickly, and loud ones brighten and take longer to speak; it is measured from VSCO 2's tuba, from Bb1 to Bb3, plays down to F1, and how loud each note is follows the University of Iowa's tuba.
- `timpani` takes `vel`, how hard the drum is struck: harder is louder and brighter. Its partials stand about 1.49, 1.95, 2.11 and 2.7 times above its note, not at whole multiples, and a stroke rings until it fades unless `sustain` and `release` damp it; it is measured from the five timpani of VSCO 2, from 92 to 190 Hz.
- `guitar` is a nylon-string guitar measured from recordings of a real one, and reaches down to B1, the low string of a 7-string guitar. A note rings until it fades away by itself, the low notes for over ten seconds, unless `sustain` and `release` damp it.
- `cavaquinho` and `bandolim` have steel strings, brighter and shorter.
- `bandolim` takes `tremolo`, how many times a held note is picked per beat; 0 picks it once.

The drums are kick, snare, clap, closed_hihat, open_hihat, low_tom, mid_tom, high_tom, rimshot and the crash cymbal, crash, the tambourine, struck as tambourine or shaken as tambourine_shake, the triangle, triangle, for Latin music cowbell, clave, low_conga, mid_conga, high_conga, low_bongo, high_bongo, low_timbale, high_timbale, timbale_shell, played on the timbale's shell for cáscara, and guiro, for samba and maracatu the surdo, surdo, the cuíca, cuica, the tamborim, tamborim, the agogô's two bells, low_agogo and high_agogo, and the ganza and a large shaker, the cabasa, the cajón, cajon, and for choro the pandeiro, played four ways: pandeiro_thumb for its low tone, pandeiro_jingles, pandeiro_slap and pandeiro_heel, and for Hindustani music the tabla, its dayan played as tabla_na, tabla_tun, tabla_te and tabla_tas and its bayan as tabla_ghe and tabla_ke, and for capoeira the berimbau, berimbau, and the caxixi, caxixi.
- A drum plays its own pitch with `hit()`, or `hit(amp: 0.5)` with options, and takes `note` to retune it, `amp` and `pan`.
- `low_conga`, `mid_conga` and `high_conga` take `vel`, how hard the drum is struck: harder is louder and brighter, as on the tumba, conga and quinto of Versilian Studios' VSCO 2 Community Edition they are measured from. They take `mute`, from 0 for an open tone to 1 for a stroke damped as the recordings' finger taps are, 24 to 32 dB quieter and ringing mostly above 400 Hz, and `slap`, from 0 for an open tone to 1 for a slap, which the recordings don't have.
- `low_agogo` and `high_agogo` take `vel`, from 0 to 1, how hard the bell is struck: harder is louder and brighter, as on the Versilian Community Sample Library's agogô they are measured from.
- `ganza` and `shaker` take `vel`, how hard the stroke is, and `up: 1` for an up stroke instead of a down stroke; they are measured from the small and the large shaker of the Versilian Community Sample Library.
- `pandeiro_thumb`, `pandeiro_heel`, `pandeiro_slap` and `pandeiro_jingles` take `vel`, how hard the stroke is; they are measured from pandeiro recordings on Freesound.
- `pandeiro` plays any of those strokes, named by `stroke`: `thumb`, the default, `heel`, `slap` or `jingles`.
- `tabla_na`, `tabla_tun`, `tabla_te` and `tabla_tas` are the dayan's strokes, and `tabla_ghe` and `tabla_ke` the bayan's; each takes `vel`, how hard the stroke is, harder being louder and brighter. A dayan stroke's `note` tunes the drum to Sa, D#4 by default, and `tabla_ghe` takes `note` with `note_slide` to bend the bayan while it rings, as the palm does. Play dha, dhin and the other strokes of both hands by playing a dayan and a bayan stroke on the same beat. They are measured from the "tabla bols" pack by mmiron on Freesound, each band within 6 dB and 30 percent of the fade of the recordings' from 250 Hz to 8 kHz, and from 80 Hz to 4 kHz for `tabla_ghe`; `tabla_ke`, whose recordings are too short to measure as hits, follows their spectrum and is silent 0.1 seconds after it is struck.
- `tabla` plays any of those strokes, named by `bol`: `na`, the default, `tun`, `te`, `tas`, `ghe` or `ke`; its `note` is the stroke's own unless given.
- `berimbau` plays an open stroke, `coin: 1` the stroke with the coin pressed to the string, a semitone higher, and `buzz: 1` the buzzed stroke, the coin resting on the wire so the string dies within a fifth of a second under its rattle; it takes `vel`, how hard the stick strikes, harder being louder and brighter, and `note` tunes the open string, D#2 by default, as the jam it is measured from. It is measured from "Berimbau jam without caxixi" by EliasArtista on Freesound, each band within 6 dB of the jam's as it is struck and 50, 100 and 200 ms after with the gourd held still, with its partials on the string's harmonics and the 3rd and 5th strongest, as the gourd brings them out. `gourd` is how many times a second the gourd opens and closes against the belly while the string rings, swinging its 5th harmonic against its 3rd as uiop's "berimbau.aif" on Freesound does; it is 2.3 by default, as on that recording, and 0 holds the gourd still. No open recording has buzzed strokes, so the buzz is designed rather than measured; there is no bend of the coin pressed while the string rings.
- `cabasa` takes `vel`, how hard it is struck, and `rub: 1` to turn the beads against the cylinder for its `sustain` instead of striking them; it is measured from the cabasa of the Versilian Community Sample Library.
- `cajon` takes `vel`, how hard it is played, and `slap`, from 0 for the bass tone to 1 for the slap, as the congas do; it is measured from the cajón of the Versilian Community Sample Library.
- `low_bongo` and `high_bongo` take `vel`, how hard the drum is struck, and `muted: 1` for a muted stroke; they are measured from the bongos of the Versilian Community Sample Library, whose muted strokes ring about as long as the open ones.
- `surdo` is the large drum that holds samba's beat, struck with a felt mallet, and takes `vel`, how hard it is struck, and `muted: 1` for the stroke with the hand on the head, which loses the drum's lowest ring, sounds higher and fades in half the time. With no `note` it is the surdo de primeira, ringing on 66.6 Hz with a ring at twice that 10 dB down; `note` tunes it, so `note: 41` and `note: 45` are the higher surdos de segunda and de terceira. It is measured from three loops by plotzki on Freesound, and compared with igorfiche01's surdo, a higher drum.
- `cuica` is the friction drum of samba, and takes `vel`, how hard the stick inside it is rubbed. Each stroke grips for 30 ms, then its pitch arches about 8 semitones up and back down in 0.17 seconds, its second harmonic topping at 290 Hz; `note` is the arch's top, 145 Hz with no `note`, and tunes it, keeping the arch's span. It is measured from "Cuica01.ogg" and "Cuica02.ogg" by っ on Wikimedia Commons, and compared with jackpatrick889's cuíca, whose strokes hold a steady pitch.
- `tamborim` is the small high drum of samba struck with a stick, and takes `vel`, how hard it is struck. It rings on 524 Hz with no `note`, with peaks at 1.8 and 2.5 times it and a crack of noise above 3 kHz; `note` tunes it. It is measured from "Tamborim Sound.ogg" by Samba-x on Wikimedia Commons.
- `caxixi` is the woven basket shaker that a capoeira berimbau player shakes in the bowing hand, and takes `vel`, how hard it is shaken, and no `note`. Each shake is loudest above 2.5 kHz and falls 10 to 17 dB in its first 50 ms, and its strongest peak moves from shake to shake, between about 1.7 and 9.6 kHz. It is measured from "Caxixi.ogg" by Freddythehat on Wikimedia Commons, a large and a small caxixi shaken together.
- `snare` takes `vel`, how hard it is struck: harder is louder, puts more into the head and less into the wires, and the softest strokes are dark; it is measured from the snare of Versilian Studios' VSCO 2 Community Edition with its snares on.
- `crash` takes `vel`, how hard it is struck: harder is louder and dies sooner below 1.2 kHz, as on the crash cymbal of Versilian Studios' VSCO 2 Community Edition it is measured from; it rings for 9 seconds and fades over one, and a shorter `sustain` and `release` choke it.
- `closed_hihat` and `open_hihat` take `vel`, how hard the hi-hat is struck: harder is louder and brighter, as on the hi-hat of the Versilian Community Sample Library they are measured from; the open one rings for 5 seconds, and a shorter `sustain` and `release` close it, as the pedal does.
- `low_tom`, `mid_tom` and `high_tom` take `vel`, how hard the tom is struck: harder is louder and brighter, as on the high and low toms of the Versilian Community Sample Library that `high_tom` and `low_tom` are measured from; `mid_tom` is the high tom tuned between them.
- `cowbell` takes `vel`, how hard it is struck, and `muted: 1` for a stroke the hand mutes; it is measured from the cowbells of VSCO 2 Community Edition and the Versilian Community Sample Library. Harder is louder and duller, as on the recordings, and a muted stroke loses the bell's ring near 470 Hz but keeps its upper modes, so it sounds brighter, not shorter.
- `clave` takes `vel`, how hard the sticks strike: harder is louder and brighter, as on the claves of the Versilian Community Sample Library and VSCO 2 Community Edition it is measured from; a stroke rings near 2 kHz, falling 15 dB in its first 50 ms and fading over 0.7 s.
- `guiro` takes `sustain`, the length of its scrape in beats, and `vel`, how hard it is scraped: harder is louder and brighter, as on the University of Iowa's güiro; it is measured from that güiro and the güiros of VSCO 2 Community Edition and the Versilian Community Sample Library. The stick crosses about 55 ridges in a full scrape, so a longer scrape is slower, from 125 ridges a second down to 40.
- `tambourine` takes `vel`, how hard it is struck: harder is louder, rattles longer and is fuller below 1 kHz, as on the University of Iowa's three tambourines it is measured from; VSCO 2's tambourine is much quieter from 250 Hz to 1.6 kHz, so the design follows Iowa's. `tambourine_shake` takes `vel` and `sustain`, the length of its shake in beats.
- `triangle` takes `vel`, how hard it is struck: harder is louder and brighter, as on the University of Iowa's 6- and 8-inch triangles it is measured from. It rings for up to ten seconds, and `sustain` and `release` damp it as a hand closing on it does, sooner on its highest modes; `sustain: 0` with a `release` of about 1.1 s fades as the Versilian Community Sample Library's muted strokes do, and the forró triangle's closed strokes take a release of about 0.15.

## Measure an instrument

mx's guitar was made by measuring recordings of a real guitar and fitting the design to the figures, and `mix mx.measure` takes the same measurements, so a design can be compared with the instrument it imitates.
Give it recordings of single notes, plucked or struck, each file followed by a colon and the note it starts on.
A file may hold several notes one after another a semitone apart, each starting from silence, as the University of Iowa's guitar recordings at https://theremin.music.uiowa.edu/MISguitar.html do.

```sh
mix mx.measure Guitar.mf.sulA.A2B2.aif:A2 Guitar.mf.sulE.E2B2.aif:E2
mix mx.measure Guitar.mf.sulA.A2B2.aif:A2 --synth guitar --vel 0.6
```

It prints the notes it found in each file, with their pitch and how far their harmonics are stretched sharp, then for each frequency band the median seconds a harmonic takes to fade 60 dB and its level in dB against the fundamental of the lowest note.
`--synth` renders one of mx's synths offline at each note found, at `--vel`, and prints its figures beside the recordings', with the difference.
`--option` gives the synth another option as a name and a number, such as `--option up=1` for a shaker's up stroke, and may be given more than once.
The guitar's design tests check the same figures, measured the same way.

Recordings of held notes, bowed, blown or played on an organ, take `--held`, and recordings of hits, on bars, bells and drums, take `--hits`.
A file of hits with no pitch needs no note after its name.

```sh
mix mx.measure --held Flute.vib.mf.B3B4.aiff:B3 --synth flute
mix mx.measure --hits Cowbell1_Hit_v1_rr1_Sum.wav --synth cowbell
```

With `--held`, it prints each note's pitch, attack and vibrato, then their median attack, the seconds until a note first reaches its held level, and their median vibrato, its rate and its depth in cents.
For each band it prints the level of the harmonics while the note holds and the level of the noise between them, the breath of a flute or the bow of a violin.
`--drone` with `--held` measures each file as one note held from its first sample to its last, for a drone plucked again and again, such as a tanpura, which would otherwise read as a note at each pluck.
With `--hits`, it prints each hit's strongest peaks as ratios to the lowest, which shows the partials of a bar or a bell whatever its pitch, then for each band the seconds it takes to fade 60 dB and its level as the hit starts, against the loudest band.
With `--synth`, a held note renders for as long as the recordings hold it, and a hit renders once at each note given, each with only the options the synth takes.
`--partials` with a count adds, under each hit, up to that many of its strongest partials within 40 dB of the loudest, lowest first, each with its frequency in Hz, its ratio to the lowest, its level against the loudest, and the seconds it takes to fade 60 dB; these are the figures a struck instrument's design is written in, such as the agogô's in mxs's `src/synths/drums.rs`.
With `--synth`, the synth's partials print the same way under its name, after the recordings'.

```sh
mix mx.measure --hits Agogo_Low_v1_rr1_Mid.wav --partials 12 --synth low_agogo
```

`--hits` then prints each band's level at 0, 50, 100 and 200 ms after the hit's loudest moment, against the loudest band then, as medians over the hits, with the synth's beside them when one is given.
A moment after the next hit starts or the recording ends prints as -, and a level more than 40 dB down prints as -40, so a recording's noise floor does not count as a difference.
These moments catch what the fade misses, such as a hiss that holds its level and then stops: the pandeiro passed every band's level and fade with such jingles, and did not sound like a pandeiro.
`--compare` with a file name writes a WAV file to listen to: up to three recorded hits whose bands are nearest the median, then the synth's hit three times, each 0.6 seconds at the same peak and fading out over its last 10 ms, with a quarter of a second between.
It prints which recorded hits it took, by file and second.

```sh
mix mx.measure --hits "pandeiro A.wav" --synth pandeiro_thumb --compare thumb.wav
mix mx.spectrogram thumb.wav
```

`mix mx.spectrogram FILE` draws a spectrogram of a recording into a PNG image beside it, with seconds across and octaves up the side; `--out` names the image.

`mix mx.fit` searches for the numbers a held instrument's design needs.
Write each unknown number in the design as a temporary control, such as `\k_odd.kr(-2)`, compile the designs, then give the synth, each dynamic as `--vel` and the files played at it, and each control with its starting value and step.
A step written with an x, such as `x1.15`, multiplies and divides instead of adding and subtracting.

```sh
mix mx.fit clarinet --vel 0.3 BbClar.pp.D3B3.aiff:D3 BbClar.pp.C4B4.aiff:C4 --vel 1 BbClar.ff.D3B3.aiff:D3 BbClar.ff.C4B4.aiff:C4 --from 160 --control k_odd=-2:2 --control k_att=0.15:x1.15
```

It leaves out notes found below the lowest note given, and stretches whose fundamental stands more than 25 dB below the rest of their dynamic, the breaths and key clicks between notes.
It renders the synth at every semitone from the lowest note to the highest, at each dynamic's vel, each note held as long as the recordings' notes at that dynamic hold, and scores how far each band's harmonics and the noise between them, from `--from` up to 4 kHz, fall more than 4 dB from the recordings', and how far the attack falls more than 20 percent from theirs.
It tries each control a step up and a step down, keeps whichever lowers the score, goes through the controls three times, and prints the best values, to write into the design in place of the controls.
`--check` scores the starting values instead, with no control needed, and prints each band's level of harmonics and of noise in the recordings and how far the synth is off, marking those beyond 6 dB, and each attack beyond 30 percent.
`--drone` measures each file as one note, as `mix mx.measure --held --drone` does, and leaves out the attack, since a drone's recording starts wherever it was cut.
The recordings' figures are kept in the system's temporary folder and reused until a file changes.

## Effects

These are mx's own designs, in mxs's `src/effects.rs`, with option names that follow Sonic Pi's.
bitcrusher and chorus follow Airwindows' DeRez and Chorus, as `LICENSE-designs.md` credits.

bitcrusher, bpf, chorus, compressor, distortion, echo, flanger, hpf, level, lpf, pan, ping_pong, reverb, rlpf, slicer, tremolo, wobble.

Every effect takes `amp`, `mix` from 0 for dry to 1 for wet, and `pre_amp`, the level going in.
`phase`, `decay` and `max_phase` are in beats, so a tremolo with `phase: 1` pulses once a beat at any tempo.
`wave` is the shape of a sweep: 0 saw, 1 pulse, 2 triangle, 3 sine and 4 cubic; `invert_wave: 1` turns it upside down, and `phase_offset` is where in the cycle it starts, from 0 to 1.
- `bitcrusher` takes `sample_rate`, the rate in Hz it holds samples at, `bits`, how many it rounds each to, and `cutoff`, a MIDI note number for a low-pass after it, off at 0.
- `bpf` takes `centre`, the MIDI note number of the band it keeps, and `res`, from 0 to 1, the higher the narrower.
- `chorus` takes `phase`, how long the delay takes to sweep back and forth, `decay`, how long the delayed sound feeds back, and `max_phase`, the longest `phase` it can change to.
- `compressor` takes `threshold`, the level above which it lowers the sound, `slope_above` and `slope_below`, how much the level changes above and below it, and `clamp_time` and `relax_time`, how many seconds it takes to lower and to let go.
- `distortion` takes `distort`, from 0 to 1.
- `echo` takes `phase`, the time between echoes, `decay`, how long they take to die away, and `max_phase`, the longest `phase` it can change to.
- `flanger` takes `phase`, `wave`, `invert_wave` and `phase_offset` for its sweep, `stereo_invert_wave: 1` to sweep the left channel the other way, `delay` and `depth`, in milliseconds, the delay it sweeps up from and how far, `max_delay`, the longest delay in milliseconds, `feedback` from 0 to 1 and `decay` for how strongly and how long the delayed sound feeds back, and `invert_flange: 1` to subtract the delayed sound instead.
- `hpf` and `lpf` take `cutoff`, a MIDI note number.
- `pan` takes `pan`, from -1 for left to 1 for right.
- `ping_pong` echoes between left and right: `phase` is the time between echoes, `feedback` how much of each echo the next keeps, `max_phase` the longest `phase` it can change to, and `pan_start` the side of the first echo, from -1 for left to 1 for right.
- `reverb` takes `room` and `damp`, from 0 to 1.
- `rlpf` takes `cutoff`, a MIDI note number, and `res`, from 0 to 1, how much it rings at its cutoff.
- `slicer` turns the sound on and off: `phase` is the length of a cycle, `pulse_width` the part of it that is on, `amp_min` and `amp_max` the levels off and on, `phase_offset` where in the cycle it starts, from 0 to 1, and `smooth` how many seconds each change takes.
- `tremolo` takes `phase`, `wave`, `invert_wave` and `phase_offset` for its sweep, and `depth`, from 0 to 1, how far it turns the sound down.
- `wobble` sweeps a resonant filter between `cutoff_min` and `cutoff_max`, MIDI note numbers, once a `phase`, with `res`, `wave`, `invert_wave`, `phase_offset`, `pulse_width` for wave 1, and `filter`, 0 for low-pass and 1 for high-pass.
- Every option that takes a number along a range, rather than a choice or a longest value, has a `_slide` partner; `max_phase`, `max_delay`, `phase_offset`, `smooth`, `wave`, `invert_wave`, `stereo_invert_wave`, `invert_flange`, `filter` and `pan_start` do not.

## Samples

These are the names of the samples in Sonic Pi's pack, from release v5.0.0; see the pack's README.md in its folder for where each comes from.

ambi_choir, ambi_dark_woosh, ambi_drone, ambi_glass_hum, ambi_glass_rub, ambi_haunted_hum, ambi_lunar_land, ambi_piano, ambi_sauna, ambi_soft_buzz, ambi_swoosh, arovane_beat_a, arovane_beat_b, arovane_beat_c, arovane_beat_d, arovane_beat_e, bass_dnb_f, bass_drop_c, bass_hard_c, bass_hit_c, bass_thick_c, bass_trance_c, bass_voxy_c, bass_voxy_hit_c, bass_woodsy_c, bd_808, bd_ada, bd_boom, bd_chip, bd_fat, bd_gas, bd_haus, bd_jazz, bd_klub, bd_mehackit, bd_pure, bd_sone, bd_tek, bd_zome, bd_zum, drum_bass_hard, drum_bass_soft, drum_cowbell, drum_cymbal_closed, drum_cymbal_hard, drum_cymbal_open, drum_cymbal_pedal, drum_cymbal_soft, drum_heavy_kick, drum_roll, drum_snare_hard, drum_snare_soft, drum_splash_hard, drum_splash_soft, drum_tom_hi_hard, drum_tom_hi_soft, drum_tom_lo_hard, drum_tom_lo_soft, drum_tom_mid_hard, drum_tom_mid_soft, elec_beep, elec_bell, elec_blip, elec_blip2, elec_blup, elec_bong, elec_chime, elec_cymbal, elec_filt_snare, elec_flip, elec_fuzz_tom, elec_hi_snare, elec_hollow_kick, elec_lo_snare, elec_mid_snare, elec_ping, elec_plip, elec_pop, elec_snare, elec_soft_kick, elec_tick, elec_triangle, elec_twang, elec_twip, elec_wood, glitch_bass_g, glitch_perc1, glitch_perc2, glitch_perc3, glitch_perc4, glitch_perc5, glitch_robot1, glitch_robot2, guit_e_fifths, guit_e_slide, guit_em9, guit_harmonics, hat_bdu, hat_cab, hat_cats, hat_gem, hat_gnu, hat_gump, hat_hier, hat_len, hat_mess, hat_metal, hat_noiz, hat_psych, hat_raw, hat_sci, hat_snap, hat_star, hat_tap, hat_yosh, hat_zan, hat_zap, hat_zild, loop_3d_printer, loop_amen, loop_amen_full, loop_breakbeat, loop_compus, loop_drone_g_97, loop_electric, loop_garzul, loop_industrial, loop_mehackit1, loop_mehackit2, loop_mika, loop_perc1, loop_perc2, loop_safari, loop_tabla, loop_weirdo, mehackit_phone1, mehackit_phone2, mehackit_phone3, mehackit_phone4, mehackit_robot1, mehackit_robot2, mehackit_robot3, mehackit_robot4, mehackit_robot5, mehackit_robot6, mehackit_robot7, misc_burp, misc_cineboom, misc_crow, perc_bell, perc_bell2, perc_door, perc_impact1, perc_impact2, perc_snap, perc_snap2, perc_swash, perc_swoosh, perc_till, ride_tri, ride_via, sn_dolf, sn_dub, sn_generic, sn_zome, tabla_dhec, tabla_ghe1, tabla_ghe2, tabla_ghe3, tabla_ghe4, tabla_ghe5, tabla_ghe6, tabla_ghe7, tabla_ghe8, tabla_ke1, tabla_ke2, tabla_ke3, tabla_na, tabla_na_o, tabla_na_s, tabla_re, tabla_tas1, tabla_tas2, tabla_tas3, tabla_te1, tabla_te2, tabla_te_m, tabla_te_ne, tabla_tun1, tabla_tun2, tabla_tun3, tbd_fxbed_loop, tbd_highkey_c4, tbd_pad_1, tbd_pad_2, tbd_pad_3, tbd_pad_4, tbd_perc_blip, tbd_perc_hat, tbd_perc_tap_1, tbd_perc_tap_2, tbd_voctone, vinyl_backspin, vinyl_hiss, vinyl_rewind, vinyl_scratch.

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
