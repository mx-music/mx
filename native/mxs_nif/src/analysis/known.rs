//! Notes with known partials, measured as `mix mx.fit --struck` measures a recording, for `mix mx.measure --known`: how far each measured level, frequency and strike is from the truth.

use super::partials::{self, HOP};
use super::{hz, parallel};
use rustler::NifMap;
use std::f64::consts::PI;

/// The rate the notes are made at.
pub(crate) const RATE: f64 = 44100.0;
/// The seconds of quiet before each note.
pub(crate) const BEFORE: f64 = 0.2;
/// The seconds measured, as for NSynth's notes.
const SECONDS: f64 = 2.9;
/// The level of the quiet the notes sit in, in dB of a sine's amplitude.
pub(crate) const QUIET: f64 = -100.0;
/// The gap in dB beyond which the refit tickets count a partial as off, over the first 20 ms or on average.
pub const LIMIT: f64 = 2.0;
/// The pitches each kind of note is made at: C2, C4 and C7.
pub const NOTES: [f64; 3] = [36.0, 60.0, 96.0];

/// The kinds of note, each naming what about a struck instrument it stands for.
pub const KINDS: [&str; 6] = ["slow", "short", "beating", "building", "noisy", "early"];

/// A partial as it is made: its frequency, and its level in dB at a time after the note starts.
pub(crate) struct Made {
    pub(crate) freq: f64,
    pub(crate) level: Box<dyn Fn(f64) -> f64 + Sync>,
}

/// A note as it is made: its partials, and a burst of white noise as a power in dB over the seconds it lasts.
pub(crate) struct Note {
    pub(crate) partials: Vec<Made>,
    noise: Option<(f64, f64)>,
}

/// How far the measuring is from one partial's truth.
#[derive(NifMap, Clone)]
pub struct Partial {
    pub freq: f64,
    pub found: bool,
    /// The peak over the first 20 ms after the strike the measuring finds, against the true peak over the first 20 ms after the true strike, in dB.
    pub first: f64,
    /// The mean gap over the note while the partial stands clear of the floor, in dB.
    pub mean: f64,
    pub cents: f64,
    /// Whether the first 20 ms and the average are beyond the limit.
    pub off: (bool, bool),
}

/// How far the measuring is from one note's truth.
#[derive(NifMap, Clone)]
pub struct Known {
    pub kind: String,
    pub note: f64,
    /// The measured strike against the true one, in ms.
    pub strike: f64,
    pub partials: Vec<Partial>,
    /// Every partial is found, and within the limit over the first 20 ms and on average.
    pub followed: bool,
}

fn falling(start: f64, per_second: f64) -> Box<dyn Fn(f64) -> f64 + Sync> {
    Box::new(move |t| start + per_second * t)
}

// A note of a kind at a pitch: a fundamental falling 20 dB a second unless the kind is about the fundamental, and the partial the kind is about.
pub(crate) fn made(kind: &str, note: f64) -> Note {
    let f0 = hz(note);
    let fundamental = || Made { freq: f0, level: falling(-6.0, -20.0) };
    match kind {
        // A partial that falls 60 dB over 3 seconds, alone.
        "slow" => Note { partials: vec![fundamental()], noise: None },
        // A partial that falls 30 dB in 25 ms, at the third harmonic.
        "short" => Note { partials: vec![fundamental(), Made { freq: 3.0 * f0, level: falling(-12.0, -1200.0) }], noise: None },
        // Two partials 20 Hz apart at the same level, near the second harmonic.
        "beating" => Note {
            partials: vec![fundamental(), Made { freq: 2.0 * f0, level: falling(-18.0, -20.0) }, Made { freq: 2.0 * f0 + 20.0, level: falling(-18.0, -20.0) }],
            noise: None,
        },
        // A fundamental that rises 40 dB over 40 ms, under a third harmonic that starts at once.
        "building" => Note {
            partials: vec![
                Made { freq: f0, level: Box::new(|t| if t < 0.04 { -46.0 + 1000.0 * t } else { -6.0 - 20.0 * (t - 0.04) }) },
                Made { freq: 3.0 * f0, level: falling(-18.0, -20.0) },
            ],
            noise: None,
        },
        // A third harmonic 30 dB under a burst of white noise that lasts 50 ms.
        "noisy" => Note { partials: vec![fundamental(), Made { freq: 3.0 * f0, level: falling(-30.0, -20.0) }], noise: Some((-30.0 - 3.0 + 30.0, 0.05)) },
        // A short partial at once, 24 dB under where the fundamental peaks, while the fundamental rises to come within 20 dB of its peak 30 ms later.
        "early" => Note {
            partials: vec![
                Made { freq: f0, level: Box::new(|t| if t < 0.05 { -60.0 + 1080.0 * t } else { -6.0 - 20.0 * (t - 0.05) }) },
                Made { freq: 3.0 * f0, level: falling(-30.0, -400.0) },
            ],
            noise: None,
        },
        _ => unreachable!("no kind of note named {kind}"),
    }
}

