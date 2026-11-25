//! A hummed recording's pitch, for `Mx.Hum`: filtered below 7 kHz, resampled to 16 kHz, and followed with pYIN every 10 ms, kept only where the voice is loud enough.

use super::low_pass;

const RATE: f64 = 16_000.0;
const HOP: usize = 160;
const WINDOW: usize = 480;
const LOWEST_HZ: f64 = 60.0;
const SEARCH_HZ: f64 = 50.0;
const HIGHEST_HZ: f64 = 2500.0;
const FRAME: usize = 1024;
const FLOOR_DB: f64 = -35.0;
const DIP_DB: f64 = -20.0;
const AROUND: usize = 20;

/// The pitch of each 10 ms frame as a fractional MIDI note, or None where it has none.
pub fn pitches(samples: &[f64], rate: f64) -> Vec<Option<f64>> {
    let sound = resample(samples, rate);
    let longest = (RATE as usize) / (LOWEST_HZ as usize);
    let end = sound.len() as i64 - WINDOW as i64 - longest as i64 - 1;
    let starts: Vec<usize> = if end >= 0 {
        (0..=end as usize).step_by(HOP).collect()
    } else {
        vec![]
    };
    let levels: Vec<f64> = starts
        .iter()
        .map(|start| level(&sound, start + (WINDOW - HOP) / 2))
        .collect();
    let loudest = levels.iter().cloned().fold(0.0, f64::max);
    let floor = loudest * 10f64.powf(FLOOR_DB / 20.0);
    let around = nearby_peaks(&levels);
    // pYIN centres frame i on sample i * hop, so dropping half a window centres it on frame i's level.
    // A frame with no clear period lands on pYIN's longest period, so it searches below the lowest pitch kept.
    let mut executor = pyin::PYINExecutor::new(
        SEARCH_HZ,
        HIGHEST_HZ,
        RATE as u32,
        FRAME,
        None,
        Some(HOP),
        None,
    );
    let (_, hz, voiced, _) = executor.pyin(
        &sound[(WINDOW / 2).min(sound.len())..],
        f64::NAN,
        pyin::Framing::Center(pyin::PadMode::Constant(0.0)),
    );
    levels
        .iter()
        .zip(&around)
        .zip(hz.iter().zip(voiced.iter()))
        .map(|((&level, &peak), (&hz, &voiced))| {
            (voiced
                && hz >= LOWEST_HZ
                && level > 0.0
                && level >= floor
                && level >= peak * 10f64.powf(DIP_DB / 20.0))
            .then(|| 69.0 + 12.0 * (hz / 440.0).log2())
        })
        .collect()
}

fn resample(samples: &[f64], rate: f64) -> Vec<f64> {
    let filtered = low_pass(samples, rate, 7000.0);
    if filtered.is_empty() {
        return vec![];
    }
    let count = ((filtered.len() - 1) as f64 * RATE / rate).floor() as usize;
    (0..=count)
        .map(|index| {
            let at = index as f64 * rate / RATE;
            let before = at.trunc() as usize;
            let after = (before + 1).min(filtered.len() - 1);
            let share = at - before as f64;
            filtered[before] * (1.0 - share) + filtered[after] * share
        })
        .collect()
}

fn level(sound: &[f64], start: usize) -> f64 {
    let sum = sound[start..start + HOP]
        .iter()
        .fold(0.0, |sum, sample| sample.powi(2) + sum);
    (sum / HOP as f64).sqrt()
}

fn nearby_peaks(levels: &[f64]) -> Vec<f64> {
    (0..levels.len())
        .map(|index| {
            levels[index.saturating_sub(AROUND)..=(index + AROUND).min(levels.len() - 1)]
                .iter()
                .cloned()
                .fold(f64::MIN, f64::max)
        })
        .collect()
}
