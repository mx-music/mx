//! Held notes partial by partial, bowed, blown or played on an organ, for `mix mx.fit --held` and `mix mx.measure --held --partials`.
//! A held note's pitch is followed every 5 ms and the note resampled along it to one steady pitch, so its vibrato and drift no longer smear its partials, which are then followed as a struck note's are.
//! Its figures are each partial's level at the struck notes' times up to where the note holds, one level while it holds, and a slope in dB a second once it is let go; the noise between the partials the same, in each ERB band; and the vibrato's rate and depth, with how far each partial's level swings with it.

use super::fit::{self, Band, Figures, Partial, SILENT, TIMES};
use super::partials::{self, CLEAR, Floor, HOP, LEAD, Track};
use super::{db, hz, median};
use rustfft::{FftPlanner, num_complex::Complex};
use rustler::NifMap;
use std::f64::consts::PI;

/// The seconds between two readings of the pitch.
const PITCH_HOP: f64 = 0.005;
/// The dB under the held level the note counts as holding, from its rise to its letting go.
const HOLDING: f64 = 3.0;
/// The seconds a note holds after it first comes within `HOLDING` dB of its held level before its figures hold one level, so the end of the attack is still followed.
const SETTLING: f64 = 0.1;
/// The fewest cents a vibrato swings by to count as one.
const VIBRATO: f64 = 3.0;
const ROUNDS: usize = 5;
/// The highest a held note's noise is fitted to, as a flute's breath reaches past 8 kHz.
const NOISE_TOP: f64 = 16_000.0;
/// The lowest a held note's noise is fitted from, as under it the recordings hold the room's rumble and no breath.
const NOISE_BOTTOM: f64 = 200.0;

/// A held note's figures: levels at the struck figures' times until the recording lets the note go, held at the last after, each partial's and band's tail its slope once let go.
#[derive(Clone)]
pub struct Held {
    pub figures: Figures,
    /// The seconds after the start from which every level holds.
    pub held: f64,
    /// The seconds after the start the recording lets the note go.
    pub release: f64,
    /// The vibrato's rate in Hz and its depth in cents either side, 0 when the note has none.
    pub vibrato: (f64, f64),
    /// How far each partial's level swings with the vibrato, in dB at its full depth, rising as the pitch does.
    pub swings: Vec<f64>,
}

/// A held note's pitch every 5 ms from its start, the steady pitch it is resampled to, and its vibrato.
pub struct Pitch {
    pub track: Vec<f64>,
    pub steady: f64,
    pub vibrato: (f64, f64),
    /// The cents from the steady pitch every 5 ms, with the drift slower than the vibrato taken out.
    pub swing: Vec<f64>,
}

/// A held note measured partial by partial on its steadied sound.
pub struct Measured {
    pub sound: Vec<f64>,
    pub rate: f64,
    pub start: usize,
    pub pitch: Pitch,
    pub note: partials::Note,
    /// The frames the note holds in, from its rise to its letting go.
    pub holding: std::ops::Range<usize>,
    pub held: f64,
    pub release: f64,
    pub fall: f64,
}

/// The sample a held note starts at: the first 10 ms within 30 dB of its loudest 10 ms, since a soft bow or breath rises slowly, and a click before it is too short to count.
pub fn start(sound: &[f64], rate: f64) -> usize {
    let size = (0.01 * rate).round().max(1.0) as usize;
    let levels: Vec<f64> = sound
        .chunks(size)
        .map(|c| c.iter().map(|x| x * x).sum::<f64>() / c.len() as f64)
        .collect();
    let peak = levels.iter().cloned().fold(0.0f64, f64::max);
    let first = levels.iter().position(|l| *l > peak * 1e-3).unwrap_or(0) * size;
    let local = sound[first..(first + size).min(sound.len())]
        .iter()
        .fold(0.0f64, |top, v| top.max(v.abs()));
    first
        + sound[first..]
            .iter()
            .position(|v| v.abs() > local * 0.1)
            .unwrap_or(0)
}

// The magnitude spectrum of the window of `size` samples centred on `centre`, zero-padded to `padded`.
fn spectrum(
    sound: &[f64],
    centre: f64,
    hann: &[f64],
    fft: &dyn rustfft::Fft<f64>,
    padded: usize,
) -> Vec<f64> {
    let size = hann.len();
    let mut buffer: Vec<Complex<f64>> = (0..padded)
        .map(|i| {
            if i >= size {
                return Complex::new(0.0, 0.0);
            }
            let at = (centre + i as f64 - (size / 2) as f64).round();
            let sample = if at >= 0.0 && (at as usize) < sound.len() {
                sound[at as usize]
            } else {
                0.0
            };
            Complex::new(sample * hann[i], 0.0)
        })
        .collect();
    fft.process(&mut buffer);
    buffer[..padded / 2]
        .iter()
        .map(|c| c.norm().max(1e-12))
        .collect()
}

/// Follows a held note's pitch every 5 ms from `start`, by the loudest of its first four harmonics, through a window four periods long and at least 40 ms.
/// Where the note is more than 25 dB under its loudest, before it speaks and after it ends, the pitch is the nearest one read.
pub fn pitch(sound: &[f64], rate: f64, start: usize, note: f64) -> Pitch {
    let guess = hz(note);
    let size = ((4.0 / guess).max(0.04) * rate).round() as usize;
    let padded = (4 * size).next_power_of_two();
    let fft = FftPlanner::<f64>::new().plan_fft_forward(padded);
    let hann: Vec<f64> = (0..size)
        .map(|i| 0.5 - 0.5 * (2.0 * PI * i as f64 / size as f64).cos())
        .collect();
    let bin = rate / padded as f64;
    let count = ((sound.len().saturating_sub(start)) as f64 / (PITCH_HOP * rate)) as usize;
    let frames: Vec<Vec<f64>> = super::parallel(&(0..count).collect::<Vec<_>>(), |&k| {
        spectrum(
            sound,
            start as f64 + k as f64 * PITCH_HOP * rate,
            &hann,
            fft.as_ref(),
            padded,
        )
    });
    let harmonics: Vec<usize> = (1..=4)
        .filter(|n| *n as f64 * guess < 0.45 * rate)
        .collect();
    let loudness = |n: usize| {
        frames
            .iter()
            .map(|f| partials::peak_near(f, bin, n as f64 * guess, 0.03 * n as f64 * guess).1)
            .map(|l| 10f64.powf(l / 10.0))
            .sum::<f64>()
    };
    let n = super::first_max(harmonics, |n| loudness(*n)).unwrap_or(1) as f64;
    let read: Vec<(f64, f64)> = frames
        .iter()
        .map(|f| partials::peak_near(f, bin, n * guess, 0.03 * n * guess))
        .map(|(freq, level)| (freq / n, level))
        .collect();
    let loudest = read.iter().map(|r| r.1).fold(f64::MIN, f64::max);
    let clear: Vec<usize> = (0..read.len())
        .filter(|k| read[*k].1 > loudest - 25.0)
        .collect();
    let track: Vec<f64> = (0..read.len())
        .map(|k| {
            let nearest = clear.iter().min_by_key(|c| (**c as i64 - k as i64).abs());
            nearest.map_or(guess, |c| read[*c].0)
        })
        .collect();
    let track = smoothed(&track);
    let steady = if clear.is_empty() {
        guess
    } else {
        median(&clear.iter().map(|k| track[*k]).collect::<Vec<_>>())
    };
    let cents: Vec<f64> = track.iter().map(|f| 1200.0 * (f / steady).log2()).collect();
    // The drift slower than any vibrato, a moving mean over 0.4 seconds, is taken out before the vibrato is looked for.
    let reach = (0.2 / PITCH_HOP) as usize;
    let swing: Vec<f64> = (0..cents.len())
        .map(|k| {
            let around = &cents[k.saturating_sub(reach)..(k + reach + 1).min(cents.len())];
            cents[k] - around.iter().sum::<f64>() / around.len() as f64
        })
        .collect();
    let within: Vec<usize> = clear
        .iter()
        .cloned()
        .filter(|k| *k > clear[0] + reach && *k + reach < *clear.last().unwrap())
        .collect();
    let vibrato = vibrato(&swing, &within);
    Pitch {
        track,
        steady,
        vibrato,
        swing,
    }
}

