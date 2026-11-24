//! Fitting a synth's figures to plucked and struck notes partial by partial, for `mix mx.fit`, and checking a synth against the recordings.
//! A note's figures are its pitch and, for each partial, its ratio to the pitch and its level in dB at fixed times after the strike, falling at a last slope after them; the synth plays them as sines.
//! They also hold the noise of the strike, as the level of white noise through each ERB band's filter at the same times.

use super::partials::{self, CLEAR, HOP, LEAD, Note, Track};
use super::room::{self, Room};
use super::hz;
use rustler::NifMap;

/// The seconds after the strike each partial's level is given at.
pub const TIMES: [f64; 37] = [
    0.0, 0.0025, 0.005, 0.0075, 0.01, 0.015, 0.02, 0.03, 0.04, 0.055, 0.07, 0.09, 0.115, 0.145, 0.18, 0.225, 0.28, 0.35, 0.44, 0.55, 0.7, 0.88, 1.1, 1.4, 1.75, 2.2, 2.75, 3.5,
    4.4, 5.5, 7.0, 8.8, 11.0, 14.0, 17.5, 22.0, 28.0,
];
/// The seconds of a recording `mix mx.measure --partials` measures: NSynth's notes are let go at 3 seconds.
pub const SECONDS: f64 = 2.9;
/// The seconds over which a sine rises at its start.
pub const RISE: f64 = 0.001;
const ROUNDS: usize = 6;
const AGAIN: usize = 3;

#[derive(Clone)]
pub struct Partial {
    pub ratio: f64,
    pub harmonic: u32,
    pub levels: Vec<f64>,
    pub tail: f64,
}

/// White noise through one ERB band's filter, with its level in dB at each of the times and a last slope after them.
#[derive(Clone)]
pub struct Band {
    pub low: f64,
    pub high: f64,
    pub levels: Vec<f64>,
    pub tail: f64,
}

#[derive(Clone)]
pub struct Figures {
    pub f0: f64,
    /// The pitch the synth plays the fundamental at: the note's own, so a recording a few cents off plays in tune, or a drum's given pitch.
    pub pitch: f64,
    pub partials: Vec<Partial>,
    pub noise: Vec<Band>,
    /// The last time the recording reaches, after which every level falls on at its last slope.
    pub reached: f64,
    /// The sample rate the figures were fitted at, as a band's noise gain carries less power the higher the rate.
    pub rate: f64,
}

/// The level in dB at `t` seconds after the strike: straight lines between the times given, and the last slope after them.
pub fn level_at(levels: &[f64], tail: f64, t: f64) -> f64 {
    let last = TIMES.len() - 1;
    if t >= TIMES[last] {
        return levels[last] + tail * (t - TIMES[last]);
    }
    let at = TIMES.partition_point(|time| *time <= t).max(1) - 1;
    let share = (t - TIMES[at]) / (TIMES[at + 1] - TIMES[at]);
    levels[at] + share * (levels[at + 1] - levels[at])
}

/// A noise band's level in dB at `t` seconds after the strike: its power in straight lines between the times given, and the last slope in dB after them.
pub fn noise_level_at(levels: &[f64], tail: f64, t: f64) -> f64 {
    let last = TIMES.len() - 1;
    if t >= TIMES[last] {
        return levels[last] + tail * (t - TIMES[last]);
    }
    let at = TIMES.partition_point(|time| *time <= t).max(1) - 1;
    let share = (t - TIMES[at]) / (TIMES[at + 1] - TIMES[at]);
    let power = |level: f64| 10f64.powf(level / 10.0);
    10.0 * ((1.0 - share) * power(levels[at]) + share * power(levels[at + 1])).log10()
}

/// The noise level no band goes below, where it is silent.
pub const SILENT: f64 = -160.0;

/// The seconds after the strike the noise lasts, fading out by the next time.
pub const NOISE_UNTIL: f64 = 0.7;
/// The seconds over which a band's noise rises at the strike, as a raised cosine: one over the band's width, so the burst stays within the band, from 2 to 20 ms.
pub fn noise_rise(low: f64, high: f64) -> f64 {
    (1.0 / (high - low)).clamp(0.002, 0.02)
}

/// How far a band's noise has risen `t` seconds after the strike, in amplitude.
pub fn rising(t: f64, rise: f64) -> f64 {
    if t >= rise { 1.0 } else { 0.5 - 0.5 * (std::f64::consts::PI * t.max(0.0) / rise).cos() }
}
/// The seconds the noise runs through a band's filters before the strike.
pub const WARM: f64 = 0.1;

/// The sample rate the written figures' noise gains are for, which mxs moves to the rate it plays at.
pub const NOISE_RATE: f64 = 48_000.0;

/// The dB that moves a band's noise gain fitted at `rate` to the gain giving the same power at `NOISE_RATE`.
pub fn noise_to_written(low: f64, high: f64, rate: f64) -> f64 {
    if high >= rate / 2.0 {
        return 0.0;
    }
    10.0 * (response_energy(&band_filter(low, high, rate), rate) / response_energy(&band_filter(low, high, NOISE_RATE), NOISE_RATE)).log10()
}

/// The sum of the squares of a filter's response to an impulse, over half a second.
fn response_energy(filter: &[[f64; 5]; 4], rate: f64) -> f64 {
    let mut state = [[0.0f64; 4]; 4];
    (0..(0.5 * rate) as usize)
        .map(|i| {
            let mut x = if i == 0 { 1.0 } else { 0.0 };
            for (s, [b0, b1, b2, a1, a2]) in state.iter_mut().zip(filter) {
                let y = b0 * x + b1 * s[0] + b2 * s[1] - a1 * s[2] - a2 * s[3];
                *s = [x, s[0], y, s[2]];
                x = y;
            }
            x * x
        })
        .sum()
}

