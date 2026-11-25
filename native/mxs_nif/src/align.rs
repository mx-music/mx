//! Lines a recording up against a score by the energy in each of the 12 pitch classes, for an import that takes a performance's timing and loudness.

use rustfft::{FftPlanner, num_complex::Complex};

/// The energy in each pitch class from 55 Hz to 4 kHz, of frames `hop` seconds apart, each scaled to length 1, and the second each frame starts at, which is where a note that fills it starts.
pub fn chroma(sound: &[f64], rate: f64, hop: f64) -> (Vec<[f64; 12]>, Vec<f64>) {
    let size = ((rate * 0.186) as usize).next_power_of_two();
    let step = ((rate * hop) as usize).max(1);
    if sound.len() < size {
        return (Vec::new(), Vec::new());
    }
    let window: Vec<f64> = (0..size)
        .map(|i| 0.5 - 0.5 * (std::f64::consts::TAU * i as f64 / size as f64).cos())
        .collect();
    let class: Vec<Option<usize>> = (0..size / 2)
        .map(|bin| {
            let hz = bin as f64 * rate / size as f64;
            (55.0..4000.0)
                .contains(&hz)
                .then(|| (12.0 * (hz / 440.0).log2() + 69.0).round().rem_euclid(12.0) as usize)
        })
        .collect();
    let fft = FftPlanner::new().plan_fft_forward(size);
    let mut frames = Vec::new();
    let mut starts = Vec::new();
    let mut buffer = vec![Complex::new(0.0, 0.0); size];
    let mut start = 0;
    while start + size <= sound.len() {
        for (slot, (x, w)) in buffer
            .iter_mut()
            .zip(sound[start..start + size].iter().zip(&window))
        {
            *slot = Complex::new(x * w, 0.0);
        }
        fft.process(&mut buffer);
        let mut energy = [0.0; 12];
        for (bin, pc) in class.iter().enumerate() {
            if let Some(pc) = pc {
                energy[*pc] += buffer[bin].norm_sqr();
            }
        }
        frames.push(energy);
        starts.push(start as f64 / rate);
        start += step;
    }
    let loudest = frames
        .iter()
        .flatten()
        .fold(0.0f64, |m, e| m.max(*e))
        .max(1e-12);
    for frame in &mut frames {
        for e in frame.iter_mut() {
            *e = (1.0 + 100.0 * *e / loudest).ln();
        }
        unit(frame);
    }
    (frames, starts)
}

/// Scales `frame` to length 1, leaving silence at 0.
pub fn unit(frame: &mut [f64; 12]) {
    let length = frame.iter().map(|e| e * e).sum::<f64>().sqrt();
    if length > 1e-9 {
        frame.iter_mut().for_each(|e| *e /= length);
    }
}

