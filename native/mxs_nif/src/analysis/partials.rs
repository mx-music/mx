//! Plucked and struck notes partial by partial, for `mix mx.measure --partials` and `mix mx.fit`: each partial's level every 2.5 ms from the strike until it falls into the recording's noise floor.
//! Levels are in dB of a sine's amplitude, so a sine at full scale reads 0 dB.

use super::{db, hz, median};
use rustfft::{FftPlanner, num_complex::Complex};
use std::f64::consts::PI;

/// The seconds between two frames.
pub const HOP: f64 = 0.0025;
/// The highest partial followed, in Hz, unless a fit is given another.
pub const TOP: f64 = 8000.0;
/// The dB a partial stands above the floor to count.
pub const CLEAR: f64 = 10.0;
/// The seconds before the strike each measuring starts at.
pub const LEAD: f64 = 0.005;

/// A recording's frames from just before its strike, with the frequency resolution they were taken at.
pub struct Spectra {
    pub frames: Vec<Vec<f64>>,
    pub bin: f64,
    pub resolution: f64,
    pub window: f64,
    start: f64,
    rate: f64,
}

impl Spectra {
    /// The first frame whose window lies wholly after the strike, and those up to 0.3 seconds later, where a partial's frequency is read.
    pub fn settled(&self) -> std::ops::Range<usize> {
        let first = ((LEAD + self.window / 2.0) / HOP).ceil() as usize;
        let last = ((LEAD + self.window / 2.0 + 0.3) / HOP) as usize;
        first.min(self.frames.len().saturating_sub(1))..last.min(self.frames.len())
    }

    /// The sample the strike was found at.
    pub fn struck(&self) -> f64 {
        self.start + LEAD * self.rate
    }
}

/// The sample a note's strike starts at: the first within 20 dB of its peak.
pub fn strike(sound: &[f64]) -> usize {
    let peak = sound.iter().fold(0.0f64, |top, v| top.max(v.abs()));
    sound.iter().position(|v| v.abs() > peak * 0.1).unwrap_or(0)
}

/// The samples of the window a note at `f0` is measured through: eight periods of its fundamental, from 80 to 250 ms.
pub fn window(rate: f64, f0: f64) -> usize {
    ((8.0 / f0).clamp(0.08, 0.25) * rate).round() as usize
}

/// Spectra every 2.5 ms for `seconds` from 5 ms before the strike, each through a Hann window eight periods of the fundamental long, from 80 to 250 ms.
pub fn spectra(sound: &[f64], rate: f64, f0: f64, seconds: f64) -> Spectra {
    spectra_from(sound, rate, f0, seconds, strike(sound))
}

/// The spectra from a strike at a given sample, for a sound whose own loudest moment does not mark it.
pub fn spectra_from(sound: &[f64], rate: f64, f0: f64, seconds: f64, struck: usize) -> Spectra {
    let window = window(rate, f0);
    let size = (2 * window).next_power_of_two();
    let fft = FftPlanner::<f64>::new().plan_fft_forward(size);
    let hann: Vec<f64> = (0..window)
        .map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / window as f64).cos())
        .collect();
    let norm = hann.iter().sum::<f64>() / 2.0;
    let start = struck as f64 - LEAD * rate;
    // No window reaches past the seconds measured, where a recording may already be let go.
    let count = (((seconds + LEAD - window as f64 / rate / 2.0) / HOP)
        .floor()
        .max(0.0) as usize)
        .min(((sound.len() as f64 - start) / rate / HOP).max(0.0) as usize);
    let frames = super::parallel(&(0..count).collect::<Vec<_>>(), |&k| {
        let centre = start + k as f64 * HOP * rate;
        let mut buffer: Vec<Complex<f64>> = (0..size)
            .map(|i| {
                if i >= window {
                    return Complex::new(0.0, 0.0);
                }
                let at = (centre + i as f64 - (window / 2) as f64).round();
                let sample = if at >= 0.0 && (at as usize) < sound.len() {
                    sound[at as usize]
                } else {
                    0.0
                };
                Complex::new(sample * hann[i], 0.0)
            })
            .collect();
        fft.process(&mut buffer);
        buffer[..size / 2]
            .iter()
            .map(|c| (c.norm() / norm).max(1e-12))
            .collect()
    });
    Spectra {
        frames,
        bin: rate / size as f64,
        resolution: rate / window as f64,
        window: window as f64 / rate,
        start,
        rate,
    }
}