/// A band's filter as biquads `[b0, b1, b2, a1, a2]` in turn: four band-pass sections with a peak gain of 1 at the band's centre and its width as their bandwidth, so little of its noise reaches the next band.
pub fn band_filter(low: f64, high: f64, rate: f64) -> [[f64; 5]; 4] {
    let centre = (low * high).sqrt();
    let omega = 2.0 * std::f64::consts::PI * centre / rate;
    let alpha = omega.sin() * (high - low) / (2.0 * centre);
    let a0 = 1.0 + alpha;
    [[alpha / a0, 0.0, -alpha / a0, -2.0 * omega.cos() / a0, (1.0 - alpha) / a0]; 4]
}

/// A filter's power gain at `freq`.
pub fn filter_power(filter: &[[f64; 5]; 4], freq: f64, rate: f64) -> f64 {
    let z1 = rustfft::num_complex::Complex::from_polar(1.0, -2.0 * std::f64::consts::PI * freq / rate);
    let z2 = z1 * z1;
    filter.iter().map(|[b0, b1, b2, a1, a2]| ((z1 * *b1 + z2 * *b2 + *b0) / (z1 * *a1 + z2 * *a2 + 1.0)).norm_sqr()).product()
}

// White noise from -1 to 1, the same every render.
struct Noise(u64);

impl Noise {
    fn next(&mut self) -> f64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 >> 11) as f64 / (1u64 << 52) as f64 - 1.0
    }
}

/// The figures played as sines at `rate`, after `lead` seconds of silence, for `seconds`.
pub fn render(figures: &Figures, rate: f64, lead: f64, seconds: f64) -> Vec<f64> {
    let start = (lead * rate).round() as usize;
    let count = (seconds * rate).round() as usize;
    let mut sound = vec![0.0; start + count];
    for partial in &figures.partials {
        let freq = partial.ratio * figures.f0;
        if freq >= rate / 2.0 {
            continue;
        }
        let step = 2.0 * std::f64::consts::PI * freq / rate;
        for i in 0..count {
            let t = i as f64 / rate;
            let rise = (t / RISE).min(1.0);
            let level = level_at(&partial.levels, partial.tail, t);
            if level < -140.0 && t > figures.reached {
                break;
            }
            sound[start + i] += rise * 10f64.powf(level / 20.0) * (step * i as f64).sin();
        }
    }
    for (k, band) in figures.noise.iter().enumerate() {
        if band.high >= rate / 2.0 || band.levels.iter().all(|l| *l <= SILENT) {
            continue;
        }
        let filter = band_filter(band.low, band.high, rate);
        let rise = noise_rise(band.low, band.high);
        let mut noise = Noise(0x9e37_79b9_7f4a_7c15 ^ (k as u64 + 1).wrapping_mul(0xbf58_476d_1ce4_e5b9));
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
        // The filters run on the noise before the strike, so the band starts with the strike instead of ringing up after it.
        for _ in 0..(WARM * rate) as usize {
            filtered();
        }
        for i in 0..count {
            let t = i as f64 / rate;
            let level = noise_level_at(&band.levels, band.tail, t);
            if level < -140.0 && t > figures.reached {
                break;
            }
            let x = rising(t, rise) * 10f64.powf(level / 20.0) * filtered();
            sound[start + i] += x;
        }
    }
    sound
}

/// The frame of a measuring that reads `t` seconds after the strike.
fn frame_at(t: f64) -> f64 {
    (t + LEAD) / HOP
}

/// Fits a recorded note's figures over `seconds` from its strike: each partial's levels from its measured track, then corrected against renders of them measured the same way.
/// With `exact`, the note's own frequency is its pitch, for a drum whose partials are not harmonics.
/// `top` is the highest frequency in Hz its partials and its bands of noise reach.
/// After the last time the recording reaches, each partial falls on at its last slope.
/// The render is compared with the recording with the `room` the recording was made in added, so the fit does not take the room for the note.
pub fn fit(sound: &[f64], rate: f64, note: f64, seconds: f64, exact: bool, top: f64, room: Option<&Room>) -> (Figures, Note) {
    let recorded = partials::measure(sound, rate, note, seconds, exact, top);
    let bands = erb_bands_under(top, rate);
    let noise = bands.iter().map(|(low, high)| Band { low: *low, high: *high, levels: vec![SILENT; TIMES.len()], tail: -60.0 }).collect();
    let mut figures = Figures { f0: recorded.f0, pitch: hz(note), partials: recorded.partials.iter().map(|t| first_guess(t, recorded.f0, recorded.spectra.settled().start, reached(seconds, recorded.spectra.window))).collect(), noise, reached: TIMES[reached(seconds, recorded.spectra.window)], rate };
    fall_on(&mut figures, seconds, recorded.spectra.window);
    let freqs: Vec<f64> = recorded.partials.iter().chain(&recorded.left_out).map(|t| t.freq).collect();
    // The frames whose windows take in the strike read its click as much as the partials, so the partials are first fitted without them, and the noise to what they leave.
    correct_partials(&mut figures, &recorded, &freqs, rate, note, seconds, ROUNDS, recorded.spectra.settled().start, room);
    let rendered = render(&figures, rate, 0.05, seconds + 0.1);
    let gaps: Vec<Vec<usize>> = bands.iter().map(|(low, high)| { let (a, b) = bins(&recorded.spectra, *low, *high); (a..b).collect() }).collect();
    let sines = band_powers(&partials::spectra(&rendered, rate, hz(note), seconds), &gaps);
    let (targets, weights) = noise_targets(&band_powers(&recorded.spectra, &gaps), &sines, &bands, &gaps, &recorded, &room::over(room, &bands));
    let gains = noise_gains(&recorded.spectra, &bands, &gaps, rate);
    let shares: Vec<Vec<Vec<f64>>> = bands.iter().map(|(low, high)| shares(recorded.spectra.window, targets.len(), noise_rise(*low, *high))).collect();
    for (band, levels) in figures.noise.iter_mut().zip(solve_noise(&shares, &targets, &weights, &gains)) {
        band.levels = levels;
    }
    // The noise adds to the partials' own frequencies at the strike, so they are corrected again with it playing.
    correct_partials(&mut figures, &recorded, &freqs, rate, note, seconds, AGAIN, 0, room);
    (figures, recorded)
}