// A three-frame median, so a single misread frame does not jolt the pitch.
fn smoothed(track: &[f64]) -> Vec<f64> {
    (0..track.len())
        .map(|k| median(&track[k.saturating_sub(1)..(k + 2).min(track.len())]))
        .collect()
}

// The vibrato's rate and depth: the strongest swing from 3 to 9 Hz over the frames given, a vibrato when it swings at least 3 cents either side and holds at least 40 percent of the swing there.
fn vibrato(swing: &[f64], frames: &[usize]) -> (f64, f64) {
    if frames.len() < (0.6 / PITCH_HOP) as usize {
        return (0.0, 0.0);
    }
    let values: Vec<f64> = frames.iter().map(|k| swing[*k]).collect();
    let mean = values.iter().sum::<f64>() / values.len() as f64;
    let variance = values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / values.len() as f64;
    let amplitude = |rate: f64| {
        let sum: Complex<f64> = frames
            .iter()
            .zip(&values)
            .map(|(k, v)| Complex::from_polar(v - mean, -2.0 * PI * rate * *k as f64 * PITCH_HOP))
            .sum();
        2.0 * sum.norm() / values.len() as f64
    };
    let rates = (0..=120).map(|i| 3.0 + i as f64 * 0.05);
    let (rate, depth) = rates
        .map(|r| (r, amplitude(r)))
        .fold(
            (0.0, 0.0),
            |best, next| if next.1 > best.1 { next } else { best },
        );
    if depth >= VIBRATO && depth * depth / 2.0 >= 0.4 * variance {
        (rate, depth)
    } else {
        (0.0, 0.0)
    }
}

/// The sound resampled along its pitch to the steady pitch: each sample read where the note has moved on by as many periods as at the steady pitch.
pub fn steadied(sound: &[f64], rate: f64, start: usize, pitch: &Pitch) -> (Vec<f64>, usize) {
    let hop = PITCH_HOP * rate;
    let ratio = |i: usize| {
        let at = (i as f64 - start as f64) / hop;
        let track = &pitch.track;
        if track.is_empty() {
            return 1.0;
        }
        let k = at.max(0.0).floor() as usize;
        let (a, b) = (
            track[k.min(track.len() - 1)],
            track[(k + 1).min(track.len() - 1)],
        );
        let share = (at.max(0.0) - k as f64).min(1.0);
        (a + share * (b - a)) / pitch.steady
    };
    let mut out = vec![];
    let mut tau = 0.0;
    let mut next = 0.0;
    let mut new_start = 0;
    for i in 0..sound.len().saturating_sub(1) {
        let step = ratio(i);
        if i == start {
            new_start = next as usize;
        }
        while next < tau + step {
            out.push(interpolated(sound, i as f64 + (next - tau) / step));
            next += 1.0;
        }
        tau += step;
    }
    (out, new_start)
}

// The sound between samples, through a windowed sinc 32 samples wide.
fn interpolated(sound: &[f64], at: f64) -> f64 {
    let taps = 16i64;
    let centre = at.floor() as i64;
    (centre - taps + 1..=centre + taps)
        .filter(|k| *k >= 0 && (*k as usize) < sound.len())
        .map(|k| {
            let x = at - k as f64;
            let sinc = if x.abs() < 1e-9 {
                1.0
            } else {
                (PI * x).sin() / (PI * x)
            };
            let window = 0.5 + 0.5 * (PI * x / taps as f64).cos();
            sound[k as usize] * sinc * window
        })
        .sum()
}

/// Measures a held note over `seconds` from its start: its pitch and vibrato, then its harmonics up to 8 kHz on its steadied sound, where it holds, where it is let go, and how fast it falls after.
pub fn measure(sound: &[f64], rate: f64, note: f64, seconds: f64) -> Measured {
    measure_from(sound, rate, note, seconds, start(sound, rate))
}