/// A peak's frequency and level from a parabola through the log magnitudes around the largest bin within `width` Hz of `freq`.
pub fn peak_near(frame: &[f64], bin: f64, freq: f64, width: f64) -> (f64, f64) {
    let low = ((freq - width) / bin).floor().max(1.0) as usize;
    let high = (((freq + width) / bin).ceil() as usize)
        .min(frame.len() - 2)
        .max(low);
    let best = (low..=high).fold(low, |best, i| if frame[i] > frame[best] { i } else { best });
    let (left, top, right) = (db(frame[best - 1]), db(frame[best]), db(frame[best + 1]));
    let bend = left - 2.0 * top + right;
    let shift = if bend < 0.0 {
        (0.5 * (left - right) / bend).clamp(-0.5, 0.5)
    } else {
        0.0
    };
    (
        (best as f64 + shift) * bin,
        top - 0.25 * (left - right) * shift,
    )
}

/// The level of each third of an octave from 25 Hz between the partials: the 75th percentile over the note of each frame's median there.
pub struct Floor {
    levels: Vec<f64>,
}

impl Floor {
    pub fn new(spectra: &Spectra, partials: &[f64]) -> Self {
        let edges: Vec<f64> = (0..40).map(|k| 25.0 * 2f64.powf(k as f64 / 3.0)).collect();
        let mut sorted = partials.to_vec();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let distance = |freq: f64| {
            let at = sorted.partition_point(|p| *p < freq);
            let below = at
                .checked_sub(1)
                .map_or(f64::INFINITY, |i| freq - sorted[i]);
            let above = sorted.get(at).map_or(f64::INFINITY, |p| p - freq);
            below.min(above)
        };
        let length = spectra.frames.first().map_or(0, |f| f.len());
        let levels = edges
            .windows(2)
            .map(|edge| {
                let (low, high) = (
                    (edge[0] / spectra.bin) as usize,
                    (edge[1] / spectra.bin) as usize,
                );
                let bins: Vec<usize> = (low.max(1)..high.min(length))
                    .filter(|&i| distance(i as f64 * spectra.bin) > 2.0 * spectra.resolution)
                    .collect();
                if bins.is_empty() {
                    return None;
                }
                let mut per_frame: Vec<f64> = spectra
                    .frames
                    .iter()
                    .step_by(8)
                    .map(|f| median(&bins.iter().map(|&i| db(f[i])).collect::<Vec<_>>()))
                    .collect();
                per_frame.sort_by(|a, b| a.partial_cmp(b).unwrap());
                per_frame.get(per_frame.len() * 3 / 4).copied()
            })
            .collect::<Vec<Option<f64>>>();
        // A band the partials crowd so that no bin stands clear of them takes the floor of the nearest band that has one.
        let known: Vec<(usize, f64)> = levels
            .iter()
            .enumerate()
            .filter_map(|(k, l)| l.map(|l| (k, l)))
            .collect();
        let levels = (0..levels.len())
            .map(|k| {
                known
                    .iter()
                    .min_by_key(|(at, _)| (*at as i64 - k as i64).abs())
                    .map_or(-240.0, |(_, l)| *l)
            })
            .collect();
        Floor { levels }
    }

    pub fn at(&self, freq: f64) -> f64 {
        let band = ((freq / 25.0).log2() * 3.0)
            .floor()
            .clamp(0.0, (self.levels.len() - 1) as f64) as usize;
        self.levels[band]
    }
}