// The note's samples after BEFORE seconds of quiet, each partial rising over 1 ms.
pub(crate) fn sound(note: &Note) -> Vec<f64> {
    let count = ((BEFORE + SECONDS + 0.3) * RATE) as usize;
    let mut seed: u64 = 0x2545_f491_4f6c_dd1d;
    let mut white = move || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        (seed >> 11) as f64 / (1u64 << 53) as f64 * 2.0 - 1.0
    };
    // Uniform noise from -1 to 1 has a power of a third, and a sine of amplitude a has a power of a squared over two.
    let quiet = 10f64.powf(QUIET / 20.0) * (1.5f64).sqrt();
    (0..count)
        .map(|i| {
            let t = i as f64 / RATE - BEFORE;
            let floor = quiet * white();
            if t < 0.0 {
                return floor;
            }
            let rise = (t / 0.001).min(1.0);
            let sines: f64 = note.partials.iter().map(|p| 10f64.powf((p.level)(t) / 20.0) * (2.0 * PI * p.freq * t).sin()).sum();
            let burst = match note.noise {
                Some((power, seconds)) if t < seconds => (10f64.powf(power / 10.0) * 3.0).sqrt() * white(),
                _ => 0.0,
            };
            floor + rise * sines + burst
        })
        .collect()
}

/// Measures one kind of note at one pitch and compares the measuring with the truth.
pub fn known(kind: &str, note: f64) -> Known {
    let made = made(kind, note);
    let sound = sound(&made);
    let measured = partials::measure(&sound, RATE, note, SECONDS, false);
    let onset = BEFORE * RATE;
    let start = measured.spectra.struck() - partials::LEAD * RATE;
    // The time after the true onset that each frame's window is centred on.
    let times: Vec<f64> = (0..measured.spectra.frames.len()).map(|k| (start + k as f64 * HOP * RATE - onset) / RATE).collect();
    let tracks: Vec<&partials::Track> = measured.partials.iter().chain(&measured.left_out).collect();
    let partials = made
        .partials
        .iter()
        .map(|p| {
            let nearest = tracks.iter().filter(|t| (t.freq / p.freq - 1.0).abs() < 0.03).min_by(|a, b| (a.freq - p.freq).abs().total_cmp(&(b.freq - p.freq).abs()));
            let Some(track) = nearest else {
                return Partial { freq: p.freq, found: false, first: 0.0, mean: 0.0, cents: 0.0, off: (true, true) };
            };
            let truth: Vec<f64> = times.iter().map(|t| if *t < 0.0 { QUIET } else { (p.level)(*t).max(QUIET) }).collect();
            // The check reads the first 20 ms as the frames up to 20 ms after the strike it finds, and the truth is the loudest the partial is over the 20 ms after the true one.
            let read = track.levels.iter().take(((0.02 + partials::LEAD) / HOP) as usize).map(|l| l.max(track.floor)).fold(f64::MIN, f64::max);
            let peak = (0..=200).map(|i| (p.level)(i as f64 * 0.0001).max(QUIET)).fold(f64::MIN, f64::max).max(track.floor);
            let gaps: Vec<f64> = (0..times.len()).filter(|k| truth[*k] > track.floor + partials::CLEAR && times[*k] <= SECONDS).map(|k| (track.levels[k].max(track.floor) - truth[k]).abs()).collect();
            let first = read - peak;
            let mean = if gaps.is_empty() { 0.0 } else { gaps.iter().sum::<f64>() / gaps.len() as f64 };
            Partial { freq: p.freq, found: true, first, mean, cents: 1200.0 * (track.freq / p.freq).log2(), off: (first.abs() > LIMIT, mean > LIMIT) }
        })
        .collect::<Vec<Partial>>();
    let strike = (measured.spectra.struck() - onset) / RATE * 1000.0;
    let followed = partials.iter().all(|p| p.found && !p.off.0 && !p.off.1);
    Known { kind: kind.to_string(), note, strike, partials, followed }
}

