//! Struck notes in a recording that holds one or a run of them, for `mix mx.fit`: where each starts and ends, which note it is, and whether it sounds where its name says.

use super::partials::peak_near;
use super::{db, first_max, high_pass, hz};
use rustfft::{FftPlanner, num_complex::Complex};
use rustler::NifMap;

/// The seconds a note of a run starts at least after the one before.
const GAP: f64 = 0.4;
/// The dB below the run's loudest a note may start at, and the dB it rises by over the 200 ms before, less than a lone note's 20 since a soft strike rises over the bar still ringing before it.
const WITHIN: f64 = 50.0;
const RISE: f64 = 12.0;
/// The dB under a run's middle note a sound is too quiet to be one, and the dB under the note before it a sound that is not a note belongs to that note's ring.
const QUIET: f64 = 30.0;
const UNDER: f64 = 20.0;
/// The seconds after a strike the pitch is read from, and for how long.
const AFTER: f64 = 0.03;
const READ: f64 = 0.25;

/// A note found in a recording: the samples it spans, the note it is, its pitch in Hz, and why it is left out, if it is.
#[derive(NifMap, Debug)]
pub struct Piece {
    pub from: usize,
    pub to: usize,
    pub note: i64,
    pub pitch: f64,
    pub left_out: Option<String>,
}

/// The notes of a recording that holds one of `notes`, or a run of them, each the note among them whose fundamental stands loudest.
/// A note that sounds an octave away from the one found, or more than a quarter tone from it, or that was found already, is left out and says why.
/// In a run, a sound that is not a note and stands `UNDER` dB below the note before it, such as a finger on a string, is part of that note's ring.
/// Held notes, bowed or blown, swell rather than strike, so with `held` a note starts where the sound comes out of the quiet between notes instead.
pub fn split(sound: &[f64], rate: f64, notes: &[i64], held: bool) -> Vec<Piece> {
    let lowest = notes.iter().cloned().min().unwrap_or(60);
    let filtered = || high_pass(sound, rate, hz(lowest as f64) * 0.75);
    let starts = if notes.len() == 1 {
        vec![0]
    } else if held {
        held_starts(&filtered(), rate)
    } else {
        starts(&filtered(), rate)
    };
    let ends: Vec<usize> = starts.iter().skip(1).cloned().chain([sound.len()]).collect();
    let found: Vec<(Piece, f64)> = starts
        .iter()
        .zip(&ends)
        .filter_map(|(&from, &to)| {
            let (spectrum, bin) = spectrum(&sound[from..to], rate)?;
            let level = |freq: f64| level_near(&spectrum, bin, freq);
            // No two of a run's notes are an octave apart, so the loudest fundamental names the note, for bars whose partials are not harmonics as for strings.
            let note = first_max(notes.iter().cloned(), |n| level(hz(*n as f64))).unwrap();
            let pitch = pitch(&spectrum, bin, hz(note as f64), rate);
            let left_out = octave(&level, hz(note as f64), rate).or_else(|| {
                let cents = 1200.0 * (pitch / hz(note as f64)).log2();
                (cents.abs() > 50.0).then(|| format!("sounds {cents:+.0} cents from it"))
            });
            Some((Piece { from, to, note, pitch, left_out }, spectrum.iter().cloned().fold(0.0, f64::max)))
        })
        .collect();
    let mut loudnesses: Vec<f64> = found.iter().map(|(_, loudness)| *loudness).collect();
    loudnesses.sort_by(f64::total_cmp);
    let typical = loudnesses.get(loudnesses.len() / 2).cloned().unwrap_or(1.0);
    let mut pieces: Vec<(Piece, f64)> = vec![];
    for (mut piece, loudness) in found {
        let under = db(typical / loudness);
        if under > QUIET {
            piece.left_out = Some(format!("is {under:.0} dB under the run's middle note"));
        }
        match pieces.last_mut() {
            Some((before, loud)) if piece.left_out.is_some() && db(*loud / loudness) > UNDER => {
                before.to = piece.to;
                continue;
            }
            // A rise within a note as loud as its strike or quieter is the same bar still ringing, so it joins the note; a louder one strikes it again, and only that strike is kept.
            Some((before, loud)) if before.note == piece.note && before.left_out.is_none() && piece.left_out.is_none() => {
                if loudness <= *loud {
                    before.to = piece.to;
                    continue;
                }
                before.left_out = Some("was struck again, louder".to_string());
            }
            _ => {}
        }
        pieces.push((piece, loudness));
    }
    // A note found twice keeps its louder sound, so a click or a second strike does not stand in for it.
    for i in 0..pieces.len() {
        let again = pieces.iter().enumerate().any(|(j, (other, loudness))| j != i && other.note == pieces[i].0.note && other.left_out.is_none() && (*loudness > pieces[i].1 || (*loudness == pieces[i].1 && j < i)));
        if again && pieces[i].0.left_out.is_none() {
            pieces[i].0.left_out = Some("was found already, louder".to_string());
        }
    }
    pieces.into_iter().map(|(piece, _)| piece).collect()
}