/// A partial's level in every frame, and the frequency it was found at.
#[derive(Clone)]
pub struct Track {
    pub freq: f64,
    pub harmonic: u32,
    pub levels: Vec<f64>,
    pub floor: f64,
}

impl Track {
    /// The frames it stands at least 10 dB above the floor in.
    pub fn clear(&self) -> impl Iterator<Item = (usize, f64)> + '_ {
        self.levels
            .iter()
            .cloned()
            .enumerate()
            .filter(|(_, l)| *l > self.floor + CLEAR)
    }

    /// The loudest it is over the first `seconds`.
    pub fn strike(&self, seconds: f64) -> f64 {
        let frames = ((seconds / HOP).round() as usize).max(1);
        self.levels
            .iter()
            .take(frames)
            .cloned()
            .fold(f64::MIN, f64::max)
    }
}

/// Each partial's level over a note.
pub struct Note {
    pub f0: f64,
    pub spectra: Spectra,
    pub floor: Floor,
    pub partials: Vec<Track>,
    pub left_out: Vec<Track>,
}

/// The level of each partial at its frequency in every frame of the spectra, solved together so that none takes in its neighbours' skirts.
/// Each frame is fitted, weighted by its window, as a sum of the partials' sines, each with an amplitude and a change of amplitude across the window, so a partial falling fast leaves nothing in its neighbours.
pub fn follow(sound: &[f64], spectra: &Spectra, freqs: &[f64]) -> Vec<Vec<f64>> {
    let rate = spectra.rate;
    let size = (spectra.window * rate).round() as usize;
    let hann: Vec<f64> = (0..size)
        .map(|i| 0.5 - 0.5 * (2.0 * PI * i as f64 / size as f64).cos())
        .collect();
    let centre = size as f64 / 2.0;
    let omegas: Vec<f64> = freqs.iter().map(|f| 2.0 * PI * f / rate).collect();
    let reach = 20.0 * 2.0 * PI / size as f64;
    let system = Banded::new(&omegas, reach, &hann);
    let rows = super::parallel(&(0..spectra.frames.len()).collect::<Vec<_>>(), |&k| {
        let from = (spectra.start + k as f64 * HOP * rate).round() as i64 - (size / 2) as i64;
        let heard: Vec<f64> = (0..size)
            .map(|i| {
                let at = from + i as i64;
                if at >= 0 && (at as usize) < sound.len() {
                    sound[at as usize] * hann[i]
                } else {
                    0.0
                }
            })
            .collect();
        let mut read = Vec::with_capacity(2 * omegas.len());
        for omega in &omegas {
            let turn = Complex::from_polar(1.0, -omega);
            let mut at = Complex::new(1.0, 0.0);
            let (mut level, mut change) = (Complex::new(0.0, 0.0), Complex::new(0.0, 0.0));
            for (n, sample) in heard.iter().enumerate() {
                let value = at * sample;
                level += value;
                change += value * (n as f64 - centre);
                at *= turn;
            }
            read.push(level);
            read.push(change);
        }
        let solved = system.solve(read);
        (0..omegas.len())
            .map(|j| db(solved[2 * j].norm()))
            .collect::<Vec<f64>>()
    });
    (0..freqs.len())
        .map(|j| rows.iter().map(|row| row[j]).collect())
        .collect()
}

