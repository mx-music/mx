//! The picture `mix mx.spectrogram` draws: a recording's data to one channel of samples, and the samples to rows of pixels.

use rustfft::{FftPlanner, num_complex::Complex};

const FFT: usize = 4096;
const LOW: f64 = 20.0;
const OCTAVES: usize = 10;
const PER_OCTAVE: usize = 48;
const RANGE: f64 = 100.0;
const HEIGHT: usize = OCTAVES * PER_OCTAVE;

type Decode<'a> = Box<dyn Fn(&[u8]) -> f64 + 'a>;

/// One channel of samples from -1 to 1, from `count` frames of a recording's data starting at frame `from`, or None for a kind of data mx does not read.
/// Several channels are averaged, and the kinds are those `Mx.Audio` names.
pub fn samples(data: &[u8], kind: &str, bits: usize, channels: usize, from: usize, count: usize) -> Option<Vec<f64>> {
    let integer = |bytes: &mut dyn Iterator<Item = u8>| {
        let raw = bytes.fold(0i64, |value, byte| value << 8 | byte as i64);
        let shift = 64 - bits;
        ((raw << shift) >> shift) as f64 / (1u64 << (bits - 1)) as f64
    };
    let value: Decode = match (kind, bits) {
        ("unsigned", 8) => Box::new(|b| (b[0] as f64 - 128.0) / 128.0),
        ("little", 8 | 16 | 24 | 32) => Box::new(move |b| integer(&mut b.iter().rev().copied())),
        ("big", 8 | 16 | 24 | 32) => Box::new(move |b| integer(&mut b.iter().copied())),
        ("float_little", 32) => Box::new(|b| f32::from_le_bytes(b.try_into().unwrap()) as f64),
        ("float_little", 64) => Box::new(|b| f64::from_le_bytes(b.try_into().unwrap())),
        ("float_big32", 32) => Box::new(|b| f32::from_be_bytes(b.try_into().unwrap()) as f64),
        ("float_big64", 64) => Box::new(|b| f64::from_be_bytes(b.try_into().unwrap())),
        _ => return None,
    };
    let bytes = bits / 8;
    let frames = data.chunks_exact(bytes * channels.max(1)).skip(from).take(count);
    Some(frames.map(|frame| frame.chunks_exact(bytes).map(&value).sum::<f64>() / channels as f64).collect())
}

/// The spectrogram of a sound as 480 rows of `width` RGB pixels, from the top.
/// Column `c` starts at sample `c * hop` and holds the spectrum of `size` samples; a column that covers more sound than that holds the loudest level each frequency reaches in the sound it covers.
/// `per_second` is the columns a second takes, for a line at each second, or None for no such lines.
pub fn draw(sound: &[f64], rate: f64, width: usize, hop: f64, size: usize, per_second: Option<f64>) -> Vec<u8> {
    let size = size.clamp(1, FFT);
    let step = (size / 2).max(1);
    let bins: Vec<f64> = (0..HEIGHT).rev().map(|row| LOW * 2f64.powf(row as f64 / PER_OCTAVE as f64) / (rate / FFT as f64)).collect();
    let window: Vec<f64> = (0..size).map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / size as f64).cos()).collect();
    let fft = FftPlanner::<f64>::new().plan_fft_forward(FFT);
    let (bins, window, fft) = (&bins, &window, &fft);

    let mut levels = vec![0.0f64; width * HEIGHT];
    let threads = std::thread::available_parallelism().map_or(1, |n| n.get());
    let each = width.div_ceil(threads).max(1);
    std::thread::scope(|scope| {
        for (chunk, columns) in levels.chunks_mut(each * HEIGHT).enumerate() {
            scope.spawn(move || {
                let mut buffer = vec![Complex::new(0.0, 0.0); FFT];
                let mut scratch = vec![Complex::new(0.0, 0.0); fft.get_inplace_scratch_len()];
                let mut loudest = vec![0.0f64; FFT / 2];
                for (index, column) in columns.chunks_mut(HEIGHT).enumerate() {
                    let left = (chunk * each + index) as f64;
                    let from = (left * hop).round() as usize;
                    let until = if hop > size as f64 { ((left + 1.0) * hop).round() as usize } else { from + 1 };
                    loudest.fill(0.0);
                    for at in (from..until).step_by(step) {
                        for (i, slot) in buffer.iter_mut().enumerate() {
                            let sample = if i < size { sound.get(at + i).copied().unwrap_or(0.0) * window[i] } else { 0.0 };
                            *slot = Complex::new(sample, 0.0);
                        }
                        fft.process_with_scratch(&mut buffer, &mut scratch);
                        for (held, bin) in loudest.iter_mut().zip(&buffer) {
                            *held = held.max(bin.norm());
                        }
                    }
                    for (level, &position) in column.iter_mut().zip(bins) {
                        let below = (position.floor() as usize).min(FFT / 2 - 2);
                        let magnitude = loudest[below] + (position - below as f64) * (loudest[below + 1] - loudest[below]);
                        *level = 20.0 * (magnitude.max(0.0) + 1.0e-12).log10();
                    }
                }
            });
        }
    });

    let loudest = levels.iter().copied().fold(f64::MIN, f64::max);
    let mut pixels = vec![0u8; width * HEIGHT * 3];
    for (left, column) in levels.chunks(HEIGHT).enumerate() {
        let second = per_second.is_some_and(|per| left == 0 || (left as f64 / per).floor() != ((left - 1) as f64 / per).floor());
        for (top, &level) in column.iter().enumerate() {
            let line = (HEIGHT - 1 - top).is_multiple_of(PER_OCTAVE) || second;
            let at = (top * width + left) * 3;
            pixels[at..at + 3].copy_from_slice(&pixel(level - loudest, line));
        }
    }
    pixels
}

// Black through purple and orange to pale yellow as the level rises.
fn pixel(db: f64, line: bool) -> [u8; 3] {
    let loudness = ((db + RANGE) / RANGE).clamp(0.0, 1.0);
    let blue = if loudness < 0.4 { loudness * 1.5 } else { (0.6 - (loudness - 0.4) * 1.5).max(0.0) + (loudness - 0.85).max(0.0) * 4.0 };
    let rgb = [channel(loudness * 1.6), channel(loudness * 1.6 - 0.6), channel(blue)];
    if line { rgb.map(|c| c.max(60)) } else { rgb }
}

fn channel(level: f64) -> u8 {
    (255.0 * level.clamp(0.0, 1.0)).round() as u8
}
