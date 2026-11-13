# Examples

The songs in `examples` play from a clone of mx, each with `mx` and its path, such as `mx examples/salsa.exs`.

## Pieces

`examples/tranquility_base.exs` is made only of public recordings, with no synth: VCSL's marimba, vibraphone, hand chimes and drums play as sampled instruments, choosing strengths and alternating takes, its wine glasses are tuned by their rate into a chord, and NASA's Kennedy, Apollo and Sputnik recordings are cut at seconds, stuttered, reversed and fitted to the beat over it, through thirteen of mx's effects. It needs two of VCSL's folders downloaded once, 1.5 GB together, and NASA's recordings ship beside it:

```sh
mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones"
mx samples download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Membranophones"
mx examples/tranquility_base.exs
```

`examples/ambient.exs` is a demo to start from, a slow ambient piece of pads, keys, bells and samples through reverb and echo.

`examples/salsa.exs` is a salsa band played only on mx's own synths: son clave, a tumbao on bass and congas, a piano montuno, cáscara, güiro and maracas, a horn section on filtered supersaws, and solos by the piano and the horns.
The bongos play the martillo until the mambo, where the bongocero takes up the campana, the hand bell.

`examples/choro.exs` is Ernesto Nazareth's Apanhei-te, cavaquinho, a polca of 1914 in the public domain that choro took for its own, played by a regional on mx's measured synths, in the form A A B B A C C A. The flute slurs the pianist's right hand a bar to a breath, with its mordents and grace notes, the clarinet takes the repeats and joins it an octave below, the cavaquinho strums the left hand's rhythm, the 7-string guitar runs down to each new phrase, and the pandeiro plays as its hand rocks and strikes the trio's chords with the whole regional.

`examples/odeon.exs` is the first strain of Ernesto Nazareth's Odeon, a tango brasileiro of 1909 in the public domain, played slowly by a choro regional on mx's measured synths: the trombone sings the pianist's low left-hand melody and the flute answers, then the cello and the tenor saxophone repeat it, over the 7-string guitar, cavaquinho, pandeiro and shaker. The pandeiro is written as its hand's rocking, with a muted and an open bass, ghost notes, slaps and rolls, and every other part swings where that rocking places the sixteenths.

`examples/caboclinho.exs` is a caboclinho of Pernambuco in 2/4 on mx's measured synths: the toques guerra, perré, baião and macumba do índio in turn, with the flute as the gaita on a neutral third, the ganzá and the shaker as the caracaxás, the bongos as the tarol and the preacas, and the cajón as the atabaque.

`examples/meditation.exs` is a slow meditation in raga Bhupali, tuned to Sa as just intervals, on mx's measured synths: the harp plucking a tanpura's drone, the organ breathing Sa and Pa, and the flute through alap, jor and a gat in teentaal with the bongos as tabla and the ganzá as ankle bells, ending on a tihai.

`examples/raga.exs` is raga Yaman on the tanpura, the sitar and the tabla, laid out as a Hindustani recital: one drone held from the first beat to the last, a slow alap with meend, a jor to a steady pulse, and a gat with the tabla's theka in teentaal. The gat is a composition V. N. Bhatkhande notated in his Kramik Pustak Malika, "Yaman–Trital (Madhyalay)" on page 33 of the second book, played as the book writes it, from khali, with its grace notes and its meend, and tuned to Sa in cents. The sitar plays it as a sitarist would: each pluck rings until the next, the other notes of a matra and its glides are fingered on the ringing string, and the chikari strings strike Sa between the notes.

`examples/midnight.exs` is a hypnotic piece in raga Darbari Kanada, the grave raga of midnight, on mx's measured synths: the tanpura and the organ's stopped flute drone under the oboe, which plays as a shehnai with meend, kan and andolan on Ga and Dha, while the harmonium answers its phrases plainly. In the gat the tabla plays teentaal with its dayan tuned to Sa, the güiro scrapes and then plays the cha-cha-chá, the claves play son clave, and two pianos phase as in Steve Reich's Piano Phase, one drifting a sixteenth ahead each pass until they meet again in unison as the tihai lands on the sam of shanti. The piece is mixed as a dream of that recital: the oboe's phrases echo from side to side and return three beats late as a ghost heard only through its echo, the organ's drone and the pianos sweep through slow filters, the tanpura through a light flanger, the organ's chorus pulses through a slicer, and a vibraphone drops notes of the raga into the quiet passes.