// The last of the times a recording measured for `seconds` reaches, where the last window ends.
fn reached(seconds: f64, window: f64) -> usize {
    TIMES.partition_point(|time| *time <= seconds - window / 2.0).max(1) - 1
}

// Each partial's levels after the last time the recording reaches, on its last slope from there, as a render past the recording plays them.
fn fall_on(figures: &mut Figures, seconds: f64, window: f64) {
    let reached = reached(seconds, window);
    for partial in &mut figures.partials {
        for j in reached + 1..TIMES.len() {
            partial.levels[j] = partial.levels[reached] + partial.tail * (TIMES[j] - TIMES[reached]);
        }
    }
}

// Corrects each partial's levels against renders of the figures, measured as the recording was, round after round, from the frame `from`.
#[allow(clippy::too_many_arguments)]
fn correct_partials(figures: &mut Figures, recorded: &Note, freqs: &[f64], rate: f64, note: f64, seconds: f64, rounds: usize, from: usize, room: Option<&Room>) {
    for _ in 0..rounds {
        let rendered = render(figures, rate, 0.05, seconds + 0.1);
        let measured = partials::spectra(&rendered, rate, hz(note), seconds);
        let ours = partials::follow(&rendered, &measured, freqs);
        let corrections: Vec<Vec<f64>> = recorded.partials.iter().zip(&ours).map(|(track, mine)| correction(track, mine, recorded.spectra.window, from, room::at(room, track.freq))).collect();
        for ((partial, change), track) in figures.partials.iter_mut().zip(corrections).zip(&recorded.partials) {
            // No level is fitted far above the loudest the recording reads, so a partial the measuring cannot pin down does not grow into a burst.
            let ceiling = track.strike(0.1) + 12.0;
            for (level, delta) in partial.levels.iter_mut().zip(change) {
                *level = (*level + delta).min(ceiling);
            }
        }
        fall_on(figures, seconds, recorded.spectra.window);
    }
}

// The track read at each time, averaged over the frames nearer it than its neighbours, before the first settled frame that frame's level, and after the last clear frame its last slope.
// The last time the recording reaches takes no frames after it, which belong to no time.
fn first_guess(track: &Track, f0: f64, settled: usize, reached: usize) -> Partial {
    let fall = partials::fall(track);
    let tail = fall.as_ref().map_or(-30.0, |f| f.second.min(-0.5));
    let last_clear = track.clear().map(|(i, _)| i).last().unwrap_or(0);
    let last_time = last_clear as f64 * HOP - LEAD;
    let last_level = track.levels[last_clear];
    let settled_time = settled as f64 * HOP - LEAD;
    let levels = TIMES
        .iter()
        .enumerate()
        .map(|(j, &t)| {
            if t < settled_time && settled < last_clear {
                return track.levels[settled];
            }
            if t > last_time {
                return last_level + tail * (t - last_time);
            }
            let before = if j == 0 { t } else { (t + TIMES[j - 1]) / 2.0 };
            let after = if j < reached { (t + TIMES[j + 1]) / 2.0 } else { t };
            let (from, to) = (frame_at(before).round() as usize, (frame_at(after).round() as usize).min(last_clear));
            let around: Vec<f64> = (from..=to.max(from)).filter_map(|k| track.levels.get(k).cloned()).collect();
            if around.is_empty() { last_level } else { around.iter().sum::<f64>() / around.len() as f64 }
        })
        .collect();
    Partial { ratio: track.freq / f0, harmonic: track.harmonic, levels, tail }
}

// How much to raise each time's level: the gaps between the recording and the render with the room's power added where either stands clear, each frame's shared among the times its window covers, weighted by the window.
fn correction(track: &Track, ours: &[f64], window: f64, from: usize, room: f64) -> Vec<f64> {
    let mut sums = vec![0.0; TIMES.len()];
    let mut weights = vec![0.0; TIMES.len()];
    for (k, (theirs, mine)) in track.levels.iter().zip(ours).enumerate().skip(from) {
        let centre = k as f64 * HOP - LEAD;
        let clear = *theirs > track.floor + CLEAR;
        let gap = if clear {
            theirs - room::with(*mine, room)
        } else if *mine > track.floor + CLEAR {
            track.floor + 5.0 - mine
        } else {
            continue;
        };
        for (j, time) in TIMES.iter().enumerate() {
            let offset = (time - centre) / window;
            if offset.abs() < 0.5 {
                let weight = 0.5 + 0.5 * (2.0 * std::f64::consts::PI * offset).cos();
                sums[j] += gap * weight;
                weights[j] += weight;
            }
        }
    }
    sums.iter().zip(&weights).map(|(s, w)| if *w > 0.05 { (0.8 * s / w).clamp(-12.0, 12.0) } else { 0.0 }).collect()
}

// What each band's measured power reads over its bins for its noise at a power of 1: the window's power gain times the filter's over those bins.
pub fn noise_gains(spectra: &partials::Spectra, bands: &[(f64, f64)], bins: &[Vec<usize>], rate: f64) -> Vec<f64> {
    let size = (spectra.window * rate).round() as usize;
    let hann: Vec<f64> = (0..size).map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / size as f64).cos()).collect();
    let norm = hann.iter().sum::<f64>() / 2.0;
    let window = hann.iter().map(|w| w * w).sum::<f64>() / (norm * norm);
    bands
        .iter()
        .zip(bins)
        .map(|((low, high), bins)| {
            let filter = band_filter(*low, *high, rate);
            let response: f64 = bins.iter().map(|&i| filter_power(&filter, i as f64 * spectra.bin, rate)).sum();
            // Uniform noise from -1 to 1 has a power of a third.
            window * response / 3.0
        })
        .collect()
}

/// The power in dB of each frame over each band's bins.
pub fn band_powers(spectra: &partials::Spectra, bins: &[Vec<usize>]) -> Vec<Vec<f64>> {
    spectra.frames.iter().map(|f| bins.iter().map(|bins| 10.0 * bins.iter().filter_map(|&i| f.get(i)).map(|m| m * m).sum::<f64>().max(1e-24).log10()).collect()).collect()
}

