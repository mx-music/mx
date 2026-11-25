//! Notes plucked or struck, for `Mx.Measure`: each note's pitch, how far its harmonics are stretched sharp, and each harmonic's frequency, level as the note starts, and seconds to fade 60 dB.

use super::{
    Spectra, db, fade, filter_loss, first_max, high_pass, hz, inferred, magnitude_at, onsets,
    refine, slope,
};
use rustler::NifMap;

const FFT: usize = 16_384;
const FIRST: f64 = 0.02;
const HOP: f64 = 0.1;
const LONGEST: f64 = 4.0;
const HARMONICS: usize = 24;

#[derive(NifMap, Clone)]
pub struct Harmonic {
    pub number: u32,
    pub freq: f64,
    pub level: f64,
    pub fade: Option<f64>,
}

#[derive(NifMap)]
pub struct Note {
    pub note: i64,
    pub pitch: f64,
    pub stretch: f64,
    pub harmonics: Vec<Harmonic>,
}

fn longest(rate: f64) -> usize {
    ((FIRST + LONGEST) * rate).round() as usize + FFT
}

/// Each note of a sound whose first note is `first`, one after another a semitone apart.
pub fn notes(samples: &[f64], rate: f64, first: i64) -> Vec<Note> {
    let cutoff = hz(first as f64) * 0.75;
    let sound = high_pass(samples, rate, cutoff);
    let starts = onsets(&sound, rate, 2.0);
    let ends: Vec<usize> = starts
        .iter()
        .skip(1)
        .cloned()
        .chain([sound.len()])
        .collect();
    let mut spectra = Spectra::default();
    starts
        .iter()
        .zip(&ends)
        .enumerate()
        .filter_map(|(index, (&from, &to))| {
            let segment = &sound[from..to.min(from + longest(rate))];
            measure(segment, rate, first + index as i64, cutoff, &mut spectra)
        })
        .collect()
}

/// A sound that is one note from its first sample, or None when it is too short.
pub fn note(samples: &[f64], rate: f64, note: i64) -> Option<Note> {
    let cutoff = hz(note as f64) * 0.75;
    let sound = high_pass(samples, rate, cutoff);
    let segment = &sound[..sound.len().min(longest(rate))];
    measure(segment, rate, note, cutoff, &mut Spectra::default())
}

fn measure(
    sound: &[f64],
    rate: f64,
    guess: i64,
    cutoff: f64,
    spectra: &mut Spectra,
) -> Option<Note> {
    let last = ((sound.len() as f64 - FFT as f64) / rate).min(LONGEST);
    let frames = ((last - FIRST) / HOP).floor().max(-1.0) as i64;
    let times: Vec<f64> = (0..=frames)
        .map(|frame| FIRST + frame as f64 * HOP)
        .collect();
    if times.len() < 5 {
        return None;
    }
    let frames: Vec<Vec<f64>> = times
        .iter()
        .map(|time| spectra.take(sound, (time * rate).round() as usize, FFT))
        .collect();
    let bin = rate / FFT as f64;
    let f0 = pitch(&frames[0], hz(guess as f64), bin);
    let harmonics = harmonics(&frames, &times, f0, bin, rate, cutoff);
    Some(Note {
        note: (69.0 + 12.0 * (f0 / 440.0).log2()).round() as i64,
        pitch: f0,
        stretch: stretch(&harmonics, f0),
        harmonics,
    })
}

// The fundamental within 6% of the guess whose first six harmonics hold the most energy.
fn pitch(spectrum: &[f64], guess: f64, bin: f64) -> f64 {
    let steps = (guess * 0.12 / 0.05).round() as i64;
    let candidates = (0..=steps).map(|step| guess * 0.94 + step as f64 * 0.05);
    first_max(candidates, |freq| {
        (1..=6)
            .map(|number| magnitude_at(spectrum, freq * number as f64 / bin))
            .sum()
    })
    .unwrap()
}

// A harmonic less than 10 dB above the noise floor, or 80 dB below the loudest, is absent, and the next is looked for one step above where it should have been.
fn harmonics(
    frames: &[Vec<f64>],
    times: &[f64],
    f0: f64,
    bin: f64,
    rate: f64,
    cutoff: f64,
) -> Vec<Harmonic> {
    let floor = super::median(&frames[0].iter().map(|m| db(*m)).collect::<Vec<_>>());
    let top = 18_000f64.min(rate / 2.0 - f0);
    let mut rows: Vec<Harmonic> = vec![];
    let (mut before, mut last) = (0.0, f0);
    for number in 1..=HARMONICS {
        let target = if number == 1 { f0 } else { 2.0 * last - before };
        if target > top || (target <= last && number > 1) {
            break;
        }
        let (row, start) = harmonic(frames, times, number as u32, target, f0, bin, floor, cutoff);
        if number == 1 {
            rows.push(row);
            continue;
        }
        let loudest = rows.iter().map(|r| r.level).fold(start, f64::max);
        if start > floor + 10.0 && start > loudest - 80.0 {
            (before, last) = (last, row.freq);
            rows.push(row);
        } else {
            (before, last) = (last, target);
        }
    }
    rows
}

// The harmonic nearest the target, and its level in the first spectrum before the filter's loss is added back.
#[allow(clippy::too_many_arguments)]
fn harmonic(
    frames: &[Vec<f64>],
    times: &[f64],
    number: u32,
    target: f64,
    f0: f64,
    bin: f64,
    floor: f64,
    cutoff: f64,
) -> (Harmonic, f64) {
    let first = &frames[0];
    let bins: Vec<usize> = inferred(
        (((target - f0 / 4.0) / bin).ceil() as i64).max(1),
        ((target + f0 / 4.0) / bin).floor() as i64,
    )
    .into_iter()
    .map(|b| b as usize)
    .collect();
    let peak = first_max(bins.iter().cloned(), |at| first[*at]).unwrap();
    let (position, start) = refine(first, peak);
    let freq = position * bin;
    let track: Vec<f64> = frames
        .iter()
        .map(|spectrum| db(bins.iter().map(|at| spectrum[*at]).fold(f64::MIN, f64::max)))
        .collect();
    let fade = fade(times, &track, (track[0] - 40.0).max(floor + 10.0));
    let level = start + filter_loss(freq, cutoff);
    (
        Harmonic {
            number,
            freq,
            level,
            fade,
        },
        start,
    )
}

// How far the harmonics are stretched sharp: B, where harmonic n sits at n times the fundamental times the square root of 1 + B n².
fn stretch(harmonics: &[Harmonic], f0: f64) -> f64 {
    let points: Vec<(f64, f64)> = harmonics
        .iter()
        .skip(1)
        .take(11)
        .map(|h| {
            let n = h.number as f64;
            (n * n, (h.freq / (n * f0)).powi(2) - 1.0)
        })
        .collect();
    if points.len() > 2 {
        slope(&points)
    } else {
        0.0
    }
}