/// The weights `follow` reads each partial's amplitude with, one row a partial over the window's samples: the partial's level in a frame is the magnitude of its row's weighted sum of the frame's samples, in dB.
#[cfg(any(test, all(feature = "gpu", target_os = "macos")))]
pub fn reading(rate: f64, window: f64, freqs: &[f64]) -> Vec<Vec<Complex<f64>>> {
    let size = (window * rate).round() as usize;
    let hann: Vec<f64> = (0..size)
        .map(|i| 0.5 - 0.5 * (2.0 * PI * i as f64 / size as f64).cos())
        .collect();
    let centre = size as f64 / 2.0;
    let omegas: Vec<f64> = freqs.iter().map(|f| 2.0 * PI * f / rate).collect();
    let reach = 20.0 * 2.0 * PI / size as f64;
    let system = Banded::new(&omegas, reach, &hann);
    let columns = super::parallel(&(0..size).collect::<Vec<_>>(), |&n| {
        let read: Vec<Complex<f64>> = omegas
            .iter()
            .flat_map(|omega| {
                let value = Complex::from_polar(hann[n], -omega * n as f64);
                [value, value * (n as f64 - centre)]
            })
            .collect();
        system.solve(read)
    });
    (0..freqs.len())
        .map(|j| columns.iter().map(|column| column[2 * j]).collect())
        .collect()
}

// The window's weighted sums of a sine and of a sine times the offset from the window's centre, once and twice, at an angle `theta` per sample.
fn responses(theta: f64, hann: &[f64]) -> [Complex<f64>; 3] {
    let centre = hann.len() as f64 / 2.0;
    let turn = Complex::from_polar(1.0, -theta);
    let mut at = Complex::new(1.0, 0.0);
    let mut sums = [Complex::new(0.0, 0.0); 3];
    for (n, weight) in hann.iter().enumerate() {
        let offset = n as f64 - centre;
        let value = at * weight;
        sums[0] += value;
        sums[1] += value * offset;
        sums[2] += value * offset * offset;
        at *= turn;
    }
    sums
}

// The weighted sums between partials near enough to reach one another, factored once for every frame: two unknowns for each partial, in order of frequency.
struct Banded {
    order: Vec<usize>,
    band: usize,
    lower: Vec<Vec<Complex<f64>>>,
    upper: Vec<Vec<Complex<f64>>>,
}

impl Banded {
    fn new(omegas: &[f64], reach: f64, hann: &[f64]) -> Self {
        let mut order: Vec<usize> = (0..omegas.len()).collect();
        order.sort_by(|a, b| omegas[*a].partial_cmp(&omegas[*b]).unwrap());
        let sorted: Vec<f64> = order.iter().map(|&i| omegas[i]).collect();
        let partials = sorted.len();
        let near = (0..partials)
            .map(|j| {
                (j..partials)
                    .take_while(|&k| sorted[k] - sorted[j] < reach)
                    .count()
            })
            .max()
            .unwrap_or(1)
            .max(1);
        let count = 2 * partials;
        let band = 2 * near + 1;
        // Each row holds the columns from j - band to j + band.
        let width = 2 * band + 1;
        let mut matrix = vec![vec![Complex::new(0.0, 0.0); width]; count];
        for j in 0..partials {
            for k in j.saturating_sub(near)..(j + near + 1).min(partials) {
                let sums = responses(sorted[j] - sorted[k], hann);
                for m in 0..2 {
                    for p in 0..2 {
                        let (row, column) = (2 * j + m, 2 * k + p);
                        matrix[row][column + band - row] = sums[m + p] * 0.5;
                    }
                }
            }
        }
        let mut lower = vec![vec![Complex::new(0.0, 0.0); band]; count];
        for p in 0..count {
            for j in p + 1..(p + band + 1).min(count) {
                let factor = matrix[j][p + band - j] / matrix[p][band];
                lower[j][p + band - j] = factor;
                for k in p..(p + band + 1).min(count) {
                    let value = matrix[p][k + band - p];
                    matrix[j][k + band - j] -= factor * value;
                }
            }
        }
        Banded {
            order,
            band,
            lower,
            upper: matrix,
        }
    }