// The power in each frame and band that the noise is fitted to, what the recording has beyond the sines and the room where it has at least twice the sines', and how much each counts: the inverse square of the recording's power, or of its floor where the recording is under it.
fn noise_targets(theirs: &[Vec<f64>], sines: &[Vec<f64>], bands: &[(f64, f64)], bins: &[Vec<usize>], recorded: &Note, rooms: &[f64]) -> (Vec<Vec<f64>>, Vec<Vec<f64>>) {
    let floors: Vec<f64> = bands.iter().zip(bins).map(|((low, high), bins)| 10f64.powf((recorded.floor.at((low * high).sqrt()) + 10.0 * (bins.len() as f64).log10() + CLEAR) / 10.0)).collect();
    let pairs: Vec<(Vec<f64>, Vec<f64>)> = theirs
        .iter()
        .zip(sines)
        .map(|(a, s)| {
            (0..bands.len())
                .map(|k| {
                    let (theirs, sines) = (10f64.powf(a[k] / 10.0), 10f64.powf(s[k] / 10.0));
                    // Where the sines hold most of the band, what the recording has beyond them is their own small misfit, not noise.
                    let wanted = if theirs > floors[k] && theirs > 2.0 * sines { (theirs - sines - rooms[k]).max(0.0) } else { 0.0 };
                    (wanted, 1.0 / theirs.max(floors[k]).powi(2))
                })
                .unzip()
        })
        .collect();
    pairs.into_iter().unzip()
}

// How much of each frame's power comes from the noise's power at each of the times up to the noise's end, for noise of the same power at every time: the window's squared weights over each time's share of the straight lines between them.
fn shares(window: f64, frames: usize, rise: f64) -> Vec<Vec<f64>> {
    let last = TIMES.partition_point(|time| *time <= NOISE_UNTIL);
    let step = 0.0005;
    (0..frames)
        .map(|f| {
            let centre = f as f64 * HOP - LEAD;
            let mut shares = vec![0.0; last];
            let mut total = 0.0;
            let count = (window / step).round() as usize;
            for i in 0..count {
                let offset = (i as f64 + 0.5) / count as f64;
                let weight = (0.5 - 0.5 * (2.0 * std::f64::consts::PI * offset).cos()).powi(2);
                total += weight;
                let t = centre + (offset - 0.5) * window;
                if t < 0.0 || t >= TIMES[last] {
                    continue;
                }
                let at = TIMES.partition_point(|time| *time <= t).max(1) - 1;
                let share = (t - TIMES[at]) / (TIMES[at + 1] - TIMES[at]);
                let weight = weight * rising(t, rise).powi(2);
                shares[at] += weight * (1.0 - share);
                if at + 1 < last {
                    shares[at + 1] += weight * share;
                }
            }
            shares.iter().map(|s| s / total).collect()
        })
        .collect()
}

// Every band's noise levels at the times, as a level at the strike falling at a steady slope until the noise's end: the slope searched from 20 to 2000 dB a second, and for each slope the level that brings the band's frames nearest the wanted powers by least squares, each frame counting by its weight.
fn solve_noise(shares: &[Vec<Vec<f64>>], wanted: &[Vec<f64>], weights: &[Vec<f64>], gains: &[f64]) -> Vec<Vec<f64>> {
    let count = shares[0][0].len();
    let slopes: Vec<f64> = (0..=40).map(|i| -20.0 * 100f64.powf(i as f64 / 40.0)).collect();
    (0..gains.len())
        .map(|k| {
            let best = slopes
                .iter()
                .map(|&slope| {
                    let made: Vec<f64> = shares[k].iter().map(|s| gains[k] * s.iter().enumerate().map(|(j, share)| share * 10f64.powf(slope * TIMES[j] / 10.0)).sum::<f64>()).collect();
                    let (mut lifted, mut down) = (0.0, 0.0);
                    for ((m, w), v) in made.iter().zip(wanted).zip(weights) {
                        lifted += v[k] * m * w[k];
                        down += v[k] * m * m;
                    }
                    let power = (lifted / down.max(1e-300)).max(0.0);
                    let error: f64 = made.iter().zip(wanted).zip(weights).map(|((m, w), v)| v[k] * (power * m - w[k]).powi(2)).sum();
                    (error, power, slope)
                })
                .fold((f64::MAX, 0.0, 0.0), |best, next| if next.0 < best.0 { next } else { best });
            let (_, power, slope) = best;
            let start = if power > 0.0 { 10.0 * power.log10() } else { SILENT };
            (0..TIMES.len()).map(|j| if j < count { (start + slope * TIMES[j]).max(SILENT) } else { SILENT }).collect()
        })
        .collect()
}

/// How far a partial of a render is from the recording's.
#[derive(NifMap)]
pub struct PartialGap {
    pub ratio: f64,
    pub harmonic: u32,
    pub below: f64,
    pub strike: f64,
    pub mean: f64,
    /// The recording's noise floor around the partial, against the recording's loudest partial.
    pub floor: f64,
    /// Every half second from 0.5 to 2.5 seconds and every second after while the note lasts: the time, the recording's level and the render's, against the recording's loudest partial, neither below the floor.
    pub levels: Vec<(f64, f64, f64)>,
}

/// How far a render is from a recording of the same note, partial by partial and in ERB bands.
#[derive(NifMap)]
pub struct Check {
    pub partials: Vec<PartialGap>,
    pub erb: f64,
    pub bands: Vec<(f64, f64, usize)>,
    /// The mean gap in ERB bands over the 50 ms furthest off, and the seconds after the strike its frames' windows are centred from.
    pub stretch: (f64, f64),
    /// The recording's partials and the render's over their first half second, in dB.
    pub levels: (f64, f64),
    /// The cents the recording's fundamental and the render's are from the note's name.
    pub pitch: (f64, f64),
    /// The room's level over each of the ERB bands in dB, where a sine at full scale reads 0 dB, or none where the recording has no room.
    pub room: Vec<f64>,
}

