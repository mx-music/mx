//! Held notes, bowed, blown or played on an organ, for `Mx.Measure.Held`: the pitch, the attack, each harmonic's level while the note holds, the vibrato, and the noise between the harmonics.

use super::{
    BANDS, Spectra, db, filter_loss, first_max, high_pass, hz, inferred, magnitude_at, median,
    onsets, refine, slope,
};
use rustler::NifMap;

const HOP: f64 = 0.01;
const LEAD: f64 = 0.05;
const HELD_RANGE: f64 = 12.0;
const REACH: f64 = 0.5;

#[derive(NifMap)]
pub struct Harmonic {
    pub number: u32,
    pub freq: f64,
    pub level: f64,
}

#[derive(NifMap)]
pub struct Vibrato {
    pub rate: f64,
    pub depth: f64,
}

#[derive(NifMap)]
pub struct Noise {
    pub band: (u32, u32),
    pub level: f64,
}

#[derive(NifMap)]
pub struct Note {
    pub note: i64,
    pub pitch: f64,
    pub held: f64,
    pub attack: f64,
    pub vibrato: Option<Vibrato>,
    pub harmonics: Vec<Harmonic>,
    pub noise: Vec<Noise>,
}

/// Each held note of a sound whose first note is `first`, one after another a semitone apart.
pub fn notes(samples: &[f64], rate: f64, first: i64) -> Vec<Note> {
    let cutoff = hz(first as f64) * 0.75;
    let sound = high_pass(samples, rate, cutoff);
    let starts = onsets(&sound, rate, 1.0);
    let ends: Vec<usize> = starts
        .iter()
        .skip(1)
        .cloned()
        .chain([sound.len()])
        .collect();
    let lead = (LEAD * rate).round() as usize;
    let mut spectra = Spectra::default();
    starts
        .iter()
        .zip(&ends)
        .enumerate()
        .filter_map(|(index, (&from, &to))| {
            let mut segment = vec![0.0; lead.saturating_sub(from)];
            segment.extend_from_slice(&sound[from.saturating_sub(lead)..to]);
            measure(&segment, rate, first + index as i64, cutoff, &mut spectra)
        })
        .collect()
}

/// A sound that is one held note from its first sample, or None when it is too short.
pub fn note(samples: &[f64], rate: f64, note: i64) -> Option<Note> {
    let cutoff = hz(note as f64) * 0.75;
    let mut segment = vec![0.0; (LEAD * rate).round() as usize];
    segment.extend(high_pass(samples, rate, cutoff));
    measure(&segment, rate, note, cutoff, &mut Spectra::default())
}

// The power of two nearest the given seconds.
fn window(rate: f64, seconds: f64) -> usize {
    2usize.pow((seconds * rate).log2().round() as u32)
}

fn energy(spectrum: &[f64]) -> f64 {
    10.0 * (spectrum.iter().map(|m| m * m).sum::<f64>() + 1.0e-24).log10()
}

fn measure(
    sound: &[f64],
    rate: f64,
    guess: i64,
    cutoff: f64,
    spectra: &mut Spectra,
) -> Option<Note> {
    let small = window(rate, 0.043);
    let large = window(rate, 0.17);
    let hop = (HOP * rate).round() as usize;
    if sound.len() < large {
        return None;
    }
    let starts: Vec<usize> = (0..=sound.len() - large).step_by(hop).collect();
    if starts.len() < 40 {
        return None;
    }
    let offset = (large - small) / 2;
    let energies: Vec<f64> = starts
        .iter()
        .map(|from| energy(&spectra.take(sound, from + offset, small)))
        .collect();
    let held = held(&starts, &energies);
    // A single frame is a burst, such as an accent, with nothing held after it.
    if held.len() == 1 {
        return None;
    }
    let inside = inside(&held, offset);
    let frames: Vec<Vec<f64>> = inside
        .iter()
        .step_by(5)
        .map(|from| spectra.take(sound, *from, large))
        .collect();
    let bin = rate / large as f64;
    let f0 = pitch(&frames, hz(guess as f64), bin);
    let harmonics = harmonics(&frames, f0, bin, rate, cutoff);
    let centre = large / 2;
    Some(Note {
        note: (69.0 + 12.0 * (f0 / 440.0).log2()).round() as i64,
        pitch: f0,
        held: held.len() as f64 * HOP,
        attack: attack(sound, rate, &held, centre),
        vibrato: vibrato(sound, &held, f0, &harmonics, rate, centre, spectra),
        noise: noise(&frames, f0, bin, rate, cutoff),
        harmonics,
    })
}