/// Measures a held note as `measure` does, from a start given, for a render whose note starts where it was played.
pub fn measure_from(sound: &[f64], rate: f64, note: f64, seconds: f64, begin: usize) -> Measured {
    let pitch = pitch(sound, rate, begin, note);
    let (steady_sound, start) = steadied(sound, rate, begin, &pitch);
    let seconds = seconds.min((steady_sound.len() - start) as f64 / rate);
    let spectra = partials::spectra_from(&steady_sound, rate, pitch.steady, seconds, start);
    let f0 = pitch.steady;
    let top = partials::TOP.min(0.45 * rate);
    let harmonics: Vec<f64> = (1..)
        .map(|n| n as f64 * f0)
        .take_while(|f| *f <= top)
        .collect();
    let floor = Floor::new(&spectra, &harmonics);
    let freqs: Vec<(f64, u32)> = harmonics
        .iter()
        .enumerate()
        .map(|(n, f)| (*f, n as u32 + 1))
        .collect();
    let levels = partials::follow(
        &steady_sound,
        &spectra,
        &freqs.iter().map(|f| f.0).collect::<Vec<_>>(),
    );
    let tracks: Vec<Track> = freqs
        .iter()
        .zip(levels)
        .map(|((freq, harmonic), levels)| Track {
            freq: *freq,
            harmonic: *harmonic,
            floor: floor.at(*freq),
            levels,
        })
        .collect();
    let total: Vec<f64> = (0..spectra.frames.len())
        .map(|k| {
            10.0 * tracks
                .iter()
                .map(|t| 10f64.powf(t.levels[k] / 10.0))
                .sum::<f64>()
                .max(1e-30)
                .log10()
        })
        .collect();
    let loudest = total.iter().cloned().fold(f64::MIN, f64::max);
    let body: Vec<f64> = total
        .iter()
        .cloned()
        .filter(|l| *l > loudest - 15.0)
        .collect();
    let level = median(&body);
    let first = total
        .iter()
        .position(|l| *l >= level - HOLDING)
        .unwrap_or(0);
    // The note is let go at the last frame within `HOLDING` dB of its held level before it first stays 6 dB under it for a tenth of a second, so a sound later in the stretch is not taken for the note.
    let gone = (0.1 / HOP) as usize;
    let mut under = 0;
    let mut last = first;
    for (k, l) in total.iter().enumerate().skip(first) {
        if *l >= level - HOLDING {
            last = k;
        }
        under = if *l < level - 6.0 { under + 1 } else { 0 };
        if under >= gone {
            break;
        }
    }
    let time = |k: usize| k as f64 * HOP - LEAD;
    // The figures hold from a time of the struck notes' at or after the attack settles.
    let settles = time(first) + SETTLING;
    let held = TIMES
        .iter()
        .cloned()
        .find(|t| *t >= settles)
        .unwrap_or(TIMES[TIMES.len() - 1])
        .min(time(last).max(0.0));
    let release = time(last);
    // The frames whose windows lie wholly between the attack and the letting go.
    let half = (spectra.window / 2.0 / HOP).ceil() as usize;
    let from = ((held + LEAD) / HOP).round() as usize;
    let holding = from.min(last)
        ..last
            .saturating_sub(half)
            .max(from.min(last) + 1)
            .min(total.len());
    let partials: Vec<Track> = tracks
        .into_iter()
        .filter(|t| {
            t.levels[..holding.end]
                .iter()
                .cloned()
                .fold(f64::MIN, f64::max)
                > t.floor + CLEAR
        })
        .collect();
    let fall = falling(&steady_sound, rate, start, release);
    let note = partials::Note {
        f0,
        spectra,
        floor,
        partials,
        left_out: vec![],
    };
    Measured {
        sound: steady_sound,
        rate,
        start,
        pitch,
        note,
        holding,
        held,
        release,
        fall,
    }
}

// How fast the whole sound falls once let go, in dB a second: from 6 dB under its held level to 36 dB under, read every 5 ms, or to as far as it falls above its floor.
fn falling(sound: &[f64], rate: f64, start: usize, release: f64) -> f64 {
    let hop = (0.005 * rate) as usize;
    let levels: Vec<f64> = sound[start..]
        .chunks(hop)
        .map(|c| db((c.iter().map(|x| x * x).sum::<f64>() / c.len() as f64).sqrt()))
        .collect();
    let at = ((release / 0.005).max(0.0) as usize).min(levels.len().saturating_sub(1));
    let before = &levels[at.saturating_sub((0.3 / 0.005) as usize)..at.max(1)];
    let held = median(before);
    let floor = {
        let mut sorted = levels.clone();
        sorted.sort_by(f64::total_cmp);
        sorted[sorted.len() / 20]
    };
    let begin = at.saturating_sub(10);
    let Some(six) = levels[begin..]
        .iter()
        .position(|l| *l < held - 6.0)
        .map(|i| i + begin)
    else {
        return -60.0;
    };
    let deepest = (held - 36.0).max(floor + 6.0);
    match levels[six..].iter().position(|l| *l < deepest) {
        Some(i) if i > 0 => -(held - 6.0 - deepest).max(6.0) / (i as f64 * 0.005),
        _ => -60.0,
    }
}

/// The level of a held note's partial or band at `t` seconds after its start, let go at `release`: its figures' level until then, falling at its tail after.
pub fn level_at(levels: &[f64], tail: f64, t: f64, release: f64) -> f64 {
    fit::level_at(levels, 0.0, t.min(release))
        + if t > release {
            tail * (t - release)
        } else {
            0.0
        }
}

fn noise_level_at(levels: &[f64], tail: f64, t: f64, release: f64) -> f64 {
    fit::noise_level_at(levels, 0.0, t.min(release))
        + if t > release {
            tail * (t - release)
        } else {
            0.0
        }
}

// White noise from -1 to 1, the same every render, as the struck figures' noise.
struct Noise(u64);

impl Noise {
    fn next(&mut self) -> f64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 >> 11) as f64 / (1u64 << 52) as f64 - 1.0
    }
}

/// The figures played as sines and noise at `rate`, after `lead` seconds of silence, let go at `release`, for `seconds`, with their vibrato or steady.
/// The vibrato fades in over the attack, to its depth where the note holds.
pub fn render(
    held: &Held,
    rate: f64,
    lead: f64,
    release: f64,
    seconds: f64,
    vibrato: bool,
) -> Vec<f64> {
    let figures = &held.figures;
    let start = (lead * rate).round() as usize;
    let count = (seconds * rate).round() as usize;
    let mut sound = vec![0.0; start + count];
    let (vibrato_rate, depth) = if vibrato { held.vibrato } else { (0.0, 0.0) };
    let swing = |t: f64| {
        if depth > 0.0 {
            (t / held.held.max(0.05)).min(1.0) * (2.0 * PI * vibrato_rate * t).sin()
        } else {
            0.0
        }
    };
    for (p, partial) in figures.partials.iter().enumerate() {
        let freq = partial.ratio * figures.f0;
        if freq >= rate / 2.0 {
            continue;
        }
        let swings = held.swings.get(p).cloned().unwrap_or(0.0);
        let mut phase = 0.0f64;
        for i in 0..count {
            let t = i as f64 / rate;
            let v = swing(t);
            let level = level_at(&partial.levels, partial.tail, t, release) + swings * v;
            if level < -140.0 && t > release {
                break;
            }
            let rise = (t / fit::RISE).min(1.0);
            sound[start + i] += rise * 10f64.powf(level / 20.0) * phase.sin();
            phase += 2.0 * PI * freq * 2f64.powf(depth * v / 1200.0) / rate;
        }
    }
    for (k, band) in figures.noise.iter().enumerate() {
        if band.high >= rate / 2.0 || band.levels.iter().all(|l| *l <= SILENT) {
            continue;
        }
        let filter = fit::band_filter(band.low, band.high, rate);
        let rise = fit::noise_rise(band.low, band.high);
        let mut noise =
            Noise(0x9e37_79b9_7f4a_7c15 ^ (k as u64 + 1).wrapping_mul(0xbf58_476d_1ce4_e5b9));
        let mut state = [[0.0f64; 4]; 4];
        let mut filtered = || {
            let mut x = noise.next();
            for (s, [b0, b1, b2, a1, a2]) in state.iter_mut().zip(&filter) {
                let y = b0 * x + b1 * s[0] + b2 * s[1] - a1 * s[2] - a2 * s[3];
                *s = [x, s[0], y, s[2]];
                x = y;
            }
            x
        };
        for _ in 0..(fit::WARM * rate) as usize {
            filtered();
        }
        for i in 0..count {
            let t = i as f64 / rate;
            let level = noise_level_at(&band.levels, band.tail, t, release);
            if level < -140.0 && t > release {
                break;
            }
            sound[start + i] += fit::rising(t, rise) * 10f64.powf(level / 20.0) * filtered();
        }
    }
    sound
}