/// A recording's fundamental, and the ratio of a render's pitch to the recording's: of the render's peak within a quarter tone of the recording's loudest partial to that partial, over the frames where a partial's frequency is read.
/// A recording more than a quarter tone from its name is left out before it is checked, so its fundamental is its partial within a quarter tone of the name, or where it has none, the pitch its harmonics give.
pub fn tuning(theirs: &Note, ours: &partials::Spectra, note: f64) -> (f64, f64) {
    let (named, quarter) = (hz(note), 2f64.powf(0.5 / 12.0));
    let fundamental = theirs.partials.iter().chain(&theirs.left_out).map(|t| t.freq).filter(|f| (f / named).ln().abs() <= quarter.ln()).min_by(|a, b| (a / named).ln().abs().total_cmp(&(b / named).ln().abs())).unwrap_or(theirs.f0);
    let Some(loudest) = theirs.partials.iter().max_by(|a, b| a.strike(0.02).total_cmp(&b.strike(0.02))) else { return (fundamental, 1.0) };
    let found = partials::settle(ours, loudest.freq, loudest.freq * (quarter - 1.0));
    (fundamental, found / loudest.freq)
}

/// Compares a render with a recording of the same note over `seconds` from its strike, each brought to the same total over its first half second, the render with the `room` the recording was made in added.
#[allow(clippy::too_many_arguments)]
pub fn check(recording: &[f64], rate: f64, rendered: &[f64], render_rate: f64, note: f64, seconds: f64, exact: bool, top: f64, room: Option<&Room>) -> Check {
    let theirs = partials::measure(recording, rate, note, seconds, exact, top);
    let ours = partials::spectra(rendered, render_rate, hz(note), seconds);
    let half = (0.5 / HOP) as usize;
    let power = |levels: &[f64]| levels.iter().take(half).map(|l| 10f64.powf(l / 10.0)).sum::<f64>();
    // The render is read at its own pitch, so a synth in tune is not counted off against a recording that is not.
    let (anchor, ratio) = tuning(&theirs, &ours, note);
    let freqs: Vec<f64> = theirs.partials.iter().chain(&theirs.left_out).map(|t| t.freq * ratio).collect();
    let ours_tracks = partials::follow(rendered, &ours, &freqs);
    let total_theirs: f64 = theirs.partials.iter().map(|t| power(&t.levels)).sum();
    let total_ours: f64 = ours_tracks.iter().map(|l| power(l)).sum();
    let shift = 10.0 * (total_theirs / total_ours).log10();
    let loudest = theirs.partials.iter().map(|t| t.strike(0.02)).fold(f64::MIN, f64::max);
    let partials = theirs
        .partials
        .iter()
        .zip(&ours_tracks)
        .map(|(track, mine)| {
            let floor = track.floor;
            let around = room::at(room, track.freq);
            let mine: Vec<f64> = mine.iter().map(|l| room::with(l + shift, around).max(floor)).collect();
            let strike_frames = (0.02 / HOP) as usize + (LEAD / HOP) as usize;
            let top = |levels: &[f64]| levels.iter().take(strike_frames).map(|l| l.max(floor)).fold(f64::MIN, f64::max);
            let gaps: Vec<f64> = track
                .levels
                .iter()
                .zip(&mine)
                .filter(|(a, b)| **a > floor + CLEAR || **b > floor + CLEAR)
                .map(|(a, b)| (b - a.max(floor)).abs())
                .collect();
            let levels = (1..=5)
                .map(|half_seconds| 0.5 * half_seconds as f64)
                .chain((3..=seconds as usize).map(|second| second as f64))
                .filter_map(|at| {
                    let frame = ((at + LEAD) / HOP).round() as usize;
                    Some((at, track.levels.get(frame)?.max(floor) - loudest, mine.get(frame)?.max(floor) - loudest))
                })
                .collect();
            PartialGap {
                ratio: track.freq / theirs.f0,
                harmonic: track.harmonic,
                below: loudest - track.strike(0.02),
                strike: top(&mine) - top(&track.levels),
                mean: if gaps.is_empty() { 0.0 } else { gaps.iter().sum::<f64>() / gaps.len() as f64 },
                floor: floor - loudest,
                levels,
            }
        })
        .collect();
    let erb_bands = erb_bands_under(top, rate);
    let (erb, bands, stretch) = erb_gap(&theirs, &ours, ratio, &erb_bands, room);
    let cents = |freq: f64| 1200.0 * (freq / hz(note)).log2();
    let pitch = (cents(anchor), cents(anchor * ratio));
    let room = if room.is_some() { room::over(room, &erb_bands).iter().map(|p| 10.0 * p.max(1e-24).log10()).collect() } else { vec![] };
    Check { partials, erb, bands, stretch, levels: (10.0 * total_theirs.log10(), 10.0 * total_ours.log10()), pitch, room }
}

/// How far the fit's own render of a recording, its figures played as sines and noise with no synth, is from the recording: the closest a synth playing the figures can come.
pub fn own(sound: &[f64], rate: f64, note: f64, seconds: f64, exact: bool, top: f64, room: Option<&Room>) -> Check {
    let (figures, _) = fit(sound, rate, note, seconds, exact, top, room);
    let rendered = render(&figures, rate, 0.05, seconds + 0.3);
    check(sound, rate, &rendered, rate, note, seconds, exact, top, room)
}

/// One partial's or one ERB band's levels at the times asked for, in dB against the recording's loudest partial: the recording, the synth when given, the fit's own render, and that render's sines and noise apart.
#[derive(NifMap)]
pub struct Rows {
    /// The partial's ratio to the pitch and its harmonic, 0 between harmonics, or the band's edges in Hz.
    pub at: (f64, f64),
    pub floor: f64,
    pub rows: Vec<(String, Vec<f64>)>,
}

/// One recording beside the synth and the fit's own render, frame by frame.
#[derive(NifMap)]
pub struct Frames {
    /// The fundamental's frequency as measured.
    pub pitch: f64,
    /// The seconds into the sound given that the strike was found at.
    pub strike: f64,
    pub partials: Vec<Rows>,
    pub bands: Vec<Rows>,
}

