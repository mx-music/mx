//! Hits, struck bars, bells, drums and scrapers, for `Mx.Measure.Hits`: each band's level and fade, its level at moments after the hit, the strongest peaks, and the partials.

use super::{BANDS, Spectra, db, fade, filter_loss, high_pass, hz, onsets, refine, runs};
use rustler::NifMap;

const HOP: f64 = 0.01;
const LONGEST: f64 = 4.0;
const PEAKS: usize = 6;
const MOMENTS: [f64; 4] = [0.0, 50.0, 100.0, 200.0];
/// The semitones above its first note a run of hits may reach, short of the octave that would name a note by its octave's fundamental.
const RUN: i64 = 11;

#[derive(NifMap)]
pub struct Band {
    pub band: (u32, u32),
    pub level: f64,
    pub fade: Option<f64>,
}

#[derive(NifMap)]
pub struct Moments {
    pub band: (u32, u32),
    pub levels: Vec<Option<f64>>,
}

#[derive(NifMap)]
pub struct Partial {
    pub hz: f64,
    pub ratio: f64,
    pub level: f64,
    pub ring: Option<f64>,
}

#[derive(NifMap)]
pub struct Hit {
    pub start: f64,
    pub note: Option<i64>,
    pub bands: Vec<Band>,
    pub moments: Vec<Moments>,
    pub peaks: Vec<f64>,
    pub partials: Vec<Partial>,
}

fn cutoff(note: Option<i64>) -> f64 {
    note.map_or(30.0, |note| hz(note as f64) * 0.75)
}

/// Each hit of a sound, one after another from silence, with the note they play or None.
/// Several hits given a note are a run from that note up to `RUN` semitones above it, split into its notes as `mix mx.fit` splits a run, each hit named by its note, so a bar ringing on under the next is not a hit of its own.
pub fn hits(samples: &[f64], rate: f64, note: Option<i64>, partials: Option<usize>) -> Vec<Hit> {
    let cutoff = cutoff(note);
    let sound = high_pass(samples, rate, cutoff);
    let onsets: Vec<(usize, Option<i64>)> = onsets(&sound, rate, 0.25).into_iter().map(|from| (from, note)).collect();
    let starts = match note {
        Some(first) if onsets.len() > 1 => runs::split(samples, rate, &(first..=first + RUN).collect::<Vec<_>>(), false)
            .into_iter()
            .filter(|piece| piece.left_out.is_none())
            .map(|piece| (piece.from, Some(piece.note)))
            .collect(),
        _ => onsets,
    };
    let ends: Vec<usize> = starts.iter().skip(1).map(|(from, _)| *from).chain([sound.len()]).collect();
    let longest = (LONGEST * rate).round() as usize;
    let mut spectra = Spectra::default();
    starts
        .iter()
        .zip(&ends)
        .filter_map(|(&(from, note), &to)| measure(&sound[from..to.min(from + longest)], from as f64 / rate, note, rate, cutoff, partials, &mut spectra))
        .collect()
}

/// A sound that is one hit from its first sample, or None when it is too short.
pub fn hit(samples: &[f64], rate: f64, note: Option<i64>, partials: Option<usize>) -> Option<Hit> {
    let cutoff = cutoff(note);
    let sound = high_pass(samples, rate, cutoff);
    let segment = &sound[..sound.len().min((LONGEST * rate).round() as usize)];
    measure(segment, 0.0, note, rate, cutoff, partials, &mut Spectra::default())
}

fn measure(sound: &[f64], start: f64, note: Option<i64>, rate: f64, cutoff: f64, count: Option<usize>, spectra: &mut Spectra) -> Option<Hit> {
    let size = 2usize.pow((0.043 * rate).log2().round() as u32);
    let hop = (HOP * rate).round() as usize;
    if sound.len() < size {
        return None;
    }
    let starts: Vec<usize> = (0..=sound.len() - size).step_by(hop).collect();
    if starts.len() < 5 {
        return None;
    }
    let frames: Vec<Vec<f64>> = starts.iter().map(|from| spectra.take(sound, *from, size)).collect();
    let times: Vec<f64> = starts.iter().map(|from| (*from as f64 + size as f64 / 2.0) / rate).collect();
    let tracks = tracks(&frames, rate / size as f64, rate, cutoff);
    Some(Hit {
        start,
        note,
        bands: bands(&tracks, &times),
        moments: track_moments(&tracks),
        peaks: peaks(sound, rate, cutoff, spectra),
        partials: match count {
            Some(count) => partials(sound, &frames, &times, rate / size as f64, rate, cutoff, count, spectra),
            None => vec![],
        },
    })
}

// Each band's power in every frame, in dB, from the rumble filter's cutoff up.
fn tracks(frames: &[Vec<f64>], bin: f64, rate: f64, cutoff: f64) -> Vec<((u32, u32), Vec<f64>)> {
    BANDS
        .iter()
        .filter(|(_, high)| *high as f64 <= rate / 2.0)
        .filter_map(|&(low, high)| {
            let first = ((low as f64).max(cutoff) / bin).ceil() as i64;
            let last = (high as f64 / bin).ceil() as i64 - 1;
            if first > last {
                return None;
            }
            let track = frames
                .iter()
                .map(|spectrum| {
                    let power: f64 = (first..=last)
                        .map(|at| spectrum[at as usize].powi(2) * 10f64.powf(filter_loss(at as f64 * bin, cutoff) / 10.0))
                        .sum();
                    10.0 * (power + 1.0e-24).log10()
                })
                .collect();
            Some(((low, high), track))
        })
        .collect()
}

fn first_three_max(track: &[f64]) -> f64 {
    track.iter().take(3).cloned().fold(f64::MIN, f64::max)
}