/// Fits a held note's figures over `seconds` from its start: each partial's level at each time from its track on the steadied sound, until the recording lets it go, and the noise from what the recording holds beyond the partials, both corrected against steady renders measured the same way.
/// After the last time before the recording lets the note go, every level holds, so a note held longer holds as the recording last did.
/// With `steady`, every level holds from where the note starts holding instead, at one level over the whole stretch, for recordings that ease off before they are let go, as Iowa's flute does, since a longer note should not hold the easing.
pub fn fit(sound: &[f64], rate: f64, note: f64, seconds: f64, steady: bool) -> (Held, Measured) {
    let measured = measure(sound, rate, note, seconds);
    let recorded = &measured.note;
    let spectra = &recorded.spectra;
    let seconds = spectra.frames.len() as f64 * HOP + spectra.window / 2.0 - LEAD;
    let frame = |t: f64| ((t + LEAD) / HOP).round().max(0.0) as usize;
    let last = measured.holding.end.min(spectra.frames.len());
    let follows = TIMES.partition_point(|t| frame(*t) < last).max(1);
    let holds = if steady {
        follows.min(TIMES.partition_point(|t| *t < measured.held) + 1)
    } else {
        follows
    };
    // The frames each time is read over: those nearer it than its neighbours, the last time's reaching to where the note is let go.
    let segments: Vec<std::ops::Range<usize>> = (0..holds)
        .map(|j| {
            let from = if j == 0 {
                0
            } else {
                frame((TIMES[j - 1] + TIMES[j]) / 2.0)
            };
            let to = if j + 1 == holds {
                last
            } else {
                frame((TIMES[j] + TIMES[j + 1]) / 2.0)
            };
            let from = from.min(last.saturating_sub(1));
            from..to.clamp(from + 1, last.max(from + 1))
        })
        .collect();
    let hold = |levels: &mut Vec<f64>| {
        let kept = levels[holds - 1];
        levels[holds..].iter_mut().for_each(|l| *l = kept);
    };
    let partials: Vec<Partial> = recorded
        .partials
        .iter()
        .map(|track| {
            let mut levels: Vec<f64> = (0..TIMES.len())
                .map(|j| {
                    segments
                        .get(j)
                        .map_or(SILENT, |range| mean_db(&track.levels[range.clone()]))
                })
                .collect();
            hold(&mut levels);
            Partial {
                ratio: track.freq / recorded.f0,
                harmonic: track.harmonic,
                levels,
                tail: release_slope(track, &measured),
            }
        })
        .collect();
    let bands = fit::erb_bands_to(NOISE_TOP);
    let noise = bands
        .iter()
        .map(|(low, high)| Band {
            low: *low,
            high: *high,
            levels: vec![SILENT; TIMES.len()],
            tail: measured.fall,
        })
        .collect();
    let mut held = Held {
        figures: Figures {
            f0: recorded.f0,
            pitch: hz(note),
            partials,
            noise,
            reached: TIMES[TIMES.len() - 1],
            rate,
        },
        held: measured.held,
        release: measured.release,
        vibrato: measured.pitch.vibrato,
        swings: vec![],
    };
    let freqs: Vec<f64> = recorded.partials.iter().map(|t| t.freq).collect();
    let bins: Vec<Vec<usize>> = bands
        .iter()
        .map(|(low, high)| {
            let a = (low / spectra.bin).round() as usize;
            (a..((high / spectra.bin).round() as usize).max(a + 1)).collect()
        })
        .collect();
    let gains = fit::noise_gains(spectra, &bands, &bins, rate);
    let theirs = fit::band_powers(spectra, &bins);
    // A band's noise is read from its bins clear of the partials, scaled to the whole band, so a band holding a partial keeps the noise around it.
    let near: Vec<f64> = freqs
        .iter()
        .copied()
        .chain(
            (1..)
                .map(|n| n as f64 * recorded.f0)
                .take_while(|f| *f <= NOISE_TOP),
        )
        .collect();
    let clear: Vec<Vec<usize>> = bins
        .iter()
        .map(|bins| {
            bins.iter()
                .copied()
                .filter(|&i| {
                    near.iter()
                        .all(|f| (i as f64 * spectra.bin - f).abs() > 2.0 * spectra.resolution)
                })
                .collect()
        })
        .collect();
    let clear_powers = |spectra: &partials::Spectra| -> Vec<Vec<f64>> {
        spectra
            .frames
            .iter()
            .map(|f| {
                clear
                    .iter()
                    .zip(&bins)
                    .map(|(clear, all)| {
                        let power = clear
                            .iter()
                            .filter_map(|&i| f.get(i))
                            .map(|m| m * m)
                            .sum::<f64>()
                            / clear.len().max(1) as f64
                            * all.len() as f64;
                        10.0 * power.max(1e-24).log10()
                    })
                    .collect()
            })
            .collect()
    };
    let theirs_clear = clear_powers(spectra);
    // The room's floor in each band is its quietest frames, before the note and after it ends, since between a held note's partials is its breath or bow.
    let floors: Vec<f64> = (0..bands.len())
        .map(|k| {
            let mut levels: Vec<f64> = theirs.iter().map(|row| row[k]).collect();
            levels.sort_by(|a, b| a.partial_cmp(b).unwrap());
            10f64.powf((levels.get(levels.len() / 20).copied().unwrap_or(SILENT) + CLEAR) / 10.0)
        })
        .collect();
    let lead = (0.05 * rate).round() as usize;
    for round in 0..ROUNDS {
        let rendered = render(&held, rate, 0.05, measured.release, seconds + 0.1, false);
        let ours = partials::spectra_from(&rendered, rate, recorded.f0, seconds, lead);
        let tracks = partials::follow(&rendered, &ours, &freqs);
        for ((partial, track), mine) in held
            .figures
            .partials
            .iter_mut()
            .zip(&recorded.partials)
            .zip(&tracks)
        {
            let ceiling = track.levels.iter().cloned().fold(f64::MIN, f64::max) + 12.0;
            // Each frame's level and the render's where either stands clear, as the check reads them.
            let pair = |k: usize| {
                let (theirs, mine) = (*track.levels.get(k)?, *mine.get(k)?);
                if theirs > track.floor + CLEAR {
                    Some((theirs, mine))
                } else if mine > track.floor + CLEAR {
                    Some((track.floor + 5.0, mine))
                } else {
                    None
                }
            };
            let gap = |k: usize| pair(k).map(|(theirs, mine)| theirs - mine);
            // Over each time's frames the gap is between their powers, as the ear hears a level that swings, not between their dB.
            for (j, range) in segments.iter().enumerate() {
                let pairs: Vec<(f64, f64)> = range.clone().filter_map(pair).collect();
                if !pairs.is_empty() {
                    let (theirs, mine): (Vec<f64>, Vec<f64>) = pairs.into_iter().unzip();
                    let change = (0.8 * (mean_db(&theirs) - mean_db(&mine))).clamp(-12.0, 12.0);
                    partial.levels[j] = (partial.levels[j] + change).min(ceiling);
                }
            }
            hold(&mut partial.levels);
            // Once let go, a render quieter than the recording on average over the next second falls too fast, by its gap over the mean time it has fallen for.
            let after: Vec<(f64, f64)> = (last..last + (1.0 / HOP) as usize)
                .filter_map(|k| gap(k).map(|g| (g, (k - last) as f64 * HOP)))
                .collect();
            if !after.is_empty() {
                let (sum, fallen) = after
                    .iter()
                    .fold((0.0, 0.0), |(s, t), (g, d)| (s + g, t + d));
                let mean_time = (fallen / after.len() as f64).max(0.05);
                partial.tail = (partial.tail + 0.8 * sum / after.len() as f64 / mean_time)
                    .clamp(-2000.0, -1.0);
            }
        }
        // The noise is what the recording holds beyond the partials, once they are near their own levels, the median over each time's frames, so a burst does not lift a whole stretch.
        if round >= 1 {
            let mut sines = held.clone();
            sines
                .figures
                .noise
                .iter_mut()
                .for_each(|b| b.levels.fill(SILENT));
            let sines_spectra = partials::spectra_from(
                &render(&sines, rate, 0.05, measured.release, seconds + 0.1, false),
                rate,
                recorded.f0,
                seconds,
                lead,
            );
            let sines_powers = fit::band_powers(&sines_spectra, &bins);
            let ours_powers = fit::band_powers(&ours, &bins);
            let (sines_clear, ours_clear) = (clear_powers(&sines_spectra), clear_powers(&ours));
            for (k, band) in held.figures.noise.iter_mut().enumerate() {
                let power = |levels: &Vec<Vec<f64>>, f: usize| {
                    levels.get(f).map_or(0.0, |row| 10f64.powf(row[k] / 10.0))
                };
                let (theirs, sines_powers, ours_powers) = if clear[k].is_empty() {
                    (&theirs, &sines_powers, &ours_powers)
                } else {
                    (&theirs_clear, &sines_clear, &ours_clear)
                };
                let wanted = |f: usize| {
                    let (a, s) = (power(theirs, f), power(sines_powers, f));
                    if band.high > NOISE_BOTTOM && a > floors[k] && a > 2.0 * s {
                        a - s
                    } else {
                        0.0
                    }
                };
                let made = |f: usize| (power(ours_powers, f) - power(sines_powers, f)).max(0.0);
                let set = |level: &mut f64, range: &std::ops::Range<usize>| {
                    if range.is_empty() {
                        return;
                    }
                    let want = median(&range.clone().map(wanted).collect::<Vec<_>>());
                    let have = median(&range.clone().map(made).collect::<Vec<_>>());
                    *level = if want <= 0.0 {
                        SILENT
                    } else if *level <= SILENT || have <= 0.0 {
                        10.0 * (want / gains[k]).log10()
                    } else {
                        (*level + 10.0 * (want / have).log10()).clamp(SILENT, *level + 12.0)
                    };
                };
                for (j, range) in segments.iter().enumerate() {
                    set(&mut band.levels[j], range);
                }
                hold(&mut band.levels);
                // Once let go, a band louder than the recording on average over the next second falls too slowly, as a bow's or breath's noise stops before the strings and the room do.
                let floor = 10.0 * floors[k].log10() - CLEAR;
                let after: Vec<(f64, f64)> = (last..last + (1.0 / HOP) as usize)
                    .filter_map(|f| {
                        let (a, o) = (
                            10.0 * power(theirs, f).max(1e-30).log10(),
                            10.0 * power(ours_powers, f).max(1e-30).log10(),
                        );
                        (a > floor + CLEAR || o > floor + CLEAR)
                            .then(|| (a.max(floor) - o.max(floor), (f - last) as f64 * HOP))
                    })
                    .collect();
                if !after.is_empty() {
                    let (sum, fallen) = after
                        .iter()
                        .fold((0.0, 0.0), |(s, t), (g, d)| (s + g, t + d));
                    let mean_time = (fallen / after.len() as f64).max(0.05);
                    band.tail = (band.tail + 0.8 * sum / after.len() as f64 / mean_time)
                        .clamp(-2000.0, -1.0);
                }
            }
        }
    }
    let ratios: Vec<f64> = held.figures.partials.iter().map(|p| p.ratio).collect();
    held.swings = swings(&measured, &ratios);
    (held, measured)
}