/// Fits a recording, renders the figures with their sines and noise together and apart, and gives each partial within 60 dB of the loudest, lowest first, and each ERB band at `times` seconds after the strike.
/// Each sound is brought to the recording's total over its first half second as `check` brings it, the sines and noise by the fit's own render's shift.
/// The synth and the fit's own render have the `room` the recording was made in added, as `check` adds it, and the room has a row of its own.
#[allow(clippy::too_many_arguments)]
pub fn frames(sound: &[f64], rate: f64, note: f64, seconds: f64, exact: bool, top: f64, synth: Option<(&[f64], f64)>, times: &[f64], room: Option<&Room>) -> Frames {
    let (figures, theirs) = fit(sound, rate, note, seconds, exact, top, room);
    let own = render(&figures, rate, 0.05, seconds + 0.3);
    let mut sines = figures.clone();
    for band in &mut sines.noise {
        band.levels.fill(SILENT);
    }
    let mut noise = figures.clone();
    for partial in &mut noise.partials {
        partial.levels.fill(SILENT);
    }
    let own_spectra = partials::spectra(&own, rate, hz(note), seconds);
    let struck = own_spectra.struck() as usize;
    let apart = |figures: &Figures| partials::spectra_from(&render(figures, rate, 0.05, seconds + 0.3), rate, hz(note), seconds, struck);
    let freqs: Vec<f64> = theirs.partials.iter().chain(&theirs.left_out).map(|t| t.freq).collect();
    let bands = erb_bands_under(top, rate);
    let half = (0.5 / HOP) as usize;
    let power = |levels: &[f64]| levels.iter().take(half).map(|l| 10f64.powf(l / 10.0)).sum::<f64>();
    let tracks_total = |tracks: &[Vec<f64>]| 10.0 * tracks.iter().take(theirs.partials.len()).map(|l| power(l)).sum::<f64>().log10();
    let bands_total = |levels: &[Vec<f64>]| 10.0 * levels.iter().take(half).flatten().map(|d| 10f64.powf(d / 10.0)).sum::<f64>().log10();
    let recorded: Vec<Vec<f64>> = theirs.partials.iter().map(|t| t.levels.clone()).collect();
    let recorded_bands = erb_levels(&theirs.spectra, &bands);
    let (track_target, band_target) = (tracks_total(&recorded), bands_total(&recorded_bands));
    // Each sound's tracks and bands, and the shifts that bring its own render's totals to the recording's.
    let measured = |sound: &[f64], spectra: &partials::Spectra, ratio: f64| {
        let freqs: Vec<f64> = freqs.iter().map(|f| f * ratio).collect();
        let moved: Vec<(f64, f64)> = bands.iter().map(|(low, high)| (low * ratio, high * ratio)).collect();
        (partials::follow(sound, spectra, &freqs), erb_levels(spectra, &moved))
    };
    let own_ratio = tuning(&theirs, &own_spectra, note).1;
    let (own_tracks, own_bands) = measured(&own, &own_spectra, own_ratio);
    let shifts = (track_target - tracks_total(&own_tracks), band_target - bands_total(&own_bands));
    let mut sounds: Vec<(String, Vec<Vec<f64>>, Vec<Vec<f64>>, (f64, f64), bool)> = vec![("recording".to_string(), recorded, recorded_bands, (0.0, 0.0), false)];
    if let Some((synth, synth_rate)) = synth {
        let spectra = partials::spectra(synth, synth_rate, hz(note), seconds);
        let (tracks, levels) = measured(synth, &spectra, tuning(&theirs, &spectra, note).1);
        let shift = (track_target - tracks_total(&tracks), band_target - bands_total(&levels));
        sounds.push(("synth".to_string(), tracks, levels, shift, true));
    }
    sounds.push(("fit".to_string(), own_tracks, own_bands, shifts, true));
    for (name, figures) in [("sines", &sines), ("noise", &noise)] {
        let rendered = render(figures, rate, 0.05, seconds + 0.3);
        let spectra = apart(figures);
        let (tracks, levels) = measured(&rendered, &spectra, own_ratio);
        sounds.push((name.to_string(), tracks, levels, shifts, false));
    }
    let loudest = loudest(&theirs);
    let frames: Vec<usize> = times.iter().map(|t| ((t + LEAD) / HOP).round().max(0.0) as usize).collect();
    let at = |levels: &[f64], shift: f64, added: f64| frames.iter().map(|k| levels.get(*k).map_or(SILENT, |l| room::with(l + shift, added) - loudest)).collect::<Vec<f64>>();
    let room_row = |power: f64| room.map(|_| ("room".to_string(), vec![10.0 * power.max(1e-24).log10() - loudest; frames.len()]));
    let rooms = room::over(room, &bands);
    let mut order: Vec<usize> = (0..theirs.partials.len()).filter(|i| loudest - theirs.partials[*i].strike(0.02) <= 60.0).collect();
    order.sort_by(|a, b| theirs.partials[*a].freq.total_cmp(&theirs.partials[*b].freq));
    let fundamental = theirs.partials.iter().find(|t| t.harmonic == 1).map_or(theirs.f0, |t| t.freq);
    let partial_rows = order
        .iter()
        .map(|i| {
            let track = &theirs.partials[*i];
            let around = room::at(room, track.freq);
            let rows = sounds.iter().map(|(name, tracks, _, (shift, _), roomed)| (name.clone(), at(&tracks[*i], *shift, if *roomed { around } else { 0.0 }))).chain(room_row(around)).collect();
            Rows { at: (track.freq / fundamental, track.harmonic as f64), floor: track.floor - loudest, rows }
        })
        .collect();
    let band_rows = bands
        .iter()
        .enumerate()
        .map(|(k, (low, high))| {
            let floor = theirs.floor.at((low * high).sqrt()) + 10.0 * ((high - low) / theirs.spectra.bin).max(1.0).log10();
            let rows = sounds.iter().map(|(name, _, levels, (_, shift), roomed)| (name.clone(), at(&levels.iter().map(|frame| frame[k]).collect::<Vec<f64>>(), *shift, if *roomed { rooms[k] } else { 0.0 }))).chain(room_row(rooms[k])).collect();
            Rows { at: (*low, *high), floor: floor - loudest, rows }
        })
        .collect();
    Frames { pitch: fundamental, strike: theirs.spectra.struck() / rate, partials: partial_rows, bands: band_rows }
}