/// For each score frame, the recording frame that plays it, fractional where the path passes between two, and the cost there, 1 less the cosine of the two frames.
/// The path takes steps of one frame in each, two score frames to one recording frame, or one to two, so the recording plays from half to twice the score's speed.
/// It starts in the first `free` recording frames and ends where the cost along it, over its steps, is least: with the score, or with the recording, when the score goes on after it, and then only the frames the recording plays have a place.
pub fn path(score: &[[f64; 12]], recording: &[[f64; 12]], free: usize) -> (Vec<f64>, Vec<f64>) {
    let (n, m) = (score.len(), recording.len());
    if n == 0 || m == 0 {
        return (Vec::new(), Vec::new());
    }
    let cost = |i: usize, j: usize| {
        1.0 - score[i]
            .iter()
            .zip(&recording[j])
            .map(|(a, b)| a * b)
            .sum::<f64>()
    };
    let mut total = vec![f64::INFINITY; n * m];
    let mut steps = vec![0u32; n * m];
    for j in 0..free.min(m) {
        total[j] = cost(0, j);
        steps[j] = 1;
    }
    let at = |i: usize, j: usize| i * m + j;
    for i in 1..n {
        for j in 1..m {
            let mut best = (total[at(i - 1, j - 1)], steps[at(i - 1, j - 1)]);
            // Two score frames on one recording frame pay for both, so a path cannot lower its cost by skipping score.
            if i >= 2 && total[at(i - 2, j - 1)] + cost(i - 1, j) < best.0 {
                best = (
                    total[at(i - 2, j - 1)] + cost(i - 1, j),
                    steps[at(i - 2, j - 1)] + 1,
                );
            }
            if j >= 2 && total[at(i - 1, j - 2)] < best.0 {
                best = (total[at(i - 1, j - 2)], steps[at(i - 1, j - 2)]);
            }
            if best.0.is_finite() {
                total[at(i, j)] = best.0 + cost(i, j);
                steps[at(i, j)] = best.1 + 1;
            }
        }
    }
    // The path ends with the score, anywhere in the recording, or with the recording, anywhere in the score.
    let mean = |(i, j): &(usize, usize)| total[at(*i, *j)] / steps[at(*i, *j)] as f64;
    let end = (0..m)
        .map(|j| (n - 1, j))
        .chain((0..n).map(|i| (i, m - 1)))
        .filter(|(i, j)| total[at(*i, *j)].is_finite())
        .min_by(|a, b| mean(a).total_cmp(&mean(b)));
    let Some((last, mut j)) = end else {
        return (Vec::new(), Vec::new());
    };
    let mut frames = vec![0.0; last + 1];
    let mut i = last;
    frames[i] = j as f64;
    while i > 0 {
        let mut options = vec![(total[at(i - 1, j - 1)], i - 1, j - 1)];
        if i >= 2 {
            options.push((total[at(i - 2, j - 1)] + cost(i - 1, j), i - 2, j - 1));
        }
        if j >= 2 {
            options.push((total[at(i - 1, j - 2)], i - 1, j - 2));
        }
        let (_, before_i, before_j) = options
            .into_iter()
            .min_by(|a, b| a.0.total_cmp(&b.0))
            .unwrap();
        if before_i + 2 == i {
            frames[i - 1] = j as f64 - 0.5;
        }
        i = before_i;
        j = before_j;
        frames[i] = j as f64;
    }
    let costs = frames
        .iter()
        .enumerate()
        .map(|(i, j)| cost(i, j.round() as usize))
        .collect();
    (frames, costs)
}

/// The level of each slice of `seconds`, in dB, down to -120.
pub fn levels(sound: &[f64], rate: f64, seconds: f64) -> Vec<f64> {
    let size = ((rate * seconds) as usize).max(1);
    sound
        .chunks(size)
        .map(|slice| {
            let power = slice.iter().map(|x| x * x).sum::<f64>() / slice.len() as f64;
            (10.0 * power.log10()).max(-120.0)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tone(midis: &[(f64, f64)], rate: f64) -> Vec<f64> {
        let mut sound = Vec::new();
        for &(midi, seconds) in midis {
            let hz = 440.0 * 2f64.powf((midi - 69.0) / 12.0);
            sound.extend(
                (0..(seconds * rate) as usize)
                    .map(|i| (std::f64::consts::TAU * hz * i as f64 / rate).sin() * 0.3),
            );
        }
        sound
    }

    fn frame(class: usize) -> [f64; 12] {
        let mut frame = [0.0; 12];
        frame[class] = 1.0;
        frame
    }

    #[test]
    fn a_recording_that_stops_halfway_through_the_score_places_only_the_frames_it_plays() {
        let rate = 16000.0;
        let sound = tone(&[(60.0, 1.0), (62.0, 1.0)], rate);
        let (recording, _starts) = chroma(&sound, rate, 0.1);
        let score: Vec<[f64; 12]> = [0, 2, 4, 5]
            .iter()
            .flat_map(|c| std::iter::repeat_n(frame(*c), 10))
            .collect();
        let (frames, _costs) = path(&score, &recording, 5);
        assert!(
            (15..25).contains(&frames.len()),
            "{} frames placed",
            frames.len()
        );
    }

    #[test]
    fn a_scale_played_slower_than_written_lines_up_note_by_note() {
        let rate = 16000.0;
        let sound = tone(&[(60.0, 1.5), (62.0, 1.5), (64.0, 1.5), (65.0, 1.5)], rate);
        let (recording, starts) = chroma(&sound, rate, 0.1);
        let score: Vec<[f64; 12]> = [0, 2, 4, 5]
            .iter()
            .flat_map(|c| std::iter::repeat_n(frame(*c), 10))
            .collect();
        let (frames, _costs) = path(&score, &recording, 5);
        let second = |k: usize| starts[frames[k].round() as usize];
        for (note, starts) in [(1, 1.5), (2, 3.0), (3, 4.5)] {
            assert!(
                (second(note * 10) - starts).abs() < 0.2,
                "note {note} at {}",
                second(note * 10)
            );
        }
    }
}