// A band's level as the hit starts is the loudest of the first three frames; a band less than 10 dB above its own quietest frame, or 60 dB below the loudest band, is left out.
fn bands(tracks: &[((u32, u32), Vec<f64>)], times: &[f64]) -> Vec<Band> {
    let loudest = tracks.iter().map(|(_, track)| first_three_max(track)).fold(f64::MIN, f64::max);
    tracks
        .iter()
        .filter_map(|(band, track)| {
            let start = first_three_max(track);
            let quietest = track.iter().cloned().fold(f64::INFINITY, f64::min);
            (start > quietest + 10.0 && start > loudest - 60.0)
                .then(|| Band { band: *band, level: start - loudest, fade: fade(times, track, (start - 40.0).max(quietest + 10.0)) })
        })
        .collect()
}

// Each band's level at each moment after the loudest of the first three frames, against the loudest band then; past the last frame it is None, and more than 40 dB down it is -40.
fn track_moments(tracks: &[((u32, u32), Vec<f64>)]) -> Vec<Moments> {
    let power: Vec<f64> = (0..3).map(|frame| tracks.iter().map(|(_, track)| 10f64.powf(track[frame] / 10.0)).sum()).collect();
    let top_power = power.iter().cloned().fold(f64::MIN, f64::max);
    let loudest = power.iter().position(|p| *p == top_power).unwrap();
    let top = tracks.iter().map(|(_, track)| track[loudest]).fold(f64::MIN, f64::max);
    tracks
        .iter()
        .map(|(band, track)| Moments {
            band: *band,
            levels: MOMENTS
                .iter()
                .map(|ms| track.get(loudest + (ms / 1000.0 / HOP).round() as usize).map(|level| (level - top).max(-40.0)))
                .collect(),
        })
        .collect()
}

// The strongest peaks of a spectrum of the hit's start, each at least 3% and four bins from a stronger one.
fn peaks(sound: &[f64], rate: f64, cutoff: f64, spectra: &mut Spectra) -> Vec<f64> {
    let (spectrum, levels, loudest, bin) = start_spectrum(sound, rate, spectra);
    let mut positions: Vec<f64> = strongest(&levels, loudest - 30.0, (cutoff / bin).ceil() as i64, |other| 4f64.max(0.03 * other as f64), PEAKS)
        .into_iter()
        .map(|at| refine(&spectrum, at).0)
        .collect();
    positions.sort_by(|a, b| a.partial_cmp(b).unwrap());
    match positions.first() {
        Some(&lowest) => positions.iter().map(|p| p / lowest).collect(),
        None => vec![],
    }
}

// Each partial's ring follows the frames' bins around it, as a band's fade follows its bins.
#[allow(clippy::too_many_arguments)]
fn partials(sound: &[f64], frames: &[Vec<f64>], times: &[f64], frame_bin: f64, rate: f64, cutoff: f64, count: usize, spectra: &mut Spectra) -> Vec<Partial> {
    let (spectrum, levels, loudest, bin) = start_spectrum(sound, rate, spectra);
    let mut found: Vec<(f64, f64)> = strongest(&levels, loudest - 40.0, (cutoff / bin).ceil() as i64, |other| 3f64.max(0.01 * other as f64), count)
        .into_iter()
        .map(|at| refine(&spectrum, at))
        .collect();
    found.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let Some(&(lowest, _)) = found.first() else { return vec![] };
    let top = found.iter().map(|(_, level)| *level).fold(f64::MIN, f64::max);
    found
        .iter()
        .map(|&(position, level)| {
            let hz = position * bin;
            let at = (hz / frame_bin).round() as usize;
            let track: Vec<f64> = frames.iter().map(|frame| db(peak_near(frame, at))).collect();
            let start = first_three_max(&track);
            let quietest = track.iter().cloned().fold(f64::INFINITY, f64::min);
            Partial { hz, ratio: position / lowest, level: level - top, ring: fade(times, &track, (start - 40.0).max(quietest + 10.0)) }
        })
        .collect()
}

fn start_spectrum(sound: &[f64], rate: f64, spectra: &mut Spectra) -> (Vec<f64>, Vec<f64>, f64, f64) {
    let power = ((sound.len() as f64).log2().floor() as i64).min((0.34 * rate).log2().round() as i64);
    let size = 2usize.pow(power as u32);
    let spectrum = spectra.take(sound, 0, size);
    let levels: Vec<f64> = spectrum.iter().map(|m| db(*m)).collect();
    let loudest = levels.iter().cloned().fold(f64::MIN, f64::max);
    (spectrum, levels, loudest, rate / size as f64)
}

// The bins of the loudest local peaks above `floor`, from `first` up, each apart from a stronger one kept.
fn strongest(levels: &[f64], floor: f64, first: i64, apart: impl Fn(usize) -> f64, count: usize) -> Vec<usize> {
    let mut candidates: Vec<usize> = (first.max(1) as usize..levels.len().saturating_sub(1))
        .filter(|&at| levels[at] > floor && levels[at] > levels[at - 1] && levels[at] >= levels[at + 1])
        .collect();
    candidates.sort_by(|a, b| levels[*b].partial_cmp(&levels[*a]).unwrap());
    let mut kept: Vec<usize> = vec![];
    for at in candidates {
        let apart_from_all = kept.iter().all(|&other| (at as f64 - other as f64).abs() > apart(other));
        if apart_from_all && kept.len() < count {
            kept.insert(0, at);
        }
    }
    kept
}

fn peak_near(frame: &[f64], at: usize) -> f64 {
    (at.saturating_sub(1)..=(at + 1).min(frame.len() - 1)).map(|near| frame[near]).fold(f64::MIN, f64::max)
}
