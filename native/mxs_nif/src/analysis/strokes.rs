//! Strokes that run into one another, for `Mx.Measure.Strokes`: where each stroke lies, its pitch every 4 ms, and its harmonics and noise every 8 ms from a least-squares fit.
//! Sums follow the order the Elixir measuring took, so the figures come out the same.

use super::{median, parallel};
use rustler::NifMap;
use std::f64::consts::PI;

const HOP: f64 = 0.004;
const STEP: usize = 2;
const PITCH_WINDOW: f64 = 0.02;
const LOWEST: i64 = 150;
const HIGHEST: i64 = 1800;
const SURE: f64 = 0.15;
const DOUBT: f64 = 0.25;
const OCTAVE_ABOVE: f64 = 480.0;
const OCTAVE_UNDER: f64 = -22.0;
const LEVEL_WINDOW: f64 = 0.012;
const TONE_WINDOW: f64 = 0.025;
const FIT_WINDOW: f64 = 0.014;
const FITTED: usize = 20;
const KEPT: usize = 16;
const SEARCH: f64 = 0.03;
const TOP: f64 = 0.45;
const AROUND: usize = 4;
const COVERED: f64 = 0.3;
const ENVELOPE_WINDOW: f64 = 0.008;
const ENVELOPE_HOP: f64 = 0.002;
const DIP: f64 = 7.0;
const APART: i64 = 20;
const HEARD: f64 = -22.0;
const TRIM: f64 = 30.0;
const SHORTEST: f64 = 0.04;
const VOICED: usize = 5;
const MARGIN: f64 = 0.002;
const JUMP: f64 = 250.0;
const RING: f64 = 0.25;
const BEFORE_NEXT: f64 = 0.006;
const RUNG: f64 = -56.0;
const NOISE_UNDER: f64 = -15.0;
const MOST: f64 = 4.0;
const FLOOR: i64 = -66;
const SILENT: i64 = -127;

#[derive(NifMap, Clone)]
pub struct Stroke {
    pub from: f64,
    pub to: f64,
    pub level: f64,
    pub note: f64,
    pub start: f64,
}

#[derive(NifMap)]
pub struct Tracks {
    pub note: f64,
    pub body: usize,
    pub scoop: f64,
    pub ends: f64,
    pub cents: Vec<i64>,
    pub levels: Vec<Vec<i64>>,
}

#[derive(Clone, Copy)]
struct Frame {
    at: usize,
    hz: Option<f64>,
    level: f64,
}

/// A recording's sound and its pitch every 4 ms, kept for its strokes' tracks.
pub struct Recording {
    rate: f64,
    sound: Vec<f64>,
    frames: Vec<Frame>,
    pub strokes: Vec<Stroke>,
}

fn note(hz: f64) -> f64 {
    69.0 + 12.0 * (hz / 440.0).log2()
}

fn cents(hz: f64, against: f64) -> f64 {
    1200.0 * (hz / against).log2()
}

// Elixir's dot added from the last pair back.
fn dot(ones: &[f64], others: &[f64]) -> f64 {
    ones.iter().zip(others).rev().fold(0.0, |sum, (one, other)| one * other + sum)
}

fn hann(size: usize) -> Vec<f64> {
    (0..size).map(|at| 0.5 - 0.5 * (2.0 * PI * at as f64 / (size - 1) as f64).cos()).collect()
}

fn slice(sound: &[f64], from: i64, size: usize) -> Option<&[f64]> {
    (from >= 0 && from as usize + size <= sound.len()).then(|| &sound[from as usize..from as usize + size])
}

/// Finds the strokes of a sound and follows its pitch.
pub fn strokes(sound: Vec<f64>, rate: f64) -> Recording {
    let frames = frames(&sound, rate);
    let strokes = segments(&sound, rate)
        .into_iter()
        .filter_map(|(from, to, level)| {
            let pitches: Vec<f64> = frames.iter().filter(|f| f.at as f64 / rate >= from && f.at as f64 / rate <= to).filter_map(|f| f.hz).collect();
            (pitches.len() >= VOICED).then(|| {
                let settled = median(&pitches[pitches.len() / 2..]);
                let first = median(&pitches[..3]);
                Stroke { from, to, level, note: note(settled), start: cents(first, settled) }
            })
        })
        .collect();
    Recording { rate, sound, frames, strokes }
}

