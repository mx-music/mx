//! A recording's levels over time as numbers, for `Mx.Levels`: a row of levels for each moment, and the strokes where sounds start.

use rustfft::{Fft, FftPlanner, num_complex::Complex};
use std::sync::Arc;

const FFT: usize = 4096;
const LOW: f64 = 20.0;
const BANDS: usize = 10;
const FLOOR: f64 = -100.0;
const STROKE_FFT: usize = 1024;
const STROKE_HOP: f64 = 0.005;
const STROKE_GAP: f64 = 0.03;
const STROKE_RISE: f64 = 0.02;
const STROKE_LAG: usize = 2;
const STROKE_RANGE: f64 = 50.0;

/// One moment of a recording: the second it starts at, the level of the whole sound and of each octave from 20 Hz, in dB under the loudest moment, and the frequency half its energy lies under.
pub type Row = (f64, f64, Vec<f64>, f64);

/// The rows of `sound`, `per_second` of them a second, each covering the sound from its start to the next's.
pub fn rows(sound: &[f64], rate: f64, per_second: f64) -> Vec<Row> {
    let hop = rate / per_second;
    let count = (sound.len() as f64 / hop).ceil() as usize;
    let fft = FftPlanner::<f64>::new().plan_fft_forward(FFT);
    let window = hann(FFT);
    let edges = band_edges(rate, FFT);

    let measured: Vec<(f64, Vec<f64>, f64)> = (0..count)
        .map(|index| {
            let from = (index as f64 * hop).round() as usize;
            let until = (((index + 1) as f64 * hop).round() as usize).min(sound.len());
            let slice = &sound[from..until];
            let power = slice.iter().map(|x| x * x).sum::<f64>() / slice.len().max(1) as f64;
            // Spectra centred every half window across the row, so a short sound inside it is heard.
            let step = (FFT / 2).min(until - from).max(1);
            let mut spectrum = vec![0.0; FFT / 2];
            let mut centre = from + step / 2;
            while centre < until.max(from + 1) {
                add_spectrum(sound, centre, &window, &fft, &mut spectrum);
                centre += step;
            }
            let total: f64 = spectrum.iter().sum();
            let bands = edges
                .iter()
                .map(|&(low, high)| {
                    let share = if total > 0.0 { spectrum[low..high].iter().sum::<f64>() / total } else { 0.0 };
                    power * share
                })
                .collect();
            (power, bands, median_hz(&spectrum, total, rate / FFT as f64))
        })
        .collect();

    let loudest = measured.iter().map(|m| m.0).fold(0.0, f64::max);
    let db = |power: f64| if loudest > 0.0 && power > 0.0 { (10.0 * (power / loudest).log10()).max(FLOOR) } else { FLOOR };
    measured
        .into_iter()
        .enumerate()
        .map(|(index, (power, bands, brightness))| (index as f64 / per_second, db(power), bands.into_iter().map(db).collect(), brightness))
        .collect()
}