`examples/dubwise.exs` is a dub in A dorian on mx's measured synths, over a riddim of four bars, Am7, D9, Am7 and G: the drum kit leads through the one drop, rockers and steppers, the double bass plucks under a guitar skank and the organ's bubble, and the harmonium plays as a melodica, answered by the vibraphone and doubled by the trombone in the last riddim. The parts are thrown into a tape echo and swept through filters as on a dub mixing desk, with a dub siren, and a rewind before the last riddim; its samples are Sonic Pi's.

## Keyboards and mallets

`examples/solo/piano.exs` is the piano on its own: a sweep from its lowest note to its highest, chords played softly and then hard, runs over a bass, and its lowest and highest notes at the hardest and the softest.

`examples/piano/clair_de_lune.exs` is Debussy's Clair de lune of 1905, in the public domain, played whole on the piano from the Mutopia Project's engraving: the melody voiced over the inner notes, the pedal changing with the bass, and the bars stretched and pressed by the rubato its markings ask for, from pianissimo to the forte of bar 41 and back to a morendo.

`examples/solo/organ.exs` is the organ on its own: chords held over a walking bass on its quiet set, then on its loud set, and a last chord on both.

`examples/solo/harmonium.exs` is the harmonium on its own in raga Bhairav, tuned to Sa G in cents: the left hand holds Sa an octave down while the right plays the ascent and descent, the pakad, a phrase dipping below Sa, one high in the upper octave, and an ending on Sa.

`examples/solo/accordion.exs` is the accordion's right hand on its own, a bal-musette waltz in A minor: a low theme with the musette reeds beating, the theme an octave up played short and dry on one reed, the waltz's chords struck on the first beat and short on the second and third, and the theme again with an ending on a long A.

`examples/solo/marimba.exs` is the marimba on its own: a sweep from its lowest bar to its highest, a melody rolled by two mallets over ringing bass bars, the same arpeggio on its low bars and its high ones, and a last chord.

`examples/solo/vibraphone.exs` is the vibraphone on its own: chords left to ring with the pedal, the same chords with the motor turning, a line of short damped notes, and a last chord.

`examples/solo/xylophone.exs` is the xylophone on its own: runs over two octaves in sixteenths, a note struck every sixteenth as a melody moves under it, a melody on its brightest bars, and a run up to its top bar.

`examples/solo/glockenspiel.exs` is the glockenspiel on its own: a melody high in its range, each note damped as the next one comes, then a chord struck one bar at a time and left to ring, and an arpeggio up to its top bar.

## Strings

`examples/solo/harp.exs` is the harp on its own: a joropo in A minor, the bass in 3/4 under arpeggios in 6/8, then chords left to ring, and a last arpeggio.

`examples/guitar/` shows the guitar on its own: `fingerpicking.exs` lets each string ring until it is plucked again, `bass_line.exs` walks the low strings of a 7-string guitar, and `soft_and_hard.exs` plays one phrase softly, normally and hard.

`examples/solo/violin.exs` is the violin on its own, in D minor: a cantabile slurred in groups whose long notes swell and ease, bariolage against the open A string as in the Preludio of Bach's Partita No. 3, the melodic minor slurred eight notes to a bow and arpeggios in short notes, chords plucked down to the open G, and a climb on audible shifts to a long D7 with vibrato.

`examples/violin/paganini_caprice_24.exs` is the theme and the first variation of Paganini's Caprice No. 24 in A minor, of 1817, each half repeated, the notes bowed phrase by phrase as the score slurs them.

`examples/solo/viola.exs` is the viola on its own, in C minor: a cantabile low on its C and G strings whose long notes swell and ease, measured tremolo growing from soft to loud, arpeggios from the low C slurred four notes to a bow across the strings, plucked chords, and the melody an octave higher settling on the low C.

`examples/solo/cello.exs` is the cello on its own, in G major: the opening bars of the Prelude of Bach's Cello Suite No. 1 broken across the strings, a cantabile climbing to the A string on audible shifts with its long notes swelled, a plucked walking bass, and a climb to a long high D falling back to the low G.

`examples/solo/double_bass.exs` is the double bass on its own: a plucked walking line through a twelve-bar blues in F, then a slow melody over its low strings slurred in swelled bows, and a last walk down to its low F, bowed, held and swelled.