fn frames(sound: &[f64], rate: f64) -> Vec<Frame> {
    let whole = rate as i64;
    let hop = (HOP * rate).trunc() as usize;
    let window = (PITCH_WINDOW * rate).trunc() as usize;
    let lags = (whole / LOWEST) as usize;
    let tone = (TONE_WINDOW * rate).trunc() as usize;
    let last = sound.len() as i64 - window as i64 - lags as i64;
    let starts: Vec<usize> = if last >= 1 { (0..last as usize).step_by(hop).collect() } else { vec![] };
    let around_window = hann(tone);
    parallel(&starts, |&from| {
        let at = from + window / 2;
        let frame = &sound[from..from + window + lags];
        let around = slice(sound, at as i64 - (tone / 2) as i64, tone);
        let hz = around.and_then(|around| pitch(frame, around, &around_window, window, lags, rate));
        Frame { at, hz, level: level(sound, at, rate) }
    })
}

fn level(sound: &[f64], at: usize, rate: f64) -> f64 {
    let half = (LEVEL_WINDOW * rate).trunc() as usize / 2;
    let from = at.saturating_sub(half);
    let heard = &sound[from..(at + half).min(sound.len())];
    (dot(heard, heard) / heard.len() as f64 + 1.0e-16).sqrt()
}

fn pitch(frame: &[f64], around: &[f64], window_weights: &[f64], window: usize, lags: usize, rate: f64) -> Option<f64> {
    let shortest = (rate as i64 / HIGHEST) as usize;
    let (lag, doubt) = yin(frame, window, lags, shortest);
    let hz = rate / lag;
    if doubt > DOUBT {
        None
    } else if hz > OCTAVE_ABOVE && tone(around, window_weights, hz / 2.0, rate) > tone(around, window_weights, hz, rate) * 10f64.powf(OCTAVE_UNDER / 20.0) {
        voiced(around, window_weights, hz / 2.0, rate)
    } else {
        voiced(around, window_weights, hz, rate)
    }
}

fn voiced(around: &[f64], weights: &[f64], hz: f64, rate: f64) -> Option<f64> {
    (tone(around, weights, hz, rate) > 0.0).then_some(hz)
}

// The amplitude of a sine at `hz` in the sound, or within 1% of it.
fn tone(around: &[f64], weights: &[f64], hz: f64, rate: f64) -> f64 {
    let heard: Vec<f64> = around.iter().zip(weights).map(|(s, w)| s * w).collect();
    let strongest = [-0.01, 0.0, 0.01]
        .iter()
        .map(|off| {
            let turn = 2.0 * PI * hz * (1.0 + off) / rate;
            let (mut real, mut imaginary) = (0.0, 0.0);
            for (at, sample) in heard.iter().enumerate() {
                real += sample * (turn * at as f64).cos();
                imaginary += sample * (turn * at as f64).sin();
            }
            (real * real + imaginary * imaginary).sqrt()
        })
        .fold(f64::MIN, f64::max);
    strongest * 2.0 / weights.iter().sum::<f64>()
}

// The lag at which the frame best repeats, by the YIN method, and its doubt there.
fn yin(frame: &[f64], window: usize, lags: usize, shortest: usize) -> (f64, f64) {
    let held = &frame[..window];
    let mut doubts = vec![1.0];
    let mut sum = 0.0;
    for lag in 1..=lags {
        let shifted = &frame[lag..];
        let difference = held.iter().zip(shifted).fold(0.0, |total, (one, other)| total + (one - other) * (one - other));
        doubts.push(difference * lag as f64 / (sum + difference).max(1.0e-12));
        sum += difference;
    }
    let searched = super::inferred(shortest as i64, lags as i64 - 1);
    let lag = searched
        .iter()
        .map(|l| *l as usize)
        .find(|&lag| doubts[lag] < SURE && doubts[lag] <= doubts[lag + 1])
        .unwrap_or_else(|| {
            let mut best = searched[0] as usize;
            for &l in &searched {
                if doubts[l as usize] < doubts[best] {
                    best = l as usize;
                }
            }
            best
        });
    (lag as f64 + vertex(doubts[lag - 1], doubts[lag], doubts[lag + 1]), doubts[lag])
}