/// The second each sound in `sound` starts, where the spectrum rises sharply, and its level in dB under the loudest stroke's.
pub fn strokes(sound: &[f64], rate: f64) -> Vec<(f64, f64)> {
    let hop = (STROKE_HOP * rate).round() as usize;
    let fft = FftPlanner::<f64>::new().plan_fft_forward(STROKE_FFT);
    let window = hann(STROKE_FFT);
    let bin = rate / STROKE_FFT as f64;
    let (low, high) = ((30.0 / bin) as usize, ((16_000.0 / bin) as usize).min(STROKE_FFT / 2));
    let count = sound.len().div_ceil(hop);
    let spectra: Vec<Vec<f64>> = (0..count)
        .map(|index| {
            let mut spectrum = vec![0.0; STROKE_FFT / 2];
            add_spectrum(sound, index * hop, &window, &fft, &mut spectrum);
            spectrum[low..high].iter().map(|p| p.sqrt()).collect()
        })
        .collect();
    let top = spectra.iter().flat_map(|s| s.iter().copied()).fold(0.0, f64::max);
    if top <= 0.0 {
        return Vec::new();
    }
    let compressed: Vec<Vec<f64>> = spectra.iter().map(|s| s.iter().map(|m| (1.0 + 1000.0 * m / top).log10()).collect()).collect();
    // Each bin rises against the loudest of its neighbours a frame before, so a partial that beats or drifts does not.
    let flux: Vec<f64> = (0..count)
        .map(|t| {
            if t < STROKE_LAG {
                return 0.0;
            }
            let (now, before) = (&compressed[t], &compressed[t - STROKE_LAG]);
            (0..now.len())
                .map(|k| {
                    let near = before[k.saturating_sub(1)..(k + 2).min(before.len())].iter().copied().fold(0.0, f64::max);
                    (now[k] - near).max(0.0)
                })
                .sum()
        })
        .collect();
    let loudest = flux.iter().copied().fold(0.0, f64::max);
    if loudest <= 0.0 {
        return Vec::new();
    }

    let gap = (STROKE_GAP / STROKE_HOP).round() as usize;
    let behind = (0.1 / STROKE_HOP).round() as usize;
    let mut found: Vec<usize> = Vec::new();
    for t in 0..count {
        let near = &flux[t.saturating_sub(gap)..(t + gap + 1).min(count)];
        let around = &flux[t.saturating_sub(behind)..(t + gap + 1).min(count)];
        let mean = around.iter().sum::<f64>() / around.len() as f64;
        let peak = near.iter().all(|&f| f <= flux[t]);
        // A recording that stops on a sound jumps to silence at its end, which is no stroke.
        let inside = t * hop + STROKE_FFT / 2 <= sound.len();
        if inside && peak && flux[t] >= mean + STROKE_RISE * loudest && found.last().is_none_or(|&at| t > at + gap) {
            found.push(t);
        }
    }

    let power = |t: usize| {
        let from = t * hop;
        let slice = &sound[from.min(sound.len())..(from + (STROKE_GAP * rate) as usize).min(sound.len())];
        slice.iter().map(|x| x * x).sum::<f64>() / slice.len().max(1) as f64
    };
    let powers: Vec<f64> = found.iter().map(|&t| power(t)).collect();
    let strongest = powers.iter().copied().fold(0.0, f64::max);
    // A window's centre reaches a sound half a window after its front, and the rise is strongest between.
    let lead = (STROKE_FFT / 4) as f64 / rate;
    found
        .into_iter()
        .zip(powers)
        .filter(|&(_, p)| p > 0.0 && 10.0 * (p / strongest).log10() > -STROKE_RANGE)
        .map(|(t, p)| (((t * hop) as f64 / rate - lead).max(0.0), 10.0 * (p / strongest).log10()))
        .collect()
}

fn hann(size: usize) -> Vec<f64> {
    (0..size).map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / size as f64).cos()).collect()
}

/// The bins of each octave from 20 Hz, as `[low, high)`, for a spectrum of `size` samples.
fn band_edges(rate: f64, size: usize) -> Vec<(usize, usize)> {
    let bin = rate / size as f64;
    (0..BANDS)
        .map(|band| {
            let low = (LOW * 2f64.powi(band as i32) / bin).round() as usize;
            let high = (LOW * 2f64.powi(band as i32 + 1) / bin).round() as usize;
            (low.min(size / 2), high.clamp(low + 1, size / 2).max(low.min(size / 2)))
        })
        .collect()
}

/// Adds the power spectrum of the window of `sound` centred on sample `centre` to `spectrum`.
fn add_spectrum(sound: &[f64], centre: usize, window: &[f64], fft: &Arc<dyn Fft<f64>>, spectrum: &mut [f64]) {
    let size = window.len();
    let start = centre as isize - (size / 2) as isize;
    let mut buffer: Vec<Complex<f64>> = (0..size)
        .map(|i| {
            let at = start + i as isize;
            let x = if at >= 0 && (at as usize) < sound.len() { sound[at as usize] } else { 0.0 };
            Complex::new(x * window[i], 0.0)
        })
        .collect();
    fft.process(&mut buffer);
    for (sum, value) in spectrum.iter_mut().zip(&buffer) {
        *sum += value.norm_sqr();
    }
}

/// The frequency that half the spectrum's energy lies under, interpolated within its bin.
fn median_hz(spectrum: &[f64], total: f64, bin: f64) -> f64 {
    if total <= 0.0 {
        return 0.0;
    }
    let mut below = 0.0;
    for (index, power) in spectrum.iter().enumerate() {
        if below + power >= total / 2.0 {
            let inside = (total / 2.0 - below) / power;
            return (index as f64 - 0.5 + inside) * bin;
        }
        below += power;
    }
    spectrum.len() as f64 * bin
}