    // The amplitude and change of each partial, from what the frame reads at each, as the pairs `read` gives them in the partials' own order.
    fn solve(&self, read: Vec<Complex<f64>>) -> Vec<Complex<f64>> {
        let count = 2 * self.order.len();
        let band = self.band;
        let mut values: Vec<Complex<f64>> = self
            .order
            .iter()
            .flat_map(|&i| [read[2 * i], read[2 * i + 1]])
            .collect();
        for j in 0..count {
            for p in j.saturating_sub(band)..j {
                let factor = self.lower[j][p + band - j];
                let value = values[p];
                values[j] -= factor * value;
            }
        }
        for j in (0..count).rev() {
            for k in j + 1..(j + band + 1).min(count) {
                let value = values[k];
                values[j] -= self.upper[j][k + band - j] * value;
            }
            values[j] /= self.upper[j][band];
        }
        let mut solved = vec![Complex::new(0.0, 0.0); count];
        for (place, &i) in self.order.iter().enumerate() {
            solved[2 * i] = values[2 * place];
            solved[2 * i + 1] = values[2 * place + 1];
        }
        solved
    }
}

/// Measures a note: its pitch near `note`, or with `exact` the note's own frequency, its harmonics up to `top` Hz or the highest the recording holds, and the peaks that are not harmonics as the note starts.
/// A partial between harmonics with no strike, standing no more than 3 dB above its level once settled as the note starts, and hardly any fall, moving less than 12 dB after, is a line that is not the instrument's, and is left out.
pub fn measure(sound: &[f64], rate: f64, note: f64, seconds: f64, exact: bool, top: f64) -> Note {
    let guess = hz(note);
    let spectra = spectra(sound, rate, guess, seconds);
    let f0 = if exact {
        guess
    } else {
        let rough = pitch(
            &spectra.frames[spectra.settled().start],
            spectra.bin,
            guess,
            spectra.resolution,
        );
        // The grid's pitch can sit a few cents off where the bell's partials pull its score, so the first harmonics settle it.
        median(
            &(1..=4)
                .map(|n| {
                    settle(
                        &spectra,
                        n as f64 * rough,
                        (n as f64 * rough * 0.03).max(spectra.resolution),
                    ) / n as f64
                })
                .collect::<Vec<_>>(),
        )
    };
    let top = top.min(0.45 * rate);
    let harmonics: Vec<f64> = (1..)
        .map(|n| n as f64 * f0)
        .take_while(|f| *f <= top)
        .collect();
    let first_floor = Floor::new(&spectra, &harmonics);
    // A drum's partials are not harmonics, so with its pitch given they are looked for from just above it; a string's from halfway to its second harmonic, clear of the fundamental's skirt.
    let others = others(
        &spectra,
        f0,
        top,
        &first_floor,
        if exact { 1.06 } else { 1.5 },
    );
    let mut every = harmonics.clone();
    every.extend(others.iter().cloned());
    let floor = Floor::new(&spectra, &every);
    // A peak further than this from a whole multiple is another partial, such as a tine's bell, standing in for a harmonic the note lacks.
    let width = |target: f64| (target * 0.01).min(0.25 * f0).max(spectra.resolution);
    let mut freqs: Vec<(f64, u32)> = vec![];
    for (n, target) in harmonics.iter().enumerate() {
        // A pitch given exactly is the first partial's own, which a louder partial nearby could pull off it.
        let freq = if exact && n == 0 {
            *target
        } else {
            settle(&spectra, *target, width(*target))
        };
        // A harmonic settling outside its window has followed another partial's skirt, and high up neighbouring harmonics may settle on the same peak, which is kept once.
        if (freq - target).abs() <= width(*target)
            && freqs
                .iter()
                .all(|(f, _)| (f - freq).abs() > spectra.resolution)
        {
            freqs.push((freq, n as u32 + 1));
        }
    }
    for freq in &others {
        let freq = settle(&spectra, *freq, spectra.resolution);
        // Two partials closer than twice the window's resolution cannot be told apart reliably, so the weaker is dropped.
        if freqs
            .iter()
            .all(|(f, _)| (f - freq).abs() > 2.0 * spectra.resolution)
        {
            freqs.push((freq, 0));
        }
    }
    let levels = follow(
        sound,
        &spectra,
        &freqs.iter().map(|f| f.0).collect::<Vec<_>>(),
    );
    let mut partials = vec![];
    let mut left_out = vec![];
    for ((freq, harmonic), levels) in freqs.into_iter().zip(levels) {
        let track = Track {
            freq,
            harmonic,
            levels,
            floor: floor.at(freq),
        };
        if harmonic > 0 {
            if track.strike(0.1) > track.floor + CLEAR {
                partials.push(track);
            }
        } else if median(&track.levels[spectra.settled()]) <= track.floor + CLEAR {
            // A peak the solving leaves nothing of was a stronger partial's sidelobe.
        } else if moves(&track, spectra.settled()) < 12.0
            && track.strike(0.05) - median(&track.levels[spectra.settled()]) < 3.0
        {
            left_out.push(track);
        } else {
            partials.push(track);
        }
    }
    Note {
        f0,
        spectra,
        floor,
        partials,
        left_out,
    }
}