fn vertex(before: f64, at: f64, later: f64) -> f64 {
    let bend = before - 2.0 * at + later;
    if bend.abs() > 1.0e-12 { 0.5 * (before - later) / bend } else { 0.0 }
}

// The stretches between dips of the level that hold a stroke, as their seconds and loudest level.
fn segments(sound: &[f64], rate: f64) -> Vec<(f64, f64, f64)> {
    let size = (ENVELOPE_WINDOW * rate).trunc() as usize;
    let hop = (ENVELOPE_HOP * rate).trunc() as usize;
    let count = (sound.len() as i64 - size as i64).div_euclid(hop as i64).max(0) as usize;
    let levels: Vec<f64> = (0..count)
        .map(|frame| {
            let heard = &sound[frame * hop..frame * hop + size];
            (dot(heard, heard) / size as f64).sqrt()
        })
        .collect();
    let loudest = levels.iter().cloned().fold(0.0, f64::max);
    if loudest < 1.0e-5 {
        return vec![];
    }
    let smooth = smooth(&levels.iter().map(|l| 20.0 * (l / loudest + 1.0e-6).log10()).collect::<Vec<_>>());
    let mut bounds = vec![0];
    bounds.extend(dips(&smooth));
    bounds.push(smooth.len() - 1);
    let seconds = |frame: usize| (frame as f64 * hop as f64 + size as f64 / 2.0) / rate;
    bounds
        .windows(2)
        .filter(|pair| pair[1] > pair[0])
        .filter_map(|pair| {
            let between = pair[0]..pair[1];
            let peak = between.clone().map(|f| smooth[f]).fold(f64::MIN, f64::max);
            if peak < HEARD {
                return None;
            }
            let inside: Vec<usize> = between.filter(|&f| smooth[f] > peak - TRIM).collect();
            let (from, to) = (seconds(inside[0]), seconds(inside[inside.len() - 1]));
            (to - from >= SHORTEST).then_some((from, to, peak))
        })
        .collect()
}

fn smooth(levels: &[f64]) -> Vec<f64> {
    let mut padded = vec![0.0, 0.0];
    padded.extend_from_slice(levels);
    padded.extend([0.0, 0.0]);
    padded.windows(5).map(|w| (0.25 * w[0] + 0.75 * w[1] + w[2] + 0.75 * w[3] + 0.25 * w[4]) / 3.0).collect()
}

// The frames where the level dips at least 7 dB under what surrounds it, 20 frames or more apart.
fn dips(smooth: &[f64]) -> Vec<usize> {
    let last = smooth.len() as i64 - 1;
    let mut lows: Vec<usize> = (1..last.max(1))
        .map(|f| f as usize)
        .filter(|&f| smooth[f] < smooth[f - 1] && smooth[f] <= smooth[f + 1])
        .collect();
    lows.sort_by(|a, b| smooth[*a].partial_cmp(&smooth[*b]).unwrap());
    let mut kept: Vec<usize> = vec![];
    for frame in lows {
        if kept.iter().all(|&k| (k as i64 - frame as i64).abs() >= APART) {
            kept.insert(0, frame);
        }
    }
    let mut dips: Vec<usize> = kept
        .into_iter()
        .filter(|&frame| {
            let level = smooth[frame];
            rise(smooth, frame, -1, level).min(rise(smooth, frame, 1, level)) - level >= DIP
        })
        .collect();
    dips.sort();
    dips
}

// The highest level on one side of a dip before the level falls under the dip's.
fn rise(smooth: &[f64], frame: usize, way: i64, level: f64) -> f64 {
    let mut highest: Option<f64> = None;
    let mut at = frame as i64;
    loop {
        let next = at + way;
        if next < 0 || next >= smooth.len() as i64 || smooth[next as usize] < level {
            return highest.unwrap_or(level);
        }
        highest = Some(highest.unwrap_or(level).max(smooth[next as usize]));
        at = next;
    }
}