// The sample each note starts at: a 5 ms level within `WITHIN` dB of the loudest that rises `RISE` dB over the quietest of the 200 ms before it, at least `GAP` seconds after the one before.
// Before the recording counts as the quietest it holds, and a rise is a strike only where its first 50 ms come within 6 dB of the loudest of the gap after it, so a wobble of the room before a strike is not a note.
fn starts(sound: &[f64], rate: f64) -> Vec<usize> {
    let hop = (rate * 0.005).round() as usize;
    let levels: Vec<f64> = sound.chunks(hop).map(|chunk| db((chunk.iter().map(|x| x * x).sum::<f64>() / hop as f64).sqrt())).collect();
    let loudest = levels.iter().cloned().fold(f64::MIN, f64::max);
    let quietest = levels.iter().cloned().fold(f64::MAX, f64::min);
    let before = 40;
    let mut found: Vec<usize> = vec![];
    // The filter's edge at the first sample reads as a click, so the first 10 ms are not looked at.
    for (frame, level) in levels.iter().enumerate().skip(2) {
        let lowest = levels[frame.saturating_sub(before)..frame].iter().cloned().chain((frame < before).then_some(quietest)).fold(f64::MAX, f64::min);
        let (soon, later) = (frame + 10, frame + (GAP / 0.005) as usize);
        let top = |end: usize| levels[frame..end.min(levels.len())].iter().cloned().fold(f64::MIN, f64::max);
        let rises = *level > loudest - WITHIN && level - lowest > RISE && top(soon) > top(later) - 6.0;
        if rises && found.last().is_none_or(|last| (frame - last) as f64 * 0.005 > GAP) {
            found.push(frame);
        }
    }
    found.into_iter().map(|frame| frame * hop).collect()
}

// The sample each held note's stretch starts at: 0.1 seconds before its 5 ms level first stands 15 dB over the recording's quiet and within 35 dB of its loudest, after at least `GAP` seconds under that.
// The quiet is the tenth of the levels that are not digital silence, so the step from silence up to the room's noise is not a note.
fn held_starts(sound: &[f64], rate: f64) -> Vec<usize> {
    let hop = (rate * 0.005).round() as usize;
    let levels: Vec<f64> = sound.chunks(hop).map(|chunk| db((chunk.iter().map(|x| x * x).sum::<f64>() / hop as f64).sqrt())).collect();
    let loudest = levels.iter().cloned().fold(f64::MIN, f64::max);
    let mut heard: Vec<f64> = levels.iter().cloned().filter(|l| *l > -150.0).collect();
    heard.sort_by(f64::total_cmp);
    let quiet = heard.get(heard.len() / 10).cloned().unwrap_or(-150.0);
    let threshold = (quiet + 15.0).max(loudest - 35.0);
    let gap = (GAP / 0.005) as usize;
    let mut found: Vec<usize> = vec![];
    let mut under = gap;
    for (frame, level) in levels.iter().enumerate().skip(2) {
        if *level > threshold {
            if under >= gap {
                found.push(frame.saturating_sub(20));
            }
            under = 0;
        } else {
            under += 1;
        }
    }
    found.into_iter().map(|frame| frame * hop).collect()
}