`examples/solo/sitar.exs` is the sitar on its own in raga Yaman, tuned to Sa C sharp in cents: a slow alap that glides between notes on one pluck, then a gat in teentaal, low and high on the string, with long notes and quick runs.

`examples/solo/tanpura.exs` is the tanpura on its own: Pa, Sa, Sa and the low Sa plucked in turn, the first and the last given two beats, in a slow drone on C sharp, the same drone plucked quicker, two short drones on a low E, and a long, slow drone on C sharp.

## Winds

`examples/solo/flute.exs` is the flute on its own: Debussy's Syrinx, from its first edition of 1927, each breath of the score one held note that its later notes move, and the notes that start a slur tongued.

`examples/flute/bhupali.exs` is raga Bhupali for flute and tabla, as a bansuri player lays it out: a slow alap without a beat, a drut gat in teentaal, taans, and a tihai landing on sam, each breath one note that its later changes move from swara to swara.

`examples/solo/clarinet.exs` is the clarinet on its own: a dark melody in G minor low in its range, fast arpeggios through its registers, the melody again higher up, and a last phrase high in its range, loud.

`examples/solo/oboe.exs` is the oboe on its own: a pastoral melody in F major, a dance in short detached notes, a climb through its range from its low B flat to F6, and the melody again an octave up.

`examples/solo/bassoon.exs` is the bassoon on its own: a song-like melody in B flat in its tenor register, a walking bass line low in its range, a comic tune in short detached notes, and the melody again, closing on its low B flat.

`examples/solo/tenor_sax.exs` is the tenor saxophone on its own: a choro melody in F major with its runs in sixteenths, a slow phrase with vibrato, the same phrase at its softest and then its loudest, and a last run down to its low A flat.

`examples/solo/trumpet.exs` is the trumpet on its own: a fanfare call in Bb major, tongued short and answered, then a fourth higher, a lyrical phrase with vibrato, the call at its loudest with a soft echo, and a last climb to a held Bb5.

`examples/solo/trombone.exs` is the trombone on its own: a legato melody in F major whose notes glide into each other as the slide moves, then a fourth lower, a march in short notes, a long note at its softest and then its loudest, and a last glide from F2 up to F4.

`examples/solo/horn.exs` is the French horn on its own: a broad melody in Eb major, then again an octave lower, hunting calls answered a fourth lower, a long note at its softest and then its loudest, and a run down to a held low Eb2.

`examples/solo/tuba.exs` is the tuba on its own: an oom-pah bass in Bb major in short notes, then a walking bass under the same chords, a melody high in its range, a long note at its softest and then its loudest, and a run down to a held low F1.

## Percussion

`examples/solo/drums.exs` is the drum kit on its own: the beat of James Brown's "Funky Drummer" built up from the hi-hat alone to the snare's ghost notes and the hi-hat opening, a paradiddle between the hi-hat and the snare, a solo over the feet that accents every third sixteenth across the snare and the toms, runs down the drums in sextuplets, plays flams and a drag and rolls from the snare's softest stroke to its hardest, and a last crash that is choked.

`examples/solo/timpani.exs` is the timpani on its own: a roll on A2 that swells from soft to loud, the tonic and dominant pounded in turn, a melody on five drums tuned to D major, the same melody at its softest, and a roll on D3 that ends on a loud stroke left to ring.

`examples/solo/congas.exs` is the three congas on their own: the tumbao of son montuno on one drum, heel, tip, slap and open tones, then on two drums with the tumba's open tones on the clave's three side; the quinto over it as in rumba, in the lock, the son clave a sixteenth late with its tones and slaps changing places, and the cross, a slap on every third sixteenth for three claves; a roll of heel and tip; and a run down the three drums.

`examples/solo/bongos.exs` is the bongos on their own, as the bongocero plays in son and salsa: the martillo, with the hembra's open tone on its seventh stroke, a rim shot ending every second bar and heel-tip strokes, left for repiques and taken up again; the repiques accent every third sixteenth, play quarter-note triplets across the two drums, mark the offbeats and the fourth beat as in changüí, and roll the fingers into ruffs and a last roll.

`examples/solo/cajon.exs` is the cajón on its own, from Peru to flamenco and the drum kit: a festejo of mx's own in 12/8, with bass tones, slaps and ghost strokes; the rumba flamenca, its eighths grouped 3+3+2 with the slap on two and four; the bulerías, twelve counts accented on 12, 3, 6, 8 and 10, closing on 10; a rock beat moved from the kit, filled in until every sixteenth is played; and a roll of slaps that grows into the bass tone.