struct Fit {
    at: usize,
    hz: Option<f64>,
    harmonics: Vec<f64>,
    wave: Option<Vec<f64>>,
    level: f64,
}

struct Fitted {
    hz: Option<f64>,
    harmonics: Vec<f64>,
    level: f64,
    noise: f64,
}

#[derive(Clone)]
struct Clean {
    level: f64,
    noise: f64,
    hz: f64,
    harmonics: Vec<f64>,
}

impl Recording {
    /// The tracks of the stroke at `index`, or None when it has no pitch.
    pub fn tracks(&self, index: usize, alone: bool, ignore: Option<(f64, f64)>) -> Option<Tracks> {
        let stroke = self.strokes.get(index)?;
        let (body, ring) = self.span(stroke, self.strokes.get(index + 1), alone);
        if body.is_empty() {
            return None;
        }
        let indices: Vec<usize> = body.iter().chain(&ring).cloned().collect();
        let fitted = self.fit_all(&indices);
        if fitted.iter().any(|f| f.hz.is_some()) { Some(steps(clean(&fitted, body.len(), ignore), body.len())) } else { None }
    }

    // The frames of a stroke, and those of the ring after it when it was played alone.
    fn span(&self, stroke: &Stroke, following: Option<&Stroke>, alone: bool) -> (Vec<usize>, Vec<usize>) {
        let count = self.frames.len();
        let seconds = |index: usize| self.frames[index].at as f64 / self.rate;
        let body: Vec<usize> = (0..count).filter(|&i| seconds(i) >= stroke.from - MARGIN && seconds(i) <= stroke.to + MARGIN).collect();
        if alone && !body.is_empty() {
            let next = following.map_or(seconds(count - 1), |f| f.from - BEFORE_NEXT);
            let stop = next.min(stroke.to + RING);
            let loudest = body.iter().map(|&i| self.frames[i].level).fold(f64::MIN, f64::max);
            let quiet = loudest * 10f64.powf(RUNG / 20.0);
            let ring = (body[body.len() - 1] + 1..count).take_while(|&i| seconds(i) <= stop && self.frames[i].level >= quiet).collect();
            (body, ring)
        } else {
            (body, vec![])
        }
    }

    fn fit_all(&self, indices: &[usize]) -> Vec<Fitted> {
        let size = (FIT_WINDOW * self.rate).trunc() as usize | 1;
        let half = size / 2;
        let window = hann(size);
        let (first, last) = (indices[0], indices[indices.len() - 1]);
        let fitted: Vec<usize> = (first.saturating_sub(AROUND)..=(last + AROUND).min(self.frames.len() - 1)).collect();
        let fits = parallel(&fitted, |&index| {
            let frame = self.frames[index];
            let heard = frame.hz.and_then(|_| slice(&self.sound, frame.at as i64 - half as i64, size));
            fit(frame, heard, &window, self.rate)
        });
        let modelled = Modelled::new(&fits, &window, half);
        fits.iter()
            .zip(&fitted)
            .filter(|(_, index)| (first..=last).contains(*index))
            .map(|(fit, _)| Fitted { hz: fit.hz, harmonics: fit.harmonics.clone(), level: fit.level, noise: self.noise(&modelled, fit.at) })
            .collect()
    }

    // The level of what the fits leave of the sound around a frame.
    fn noise(&self, modelled: &Modelled, at: usize) -> f64 {
        let half = (LEVEL_WINDOW * self.rate).trunc() as usize / 2;
        let left: Vec<f64> = (at.saturating_sub(half)..(at + half).min(self.sound.len()))
            .map(|sample| match modelled.get(sample) {
                Some((values, weights)) if weights > COVERED => self.sound[sample] - values / weights,
                _ => self.sound[sample],
            })
            .collect();
        (dot(&left, &left) / left.len() as f64 + 1.0e-16).sqrt()
    }
}

// The fits that cover each sample, summed, with the sum of their windows.
struct Modelled {
    first: i64,
    sums: Vec<Option<(f64, f64)>>,
}