// Why a note does not sound at `f0`: its odd harmonics all far under its even ones, so it sounds an octave above, or peaks halfway between its harmonics as loud as they are, so it sounds an octave below.
fn octave(level: &impl Fn(f64) -> f64, f0: f64, rate: f64) -> Option<String> {
    // Below 25 Hz a recording holds rumble rather than a note.
    let loudest = |ratios: &[f64]| ratios.iter().filter(|r| *r * f0 < 0.45 * rate && *r * f0 >= 25.0).map(|r| level(r * f0)).fold(f64::MIN, f64::max);
    let (odd, even, half) = (loudest(&[1.0, 3.0, 5.0]), loudest(&[2.0, 4.0, 6.0]), loudest(&[0.5, 1.5, 2.5]));
    if odd < even - 25.0 {
        Some("sounds an octave above it".to_string())
    } else if half > odd.max(even) - 12.0 {
        Some("sounds an octave below it".to_string())
    } else {
        None
    }
}

// The pitch from the loudest of the first four harmonics within 6 percent of `f0`'s, its peak refined by a parabola through its log magnitudes.
fn pitch(spectrum: &[f64], bin: f64, f0: f64, rate: f64) -> f64 {
    let peaks = (1..=4).filter(|k| *k as f64 * f0 < 0.45 * rate).map(|k| {
        let (freq, level) = peak_near(spectrum, bin, k as f64 * f0, 0.06 * k as f64 * f0);
        (freq / k as f64, level)
    });
    first_max(peaks, |(_, level)| *level).map_or(f0, |(freq, _)| freq)
}

// The level in dB of the loudest bin within 1.5 percent of `freq`.
fn level_near(spectrum: &[f64], bin: f64, freq: f64) -> f64 {
    let low = ((freq * 0.985 / bin).floor() as usize).max(1);
    let high = ((freq * 1.015 / bin).ceil() as usize).min(spectrum.len() - 1).max(low);
    db(spectrum[low..=high].iter().cloned().fold(0.0, f64::max))
}