/// A partial's frequency near `freq`, as the median of its peak over the settled frames.
pub fn settle(spectra: &Spectra, freq: f64, width: f64) -> f64 {
    let found: Vec<f64> = spectra.frames[spectra.settled()]
        .iter()
        .map(|f| peak_near(f, spectra.bin, freq, width).0)
        .collect();
    if found.is_empty() {
        freq
    } else {
        median(&found)
    }
}

// The fundamental within 6% of the guess whose first six harmonics are loudest, in steps of a thousandth.
fn pitch(frame: &[f64], bin: f64, guess: f64, _resolution: f64) -> f64 {
    let candidates = (0..=120).map(|step| guess * (0.94 + step as f64 * 0.001));
    super::first_max(candidates, |f0| {
        (1..=6)
            .map(|n| super::magnitude_at(frame, f0 * n as f64 / bin))
            .sum()
    })
    .unwrap()
}

// Peaks over the first 20 ms of settled frames above `above` times the pitch that stand clear of the harmonics and of the floor, strongest first, so a sidelobe gives way to the peak it leans on.
fn others(spectra: &Spectra, f0: f64, top: f64, floor: &Floor, above: f64) -> Vec<f64> {
    let mut peaks: Vec<(f64, f64)> = vec![];
    let last = ((top / spectra.bin) as usize).min(spectra.frames[0].len() - 3);
    let near = (0.06 * f0).max(2.0 * spectra.resolution);
    for step in [0, 4, 8] {
        let Some(frame) = spectra.frames.get(spectra.settled().start + step) else {
            continue;
        };
        for i in 2..last {
            let freq = i as f64 * spectra.bin;
            let local = frame[i] > frame[i - 1]
                && frame[i] >= frame[i + 1]
                && frame[i] > frame[i - 2]
                && frame[i] >= frame[i + 2];
            let off = ((freq / f0) - (freq / f0).round()).abs() * f0;
            if local && off > near && freq > above * f0 && db(frame[i]) > floor.at(freq) + CLEAR {
                peaks.push(peak_near(frame, spectra.bin, freq, spectra.bin));
            }
        }
    }
    peaks.sort_by(|a, b| b.1.total_cmp(&a.1));
    let mut found: Vec<f64> = vec![];
    for (freq, _) in peaks {
        if found
            .iter()
            .all(|f| (f - freq).abs() > 2.0 * spectra.resolution)
        {
            found.push(freq);
        }
    }
    found
}

// How far a partial's level moves, up or down, from its first tenth of a second after the strike's frames to its last half second.
fn moves(track: &Track, settled: std::ops::Range<usize>) -> f64 {
    let tail = (0.5 / HOP) as usize;
    let last = &track.levels[track.levels.len().saturating_sub(tail)..];
    let first = &track.levels
        [settled.start..(settled.start + (0.1 / HOP) as usize).min(track.levels.len())];
    (median(first) - median(last)).abs()
}