impl Modelled {
    fn new(fits: &[Fit], window: &[f64], half: usize) -> Self {
        let covering: Vec<(&Fit, &Vec<f64>)> = fits.iter().filter_map(|f| f.wave.as_ref().map(|w| (f, w))).collect();
        let Some(first) = covering.iter().map(|(f, _)| f.at as i64 - half as i64).min() else { return Modelled { first: 0, sums: vec![] } };
        let last = covering.iter().map(|(f, _)| f.at as i64 + half as i64).max().unwrap();
        let mut sums = vec![None; (last - first + 1) as usize];
        for (fit, wave) in covering {
            for (offset, (value, weight)) in wave.iter().zip(window).enumerate() {
                let slot = &mut sums[(fit.at as i64 - half as i64 + offset as i64 - first) as usize];
                *slot = Some(match *slot {
                    Some((values, weights)) => (values + value, weights + weight),
                    None => (*value, *weight),
                });
            }
        }
        Modelled { first, sums }
    }

    fn get(&self, sample: usize) -> Option<(f64, f64)> {
        let at = sample as i64 - self.first;
        if at < 0 { None } else { self.sums.get(at as usize).copied().flatten() }
    }
}

// The harmonics that best fit the sound around a frame, at the pitch within 3% of the one followed that leaves least.
fn fit(frame: Frame, heard: Option<&[f64]>, window: &[f64], rate: f64) -> Fit {
    let (Some(followed), Some(heard)) = (frame.hz, heard) else {
        return Fit { at: frame.at, hz: None, harmonics: vec![], wave: None, level: frame.level };
    };
    let weighted: Vec<f64> = heard.iter().zip(window).map(|(s, w)| s * w).collect();
    let mut best: Option<(f64, f64, Vec<f64>, Vec<f64>, Vec<Vec<f64>>)> = None;
    for step in -6..=6 {
        let hz = followed * (1.0 + step as f64 * SEARCH / 6.0);
        let (left, harmonics, found, columns) = fit_at(&weighted, window, hz, rate);
        if best.as_ref().is_none_or(|b| left < b.0) {
            best = Some((left, hz, harmonics, found, columns));
        }
    }
    let (_, hz, harmonics, found, columns) = best.unwrap();
    let wave = (0..window.len()).map(|at| found.iter().zip(&columns).fold(0.0, |sum, (level, column)| sum + column[at] * level)).collect();
    Fit { at: frame.at, hz: Some(hz), harmonics, wave: Some(wave), level: frame.level }
}

fn fit_at(weighted: &[f64], window: &[f64], hz: f64, rate: f64) -> (f64, Vec<f64>, Vec<f64>, Vec<Vec<f64>>) {
    let count = (FITTED as i64).min((TOP * rate / hz).ceil() as i64 - 1).max(0) as usize;
    let half = (window.len() / 2) as f64;
    let mut columns: Vec<Vec<f64>> = vec![];
    for wave in [f64::cos, f64::sin] {
        for harmonic in 1..=count {
            let turn = 2.0 * PI * harmonic as f64 * hz / rate;
            columns.push(window.iter().enumerate().map(|(at, weight)| weight * wave(turn * (at as f64 - half))).collect());
        }
    }
    let projected: Vec<f64> = columns.iter().map(|column| dot(column, weighted)).collect();
    let all = columns.len();
    let mut gram = vec![vec![0.0; all]; all];
    for row in 0..all {
        for other in row..all {
            let value = dot(&columns[row], &columns[other]);
            gram[row][other] = value;
            gram[other][row] = value;
        }
    }
    let rows: Vec<Vec<f64>> = (0..all).map(|row| gram[row].iter().cloned().chain([projected[row]]).collect()).collect();
    let found = solve(rows);
    let mut harmonics: Vec<f64> = (0..count).map(|h| (found[h] * found[h] + found[count + h] * found[count + h]).sqrt()).collect();
    harmonics.resize(FITTED, 0.0);
    (-dot(&found, &projected), harmonics, found, columns)
}