// The magnitude spectrum through a Hann window over a quarter second from just after the strike, the strike being the first sample within 20 dB of the sound's peak, and the width of a bin.
fn spectrum(sound: &[f64], rate: f64) -> Option<(Vec<f64>, f64)> {
    let peak = sound.iter().fold(0.0f64, |top, v| top.max(v.abs()));
    let struck = sound.iter().position(|v| v.abs() > peak * 0.1)?;
    let from = struck + (AFTER * rate) as usize;
    let window = ((READ * rate) as usize).min(sound.len().saturating_sub(from));
    if window < (0.05 * rate) as usize {
        return None;
    }
    let size = (4 * window).next_power_of_two();
    let mut buffer: Vec<Complex<f64>> = (0..size)
        .map(|i| {
            let x = if i < window { sound[from + i] * (0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / window as f64).cos()) } else { 0.0 };
            Complex::new(x, 0.0)
        })
        .collect();
    FftPlanner::<f64>::new().plan_fft_forward(size).process(&mut buffer);
    Some((buffer[..size / 2].iter().map(|c| c.norm()).collect(), rate / size as f64))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tone(rate: f64, seconds: f64, f0: f64, harmonics: &[(f64, f64)]) -> Vec<f64> {
        (0..(seconds * rate) as usize)
            .map(|i| {
                let t = i as f64 / rate;
                let rise = (t / 0.002).min(1.0);
                harmonics.iter().map(|(k, a)| a * (2.0 * std::f64::consts::PI * k * f0 * t).sin()).sum::<f64>() * rise * (-2.0 * t).exp()
            })
            .collect()
    }

    fn run(rate: f64, notes: &[(f64, &[(f64, f64)])]) -> Vec<f64> {
        let mut sound = vec![0.0; (0.2 * rate) as usize];
        for (f0, harmonics) in notes {
            sound.extend(tone(rate, 1.5, *f0, harmonics));
        }
        sound
    }

    const STRING: &[(f64, f64)] = &[(1.0, 0.5), (2.0, 0.3), (3.0, 0.2), (4.0, 0.1), (5.0, 0.05)];

    // Held notes swelling in over 0.3 seconds, with digital silence then a room's noise 56 dB down between them, as the University of Iowa's runs have.
    fn held_run(rate: f64, notes: &[f64]) -> Vec<f64> {
        let mut seed = 7u64;
        let mut room = |n: usize| -> Vec<f64> {
            (0..n)
                .map(|_| {
                    seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
                    1.6e-3 * ((seed >> 11) as f64 / (1u64 << 53) as f64 * 2.0 - 1.0)
                })
                .collect()
        };
        let mut sound = vec![];
        for f0 in notes {
            sound.extend(vec![0.0; (0.5 * rate) as usize]);
            sound.extend(room((0.6 * rate) as usize));
            sound.extend((0..(1.5 * rate) as usize).map(|i| {
                let t = i as f64 / rate;
                STRING.iter().map(|(k, a)| a * (2.0 * std::f64::consts::PI * k * f0 * t).sin()).sum::<f64>() * (t / 0.3).min(1.0) * 0.3
            }));
            sound.extend(room((0.6 * rate) as usize));
        }
        sound
    }

    #[test]
    fn a_run_of_held_notes_starts_each_where_it_comes_out_of_the_quiet_not_where_the_room_comes_in() {
        let rate = 48000.0;
        let sound = held_run(rate, &[hz(60.0), hz(62.0), hz(64.0)]);
        let pieces = split(&sound, rate, &(60..=64).collect::<Vec<_>>(), true);
        let found: Vec<(i64, bool)> = pieces.iter().map(|p| (p.note, p.left_out.is_none())).collect();
        assert_eq!(found, vec![(60, true), (62, true), (64, true)], "{pieces:?}");
        let each = (3.2 * rate) as usize;
        for (k, piece) in pieces.iter().enumerate() {
            let swell = k * each + (1.1 * rate) as usize;
            assert!(piece.from < swell && swell - piece.from < (0.15 * rate) as usize, "{piece:?}");
        }
    }

    #[test]
    fn a_run_is_split_into_its_notes_by_their_harmonics_not_their_order() {
        let rate = 48000.0;
        let sound = run(rate, &[(hz(60.0), STRING), (hz(62.0), STRING), (hz(61.0), STRING)]);
        let pieces = split(&sound, rate, &(60..=71).collect::<Vec<_>>(), false);
        let found: Vec<i64> = pieces.iter().map(|p| p.note).collect();
        assert_eq!(found, vec![60, 62, 61]);
        assert!(pieces.iter().all(|p| p.left_out.is_none()), "{pieces:?}");
        assert!((pieces[1].pitch / hz(62.0) - 1.0).abs() < 0.002);
    }

    #[test]
    fn a_note_with_only_the_even_harmonics_of_its_name_sounds_an_octave_above() {
        let rate = 48000.0;
        let sound = tone(rate, 1.5, hz(60.0), &[(2.0, 0.5), (4.0, 0.3), (6.0, 0.2)]);
        let pieces = split(&sound, rate, &[48], false);
        assert_eq!(pieces[0].left_out.as_deref(), Some("sounds an octave above it"));
        assert!(split(&sound, rate, &[72], false)[0].left_out.is_none());
    }

    #[test]
    fn a_note_named_an_octave_too_high_sounds_an_octave_below() {
        let rate = 48000.0;
        let sound = tone(rate, 1.5, hz(48.0), STRING);
        assert_eq!(split(&sound, rate, &[60], false)[0].left_out.as_deref(), Some("sounds an octave below it"));
    }

    #[test]
    fn a_note_found_twice_keeps_its_louder_sound() {
        let rate = 48000.0;
        let soft: Vec<(f64, f64)> = STRING.iter().map(|(k, a)| (*k, a * 0.1)).collect();
        let sound = run(rate, &[(hz(60.0), &soft), (hz(60.0), STRING), (hz(62.0), STRING)]);
        let pieces = split(&sound, rate, &(60..=62).collect::<Vec<_>>(), false);
        let kept: Vec<i64> = pieces.iter().filter(|p| p.left_out.is_none()).map(|p| p.note).collect();
        assert_eq!(kept, vec![60, 62]);
        assert_eq!(pieces[0].left_out.as_deref(), Some("was struck again, louder"));
    }
}