// The frame starts of the longest stretch within 12 dB of the loudest.
fn held(starts: &[usize], energies: &[f64]) -> Vec<usize> {
    let loudest = energies.iter().cloned().fold(f64::MIN, f64::max);
    let mut runs: Vec<Vec<usize>> = vec![];
    let mut inside_before: Option<bool> = None;
    for (start, energy) in starts.iter().zip(energies) {
        let inside = *energy >= loudest - HELD_RANGE;
        if inside_before != Some(inside) {
            runs.push(vec![]);
        }
        inside_before = Some(inside);
        if inside {
            runs.last_mut().unwrap().push(*start);
        }
    }
    first_max(runs.into_iter().filter(|run| !run.is_empty()), |run| {
        run.len() as f64
    })
    .unwrap_or_default()
}

// The held frames whose large window lies wholly within the held part, so a sound cut off right after it leaks into no spectrum.
fn inside(held: &[usize], trim: usize) -> Vec<usize> {
    let first = held[0] + trim;
    let last = held[held.len() - 1] as i64 - trim as i64;
    let kept: Vec<usize> = held
        .iter()
        .cloned()
        .filter(|at| *at >= first && *at as i64 <= last)
        .collect();
    if kept.is_empty() { held.to_vec() } else { kept }
}

// The fundamental within 6% of the guess whose first six harmonics hold the most energy, over the held spectra.
fn pitch(frames: &[Vec<f64>], guess: f64, bin: f64) -> f64 {
    let steps = (guess * 0.12 / 0.05).round() as i64;
    let candidates = (0..=steps).map(|step| guess * 0.94 + step as f64 * 0.05);
    first_max(candidates, |freq| {
        frames
            .iter()
            .flat_map(|spectrum| {
                (1..=6).map(move |n| magnitude_at(spectrum, freq * n as f64 / bin))
            })
            .sum()
    })
    .unwrap()
}

fn mean_power(frames: &[Vec<f64>]) -> Vec<f64> {
    let count = frames.len() as f64;
    (0..frames[0].len())
        .map(|at| frames.iter().map(|f| f[at] * f[at]).sum::<f64>() / count)
        .collect()
}

fn power_mean(levels: &[f64]) -> f64 {
    10.0 * (levels.iter().map(|l| 10f64.powf(l / 10.0)).sum::<f64>() / levels.len() as f64).log10()
}

// The loudest bin's position and level, refined between bins only when it is louder than both its neighbours.
fn peak(spectrum: &[f64], bins: &[usize]) -> (f64, f64) {
    let peak = first_max(bins.iter().cloned(), |at| spectrum[*at]).unwrap();
    let level = spectrum[peak];
    if level > spectrum[peak - 1] && level >= spectrum[peak + 1] {
        refine(spectrum, peak)
    } else {
        (peak as f64, db(level))
    }
}