// Gaussian elimination, each row its coefficients and then its target, the row with the largest lead first at each step.
fn solve(mut rows: Vec<Vec<f64>>) -> Vec<f64> {
    let mut leads: Vec<Vec<f64>> = vec![];
    while !rows.is_empty() {
        rows.sort_by(|a, b| (-a[0].abs()).partial_cmp(&-b[0].abs()).unwrap());
        let lead = rows.remove(0);
        rows = rows
            .into_iter()
            .map(|row| {
                let factor = row[0] / lead[0];
                row[1..].iter().zip(&lead[1..]).map(|(value, other)| value - factor * other).collect()
            })
            .collect();
        leads.push(lead);
    }
    let mut solved: Vec<f64> = vec![];
    for lead in leads.iter().rev() {
        let tail = &lead[1..];
        let (coefficients, target) = tail.split_at(tail.len() - 1);
        solved.insert(0, (target[0] - dot(coefficients, &solved)) / lead[0]);
    }
    solved
}

fn sounding(harmonics: &[f64]) -> f64 {
    (dot(harmonics, harmonics) / 2.0).sqrt()
}

// The frames of one stroke as a pitch, harmonics and noise at every frame, against its loudest frame.
fn clean(fitted: &[Fitted], body: usize, ignore: Option<(f64, f64)>) -> (f64, Vec<(f64, Vec<f64>, f64)>) {
    let count = fitted.len();
    let kept = same_stroke(&fitted.iter().map(|f| f.hz).collect::<Vec<_>>(), body);
    let known: Vec<usize> = (0..count).filter(|i| kept.contains(i)).collect();
    let (first, last) = (known[0], known[known.len() - 1]);
    let pitches = fill(&known.iter().map(|&i| (i, fitted[i].hz.unwrap())).collect::<Vec<_>>(), count);
    let harmonics: Vec<Vec<f64>> = (0..KEPT)
        .map(|h| fill(&known.iter().map(|&i| (i, fitted[i].harmonics[h].max(1.0e-7).ln())).collect::<Vec<_>>(), count).into_iter().map(f64::exp).collect())
        .collect();
    let frames: Vec<Clean> = (0..count)
        .map(|index| {
            let frame = Clean { level: fitted[index].level, noise: fitted[index].noise, hz: pitches[index], harmonics: (0..KEPT).map(|h| harmonics[h][index]).collect() };
            let frame = if index < first || index > last { outside(frame) } else { frame };
            without(toned(frame), ignore)
        })
        .collect();
    let settled = settled(&frames);
    let loudest = frames.iter().map(|f| sounding(&f.harmonics)).fold(f64::MIN, f64::max);
    let cleaned = frames.iter().map(|f| (cents(f.hz, settled), f.harmonics.iter().map(|h| h / loudest).collect(), f.noise / loudest)).collect();
    (settled, cleaned)
}

// The frames that have a pitch, out from the middle of the stroke until the pitch jumps to a neighbouring stroke's.
fn same_stroke(pitches: &[Option<f64>], body: usize) -> Vec<usize> {
    let voiced: Vec<usize> = (0..pitches.len()).filter(|&i| pitches[i].is_some()).collect();
    let target = (body / 2) as i64;
    let middle = super::first_max(voiced.iter().cloned(), |&i| -((i as i64 - target).abs() as f64)).unwrap();
    let later: Vec<usize> = voiced.iter().cloned().filter(|&i| i > middle).collect();
    let earlier: Vec<usize> = voiced.iter().rev().cloned().filter(|&i| i < middle).collect();
    let mut kept = vec![middle];
    kept.extend(walk(&later, middle, pitches));
    kept.extend(walk(&earlier, middle, pitches));
    kept
}

fn walk(indices: &[usize], mut last: usize, pitches: &[Option<f64>]) -> Vec<usize> {
    let mut kept = vec![];
    for &index in indices {
        let moved = cents(pitches[index].unwrap(), pitches[last].unwrap()).abs();
        if moved > JUMP * 1f64.max((index as f64 - last as f64).abs()) {
            break;
        }
        kept.push(index);
        last = index;
    }
    kept
}

fn fill(known: &[(usize, f64)], count: usize) -> Vec<f64> {
    (0..count).map(|at| between(known, at)).collect()
}