// A partial's slope once let go: its own fall over its first 30 dB where it stands clear of the floor for 20 ms once the window's middle has passed the letting go, or else the whole sound's.
fn release_slope(track: &Track, measured: &Measured) -> f64 {
    let window = measured.note.spectra.window;
    let from = ((measured.release + window / 2.0 + LEAD) / HOP).round() as usize;
    let top = track.levels.get(from).cloned().unwrap_or(SILENT);
    let points: Vec<(f64, f64)> = track
        .levels
        .iter()
        .enumerate()
        .skip(from)
        .take_while(|(_, l)| **l > (track.floor + CLEAR).max(top - 30.0))
        .map(|(k, l)| (k as f64 * HOP, *l))
        .collect();
    if points.len() >= (0.02 / HOP) as usize {
        super::slope(&points).min(-1.0).max(measured.fall)
    } else {
        measured.fall
    }
}

// How far each partial's level swings with the vibrato, in dB at its full depth: its level read every 5 ms through a window four periods long and 20 to 60 ms, against the pitch's swing, where the note holds.
fn swings(measured: &Measured, ratios: &[f64]) -> Vec<f64> {
    let (_, depth) = measured.pitch.vibrato;
    if depth <= 0.0 {
        return vec![0.0; ratios.len()];
    }
    let rate = measured.rate;
    let f0 = measured.note.f0;
    let size = ((4.0 / f0).clamp(0.02, 0.06) * rate).round() as usize;
    let hann: Vec<f64> = (0..size)
        .map(|i| 0.5 - 0.5 * (2.0 * PI * i as f64 / size as f64).cos())
        .collect();
    let norm = hann.iter().sum::<f64>() / 2.0;
    let from = measured.holding.start as f64 * HOP - LEAD;
    let to = measured.holding.end as f64 * HOP - LEAD;
    let frames: Vec<usize> = ((from / PITCH_HOP).ceil() as usize..(to / PITCH_HOP) as usize)
        .filter(|k| *k < measured.pitch.swing.len())
        .collect();
    if frames.len() < 20 {
        return vec![0.0; ratios.len()];
    }
    let v: Vec<f64> = frames
        .iter()
        .map(|k| measured.pitch.swing[*k] / depth)
        .collect();
    let mean_v = v.iter().sum::<f64>() / v.len() as f64;
    let variance = v.iter().map(|x| (x - mean_v).powi(2)).sum::<f64>();
    super::parallel(ratios, |ratio| {
        let omega = 2.0 * PI * ratio * f0 / rate;
        let levels: Vec<f64> = frames
            .iter()
            .map(|k| {
                let centre = measured.start as f64 + *k as f64 * PITCH_HOP * rate;
                let first = centre.round() as i64 - (size / 2) as i64;
                let sum: Complex<f64> = (0..size)
                    .map(|i| {
                        let at = first + i as i64;
                        let x = if at >= 0 && (at as usize) < measured.sound.len() {
                            measured.sound[at as usize]
                        } else {
                            0.0
                        };
                        Complex::from_polar(x * hann[i], -omega * at as f64)
                    })
                    .sum();
                db(sum.norm() / norm)
            })
            .collect();
        let mean_l = levels.iter().sum::<f64>() / levels.len() as f64;
        let covariance: f64 = levels
            .iter()
            .zip(&v)
            .map(|(l, x)| (l - mean_l) * (x - mean_v))
            .sum();
        (covariance / variance.max(1e-9)).clamp(-12.0, 12.0)
    })
}