/// Every kind of note at every pitch, in order of kind.
pub fn all() -> Vec<Known> {
    let pairs: Vec<(&str, f64)> = KINDS.iter().flat_map(|k| NOTES.iter().map(move |n| (*k, *n))).collect();
    parallel(&pairs, |(kind, note)| known(kind, *note))
}

#[cfg(test)]
mod tests {
    use super::*;

    // Each partial's gap over the first 20 ms and on average when mx-00177 was done, None where it was not found, so a change to the measuring that follows any note worse fails.
    const RECORDED: [(&str, f64, &[Option<(f64, f64)>]); 18] = [
        ("slow", 36.0, &[Some((2.708, 0.058))]),
        ("slow", 60.0, &[Some((1.590, 0.038))]),
        ("slow", 96.0, &[Some((1.638, 0.031))]),
        ("short", 36.0, &[Some((2.729, 0.058)), Some((19.423, 23.220))]),
        ("short", 60.0, &[Some((1.613, 0.038)), Some((16.622, 25.310))]),
        ("short", 96.0, &[Some((1.632, 0.031)), Some((21.714, 29.772))]),
        ("beating", 36.0, &[Some((2.766, 0.071)), Some((3.226, 0.076)), Some((3.004, 0.069))]),
        ("beating", 60.0, &[Some((1.623, 0.038)), Some((3.849, 0.934)), None]),
        ("beating", 96.0, &[Some((1.609, 0.031)), Some((3.779, 3.426)), Some((3.779, 3.426))]),
        ("building", 36.0, &[Some((9.309, 0.235)), Some((2.710, 0.063))]),
        ("building", 60.0, &[Some((6.454, 0.151)), Some((1.592, 0.160))]),
        ("building", 96.0, &[Some((6.533, 0.114)), Some((1.594, 0.031))]),
        ("noisy", 36.0, &[Some((2.671, 0.064)), Some((6.712, 0.119))]),
        ("noisy", 60.0, &[Some((1.700, 0.049)), Some((6.327, 0.203))]),
        ("noisy", 96.0, &[Some((1.396, 0.034)), Some((6.210, 0.236))]),
        ("early", 36.0, &[Some((28.123, 0.101)), None]),
        ("early", 60.0, &[Some((28.910, 0.071)), Some((10.030, 25.102))]),
        ("early", 96.0, &[Some((28.799, 0.058)), Some((9.936, 28.051))]),
    ];

    #[test]
    fn no_known_note_is_measured_worse_than_when_recorded() {
        let measured = all();
        for ((kind, note, recorded), known) in RECORDED.iter().zip(&measured) {
            assert_eq!((*kind, *note), (known.kind.as_str(), known.note));
            for (want, got) in recorded.iter().zip(&known.partials) {
                if let Some((first, mean)) = want {
                    assert!(got.found, "{kind} at {note}: {:.1} Hz is no longer found", got.freq);
                    assert!(got.first.abs() <= first + 0.05, "{kind} at {note}: {:.1} Hz is {:.2} dB off over the first 20 ms, against {first}", got.freq, got.first);
                    assert!(got.mean <= mean + 0.05, "{kind} at {note}: {:.1} Hz is {:.2} dB off on average, against {mean}", got.freq, got.mean);
                }
            }
        }
    }

    #[test]
    fn a_figure_is_marked_off_exactly_when_it_is_beyond_the_limit() {
        for known in all() {
            for p in known.partials.iter().filter(|p| p.found) {
                assert_eq!(p.off, (p.first.abs() > LIMIT, p.mean > LIMIT));
            }
            assert_eq!(known.followed, known.partials.iter().all(|p| p.found && !p.off.0 && !p.off.1));
        }
    }
}