fn between(known: &[(usize, f64)], at: usize) -> f64 {
    for (position, &(low, one)) in known.iter().enumerate() {
        if at <= low {
            return one;
        }
        match known.get(position + 1) {
            Some(&(high, other)) if at <= high => return one + (other - one) * (at - low) as f64 / (high - low) as f64,
            None => return one,
            _ => {}
        }
    }
    unreachable!()
}

// Past the first and last frame with a pitch, the harmonics are the nearest ones, no louder than the sound.
fn outside(mut frame: Clean) -> Clean {
    let gain = 1f64.min(frame.level / sounding(&frame.harmonics).max(1.0e-9));
    frame.harmonics.iter_mut().for_each(|h| *h *= gain);
    frame
}

// The noise is kept 15 dB under the frame's level, and the harmonics raised to the rest of it, by 12 dB at most.
fn toned(mut frame: Clean) -> Clean {
    frame.noise = frame.noise.min(frame.level * 10f64.powf(NOISE_UNDER / 20.0));
    let rest = (frame.level * frame.level - frame.noise * frame.noise).max(0.0).sqrt();
    let gain = 1f64.max((rest / sounding(&frame.harmonics).max(1.0e-9)).min(MOST));
    frame.harmonics.iter_mut().for_each(|h| *h *= gain);
    frame
}

fn without(mut frame: Clean, ignore: Option<(f64, f64)>) -> Clean {
    if let Some((low, high)) = ignore {
        for (index, level) in frame.harmonics.iter_mut().enumerate() {
            let hz = frame.hz * (index + 1) as f64;
            if hz > low && hz < high {
                *level = 0.0;
            }
        }
    }
    frame
}

// The pitch that half of the stroke's energy lies under.
fn settled(frames: &[Clean]) -> f64 {
    let mut weighed: Vec<(f64, f64)> = frames.iter().map(|f| (f.hz, sounding(&f.harmonics).powi(2))).collect();
    weighed.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let half = weighed.iter().fold(0.0, |sum, (_, w)| sum + w) / 2.0;
    let mut under = 0.0;
    for (hz, weight) in weighed {
        if under + weight >= half {
            return hz;
        }
        under += weight;
    }
    under
}

fn steps((hz, frames): (f64, Vec<(f64, Vec<f64>, f64)>), body: usize) -> Tracks {
    let mean_cents = |frames: &[(f64, Vec<f64>, f64)]| frames.iter().fold(0.0, |sum, f| sum + f.0) / frames.len() as f64;
    let early = mean_cents(&frames[..2.min(frames.len())]);
    let from = body.saturating_sub(2).min(frames.len());
    let late = mean_cents(&frames[from..(from + 2).min(frames.len())]);
    let mean_square = |values: &[f64]| (dot(values, values) / values.len() as f64).sqrt();
    let steps: Vec<(i64, Vec<f64>, f64)> = frames
        .chunks_exact(STEP)
        .map(|pair| {
            let cents = (pair.iter().fold(0.0, |sum, f| sum + f.0) / STEP as f64).round() as i64;
            let harmonics = (0..KEPT).map(|h| mean_square(&pair.iter().map(|f| f.1[h]).collect::<Vec<_>>())).collect();
            (cents, harmonics, mean_square(&pair.iter().map(|f| f.2).collect::<Vec<_>>()))
        })
        .collect();
    let loudest = steps.iter().map(|s| sounding(&s.1)).fold(f64::MIN, f64::max);
    let body = body / STEP;
    let levels = steps
        .iter()
        .enumerate()
        .map(|(index, (_, harmonics, noise))| {
            let noise = if index < body { *noise } else { 0.0 };
            harmonics.iter().chain([&noise]).map(|level| quantise(level / loudest)).collect()
        })
        .collect();
    Tracks { note: note(hz), body, scoop: -early / 100.0, ends: late / 100.0, cents: steps.iter().map(|s| s.0).collect(), levels }
}

fn quantise(level: f64) -> i64 {
    let db = (20.0 * level.max(1.0e-7).log10()).round() as i64;
    if db < FLOOR { SILENT } else { db.min(0) }
}