// Each harmonic's frequency and level, averaged in power over the held spectra; one less than 10 dB above the floor, or 80 dB below the loudest, is absent.
fn harmonics(frames: &[Vec<f64>], f0: f64, bin: f64, rate: f64, cutoff: f64) -> Vec<Harmonic> {
    let floor = median(
        &mean_power(frames)
            .iter()
            .map(|p| 10.0 * (p + 1.0e-24).log10())
            .collect::<Vec<_>>(),
    );
    let top = 18_000f64.min(rate / 2.0 - f0);
    let count = (top / f0).floor() as i64;
    let found: Vec<(Harmonic, f64)> = (1..=count)
        .map(|number| {
            let target = number as f64 * f0;
            let bins: Vec<usize> = inferred(
                (((target - f0 / 4.0) / bin).ceil() as i64).max(1),
                ((target + f0 / 4.0) / bin).floor() as i64,
            )
            .into_iter()
            .map(|b| b as usize)
            .collect();
            let peaks: Vec<(f64, f64)> = frames
                .iter()
                .map(|spectrum| peak(spectrum, &bins))
                .collect();
            let freq = peaks.iter().map(|p| p.0).sum::<f64>() / peaks.len() as f64 * bin;
            let level = power_mean(&peaks.iter().map(|p| p.1).collect::<Vec<_>>());
            (
                Harmonic {
                    number: number as u32,
                    freq,
                    level: level + filter_loss(freq, cutoff),
                },
                level,
            )
        })
        .collect();
    let loudest = found.iter().map(|(_, raw)| *raw).fold(f64::MIN, f64::max);
    found
        .into_iter()
        .filter(|(_, raw)| *raw > floor + 10.0 && *raw > loudest - 80.0)
        .map(|(h, _)| h)
        .collect()
}

// The power between the harmonics in each band above the high-pass, as the level in dB of a harmonic of the same power.
// A Hann window gives a harmonic of amplitude A a peak of A N / 4, and white noise of variance σ² a power of 3 N σ² / 8 in each bin.
fn noise(frames: &[Vec<f64>], f0: f64, bin: f64, rate: f64, cutoff: f64) -> Vec<Noise> {
    let size = frames[0].len() * 2;
    let powers = mean_power(frames);
    BANDS
        .iter()
        .filter(|(low, high)| *low as f64 >= cutoff && *high as f64 <= rate / 2.0)
        .filter_map(|&(low, high)| {
            let between = between(low as f64, high as f64, f0, bin, powers.len());
            if between.is_empty() {
                return None;
            }
            let mean = between
                .iter()
                .map(|&at| powers[at] * 10f64.powf(filter_loss(at as f64 * bin, cutoff) / 10.0))
                .sum::<f64>()
                / between.len() as f64;
            let variance = mean / (3.0 * size as f64 / 8.0);
            let power = variance * (high - low) as f64 / (rate / 2.0);
            Some(Noise {
                band: (low, high),
                level: 10.0 * (2.0 * power + 1.0e-24).log10() + db(size as f64 / 4.0),
            })
        })
        .collect()
}

// The bins of a band in the middle third between two harmonics.
fn between(low: f64, high: f64, f0: f64, bin: f64, count: usize) -> Vec<usize> {
    let first = (low / bin).ceil() as i64;
    let last = ((high / bin).floor() as i64).min(count as i64 - 1);
    (first..=last)
        .filter(|&at| {
            let place = at as f64 * bin / f0;
            let offset = place - place.floor();
            place > 1.0 && (1.0 / 3.0..=2.0 / 3.0).contains(&offset)
        })
        .map(|at| at as usize)
        .collect()
}

// The seconds from where the sound starts, 40 dB below its held level, until it first comes within 0.5 dB of it.
fn attack(sound: &[f64], rate: f64, held: &[usize], centre: usize) -> f64 {
    let window = (0.01 * rate).round() as usize;
    let step = (0.001 * rate).round() as usize;
    let envelope: Vec<(f64, f64)> = (0..=sound.len().saturating_sub(window))
        .step_by(step)
        .map(|from| {
            let sum: f64 = sound[from..from + window].iter().map(|x| x * x).sum();
            (
                (from as f64 + window as f64 / 2.0) / rate,
                (sum / window as f64).sqrt(),
            )
        })
        .collect();
    let first = (held[0] + centre) as f64 / rate;
    let last = (held[held.len() - 1] + centre) as f64 / rate;
    let level = median(
        &envelope
            .iter()
            .filter(|(t, _)| *t >= first && *t <= last)
            .map(|(_, v)| *v)
            .collect::<Vec<_>>(),
    );
    let reached = envelope
        .iter()
        .position(|(_, v)| *v >= level * 10f64.powf(-REACH / 20.0))
        .unwrap();
    let start = envelope[..reached]
        .iter()
        .filter(|(_, v)| *v < level / 100.0)
        .last()
        .map_or(0.0, |(t, _)| *t);
    envelope[reached].0 - start
}