/// The bands one ERB wide from 50 Hz to 8 kHz.
pub fn erb_bands() -> Vec<(f64, f64)> {
    erb_bands_to(partials::TOP)
}

/// The bands one ERB wide from 50 Hz to `top`, or to what a recording at `rate` holds when that is lower.
pub fn erb_bands_under(top: f64, rate: f64) -> Vec<(f64, f64)> {
    erb_bands_to(top.min(0.45 * rate))
}

/// The bands one ERB wide from 50 Hz to `top`.
pub fn erb_bands_to(top: f64) -> Vec<(f64, f64)> {
    let erb = |hz: f64| 21.4 * (1.0 + 0.00437 * hz).log10();
    let inverse = |e: f64| (10f64.powf(e / 21.4) - 1.0) / 0.00437;
    let (low, high) = (erb(50.0), erb(top));
    let count = (high - low).round() as usize;
    (0..count).map(|k| (inverse(low + (high - low) * k as f64 / count as f64), inverse(low + (high - low) * (k + 1) as f64 / count as f64))).collect()
}

fn bins(spectra: &partials::Spectra, low: f64, high: f64) -> (usize, usize) {
    let a = (low / spectra.bin).round() as usize;
    (a, ((high / spectra.bin).round() as usize).max(a + 1))
}

/// The power of a frame's magnitudes over a band from `low` to `high` Hz.
/// Each bin covers half a bin either side of its centre and counts for the share of that inside the band, so a band moved with a pitch takes the same part of each partial.
pub fn band_power(frame: &[f64], bin: f64, low: f64, high: f64) -> f64 {
    let (from, to) = (low / bin, high / bin);
    let first = (from - 0.5).floor().max(0.0) as usize;
    let last = ((to + 0.5).ceil() as usize).min(frame.len());
    (first..last).map(|i| (frame[i] * frame[i]) * ((i as f64 + 0.5).min(to) - (i as f64 - 0.5).max(from)).max(0.0)).sum()
}

pub fn erb_levels(spectra: &partials::Spectra, bands: &[(f64, f64)]) -> Vec<Vec<f64>> {
    spectra
        .frames
        .iter()
        .map(|f| {
            bands
                .iter()
                .map(|(low, high)| 10.0 * band_power(f, spectra.bin, *low, *high).max(1e-24).log10())
                .collect()
        })
        .collect()
}