/// A partial of a measured held note: its frequency and harmonic, its level at each of the struck notes' times before the note holds, its level while it holds, against the note's loudest, its slope once let go, and how far it swings with the vibrato.
#[derive(NifMap)]
pub struct Line {
    pub freq: f64,
    pub harmonic: u32,
    pub attack: Vec<(f64, f64)>,
    pub held: f64,
    pub release: f64,
    pub swing: f64,
}

/// A measured held note: its steady pitch, where it holds from and is let go, in seconds after it starts, how fast it falls after, its vibrato's rate and depth in cents, and its partials.
#[derive(NifMap)]
pub struct Summary {
    pub pitch: f64,
    pub held: f64,
    pub release: f64,
    pub fall: f64,
    pub vibrato: (f64, f64),
    pub partials: Vec<Line>,
}

fn mean_db(levels: &[f64]) -> f64 {
    10.0 * (levels.iter().map(|l| 10f64.powf(l / 10.0)).sum::<f64>() / levels.len().max(1) as f64)
        .max(1e-30)
        .log10()
}

/// Measures a held note partial by partial over `seconds`, as `mix mx.measure --held --partials` prints it.
pub fn summary(sound: &[f64], rate: f64, note: f64, seconds: f64) -> Summary {
    let measured = measure(sound, rate, note, seconds);
    let helds: Vec<f64> = measured
        .note
        .partials
        .iter()
        .map(|t| mean_db(&t.levels[measured.holding.clone()]))
        .collect();
    let loudest = helds.iter().cloned().fold(f64::MIN, f64::max);
    let ratios: Vec<f64> = measured
        .note
        .partials
        .iter()
        .map(|t| t.freq / measured.note.f0)
        .collect();
    let swings = swings(&measured, &ratios);
    let partials = measured
        .note
        .partials
        .iter()
        .zip(&helds)
        .zip(&swings)
        .map(|((track, held), swing)| {
            let attack = TIMES
                .iter()
                .take_while(|t| **t < measured.held)
                .filter_map(|t| {
                    track
                        .levels
                        .get(((t + LEAD) / HOP).round() as usize)
                        .map(|l| (*t, l.max(track.floor) - loudest))
                })
                .collect();
            Line {
                freq: track.freq,
                harmonic: track.harmonic,
                attack,
                held: held - loudest,
                release: release_slope(track, &measured),
                swing: *swing,
            }
        })
        .collect();
    Summary {
        pitch: measured.note.f0,
        held: measured.held,
        release: measured.release,
        fall: measured.fall,
        vibrato: measured.pitch.vibrato,
        partials,
    }
}

/// Compares a render with a recording of the same held note over `seconds` from its start, each measured on its own steadied sound and brought to the same total where the recording holds.
/// Partial by partial, the mean gap over the attack, given as the check's `strike`, and over the held part, while either stands 10 dB above the floor; and in ERB bands, the mean gap from the start until a second after the note is let go while either stands clear of the floor.
/// The render's note starts at the sample `begin`.
pub fn check(
    recording: &[f64],
    rate: f64,
    rendered: &[f64],
    render_rate: f64,
    begin: usize,
    note: f64,
    seconds: f64,
) -> fit::Check {
    let theirs = measure(recording, rate, note, seconds);
    let ours = measure_from(rendered, render_rate, note, seconds, begin);
    let freqs: Vec<f64> = theirs
        .note
        .partials
        .iter()
        .map(|t| t.harmonic as f64 * ours.note.f0)
        .collect();
    let mine = partials::follow(&ours.sound, &ours.note.spectra, &freqs);
    let holding = theirs.holding.clone();
    let total = |tracks: &mut dyn Iterator<Item = &Vec<f64>>| {
        10.0 * tracks
            .map(|l| {
                holding
                    .clone()
                    .filter_map(|k| l.get(k))
                    .map(|l| 10f64.powf(l / 10.0))
                    .sum::<f64>()
            })
            .sum::<f64>()
            .max(1e-30)
            .log10()
    };
    let total_theirs = total(&mut theirs.note.partials.iter().map(|t| &t.levels));
    let total_ours = total(&mut mine.iter());
    let shift = total_theirs - total_ours;
    let helds: Vec<f64> = theirs
        .note
        .partials
        .iter()
        .map(|t| mean_db(&t.levels[holding.clone()]))
        .collect();
    let loudest = helds.iter().cloned().fold(f64::MIN, f64::max);
    let gap = |track: &Track, mine: &[f64], frames: std::ops::Range<usize>| {
        let gaps: Vec<f64> = frames
            .filter_map(|k| Some((track.levels.get(k)?, mine.get(k)? + shift)))
            .filter(|(a, b)| **a > track.floor + CLEAR || *b > track.floor + CLEAR)
            .map(|(a, b)| (b.max(track.floor) - a.max(track.floor)).abs())
            .collect();
        if gaps.is_empty() {
            0.0
        } else {
            gaps.iter().sum::<f64>() / gaps.len() as f64
        }
    };
    let partials = theirs
        .note
        .partials
        .iter()
        .zip(&mine)
        .zip(&helds)
        .map(|((track, mine), held)| {
            let floor = track.floor;
            let levels = (1..=8)
                .map(|half| 0.5 * half as f64)
                .filter_map(|at| {
                    let frame = ((at + LEAD) / HOP).round() as usize;
                    Some((
                        at,
                        track.levels.get(frame)?.max(floor) - loudest,
                        (mine.get(frame)? + shift).max(floor) - loudest,
                    ))
                })
                .collect();
            fit::PartialGap {
                ratio: track.freq / theirs.note.f0,
                harmonic: track.harmonic,
                below: loudest - held,
                strike: gap(track, mine, 0..holding.start),
                mean: gap(track, mine, holding.clone()),
                floor: floor - loudest,
                levels,
            }
        })
        .collect();
    let bands = fit::erb_bands();
    let (a, b) = (
        fit::erb_levels(&theirs.note.spectra, &bands),
        fit::erb_levels(
            &ours.note.spectra,
            &bands
                .iter()
                .map(|(l, h)| {
                    (
                        l * ours.note.f0 / theirs.note.f0,
                        h * ours.note.f0 / theirs.note.f0,
                    )
                })
                .collect::<Vec<_>>(),
        ),
    );
    let band_total = |e: &[Vec<f64>]| {
        10.0 * holding
            .clone()
            .filter_map(|k| e.get(k))
            .flatten()
            .map(|d| 10f64.powf(d / 10.0))
            .sum::<f64>()
            .max(1e-30)
            .log10()
    };
    let band_shift = band_total(&a) - band_total(&b);
    let mut gaps = vec![];
    let mut per_band = vec![(0.0, 0usize); bands.len()];
    // The note is compared until a second after it is let go, so a sound later in its stretch, such as the same note played again, is not counted.
    let until = ((theirs.release + 1.0 + LEAD) / HOP).round() as usize;
    let mut per_frame = vec![];
    for (fa, fb) in a.iter().zip(&b).take(until) {
        per_frame.push((0.0, 0));
        for (k, (x, y)) in fa.iter().zip(fb).enumerate() {
            let (low, high) = bands[k];
            let floor = theirs.note.floor.at((low * high).sqrt())
                + 10.0 * ((high - low) / theirs.note.spectra.bin).max(1.0).log10();
            let y = y + band_shift;
            if *x > floor + CLEAR || y > floor + CLEAR {
                let gap = y.max(floor) - x.max(floor);
                gaps.push(gap.abs());
                per_band[k].0 += gap;
                per_band[k].1 += 1;
                let frame = per_frame.last_mut().unwrap();
                *frame = (frame.0 + gap.abs(), frame.1 + 1);
            }
        }
    }
    let stretch = fit::furthest_stretch(&per_frame, theirs.note.spectra.window);
    let erb = if gaps.is_empty() {
        0.0
    } else {
        gaps.iter().sum::<f64>() / gaps.len() as f64
    };
    let bands = bands
        .iter()
        .zip(per_band)
        .map(|((low, high), (sum, count))| ((low * high).sqrt(), sum / count.max(1) as f64, count))
        .collect();
    let cents = |freq: f64| 1200.0 * (freq / hz(note)).log2();
    fit::Check {
        partials,
        erb,
        bands,
        stretch,
        levels: (total_theirs, total_ours),
        pitch: (cents(theirs.note.f0), cents(ours.note.f0)),
        room: vec![],
    }
}