`examples/solo/cowbell.exs` is two cowbells on their own, playing salsa's bell patterns in 2:3 clave: the campana, the bongocero's bell, in its second gear, with the 3 side's first two strokes open and hard, and the standard third gear, open on each half bar and closed between; the contracampana, the timbalero's bell, a fourth above, alone and then against the campana as in a montuno; and the campana in the standard pattern of the 12/8 rhythms.

`examples/solo/claves.exs` is the claves on their own, playing the standard clave patterns: son clave 3-2 and 2-3, rumba clave, the bossa nova clave, and the 6/8 standard bell of bembé.

`examples/solo/guiro.exs` is the güiro on its own: long, slow scrapes, the cha-cha-chá's long scrape and two short ones, son's long-short-short-long, Puerto Rican bomba's three short scrapes before a long one, and a last long scrape.

`examples/solo/tambourine.exs` is the tambourine on its own, played its standard ways: a shake roll that starts and ends on a stroke, the pop and soul backbeat shaken in eighths and struck on two and four, a tarantella in continuous 6/8 triplets, soft fingertip strokes, and a roll that grows into a last stroke.

`examples/solo/triangle.exs` is the triangle on its own, played its standard ways: single strokes left to ring, strokes the hand damps at once, a roll inside one corner, and the forró triangle of the baião, open on the third sixteenth of each beat and closed on the others.

`examples/solo/cabasa.exs` is the cabasa on its own: two long turns of the beads, the steady sixteenth pulse of bossa nova as twists, harder forward than back, the two-bar bossa nova figure struck over it, the figure alone with the beads left to spin after each stroke, and a turn that grows into a last stroke.

`examples/solo/agogo.exs` is the agogô on its own: a samba bell pattern, a partido alto one, a maracatu figure, eighths across both bells with accents, and four more samba patterns.

`examples/solo/ganza.exs` is the ganzá in four samba patterns of sixteenths, down and up strokes, with the large shaker in eighths under it.

`examples/solo/pandeiro.exs` is the pandeiro on its own, in choro, samba de roda, baião, forró and coco de embolada.

`examples/pandeiro/virtuoso.exs` is a pandeiro solo whose hand never stops rocking: a coco groove and its ruffs, then accents every three and every five sixteenths that cross the bar line, and every fourth stroke of sextuplets.

`examples/solo/surdo.exs` is the three surdos of a samba bateria on their own, in 2/4: the surdo de primeira holds the marcação, muted on the first beat of each bar and open on the second, the surdo de segunda answers it open on the first beat, and the surdo de terceira cuts across them in sixteenths.

`examples/cuica/solo.exs` is the cuíca on its own, playing its part in a roda de samba in 2/4 as Luiz Guimarães notates it: the fundamental on each beat with three medium strokes after it, the roda's two-bar pattern that holds a high stroke over the barline and comes back down through three fundamental ones, and a variation that rests on the beat and answers with three high strokes, the third and fourth sixteenths of each beat coming early.

`examples/tamborim/solo.exs` is the tamborim on its own, its parts in a samba batucada in 2/4: the teleco-teco, a two-bar figure of sixteenths off the beat, the carreteiro striking every sixteenth with the teleco-teco's strokes accented, and a virada that closes a phrase with a run of thirty-seconds swelling into an accent.

`examples/solo/caxixi.exs` is the caxixi on its own, shaken with each of the berimbau's strokes in two of capoeira's toques: in angola it leans on the open note after two buzzes, and in são bento grande on the first buzz of each pair and the open note that closes the phrase.

`examples/solo/berimbau.exs` is the berimbau on its own as a capoeira roda plays it: the toque of Angola with three of its variations, São Bento Pequeno, São Bento Grande speeding up from 150 to 172 bpm, and Benguela to calm the game, each toque ending its bar on two quick buzzed strokes, at the tempo and spacing of a public-domain recording of Angola.
Its strokes move a little off the beat and in strength from bar to bar, as much as that recording's do.

`examples/solo/tabla.exs` is the tabla on its own in teentaal: its theka, with the khali, beats 9 to 12, played without the bayan, a faster variation splitting each beat in two, and the theka with the bayan bent upwards while it rings.