/// How a partial falls, from its loudest moment while it stands clear of the floor: one slope, or a fast one until a knee and a slower one after, in dB a second.
pub struct Fall {
    pub first: f64,
    pub knee: Option<f64>,
    pub second: f64,
}

pub fn fall(track: &Track) -> Option<Fall> {
    let peak = (0..((0.05 / HOP) as usize).min(track.levels.len())).fold(0, |best, i| {
        if track.levels[i] > track.levels[best] {
            i
        } else {
            best
        }
    });
    let points: Vec<(f64, f64)> = track
        .clear()
        .filter(|(i, _)| *i >= peak)
        .map(|(i, l)| (i as f64 * HOP, l))
        .collect();
    if points.len() < 8 {
        return None;
    }
    let (single, single_error) = line(&points);
    let mut best: Option<(f64, f64, f64, f64)> = None;
    // A knee needs a fifth of a second after it, so a few frames at the end cannot make one.
    let tail = (0.2 / HOP) as usize;
    for split in 4..points.len().saturating_sub(tail.max(4)) {
        let (one, one_error) = line(&points[..split]);
        let (two, two_error) = line(&points[split..]);
        let error = one_error + two_error;
        if best.is_none_or(|b| error < b.3) {
            best = Some((one, points[split].0, two, error));
        }
    }
    match best {
        Some((one, knee, two, error)) if error < 0.5 * single_error && one < two && two <= 0.0 => {
            Some(Fall {
                first: one,
                knee: Some(knee),
                second: two,
            })
        }
        _ => Some(Fall {
            first: single,
            knee: None,
            second: single,
        }),
    }
}

// The slope of the line that best fits the points, and the sum of the squares it leaves.
fn line(points: &[(f64, f64)]) -> (f64, f64) {
    let slope = super::slope(points);
    let count = points.len() as f64;
    let mean_x = points.iter().map(|p| p.0).sum::<f64>() / count;
    let mean_y = points.iter().map(|p| p.1).sum::<f64>() / count;
    let error = points
        .iter()
        .map(|(x, y)| (y - mean_y - slope * (x - mean_x)).powi(2))
        .sum();
    (slope, error)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reading_a_frame_with_its_weights_gives_what_follow_reads() {
        let rate = 16000.0;
        let freqs = [220.0, 440.0, 455.0, 1310.0];
        let sound: Vec<f64> = (0..16000)
            .map(|i| {
                freqs
                    .iter()
                    .enumerate()
                    .map(|(j, f)| {
                        (2.0 * PI * f * i as f64 / rate + j as f64).sin() / (j as f64 + 1.0)
                    })
                    .sum::<f64>()
                    * (-(i as f64) / 8000.0).exp()
            })
            .collect();
        let spectra = spectra(&sound, rate, 220.0, 0.8);
        let followed = follow(&sound, &spectra, &freqs);
        let weights = reading(rate, spectra.window, &freqs);
        let size = weights[0].len();
        for k in [3, 40, 200] {
            let from = (spectra.start + k as f64 * HOP * rate).round() as i64 - (size / 2) as i64;
            for (j, row) in weights.iter().enumerate() {
                let sum: Complex<f64> = row
                    .iter()
                    .enumerate()
                    .map(|(n, w)| {
                        let at = from + n as i64;
                        w * if at >= 0 && (at as usize) < sound.len() {
                            sound[at as usize]
                        } else {
                            0.0
                        }
                    })
                    .sum();
                assert!(
                    (db(sum.norm()) - followed[j][k]).abs() < 1e-6,
                    "partial {j} frame {k}: {} against {}",
                    db(sum.norm()),
                    followed[j][k]
                );
            }
        }
    }
}