/// How far the fit's own render of a held note, its figures played as sines and noise with their vibrato and no synth, is from the recording.
pub fn own(sound: &[f64], rate: f64, note: f64, seconds: f64, steady: bool) -> fit::Check {
    let (held, _) = fit(sound, rate, note, seconds, steady);
    let rendered = render(&held, rate, 0.05, held.release, seconds + 0.3, true);
    check(
        sound,
        rate,
        &rendered,
        rate,
        (0.05 * rate).round() as usize,
        note,
        seconds,
    )
}

/// Where a recording of a held note holds from and is let go, in seconds after it starts, and the seconds into the sound given that it starts at, so a synth can be held as long.
pub fn timing(sound: &[f64], rate: f64, note: f64, seconds: f64) -> (f64, f64, f64) {
    let begin = start(sound, rate);
    let measured = measure(sound, rate, note, seconds);
    (measured.held, measured.release, begin as f64 / rate)
}

/// The figures of held notes as mxs reads them, all numbers little-endian: "MXH1", then as the struck figures' header, the times and the noise bands, and the recordings as a u16 count.
/// Each recording is its MIDI note and velocity as u8, the seconds it holds from, the seconds the recording let it go at, the vibrato's rate in Hz and depth in cents, all as f32, and its partials as a u16 count.
/// Each partial is its frequency over the note's equal-tempered pitch as f32, its harmonic number as u16, its slope once let go, its swing with the vibrato, and its level at each time, in tenths of a dB as i16.
/// Then each noise band's slope once let go, and its level at each time, in tenths of a dB as i16, as the struck figures' noise is.
/// Each recording is moved as a whole onto its velocity's smooth curve of held loudness against pitch, see `leveled`.
pub fn figures_bytes(recordings: &[(u8, u8, Held)]) -> Vec<u8> {
    let tenths =
        |value: f64| ((value * 10.0).round().clamp(-32000.0, 32000.0) as i16).to_le_bytes();
    let loudness: Vec<(u8, u8, f64)> = recordings
        .iter()
        .map(|(note, velocity, held)| {
            let power: f64 = held
                .figures
                .partials
                .iter()
                .map(|p| 10f64.powf(p.levels[p.levels.len() - 1] / 10.0))
                .sum();
            (*note, *velocity, 10.0 * power.max(1e-30).log10())
        })
        .collect();
    let offsets = leveled(&loudness);
    let mut bytes = b"MXH1".to_vec();
    bytes.extend((TIMES.len() as u16).to_le_bytes());
    for time in TIMES {
        bytes.extend((time as f32).to_le_bytes());
    }
    let bands = fit::erb_bands_to(NOISE_TOP);
    bytes.extend((bands.len() as u16).to_le_bytes());
    for (low, high) in &bands {
        bytes.extend((*low as f32).to_le_bytes());
        bytes.extend((*high as f32).to_le_bytes());
    }
    bytes.extend((recordings.len() as u16).to_le_bytes());
    for ((note, velocity, held), offset) in recordings.iter().zip(&offsets) {
        let figures = &held.figures;
        let moved = |level: f64| {
            if level <= SILENT {
                level
            } else {
                level + offset
            }
        };
        bytes.extend([*note, *velocity]);
        for value in [held.held, held.release, held.vibrato.0, held.vibrato.1] {
            bytes.extend((value as f32).to_le_bytes());
        }
        bytes.extend((figures.partials.len() as u16).to_le_bytes());
        let fundamental = figures
            .partials
            .iter()
            .find(|p| p.harmonic == 1)
            .map_or(1.0, |p| p.ratio);
        for (partial, swing) in figures
            .partials
            .iter()
            .zip(held.swings.iter().chain(std::iter::repeat(&0.0)))
        {
            bytes.extend(
                ((partial.ratio / fundamental * figures.pitch / hz(*note as f64)) as f32)
                    .to_le_bytes(),
            );
            bytes.extend((partial.harmonic as u16).to_le_bytes());
            bytes.extend(tenths(partial.tail));
            bytes.extend(tenths(*swing));
            for level in &partial.levels {
                bytes.extend(tenths(moved(*level)));
            }
        }
        for (band, (low, high)) in figures.noise.iter().zip(&bands) {
            let written = fit::noise_to_written(*low, *high, figures.rate);
            bytes.extend(tenths(band.tail));
            for level in &band.levels {
                bytes.extend(tenths(if *level <= SILENT {
                    *level
                } else {
                    moved(*level) + written
                }));
            }
        }
    }
    bytes
}

