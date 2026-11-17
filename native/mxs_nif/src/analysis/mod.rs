//! Measuring recordings, for `Mx.Measure`: the pieces plucked notes, held notes and hits share, as `Mx.Signal` described them.
//! Levels are in dB, and a spectrum holds the magnitude of each frequency bin below half the sample rate.

pub mod fit;
pub mod held;
pub mod hits;
pub mod hum;
pub mod known;
pub mod partials;
pub mod plucked;
pub mod runs;
pub mod strokes;

use rustfft::{Fft, FftPlanner, num_complex::Complex};
use std::collections::HashMap;
use std::sync::Arc;

/// The bands measurements are given in, each a third of an octave or wider, in Hz.
pub const BANDS: [(u32, u32); 11] = [
    (80, 160),
    (160, 250),
    (250, 400),
    (400, 630),
    (630, 1000),
    (1000, 1600),
    (1600, 2500),
    (2500, 4000),
    (4000, 6300),
    (6300, 10_000),
    (10_000, 16_000),
];

const ONSET_HOP: f64 = 0.005;
const ONSET_WINDOW: usize = 40;

pub fn hz(note: f64) -> f64 {
    440.0 * 2f64.powf((note - 69.0) / 12.0)
}

pub fn db(magnitude: f64) -> f64 {
    20.0 * (magnitude + 1.0e-12).log10()
}

/// The middle value, or the mean of the two middle ones.
pub fn median(values: &[f64]) -> f64 {
    let mut sorted = values.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let middle = sorted.len() / 2;
    if sorted.len() % 2 == 1 { sorted[middle] } else { (sorted[middle - 1] + sorted[middle]) / 2.0 }
}

/// The index of the first largest value, as `Enum.max_by` picks it.
pub fn first_max<T>(items: impl IntoIterator<Item = T>, key: impl Fn(&T) -> f64) -> Option<T> {
    let mut best: Option<(T, f64)> = None;
    for item in items {
        let value = key(&item);
        if best.as_ref().is_none_or(|(_, top)| value > *top) {
            best = Some((item, value));
        }
    }
    best.map(|(item, _)| item)
}

/// The integers from `first` to `last`, counting down when `first` is the larger, as an Elixir range without a step does.
pub fn inferred(first: i64, last: i64) -> Vec<i64> {
    if first <= last { (first..=last).collect() } else { (last..=first).rev().collect() }
}

/// Each item mapped on its own thread, in order.
pub fn parallel<T: Sync, U: Send>(items: &[T], map: impl Fn(&T) -> U + Sync) -> Vec<U> {
    let threads = std::thread::available_parallelism().map_or(1, |n| n.get());
    let size = items.len().div_ceil(threads).max(1);
    std::thread::scope(|scope| {
        let handles: Vec<_> = items.chunks(size).map(|chunk| scope.spawn(|| chunk.iter().map(&map).collect::<Vec<U>>())).collect();
        handles.into_iter().flat_map(|handle| handle.join().unwrap()).collect()
    })
}

/// Spectra through a periodic Hann window, with one plan kept for each size.
pub struct Spectra {
    planner: FftPlanner<f64>,
    plans: HashMap<usize, Arc<dyn Fft<f64>>>,
}

impl Default for Spectra {
    fn default() -> Self {
        Spectra { planner: FftPlanner::new(), plans: HashMap::new() }
    }
}

impl Spectra {
    /// The magnitudes of `size` samples of `sound` from `from`, bins 0 to `size / 2 - 1`; samples past the end are silence.
    pub fn take(&mut self, sound: &[f64], from: usize, size: usize) -> Vec<f64> {
        let fft = self.plans.entry(size).or_insert_with(|| self.planner.plan_fft_forward(size)).clone();
        let mut buffer: Vec<Complex<f64>> = (0..size)
            .map(|index| {
                let sample = sound.get(from + index).copied().unwrap_or(0.0);
                let weight = 0.5 - 0.5 * (2.0 * std::f64::consts::PI * index as f64 / size as f64).cos();
                Complex::new(sample * weight, 0.0)
            })
            .collect();
        fft.process(&mut buffer);
        buffer[..size / 2].iter().map(|c| c.norm()).collect()
    }
}

/// The magnitude between bins, by a straight line between the two bins around it.
pub fn magnitude_at(spectrum: &[f64], position: f64) -> f64 {
    let below = position.floor();
    if below >= 0.0 && (below as usize) + 1 < spectrum.len() {
        let low = spectrum[below as usize];
        low + (position - below) * (spectrum[below as usize + 1] - low)
    } else {
        0.0
    }
}

/// A peak's position between bins and its level in dB, from a parabola through the log magnitudes around it.
pub fn refine(spectrum: &[f64], peak: usize) -> (f64, f64) {
    let (left, top, right) = (db(spectrum[peak - 1]), db(spectrum[peak]), db(spectrum[peak + 1]));
    let curve = left - 2.0 * top + right;
    if curve < 0.0 {
        let shift = 0.5 * (left - right) / curve;
        (peak as f64 + shift, top - 0.25 * (left - right) * shift)
    } else {
        (peak as f64, top)
    }
}