// The mean gap over every band and frame where either stands clear of the recording's floor, the render brought to the recording's total over its first half second.
// Also each band's centre, its mean signed gap, and the frames it was compared in, and the stretch furthest off.
#[allow(clippy::type_complexity)]
fn erb_gap(theirs: &Note, ours: &partials::Spectra, ratio: f64, bands: &[(f64, f64)], room: Option<&Room>) -> (f64, Vec<(f64, f64, usize)>, (f64, f64)) {
    // The render's bands move with its pitch, so a partial a few cents off stays in the band it shares with the recording.
    let moved: Vec<(f64, f64)> = bands.iter().map(|(low, high)| (low * ratio, high * ratio)).collect();
    let (a, b) = (erb_levels(&theirs.spectra, &bands), erb_levels(ours, &moved));
    let half = (0.5 / HOP) as usize;
    let total = |e: &[Vec<f64>]| 10.0 * e.iter().take(half).flatten().map(|d| 10f64.powf(d / 10.0)).sum::<f64>().log10();
    let shift = total(&a) - total(&b);
    let rooms = room::over(room, bands);
    let mut gaps = vec![];
    let mut per_band = vec![(0.0, 0); bands.len()];
    let mut per_frame = vec![];
    for (fa, fb) in a.iter().zip(&b) {
        per_frame.push((0.0, 0));
        for (k, (x, y)) in fa.iter().zip(fb).enumerate() {
            let (low, high) = bands[k];
            let floor = theirs.floor.at((low * high).sqrt()) + 10.0 * ((high - low) / theirs.spectra.bin).max(1.0).log10();
            let y = room::with(y + shift, rooms[k]);
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
    let mean = if gaps.is_empty() { 0.0 } else { gaps.iter().sum::<f64>() / gaps.len() as f64 };
    let per_band = bands.iter().zip(per_band).map(|((low, high), (sum, count))| ((low * high).sqrt(), sum / count.max(1) as f64, count)).collect();
    (mean, per_band, furthest_stretch(&per_frame, theirs.spectra.window))
}

/// The seconds of the stretch a check names as furthest off.
const STRETCH: f64 = 0.05;

/// The mean gap over the `STRETCH` of frames furthest off, each frame given as the sum of its bands' gaps and their count, and the seconds after the strike the first of its frames is centred at.
pub fn furthest_stretch(frames: &[(f64, usize)], window: f64) -> (f64, f64) {
    let span = (STRETCH / HOP).round() as usize;
    (0..frames.len().saturating_sub(span - 1))
        .filter_map(|from| {
            let (sum, count) = frames[from..from + span].iter().fold((0.0, 0), |(sum, count), frame| (sum + frame.0, count + frame.1));
            (count > 0).then(|| (sum / count as f64, from as f64 * HOP - LEAD + window / 2.0))
        })
        .max_by(|a, b| a.0.total_cmp(&b.0))
        .unwrap_or((0.0, 0.0))
}

/// The level of a note's loudest partial as it starts, for ordering.
pub fn loudest(note: &Note) -> f64 {
    note.partials.iter().map(|t| t.strike(0.02)).fold(f64::MIN, f64::max)
}


/// The figures of struck notes as mxs reads them, all numbers little-endian.
/// The header is "MXF1", the times as a u16 count and f32 seconds, the noise bands as a u16 count and f32 low and high edges, and the recordings as a u16 count.
/// Each recording is its MIDI note and velocity as u8, and its partials as a u16 count, each its frequency over the note's equal-tempered pitch as f32, its harmonic number as u16 or 0 for a partial between harmonics, its last slope and its level at each time in tenths of a dB as i16.
/// Then each noise band's last slope and its level at each time, in tenths of a dB as i16, as the gain on white noise from -1 to 1 through the band's filters at `NOISE_RATE`.
pub fn figures_bytes(recordings: &[(u8, u8, Figures)]) -> Vec<u8> {
    let tenths = |value: f64| ((value * 10.0).round().clamp(-32000.0, 32000.0) as i16).to_le_bytes();
    let mut bytes = b"MXF1".to_vec();
    bytes.extend((TIMES.len() as u16).to_le_bytes());
    for time in TIMES {
        bytes.extend((time as f32).to_le_bytes());
    }
    // Every recording of a fit has the same bands.
    let bands: Vec<(f64, f64)> = recordings.first().map_or_else(erb_bands, |(_, _, figures)| figures.noise.iter().map(|band| (band.low, band.high)).collect());
    bytes.extend((bands.len() as u16).to_le_bytes());
    for (low, high) in &bands {
        bytes.extend((*low as f32).to_le_bytes());
        bytes.extend((*high as f32).to_le_bytes());
    }
    bytes.extend((recordings.len() as u16).to_le_bytes());
    for (note, velocity, figures) in recordings {
        bytes.extend([*note, *velocity]);
        bytes.extend((figures.partials.len() as u16).to_le_bytes());
        let fundamental = figures.partials.iter().find(|p| p.harmonic == 1).map_or(1.0, |p| p.ratio);
        for partial in &figures.partials {
            bytes.extend(((partial.ratio / fundamental * figures.pitch / hz(*note as f64)) as f32).to_le_bytes());
            bytes.extend((partial.harmonic as u16).to_le_bytes());
            bytes.extend(tenths(partial.tail));
            for level in &partial.levels {
                bytes.extend(tenths(*level));
            }
        }
        for (band, (low, high)) in figures.noise.iter().zip(&bands) {
            let written = noise_to_written(*low, *high, figures.rate);
            bytes.extend(tenths(band.tail));
            for level in &band.levels {
                bytes.extend(tenths(if *level <= SILENT { *level } else { level + written }));
            }
        }
    }
    bytes
}

/// A partial of a measured note, as `mix mx.measure` prints it: its frequency, its harmonic number or 0, its level as the note starts against the note's loudest partial, and how it falls.
#[derive(NifMap)]
pub struct Line {
    pub freq: f64,
    pub harmonic: u32,
    pub level: f64,
    pub fall: Option<f64>,
    pub knee: Option<f64>,
    pub then: Option<f64>,
}

/// A measured note: its pitch, its partials, and the lines left out as not the instrument's.
#[derive(NifMap)]
pub struct Measured {
    pub pitch: f64,
    pub partials: Vec<Line>,
    pub left_out: Vec<Line>,
}

/// Measures a struck note partial by partial, over the seconds the fitting measures.
pub fn measure(sound: &[f64], rate: f64, note: f64) -> Measured {
    let measured = partials::measure(sound, rate, note, SECONDS, false, partials::TOP);
    let loudest = loudest(&measured);
    let line = |track: &Track| {
        let fall = partials::fall(track);
        Line {
            freq: track.freq,
            harmonic: track.harmonic,
            level: track.strike(0.02) - loudest,
            fall: fall.as_ref().map(|f| f.first),
            knee: fall.as_ref().and_then(|f| f.knee),
            then: fall.as_ref().and_then(|f| f.knee.map(|_| f.second)),
        }
    };
    Measured { pitch: measured.f0, partials: measured.partials.iter().map(line).collect(), left_out: measured.left_out.iter().map(line).collect() }
}

/// The level in dBFS each sound of a tour is brought to over the first half second after its strike.
const TOUR_LEVEL: f64 = -26.0;

/// A tour for listening: each recording's note and then the render beside it, from 50 ms before each strike for the recording's `seconds`, each brought to the same level over its first half second, a second of silence after each, all at `rate`.
/// The whole tour is turned down together if it would reach above -1 dBFS.
pub fn tour(pairs: &[(Vec<f64>, f64, f64, Vec<f64>)], rate: f64) -> Vec<f64> {
    let mut sound = vec![];
    for (recording, recording_rate, seconds, rendered) in pairs {
        for part in [resample(recording, *recording_rate, rate), rendered.clone()] {
            let from = partials::strike(&part).saturating_sub((0.05 * rate) as usize);
            let to = (from + (seconds * rate) as usize).min(part.len());
            let half = &part[from..(from + (0.55 * rate) as usize).min(to)];
            let level = 10.0 * (half.iter().map(|x| x * x).sum::<f64>() / half.len().max(1) as f64).max(1e-20).log10();
            let gain = 10f64.powf((TOUR_LEVEL - level) / 20.0);
            sound.extend(part[from..to].iter().map(|x| x * gain));
            sound.extend(std::iter::repeat_n(0.0, rate as usize));
        }
    }
    let peak = sound.iter().fold(0.0f64, |top, x| top.max(x.abs()));
    let most = 10f64.powf(-1.0 / 20.0);
    if peak > most {
        sound.iter_mut().for_each(|x| *x *= most / peak);
    }
    sound
}

// A sound at another rate, through a windowed sinc 32 samples wide that cuts at the lower rate's half.
fn resample(sound: &[f64], from: f64, to: f64) -> Vec<f64> {
    if from == to {
        return sound.to_vec();
    }
    let step = from / to;
    let cutoff = (1.0 / step).min(1.0);
    let taps = 16i64;
    let count = (sound.len() as f64 / step) as usize;
    (0..count)
        .map(|n| {
            let at = n as f64 * step;
            let centre = at.floor() as i64;
            (centre - taps + 1..=centre + taps)
                .filter(|k| *k >= 0 && (*k as usize) < sound.len())
                .map(|k| {
                    let x = (at - k as f64) * cutoff;
                    let sinc = if x.abs() < 1e-9 { 1.0 } else { (std::f64::consts::PI * x).sin() / (std::f64::consts::PI * x) };
                    let window = 0.5 + 0.5 * (std::f64::consts::PI * (at - k as f64) / taps as f64).cos();
                    sound[k as usize] * cutoff * sinc * window
                })
                .sum()
        })
        .collect()
}
