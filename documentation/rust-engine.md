# A Rust engine for mx on FunDSP

Notes from mx-00120, written on 10 November 2026.
They check the ticket's claims, recommend a scheduler, describe how Elixir and Rust talk and how a panic is contained, propose an exact-beat notation, and score a prototype that plays three of mx's instruments through FunDSP.
The prototype lives outside mx, in ~/code/vcrl/mx-engine, a Rust crate on fundsp 0.23.0, cpal 0.18.2 and hound, built with rustc 1.99.1.
Every instrument in it is built from FunDSP's own units after mx's designs in priv/synthdefs; no SuperCollider source was read or ported, and it is compared with today's mx only by measuring scsynth's renders.

## The claims, checked

### FunDSP

- Confirmed: fundsp 0.23.0 is under MIT OR Apache-2.0 (https://crates.io/crates/fundsp/0.23.0).
- Confirmed: it has static graphs, AudioNode, and dynamic ones, AudioUnit, with Net for graphs built at run time and a Net backend for changing one while it plays (https://github.com/SamiPerttu/fundsp).
- Confirmed: its Sequencer starts each event at the sample nearest its start time; Sequencer::process rounds the start to a sample index (src/sequencer.rs in the crate).
- Confirmed: it has oscillators, noise, filters, resonators, Karplus-Strong as pluck, delays and taps, waveshaping, panning and convolution, and loads audio files through Symphonia.
- Corrected: its only dynamics unit is a look-ahead limiter; it has no compressor.
- Confirmed: it has no audio input or output; the prototype pairs it with cpal.

### Knyst

- Confirmed: knyst 0.5.1 is under MIT OR Apache-2.0, released on 25 November 2024, its latest release (https://crates.io/crates/knyst/0.5.1).
- Confirmed: it changes graphs while playing and schedules to the sample.
- Corrected: musical-time tools are only on its roadmap (README.md:101), and its README says it is not stable (README.md:6).
- Corrected: it has no FunDSP bridge; its README says FunDSP nodes "can be encapsulated in a node" (README.md:80), and its interactive.rs example wraps a FunDSP reverb, but its published Cargo.toml declares no FunDSP dependency, so that example does not build from the crate.

### Rustler

- Confirmed: rustler 0.39.0 wraps each NIF call in catch_unwind and raises nif_panicked instead (rustler_codegen-0.39.0/src/nif.rs:82), as it does when encoding a result (rustler-0.39.0/src/codegen_runtime.rs:33) and in load (codegen_runtime.rs:115).
- Confirmed: a crate built with panic = "abort" aborts on a panic, so catch_unwind never sees it, and the BEAM dies with it.
- Confirmed: a NIF runs on the normal scheduler unless marked; the schedule option defaults to Normal and takes DirtyCpu or DirtyIo (rustler_codegen-0.39.0/src/nif.rs:8 and :104).

### Found while building the prototype

- A panic in cpal's audio callback aborts the whole process, even with panic = "unwind": cpal's callback runs on a CoreAudio thread, and the run printed "fatal runtime error: Rust panics must be rethrown, aborting" and exited with 134, SIGABRT (examples/callback_panic.rs).
- The same panic inside std::panic::catch_unwind in the callback leaves the process running, and the stream plays silence afterwards (examples/callback_panic.rs caught).
- FunDSP's Sequencer frees finished events off the audio thread as a rule: its backend sends each one back over a channel of 2048 slots, and the frontend drops them the next time it pushes or edits (src/realseq.rs, send_back_past).
- When more than 2048 events finish between two of the frontend's pushes, the rest are freed on the audio thread: two batches of 2000 events gave 1952 frees there, and two of 2048 gave 2048 (examples/sequencer_frees.rs).
- Pushing more than 2048 events before the backend takes them loses the rest silently: of 3000 pushed at once, 2048 sounded (examples/sequencer_frees.rs).
- Below those limits the Sequencer allocates nothing on the audio thread: its event lists and maps are reserved for 16384 events when it is made.
- FunDSP's envelope samples its function about every 2 ms, so a shape of a few milliseconds, such as the berimbau's 2 ms strike, comes out silent; FunDSP's Envelope::new takes a shorter interval, which the prototype uses for such shapes.
- FunDSP's bandpass_hz passes its centre at a gain of its Q, 2.857 at Q 2.857, measured with its own response method, so a bandpass that should peak at unity is scaled by 1 / Q.
- scsynth starts a note 65 samples after the start of its render, one control block and a sample; the engine starts at sample 0, and the comparison aligns both at their first sound.

## Scheduler: mx's own, on FunDSP's Sequencer

I recommend mx's own scheduler on FunDSP's Sequencer over Knyst.

- Knyst is not stable, has no musical time, and has no FunDSP bridge, so it would add a moving dependency and a bridge to write, for features mx already has.
- mx already knows each event's absolute beat and the tempo map, so the only scheduling the engine needs is starting a prebuilt sound at a time in seconds, which the Sequencer does to the sample.
- The Sequencer's frontend owns memory and its backend renders, so building and freeing sounds stays off the audio thread.
- The prototype's play binary pushes each note at its absolute beat converted to seconds, and the phrases play as written.

The Sequencer's limits set two rules for mx's scheduler.
- It pushes events a short window ahead, so fewer than 2048 are queued at once.
- It pushes or edits at least once for every 2048 events that finish, so finished events are dropped on its own thread; a frontend thread that pushes on a timer, an empty push if need be, meets this.

Settings that change while a sound plays, such as a filter's cutoff, go through FunDSP's shared values, shared and var in its prelude.

## How Elixir and Rust talk

- Elixir holds a handle to the running engine, a Rustler ResourceArc over the Sequencer's frontend and the thread that owns the cpal stream; dropping the handle stops the stream.
- mx sends events as {seconds, synth, options}; the NIF builds each sound from its design and pushes it, so the audio thread only renders.
- Building a note is cheap enough for the normal scheduler: 0.02 ms for a cello note, 0.04 to 0.07 ms for a piano note and 0.11 ms for a berimbau stroke (examples/cost.rs); a batch long enough to take over a millisecond, about ten berimbau strokes, goes through a DirtyCpu NIF, since a NIF on the normal scheduler holds up the BEAM while it runs.
- The audio callback allocates and locks nothing: it renders the Sequencer's backend, within the limits above.
- Offline renders, such as mix mx.render's, run on a DirtyCpu NIF; one second of a piano note renders in 7 to 9 ms, a cello note in 4 ms and a berimbau stroke in 19 ms, so one core plays about 115 piano notes, 264 cello notes or 54 berimbau strokes at once.

## Keeping a panic from killing the BEAM

- The crate builds with panic = "unwind", the default, so Rustler turns a panic in a NIF into an Elixir error.
- The audio callback runs its body inside catch_unwind; after a panic it plays silence, marks the engine failed, and the next NIF call returns an error naming it, so mx can restart the engine.
- CI checks three things: a Rust test that a unit panicking in the callback leaves the process alive and the stream silent, an ExUnit test that a NIF panicking on purpose raises and the BEAM carries on, and a check that no Cargo profile sets panic = "abort".

## Exact beats

### The notation

A song writes an exact fraction of a beat as frac(n, d), such as frac(1, 3) for a third of a beat.
frac does not clash with beats/1, the length of some music, or ratio/1, which turns a tuning ratio into semitones, and mx has no other function by that name.
beats(1, 3) reads well but shares its name with beats/1.
A song writes whole fractions only and never reduces them; frac(2, 6) and frac(1, 3) are the same beat.
Whole numbers stay whole numbers, and a float a song writes today plays as before.

A song in it, with a triplet, a dotted figure, and the 33 notes over 8 beats that examples/midnight.exs places today with Float.round(8 + step * 8 / 33, 3):

```elixir
import Mx

triplet = seq(for pitch <- [:c4, :e4, :g4], do: note(pitch, frac(1, 3)))
dotted = seq([note(:a4, frac(3, 4)), note(:b4, frac(1, 4))])
run = at(for step <- 0..32, do: {frac(8 * 33 + 8 * step, 33), note(72 + rem(step, 12), frac(8, 33))}, 16)

song(tempo: 84, music: seq([repeat(seq([triplet, dotted, rest(1)]), 2), run]))
```

### Underneath

- mx keeps a beat as a whole numerator and denominator, reduced by their greatest common divisor whenever it makes one, so 2/6 is stored as 1/3 and equal beats compare equal.
- Sums of lengths, loop starts and at offsets would stay exact, so a loop's 10,000th pass of six sixths would start at exactly beat 10,000.
- A float that reaches this arithmetic, from an old song, would stay a float, so nothing it plays changes.

### From beats to seconds

- Each event's time in seconds is worked out from its absolute beat through the tempo map, never by adding up lengths: the seconds up to the start of its tempo segment, plus the seconds of its exact offset into that segment.
- A segment at a steady tempo gives offset × 60 / bpm; a tempo: over: ramp moves evenly in bpm, so it gives the integral of 60 / bpm over the offset, which has a logarithm and is a float.
- Mx.Tempo already works this way from a timeline of absolute beats, keeping time as whole microseconds (lib/mx/tempo.ex:136); the engine would take the same time as f64 seconds instead.
- The exact beat becomes a float only at that last step, so no error carries from one event to the next.
- No whole-number ticks per beat sit in between: ticks are exact only for the divisions they were chosen for, while a fraction is exact for any.
- The engine takes seconds as f64 and the Sequencer rounds each start to the nearest sample; at 10 hours into a song an f64's spacing is about 7 picoseconds, far under a sample's 21 microseconds at 48 kHz.
- mx-00119 found no audible error from today's floats, so the gain is exactness and tidy output, not a fix for something heard.

## The prototype's instruments

The ticket asked for one held, one struck and one sampled instrument.
mx has none built on samples, the piano included, so the prototype plays the piano, struck; cello.bowed, held, on a bowed waveguide; and the berimbau, about 115 modes with noise and a gourd that swings its harmonics.
Each is measured as mx's designs test measures it, through mx's own Mx.Measure, beside scsynth's render of the same notes and the recordings' medians from test/mx/designs_test.exs.
The comparisons run with mix run ../mx-engine/measure/compare.exs piano berimbau and mix run ../mx-engine/measure/fit_cello.exs score, from mx.

### Piano

Each harmonic is a two-pole resonator struck once, FunDSP's biquad with its pole set by the harmonic's fade, plus a thump of lowpassed noise.
Across all nine of mx's tables, at three strengths without the pedal, with it, and below C2, every band's level is within 0.2 dB of scsynth's render and every fade is the same to the hundredth of a second.
Against the recordings the engine is off by 5.4 dB at worst, where scsynth is off by 5.5; the tests allow 6.
Its overall loudness is within 0.1 dB of scsynth's over each note's first half second, at every strength.

At vel 0.6 without the pedal, every fourth semitone from C2 to C7, against C2's fundamental:

| band, Hz | level dB, recordings | today | engine | fade s, recordings | today | engine |
|---|---|---|---|---|---|---|
| 80 to 160 | 4.9 | 3.2 | 3.2 | 8.4 | 10.1 | 10.1 |
| 160 to 250 | 6.4 | 2.6 | 2.6 | 11.1 | 11.6 | 11.6 |
| 250 to 400 | 1.1 | 1.9 | 2.0 | 10.8 | 11.3 | 11.3 |
| 400 to 630 | 0.1 | 0.6 | 0.6 | 10.8 | 10.7 | 10.7 |
| 630 to 1000 | -3.4 | -3.8 | -3.7 | 10.3 | 9.6 | 9.6 |
| 1000 to 1600 | -10.0 | -11.2 | -11.2 | 10.2 | 9.5 | 9.5 |
| 1600 to 2500 | -20.7 | -19.9 | -19.8 | 8.0 | 7.3 | 7.3 |
| 2500 to 4000 | -29.8 | -28.9 | -28.7 | 5.3 | 5.1 | 5.1 |

A held note stops within 3.08 s of a 3 s sustain and 0.1 s release, and a short one within 0.59 s, both under the tests' limits of 3.3 and 0.8.
One difference is open: in the first 5 ms the low notes, C1 and C2, are 6 to 16 dB quieter than scsynth's, while the rest are within 2 dB.
The harmonics start at phases spread by the golden angle, since starting them all at zero made a click 12 dB louder than scsynth's instead; each harmonic's beating twin starts at its phase, or the pair cancels for seconds.

### cello.bowed

Today's cello.bowed is built on sc3-plugins' DWGBowed and DWGSoundBoard, so the prototype's string is its own: a two-way waveguide, two delay lines meeting at the bow, where a friction curve holds the string while bow and string move at close speeds and lets it slip once they part.
It follows the bowed-string model of McIntyre, Schumacher and Woodhouse, "On the oscillations of musical instruments", JASA 74, 1983, and Julius O. Smith III's digital waveguides (https://ccrma.stanford.edu/~jos/pasp/Bowed_Strings.html).
After the string come mx's own high-pass, vibrato as a swinging delay, low-pass, the bow's hiss and the swell in, from its design.
Two parts of the design are left out because they correct DWGBowed's own faults: the comb that lifts the harmonics above its bow's jitter, and the table of how sharp it plays on each note.
In place of the design's ten peaks, whose gains were fitted to DWGBowed's sound, a peak sits at the centre of each of the eight bands the test measures, with its gain fitted to the recordings at pp, mf and ff by measure/fit_cello.exs.
Its level at each strength is set so it is as loud as today's cello at mf, -28.1 dB as the median over C2, C3, C4 and C5, and 14.6 dB louder at ff than at pp, where the recordings are 14.8 dB louder.
It plays C2 2.0 cents and Bb5 3.7 cents sharp, under the tests' 5; its vibrato swings at 5.90 Hz and 19 cents, where the bowed violin's swings at 5.90 Hz and 20 cents; vibrato: 0 has none; and every note is brighter at vel 1 than at vel 0.3.
Its pizzicato is not built, since it is today's plucked cello unchanged.

Every third semitone from C2 to Bb5, vibrato 0, against C2's fundamental, with today's additive cello and today's cello.bowed:

| vel 0.3 | recordings | today | today's bowed | engine |
|---|---|---|---|---|
| swells in, s | 0.54 | 0.6 | 0.6 | 0.6 |
| 80 to 160 Hz, dB | 17.2 | 19.1 | 15.9 | 16.9 |
| 160 to 250 | 21.6 | 19.3 | 22.0 | 21.6 |
| 250 to 400 | 17.3 | 15.2 | 16.5 | 17.5 |
| 400 to 630 | 10.0 | 9.3 | 13.5 | 10.4 |
| 630 to 1000 | 10.9 | 8.9 | 12.7 | 9.9 |
| 1000 to 1600 | 0.0 | 2.3 | 3.4 | 0.5 |
| 1600 to 2500 | -3.0 | -4.1 | -2.1 | -3.4 |
| 2500 to 4000 | -22.9 | -25.3 | -16.2 | -23.0 |

| vel 0.6 | recordings | today | today's bowed | engine |
|---|---|---|---|---|
| swells in, s | 0.5 | 0.5 | 0.6 | 0.5 |
| 80 to 160 Hz, dB | 17.6 | 19.1 | 17.2 | 17.2 |
| 160 to 250 | 21.1 | 19.2 | 18.1 | 21.2 |
| 250 to 400 | 17.8 | 15.6 | 18.9 | 17.7 |
| 400 to 630 | 12.2 | 12.4 | 14.8 | 12.5 |
| 630 to 1000 | 15.7 | 12.9 | 11.9 | 14.8 |
| 1000 to 1600 | 8.0 | 8.6 | 8.6 | 8.4 |
| 1600 to 2500 | 5.2 | 4.3 | 2.0 | 4.6 |
| 2500 to 4000 | -13.1 | -16.6 | -6.6 | -13.0 |

| vel 1 | recordings | today | today's bowed | engine |
|---|---|---|---|---|
| swells in, s | 0.39 | 0.5 | 0.5 | 0.4 |
| 80 to 160 Hz, dB | 15.2 | 19.3 | 16.3 | 15.2 |
| 160 to 250 | 19.8 | 19.5 | 20.0 | 19.8 |
| 250 to 400 | 14.3 | 16.0 | 17.9 | 14.3 |
| 400 to 630 | 12.5 | 13.4 | 17.1 | 13.1 |
| 630 to 1000 | 13.6 | 14.3 | 13.7 | 12.4 |
| 1000 to 1600 | 8.9 | 11.0 | 11.5 | 9.7 |
| 1600 to 2500 | 7.3 | 7.3 | 6.4 | 6.8 |
| 2500 to 4000 | -10.4 | -12.8 | -4.9 | -10.1 |

The engine scores closest partly because its peaks sit on the very bands it is measured in.
Its fitted gains reach 28 dB and alternate between neighbouring bands, which says the string's loss filters are darker than a cello's; a brighter string would need smaller gains, and I have not tried one.

### Berimbau

The berimbau follows its design in priv/synthdefs/mx-drums.scd: 19 partials of the string struck by a lowpassed tick, the gourd swinging four of them, 96 close modes of the wire struck by a burst of noise, a thud in three bands of noise, and the buzz's rattle.
Its wire's modes are drawn from FunDSP's hash, rnd1, not from scsynth's generator, so their frequencies and rings differ from today's; of eight seeds tried, two keep every wire mode under the string's 3rd and 5th harmonics, as the test asks and scsynth's seed does, and the prototype uses one of them.
The wire's levels take off 7 to 16 dB by band, fitted so the wire is as loud as in scsynth's render; with the thud corrected for bandpass_hz's gain, the string, thud and wire then match scsynth's band by band within about 1 dB over the stroke's first 85 ms.
Its loudness over the first half second is within 0.1 dB of scsynth's.

EliasArtista's jam, 46 strokes, against the loudest band as the string is struck, and 50, 100 and 200 ms after the loudest moment:

| band, Hz | at strike: recording | today | engine | 50, 100, 200 ms: recording | today | engine |
|---|---|---|---|---|---|---|
| 80 to 160 | -22.5 | -23.2 | -23.1 | -23, -23, -26 | -24.5, -25.7, -28.1 | -23.9, -25.2, -27.6 |
| 160 to 250 | -10.0 | -9.4 | -9.2 | -12, -13, -15 | -10.6, -11.9, -14.3 | -10.2, -11.4, -13.8 |
| 250 to 400 | -8.2 | -8.3 | -7.8 | -11, -12, -12 | -9.5, -10.7, -13.1 | -9.0, -10.3, -12.6 |
| 400 to 630 | -10.3 | -12.8 | -12.6 | -16, -18, -16 | -14.9, -16.5, -18.7 | -14.3, -15.4, -18.1 |
| 630 to 1000 | -11.7 | -14.4 | -13.2 | -15, -16, -18 | -15.7, -16.3, -19.0 | -13.8, -16.4, -19.0 |
| 1000 to 1600 | -10.1 | -14.4 | -14.8 | -13, -14, -16 | -16.2, -17.3, -20.4 | -15.5, -17.2, -19.7 |
| 1600 to 2500 | -9.9 | -12.5 | -12.6 | -12, -14, -18 | -15.6, -17.8, -19.9 | -18.0, -18.6, -22.1 |
| 2500 to 4000 | 0.0 | -1.9 | 0.0 | -6, -12, -19 | -9.7, -14.9, -21.1 | -8.5, -11.9, -21.9 |
| 4000 to 6300 | -0.3 | 0.0 | -0.3 | -12, -20, -22 | -8.6, -15.7, -23.1 | -8.5, -14.0, -20.3 |
| 6300 to 10000 | -5.0 | -5.7 | -10.8 | -19, -27, -27 | -18.8, -22.9, -27.1 | -19.8, -23.2, -27.5 |
| 10000 to 16000 | -9.6 | -13.0 | -14.9 | -26, -32, -33 | -23.5, -29.1, -34.0 | -22.4, -26.2, -30.8 |

The other measures of designs_test.exs, today against the engine:

| measure | test | today | engine |
|---|---|---|---|
| worst partial off the string's harmonics, open, coin, note 41 | 3% | 0.4%, 0.9%, 0.7% | 0.6%, 1.0%, 0.5% |
| strongest two partials | 233 and 390 Hz | 235 and 391 Hz | 235 and 391 Hz |
| vel 1 over vel 0.3, open, coin, buzz | over 6 dB | 17.3, 18.1, 18.6 dB | 17.3, 18.1, 18.5 dB |
| the gourd's swing of the 5th against the 3rd | over 20 dB, 0.43 s apart | 36.2 dB, 0.44 s | 36.3 dB, 0.44 s |
| with gourd: 0 | under 6 dB | 0.2 dB | 0.3 dB |
| a buzzed stroke from 0.2 s against its start | under -29.5 dB | -49.6 dB | -50.5 dB |
| an open stroke from 0.2 s against its start | over -14 dB | -13.2 dB | -13.2 dB |

A buzzed stroke is brighter than an open one in the engine too, with 66% of its first 50 ms above 1.5 kHz against 52%.
Two of the engine's figures sit within 0.7 dB of the tests' limits: the top band 5.3 dB under the recording at the strike, and 5.7 dB over it 100 ms later, where its wire rings a little longer than scsynth's.

## SuperCollider units mx's designs use, and what replaces each

The list comes from the units named in priv/synthdefs/*.scd.
Units with a direct match in FunDSP: SinOsc, Saw, Pulse, LFTri, WhiteNoise, PinkNoise, LPF, HPF, BLowPass, BHiPass, BLowShelf, BHiShelf, BPeakEQ, DelayN, DelayC, Pan2, LeakDC, SampleRate, SampleDur and ControlDur.
Those that need more:

| unit | replacement |
|---|---|
| EnvGen, IEnvGen, Line | envelope from a closure; for shapes of a few milliseconds, Envelope::new with an interval of 20 microseconds |
| BPF | bandpass_hz scaled by 1 / Q, since it peaks at a gain of Q |
| RLPF, RHPF | lowpass_hz and highpass_hz with q as 1 / rq |
| BLowPass4, BHiPass4 | two lowpass_hz or highpass_hz in a row, at q 0.541 and 1.307 |
| Ringz, Klank, DynKlank | a bank of two-pole resonators, FunDSP's biquad with each pole set from its 60 dB fade and its start phase chosen; resonator_hz's gain and phase do not suit a struck mode |
| DynKlang | a bank of sine_hz, each with its phase |
| Impulse, once | impulse |
| Impulse, repeating, and Dust | no unit; a closure on a ramp, with seeded random times from rnd1 for Dust |
| RandSeed, TRand | seed on each noise unit, and rnd1 at build time; the draws differ from scsynth's, so seeded designs are measured again |
| Decay, Decay2 | an exponential envelope, or an impulse into lowpole |
| CombC, CombL | tap or tap_linear inside feedback, minding the sample feedback adds |
| VarLag, Lag | follow |
| LFNoise1, LFNoise2 | a closure that interpolates seeded random values from rnd1, straight or curved |
| LFSaw, Phasor, Sweep | ramp_hz, or a closure on time |
| LFCub | no unit; a polynomial on a ramp |
| LFPulse | pulse, scaled to run from 0 to 1 |
| Blip | dsf_saw, or a bank of sine_hz |
| Pluck | pluck, a different string model, so the design is refitted |
| Select, InRange | Rust at build time, or a map closure |
| DetectSilence | no unit; each sound's length is worked out from its design when it is pushed, as the Sequencer needs an end time |
| Balance2 | per-channel gains |
| Compander | no compressor in FunDSP; afollow driving a gain curve in a map closure |
| FreeVerb2 | reverb_stereo, a different design, fitted by ear |
| Out, In, LocalIn, LocalOut | Net's connections and feedback |
| SoundIn | a cpal input stream into a FunDSP buffer |
| DiskOut | hound on a thread of its own, fed from the audio callback without blocking |
| BufRd, BufFrames, BufSampleRate | Wave, loaded through Symphonia, with playwave and resample |
| DWGBowed, DWGSoundBoard | a bowed waveguide of the engine's own and fitted peaks, as cello.bowed above; mx-00124 takes it further |

## What is left open

- Listening: the three phrases are rendered through the engine and through scsynth for comparison; by ear the piano is close to today's, and the cello and berimbau are not yet judged.
- The piano's low notes start 6 to 16 dB softer in their first 5 ms than scsynth's.
- cello.bowed's fitted gains are large; a brighter string may need less.
- The berimbau's top band is within 0.7 dB of its limits, and its wire was fitted against scsynth's render rather than the recording.