/// The seconds a level takes to fade 60 dB, from a straight line through the levels above `above`, or None when it does not fade.
pub fn fade(times: &[f64], track: &[f64], above: f64) -> Option<f64> {
    let points: Vec<(f64, f64)> = times.iter().zip(track).filter(|(_, l)| **l > above).map(|(t, l)| (*t, *l)).collect();
    if points.len() > 3 {
        let slope = slope(&points);
        if slope < 0.0 { Some(-60.0 / slope) } else { None }
    } else {
        None
    }
}

/// The slope of the straight line that best fits the points.
pub fn slope(points: &[(f64, f64)]) -> f64 {
    let count = points.len() as f64;
    let mean_x = points.iter().map(|p| p.0).sum::<f64>() / count;
    let mean_y = points.iter().map(|p| p.1).sum::<f64>() / count;
    let covariance: f64 = points.iter().map(|(x, y)| (x - mean_x) * (y - mean_y)).sum();
    let variance: f64 = points.iter().map(|(x, _)| (x - mean_x).powi(2)).sum();
    covariance / variance
}

/// The sample each sound starts at: a 5 ms level within 30 dB of the loudest, and 20 dB above the quietest of the 40 before it, at least `gap` seconds after the start before it.
pub fn onsets(samples: &[f64], rate: f64, gap: f64) -> Vec<usize> {
    let hop = (rate * ONSET_HOP).round() as usize;
    let levels: Vec<f64> = samples.chunks(hop).map(|chunk| (chunk.iter().map(|x| x * x).sum::<f64>() / hop as f64).sqrt()).collect();
    let loudest = levels.iter().cloned().fold(0.0f64, f64::max);
    if loudest < 1.0e-5 {
        return vec![];
    }
    let mut dbs = vec![-120.0; ONSET_WINDOW];
    dbs.extend(levels.iter().map(|level| db(level / loudest)));
    let frames = gap / ONSET_HOP;
    let mut found: Vec<usize> = vec![];
    for frame in ONSET_WINDOW..dbs.len() {
        let level = dbs[frame];
        let quietest = dbs[frame - ONSET_WINDOW..frame].iter().cloned().fold(f64::INFINITY, f64::min);
        let rises = level > -30.0 && level - quietest > 20.0;
        if rises && found.last().is_none_or(|last| (frame - last) as f64 > frames) {
            found.push(frame);
        }
    }
    found.into_iter().map(|frame| (frame - ONSET_WINDOW) * hop).collect()
}

/// A fourth-order Butterworth high-pass, run forward and then backward so it shifts nothing in time.
pub fn high_pass(samples: &[f64], rate: f64, hz: f64) -> Vec<f64> {
    both_ways(samples, |s| biquad(&biquad(s, rate, hz, 0.5412, true), rate, hz, 1.3066, true))
}

/// A fourth-order Butterworth low-pass, run forward and then backward so it shifts nothing in time.
pub fn low_pass(samples: &[f64], rate: f64, hz: f64) -> Vec<f64> {
    both_ways(samples, |s| biquad(&biquad(s, rate, hz, 0.5412, false), rate, hz, 1.3066, false))
}

fn both_ways(samples: &[f64], pass: impl Fn(&[f64]) -> Vec<f64>) -> Vec<f64> {
    let mut once = pass(samples);
    once.reverse();
    let mut twice = pass(&once);
    twice.reverse();
    twice
}

/// What the high-pass, run forward and backward, takes from a frequency, in dB.
pub fn filter_loss(freq: f64, cutoff: f64) -> f64 {
    20.0 * (1.0 + (cutoff / freq).powi(8)).log10()
}

// Robert Bristow-Johnson's high-pass and low-pass biquads.
fn biquad(samples: &[f64], rate: f64, hz: f64, quality: f64, high: bool) -> Vec<f64> {
    let angle = 2.0 * std::f64::consts::PI * hz / rate;
    let alpha = angle.sin() / (2.0 * quality);
    let cos = angle.cos();
    let scale = 1.0 + alpha;
    let (outer, middle) = if high { ((1.0 + cos) / 2.0 / scale, -(1.0 + cos) / scale) } else { ((1.0 - cos) / 2.0 / scale, (1.0 - cos) / scale) };
    let back1 = -2.0 * cos / scale;
    let back2 = (1.0 - alpha) / scale;
    let (mut in1, mut in2, mut out1, mut out2) = (0.0, 0.0, 0.0, 0.0);
    samples
        .iter()
        .map(|&input| {
            let output = outer * input + middle * in1 + outer * in2 - back1 * out1 - back2 * out2;
            (in2, in1, out2, out1) = (in1, input, out1, output);
            output
        })
        .collect()
}