// The pitch of the strongest of the first four harmonics in short frames across the held part, in cents; the frames average the swing over their length, so the depth is divided by what a Hann window keeps of a swing at that rate.
fn vibrato(
    sound: &[f64],
    held: &[usize],
    f0: f64,
    harmonics: &[Harmonic],
    rate: f64,
    centre: usize,
    spectra: &mut Spectra,
) -> Option<Vibrato> {
    let small = window(rate, 0.043);
    let bin = rate / small as f64;
    let number =
        first_max(harmonics.iter().filter(|h| h.number <= 4), |h| h.level).map_or(1, |h| h.number);
    let target = number as f64 * f0;
    let bins: Vec<usize> = inferred(
        ((target * 0.94 / bin).floor() as i64).max(1),
        (target * 1.06 / bin).ceil() as i64,
    )
    .into_iter()
    .map(|b| b as usize)
    .collect();
    let track: Vec<f64> = held
        .iter()
        .map(|from| {
            let spectrum = spectra.take(sound, from + centre - small / 2, small);
            let (position, _) = peak(&spectrum, &bins);
            1200.0 * (position * bin / target).log2()
        })
        .collect();
    swing(&track, small as f64 / rate)
}

fn swing(track: &[f64], frame: f64) -> Option<Vibrato> {
    if track.len() < 60 {
        return None;
    }
    let times: Vec<f64> = (0..track.len()).map(|index| index as f64 * HOP).collect();
    let slope = slope(
        &times
            .iter()
            .cloned()
            .zip(track.iter().cloned())
            .collect::<Vec<_>>(),
    );
    let mean = track.iter().sum::<f64>() / track.len() as f64;
    let middle = times.iter().sum::<f64>() / times.len() as f64;
    let deviations: Vec<f64> = times
        .iter()
        .zip(track)
        .map(|(time, cents)| cents - mean - slope * (time - middle))
        .collect();
    let (lag, correlation) = first_max(
        (10..=33).map(|lag| (lag, correlation(&deviations, lag))),
        |(_, c)| *c,
    )
    .unwrap();
    let rms = (deviations.iter().map(|d| d * d).sum::<f64>() / deviations.len() as f64).sqrt();
    let lag = refine_lag(&deviations, lag);
    let rate = 1.0 / (lag * HOP);
    let depth = rms * 2f64.sqrt() / kept(rate, frame);
    (correlation >= 0.5 && depth >= 5.0).then_some(Vibrato { rate, depth })
}

fn correlation(values: &[f64], lag: usize) -> f64 {
    let count = values.len();
    let products: f64 = values
        .iter()
        .zip(&values[lag.min(count)..])
        .map(|(a, b)| a * b)
        .sum();
    let power: f64 = values.iter().map(|v| v * v).sum();
    if power > 0.0 {
        products / power * count as f64 / (count - lag) as f64
    } else {
        0.0
    }
}

fn refine_lag(values: &[f64], lag: usize) -> f64 {
    let (left, top, right) = (
        correlation(values, lag - 1),
        correlation(values, lag),
        correlation(values, lag + 1),
    );
    let curve = left - 2.0 * top + right;
    if curve < 0.0 {
        lag as f64 + 0.5 * (left - right) / curve
    } else {
        lag as f64
    }
}

// What a Hann window of `frame` seconds keeps of a sine swing at `rate` times a second.
fn kept(rate: f64, frame: f64) -> f64 {
    let count = 256;
    let (mut real, mut imaginary, mut total) = (0.0, 0.0, 0.0);
    for index in 0..count {
        let weight = 0.5 - 0.5 * (2.0 * std::f64::consts::PI * index as f64 / count as f64).cos();
        let phase = 2.0 * std::f64::consts::PI * rate * frame * index as f64 / count as f64;
        real += weight * phase.cos();
        imaginary += weight * phase.sin();
        total += weight;
    }
    (real * real + imaginary * imaginary).sqrt() / total
}
