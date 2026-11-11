# Fit scores on mxs and scsynth

Each instrument measured from held notes was scored with mix mx.fit --check against its recordings, at every dynamic they have, on mxs and on scsynth, on 11 November 2026.
A score is how far the synth's attack and bands are from the recordings', so lower is closer.
The scsynth scores come from main, the last commit that plays through scsynth; the mxs scores come from the rust-engine branch.
The Iowa files are the ones played without vibrato, and arco for the bowed strings; the clarinet's bands start at 160 Hz, as its fit test's do.
The tenor sax's VCSL files name each note an octave below where it sounds, so each is given an octave up.

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

The winds and brass score within 1% of scsynth, so they kept their designs and were not refitted.
The bowed strings were refitted on mxs, as mx-00124 bows them on a waveguide of mxs's own instead of sc3-plugins' DWGBowed.

## Worse on mxs

- The flute's breath noise is 1 to 2 dB quieter between its harmonics from 250 to 400 Hz at pp and mf; its harmonics match scsynth's within 0.25 dB.
- The violin's and the cello's harmonics come within 6 dB of the recordings at every dynamic, but for the violin's 400 to 630 Hz and 1 to 1.6 kHz at pp, 6.4 and 7.5 dB low.
- The viola at every dynamic, and the double bass at ff, read 7 to 12 dB loud in every band by about the same amount, so the miss is in what the bands are measured against, the fundamental of the lowest note; I believe the body's corner, at 367 Hz for the viola and 67.5 Hz for the double bass, cuts that fundamental more than the recordings' bodies do.
- Between the harmonics, the rosin's noise has one slope for every bowed instrument: at pp the cello's is up to 14 dB too loud below 400 Hz and 9 dB too quiet above 1 kHz, and the double bass's up to 16 dB too quiet above 400 Hz.
- The violin at pp and the cello at pp and mf speak 31 to 39 percent faster than the recordings by mix mx.fit's measure, though within the design tests' 30 percent over their own notes.
- The drums struck by noise fail some design tests on mxs, as their modes land where mxs's random draw puts them rather than scsynth's: the agogô, berimbau, bongos, clave, congas, ganzá and shaker, güiro, hi-hats, pandeiro, tabla, tambourine, toms and triangle.
  They sound right by ear, and on 11 November they were kept as they are.

## Not scored with mix mx.fit

- The organ takes no vel, which mix mx.fit sets at each dynamic; its design tests, against VSCO 2's quiet and loud sets, pass on mxs.
- The harmonium's and the tanpura's Freesound recordings were not on the machine; their design tests pass on mxs.
- mix mx.fit measures held notes only, so the plucked and struck instruments are compared by their design tests alone.
