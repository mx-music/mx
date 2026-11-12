# Fit scores on mxs and scsynth

Each instrument measured from held notes was scored with mix mx.fit --check against its recordings, at every dynamic they have, on mxs and on scsynth, on 11 November 2026.
A score is how far the synth's attack and bands are from the recordings', so lower is closer.
The scsynth scores come from main, the last commit that plays through scsynth; the mxs scores come from the rust-engine branch.
The Iowa files are the ones played without vibrato, and arco for the bowed strings; the clarinet's bands start at 160 Hz, as its fit test's do.
The tenor sax's VCSL files name each note an octave below where it sounds, so each is given an octave up.
The organ takes loud instead of vel, so each of its sets was scored at one vel with loud given as a control; its files are every third key of the third manual, from C2 to C7.
The harmonium's and the tanpura's are Freesound's public previews, as their design tests were measured from: cabled_mess's C2, C3, A3, C4 and D5, and sankalp's "Tanpura 10" on Db3, measured with --drone.

| Instrument | Recordings | scsynth | mxs |
| --- | --- | --- | --- |
| clarinet | Iowa | 141.12 | 139.95 |
| flute | Iowa | 42.73 | 46.56 |
| oboe | Iowa | 110.00 | 109.31 |
| bassoon | Iowa | 174.96 | 175.65 |
| trumpet | Iowa | 291.86 | 292.58 |
| trombone | Iowa | 477.64 | 477.61 |
| horn | Iowa | 646.62 | 646.08 |
| tuba | Iowa | 1293.77 | 1292.99 |
| tenor_sax | VCSL | 29.33 | 29.53 |
| violin | Iowa | 5.83 | 49.68 |
| viola | Iowa | 5.21 | 168.85 |
| cello | Iowa | 3.10 | 83.42 |
| double_bass | Iowa | 4.42 | 146.66 |
| organ, loud 0 | VSCO 2 Quiet | 9.26 | 9.77 |
| organ, loud 1 | VSCO 2 Loud | 207.39 | 208.27 |
| harmonium | Freesound | 0.00 | 0.00 |
| tanpura | Freesound | 0.94 | 2.36 |

The winds, brass, organ and harmonium score within 1% of scsynth, so they kept their designs and were not refitted.
The bowed strings were refitted on mxs, as mx-00124 bows them on a waveguide of mxs's own instead of sc3-plugins' DWGBowed.

## The winds as physical models

mx-00127 plays the winds through physical models, and on 12 November 2026 they were scored again with mix mx.fit --check against each wind's reference recordings, at every dynamic they have.
The horn and the tuba are measured from VSCO 2's held notes, so their scores are VSCO 2's, summed over pp, mf and ff, against 1561 and 1569 for the design before; the others are against the same recordings as the table above.

| Instrument | Recordings | Before | Physical model |
| --- | --- | --- | --- |
| clarinet | Iowa | 139.95 | 68.53 |
| flute | Iowa | 46.56 | 431.50 |
| oboe | Iowa | 109.31 | 46.08 |
| bassoon | Iowa | 175.65 | 149.29 |
| trumpet | Iowa | 292.58 | 181.10 |
| trombone | Iowa | 477.61 | 330.43 |
| horn | VSCO 2 | 1561 | 250 |
| tuba | VSCO 2 | 1569 | 384 |
| tenor_sax | VCSL | 29.53 | 78.78 |

- The flute was fitted to VSCO 2's flute and to played flutes from Wikimedia Commons, and judged by ear, so it reads 10 to 20 dB quieter than Iowa's from 400 Hz to 2.5 kHz and up to 35 dB quieter in Iowa's breath noise.
- The tenor sax speaks 94 percent slower than VCSL's at mf and 223 percent at ff, as a conical reed grows slowly from its threshold; a stronger tongue, a faster breath or a stronger breath each scored worse.

## Worse on mxs

- The flute's breath noise is 1 to 2 dB quieter between its harmonics from 250 to 400 Hz at pp and mf; its harmonics match scsynth's within 0.25 dB.
- The violin's and the cello's harmonics come within 6 dB of the recordings at every dynamic, but for the violin's 400 to 630 Hz and 1 to 1.6 kHz at pp, 6.4 and 7.5 dB low.
- The viola at every dynamic, and the double bass at ff, read 7 to 12 dB loud in every band by about the same amount, so the miss is in what the bands are measured against, the fundamental of the lowest note; I believe the body's corner, at 367 Hz for the viola and 67.5 Hz for the double bass, cuts that fundamental more than the recordings' bodies do.
- Between the harmonics, the rosin's noise has one slope for every bowed instrument: at pp the cello's is up to 14 dB too loud below 400 Hz and 9 dB too quiet above 1 kHz, and the double bass's up to 16 dB too quiet above 400 Hz.
- The violin at pp and the cello at pp and mf speak 31 to 39 percent faster than the recordings by mix mx.fit's measure, though within the design tests' 30 percent over their own notes.
- The tanpura's bands all stay within 6 dB of the recording, but its 1.6 to 2.5 kHz harmonics are 5.3 dB low against scsynth's 4.8, and its 160 to 250 Hz noise 4.3 dB loud against 4.0.
- The organ's loud set reads its noise 20 to 36 dB below the recordings on both engines, as the recordings hold noise up to 5 dB above the fundamental, which I believe is the blower; its design tests compare only its harmonics.
- The drums struck by noise fail some design tests on mxs, as their modes land where mxs's random draw puts them rather than scsynth's: the agogô, berimbau, bongos, clave, congas, ganzá and shaker, güiro, hi-hats, pandeiro, tabla, tambourine, toms and triangle.
  They sound right by ear, and on 11 November they were kept as they are.

## Not scored with mix mx.fit

- mix mx.fit measures held notes only, so the plucked and struck instruments are compared by their design tests alone.