/// The dB that moves each recording onto its velocity's smooth curve of held loudness against pitch: the median of the recordings within 3 semitones, averaged over 2 semitones either side, at most 15 dB away.
/// A recording played quieter or louder than its neighbours would otherwise drop or jump as a slur reaches it, while the curve keeps an instrument louder up its range.
fn leveled(loudness: &[(u8, u8, f64)]) -> Vec<f64> {
    let median_near = |note: u8, velocity: u8| {
        let near: Vec<f64> = loudness
            .iter()
            .filter(|(n, v, _)| *v == velocity && n.abs_diff(note) <= 3)
            .map(|(_, _, l)| *l)
            .collect();
        median(&near)
    };
    loudness
        .iter()
        .map(|(note, velocity, level)| {
            let around: Vec<f64> = loudness
                .iter()
                .filter(|(n, v, _)| v == velocity && n.abs_diff(*note) <= 2)
                .map(|(n, v, _)| median_near(*n, *v))
                .collect();
            let curve = around.iter().sum::<f64>() / around.len().max(1) as f64;
            (curve - level).clamp(-15.0, 15.0)
        })
        .collect()
}

#[cfg(test)]
mod leveling {
    use super::leveled;

    #[test]
    fn a_recording_quieter_than_its_neighbours_moves_onto_their_curve_and_the_rise_with_pitch_stays()
     {
        let mut loudness: Vec<(u8, u8, f64)> =
            (60..80).map(|n| (n, 80, -40.0 + (n - 60) as f64)).collect();
        loudness[10].2 -= 12.0;
        let offsets = leveled(&loudness);
        let moved = loudness[10].2 + offsets[10];
        assert!((moved - -30.0).abs() < 1.5, "{moved}");
        assert!(
            offsets[3].abs() < 1.0 && offsets[16].abs() < 1.0,
            "{offsets:?}"
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // A held note at `f0` with harmonics at 1/n after 0.2 seconds of silence: it swells in over 50 ms, holds for `seconds`, then falls at `fall` dB a second, with a vibrato of `rate` Hz and `cents` either side, and a floor 90 dB down.
    fn held(rate: f64, f0: f64, seconds: f64, fall: f64, (vibrato, cents): (f64, f64)) -> Vec<f64> {
        let mut phase = 0.0;
        let mut seed = 3u64;
        let mut sound = vec![0.0; (0.2 * rate) as usize];
        sound.extend((0..((seconds + 1.5) * rate) as usize).map(|i| {
            let t = i as f64 / rate;
            let freq = f0 * 2f64.powf(cents * (2.0 * PI * vibrato * t).sin() / 1200.0);
            let wave: f64 = (1..=6).map(|n| (n as f64 * phase).sin() / n as f64).sum();
            phase += 2.0 * PI * freq / rate;
            let level = (t / 0.05).min(1.0) * 10f64.powf(-fall * (t - seconds).max(0.0) / 20.0);
            0.2 * wave * level
        }));
        sound
            .into_iter()
            .map(|x| {
                seed = seed
                    .wrapping_mul(6364136223846793005)
                    .wrapping_add(1442695040888963407);
                x + 3.0e-5 * ((seed >> 11) as f64 / (1u64 << 53) as f64 * 2.0 - 1.0)
            })
            .collect()
    }

    #[test]
    fn the_pitch_finds_a_vibratos_rate_and_depth_and_none_on_a_steady_note() {
        let rate = 48000.0;
        let swinging = held(rate, hz(60.0), 3.0, 60.0, (5.5, 25.0));
        let found = pitch(&swinging, rate, start(&swinging, rate), 60.0);
        assert!((found.vibrato.0 - 5.5).abs() < 0.3, "{:?}", found.vibrato);
        assert!((found.vibrato.1 - 25.0).abs() < 4.0, "{:?}", found.vibrato);
        let steady = held(rate, hz(60.0), 3.0, 60.0, (0.0, 0.0));
        assert_eq!(
            pitch(&steady, rate, start(&steady, rate), 60.0).vibrato,
            (0.0, 0.0)
        );
    }

    #[test]
    fn a_held_note_holds_its_last_level_after_it_is_let_go_and_falls_at_its_slope() {
        let rate = 48000.0;
        let sound = held(rate, hz(60.0), 2.0, 60.0, (0.0, 0.0));
        let (figures, _) = fit(&sound, rate, 60.0, 3.5, false);
        assert!((figures.release - 2.0).abs() < 0.1, "{}", figures.release);
        let first = figures
            .figures
            .partials
            .iter()
            .find(|p| p.harmonic == 1)
            .unwrap();
        let last = *first.levels.last().unwrap();
        let held_at = TIMES.iter().position(|t| *t >= figures.release).unwrap();
        assert!(first.levels[held_at..].iter().all(|l| *l == last));
        assert!((first.tail + 60.0).abs() < 12.0, "{}", first.tail);
    }

    #[test]
    fn a_note_easing_off_before_it_is_let_go_holds_its_easing_unless_steady() {
        // Its fundamental holds while its upper harmonics fall 18 dB over the last second it is held, as a recorded flute's do.
        let rate = 48000.0;
        let f0 = hz(60.0);
        let mut sound = vec![0.0; (0.2 * rate) as usize];
        sound.extend((0..(3.5 * rate) as usize).map(|i| {
            let t = i as f64 / rate;
            let easing = 10f64.powf(-18.0 * (t - 1.0).clamp(0.0, 1.0) / 20.0);
            let wave: f64 = (1..=6)
                .map(|n| {
                    (2.0 * PI * n as f64 * f0 * t).sin() / n as f64
                        * if n >= 3 { easing } else { 1.0 }
                })
                .sum();
            0.2 * wave * (t / 0.05).min(1.0) * 10f64.powf(-60.0 * (t - 2.0).max(0.0) / 20.0)
        }));
        let held_level = |steady: bool| {
            let (figures, _) = fit(&sound, rate, 60.0, 3.5, steady);
            *figures
                .figures
                .partials
                .iter()
                .find(|p| p.harmonic == 4)
                .unwrap()
                .levels
                .last()
                .unwrap()
        };
        let (following, steady) = (held_level(false), held_level(true));
        assert!(
            steady - following > 6.0,
            "steady {steady}, following {following}"
        );
    }

    #[test]
    fn the_fits_own_render_of_a_held_note_with_vibrato_is_close_partial_by_partial_and_in_erb_bands()
     {
        let rate = 48000.0;
        let sound = held(rate, hz(60.0), 2.0, 60.0, (5.0, 20.0));
        let check = own(&sound, rate, 60.0, 3.5, false);
        assert!(check.erb < 1.5, "{}", check.erb);
        let strong: Vec<_> = check.partials.iter().filter(|p| p.below < 30.0).collect();
        assert!(
            !strong.is_empty() && strong.iter().all(|p| p.mean.abs() < 2.0),
            "{:?}",
            strong.iter().map(|p| p.mean).collect::<Vec<_>>()
        );
    }
}
