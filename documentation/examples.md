# Examples

The songs in `examples` play from a clone of mx, each with `mx` and its path.
The pieces for a band come first, then each instrument on its own.

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

`examples/dubwise.exs` is a dub in A dorian on mx's measured synths, over a riddim of four bars, Am7, D9, Am7 and G: the drum kit leads through the one drop, rockers and steppers, the double bass plucks under a guitar skank and the organ's bubble, and the harmonium plays as a melodica, answered by the vibraphone and doubled by the trombone in the last riddim. The parts are thrown into a tape echo and swept through filters as on a dub mixing desk, with a dub siren, and a rewind before the last riddim; its samples are Sonic Pi's.

```sh
mx examples/dubwise.exs
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

`examples/violin/paganini_caprice_24.exs` is the theme and the first variation of Paganini's Caprice No. 24 in A minor, of 1817, each half repeated, the notes bowed phrase by phrase as the score slurs them.

```sh
mx examples/violin/paganini_caprice_24.exs
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

`examples/flute/bhupali.exs` is raga Bhupali for flute and tabla, as a bansuri player lays it out: a slow alap without a beat, a drut gat in teentaal, taans, and a tihai landing on sam, each breath one note that its later changes move from swara to swara.

```sh
mx examples/flute/bhupali.exs
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

`examples/solo/surdo.exs` is the three surdos of a samba bateria on their own, in 2/4: the surdo de primeira holds the marcação, muted on the first beat of each bar and open on the second, the surdo de segunda answers it open on the first beat, and the surdo de terceira cuts across them in sixteenths.

```sh
mx examples/solo/surdo.exs
```

`examples/cuica/solo.exs` is the cuíca on its own, its part in a samba batucada in 2/4, built from the grooves of the recordings it is measured from: four swung strokes to the beat, two low ones answered by two high ones an octave up, every fourth beat staying low, and a break of single strokes, low ones that whoop up into their note and then high squeals.

```sh
mx examples/cuica/solo.exs
```

`examples/tamborim/solo.exs` is the tamborim on its own, its parts in a samba batucada in 2/4: the teleco-teco, a two-bar figure of sixteenths off the beat, the carreteiro striking every sixteenth with the teleco-teco's strokes accented, and a virada that closes a phrase with a run of thirty-seconds swelling into an accent.

```sh
mx examples/tamborim/solo.exs
```

`examples/solo/caxixi.exs` is the caxixi on its own, shaken with each of the berimbau's strokes in two of capoeira's toques: in angola it leans on the open note after two buzzes, and in são bento grande on the first buzz of each pair and the open note that closes the phrase.

```sh
mx examples/solo/caxixi.exs
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
