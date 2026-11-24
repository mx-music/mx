//! The room a recording of struck notes was made in, for `mix mx.fit --struck`: the power its hiss and rumble add to every band, which the fit and the check add to a render before comparing it with the recording.
//! In each ERB band it is the mean power over the quietest twentieth of the whole file's frames, so a band is read where no note sounds in it, even when the notes ring into one another or one note takes most of the file.
//! The quietest frames of a steady noise read under its mean, the more so the narrower the band, so each band's mean is brought back up by what the same share of its spread reads, as minimum statistics estimate noise (Martin, Noise power spectral density estimation based on optimal smoothing and minimum statistics, IEEE Transactions on Speech and Audio Processing, 2001).
//! A file that falls silent anywhere, as one made rather than recorded does, has no room.

use super::fit::{band_power, erb_bands_to};
use super::partials;
use rustfft::{FftPlanner, num_complex::Complex};

/// The share of a file's frames, quietest first, whose mean power in a band is the room's there.
const QUIETEST: f64 = 0.05;
/// The power at or under which a frame holds nothing, as between made notes.
const NOTHING: f64 = 1e-20;

#[derive(Clone)]
pub struct Room {
    /// Each band's edges in Hz and the room's power over it, as a band's power reads in the measuring.
    bands: Vec<(f64, f64, f64)>,
    bin: f64,
}

impl Room {
    /// The room of a whole file, through the window a note at `f0` is measured with, or none where the file falls silent.
    pub fn measure(file: &[f64], rate: f64, f0: f64) -> Option<Room> {
        let window = partials::window(rate, f0);
        if file.len() < 2 * window {
            return None;
        }
        let size = (2 * window).next_power_of_two();
        let fft = FftPlanner::<f64>::new().plan_fft_forward(size);
        let hann: Vec<f64> = (0..window).map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / window as f64).cos()).collect();
        let norm = hann.iter().sum::<f64>() / 2.0;
        let bin = rate / size as f64;
        let grid = erb_bands_to(0.45 * rate);
        let mut powers = vec![vec![]; grid.len()];
        let mut buffer = vec![Complex::new(0.0, 0.0); size];
        let mut scratch = vec![Complex::new(0.0, 0.0); fft.get_inplace_scratch_len()];
        for start in (0..=file.len() - window).step_by(window / 2) {
            for (i, slot) in buffer.iter_mut().enumerate() {
                *slot = if i < window { Complex::new(file[start + i] * hann[i], 0.0) } else { Complex::new(0.0, 0.0) };
            }
            fft.process_with_scratch(&mut buffer, &mut scratch);
            let frame: Vec<f64> = buffer[..size / 2].iter().map(|c| c.norm() / norm).collect();
            let mut total = 0.0;
            for (band, (low, high)) in powers.iter_mut().zip(&grid) {
                let power = band_power(&frame, bin, *low, *high);
                total += power;
                band.push(power);
            }
            if total <= NOTHING {
                return None;
            }
        }
        let bands: Vec<(f64, f64, f64)> = grid
            .iter()
            .zip(powers)
            .map(|((low, high), mut band)| {
                band.sort_by(f64::total_cmp);
                let count = ((band.len() as f64 * QUIETEST).ceil() as usize).max(1);
                let power = band[..count].iter().sum::<f64>() / count as f64;
                (*low, *high, power / quietest_share(spread(high - low, window, rate)))
            })
            .collect();
        Some(Room { bands, bin })
    }

    /// The room's power over a band from `low` to `high` Hz, as the band's power reads in the measuring: each of the room's bands counting for the share of it inside.
    pub fn band(&self, low: f64, high: f64) -> f64 {
        self.bands.iter().map(|(a, b, power)| power * ((b.min(high) - a.max(low)) / (b - a)).max(0.0)).sum()
    }

    /// The room's power a partial at `freq` reads in: one bin's share of the room's band there.
    pub fn at(&self, freq: f64) -> f64 {
        let (low, high, power) = self.bands.iter().find(|(_, high, _)| freq < *high).or(self.bands.last()).copied().unwrap_or((0.0, 1.0, 0.0));
        power * self.bin / (high - low)
    }
}

/// The shape of the gamma distribution a band's power over a frame follows for a steady noise, which grows with how many independent squares it sums.
/// Over a band `b` bins of the window wide, its mean is `b` and its variance the double integral over the band of the squared correlation between two of its frequencies, so the shape is `b` squared over that integral: 1 for a single bin, and `b` over 35/18 for a wide band through a Hann window.
fn spread(width: f64, window: usize, rate: f64) -> f64 {
    let b = width * window as f64 / rate;
    // The correlation's square is all but gone 64 bins apart.
    let reach = b.min(64.0);
    let steps = (reach / 0.005).ceil().max(1.0) as usize;
    let step = reach / steps as f64;
    let integral: f64 = (0..steps).map(|i| (i as f64 + 0.5) * step).map(|u| 2.0 * (b - u) * correlation(u).powi(2) * step).sum();
    (b * b / integral).max(1.0)
}

/// The correlation between a Hann window's transforms of a noise at two frequencies `u` bins apart: the transform of the squared window, from its three cosines.
fn correlation(u: f64) -> f64 {
    let sinc = |x: f64| if x.abs() < 1e-9 { 1.0 } else { (std::f64::consts::PI * x).sin() / (std::f64::consts::PI * x) };
    (0.375 * sinc(u) - 0.25 * (sinc(u - 1.0) + sinc(u + 1.0)) + 0.0625 * (sinc(u - 2.0) + sinc(u + 2.0))) / 0.375
}

/// The mean of the quietest share of a gamma distribution of shape `k` and mean 1.
/// Below the share's edge `q`, the distribution's mean is that of the gamma of shape `k + 1` up to `q`.
fn quietest_share(k: f64) -> f64 {
    let (mut low, mut high) = (0.0, 1.0);
    while lower_gamma(k, k * high) < QUIETEST {
        high *= 2.0;
    }
    for _ in 0..60 {
        let middle = 0.5 * (low + high);
        if lower_gamma(k, k * middle) < QUIETEST { low = middle } else { high = middle }
    }
    lower_gamma(k + 1.0, k * low) / QUIETEST
}

/// The regularized lower incomplete gamma function, by its series.
fn lower_gamma(a: f64, x: f64) -> f64 {
    if x <= 0.0 {
        return 0.0;
    }
    let (mut term, mut sum, mut n) = (1.0 / a, 1.0 / a, a);
    while term > sum * 1e-15 {
        n += 1.0;
        term *= x / n;
        sum += term;
    }
    (sum.ln() + a * x.ln() - x - ln_gamma(a)).exp()
}

/// The logarithm of the gamma function, by Lanczos's approximation.
fn ln_gamma(x: f64) -> f64 {
    const G: [f64; 9] = [0.999_999_999_999_809_9, 676.520_368_121_885_1, -1_259.139_216_722_402_8, 771.323_428_777_653_1, -176.615_029_162_140_6, 12.507_343_278_686_905, -0.138_571_095_265_720_1, 9.984_369_578_019_572e-6, 1.505_632_735_149_311_6e-7];
    let x = x - 1.0;
    let t = x + 7.5;
    let sum = G[0] + G[1..].iter().enumerate().map(|(i, g)| g / (x + i as f64 + 1.0)).sum::<f64>();
    0.5 * (2.0 * std::f64::consts::PI).ln() + (x + 0.5) * t.ln() - t + sum.ln()
}

/// The room's power over each band, or none where there is no room.
pub fn over(room: Option<&Room>, bands: &[(f64, f64)]) -> Vec<f64> {
    bands.iter().map(|(low, high)| room.map_or(0.0, |room| room.band(*low, *high))).collect()
}

/// The room's power at a partial's frequency, or none where there is no room.
pub fn at(room: Option<&Room>, freq: f64) -> f64 {
    room.map_or(0.0, |room| room.at(freq))
}

/// A level in dB with a power added, as the room adds to what is heard; the level itself where the power is none.
pub fn with(level: f64, power: f64) -> f64 {
    if power > 0.0 { 10.0 * (10f64.powf(level / 10.0) + power).log10() } else { level }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_quietest_share_of_an_exponential_reads_as_its_distribution_gives() {
        let q = -((1.0 - QUIETEST).ln());
        let wanted = (1.0 - (-q).exp() * (1.0 + q)) / QUIETEST;
        assert!((quietest_share(1.0) - wanted).abs() < 1e-9);
    }

    #[test]
    fn one_bin_spreads_as_an_exponential_and_a_wide_band_as_35_18ths_of_a_bin_a_square() {
        assert!((spread(1e-3, 1000, 1000.0) - 1.0).abs() < 1e-3);
        assert!((spread(2000.0, 1000, 10000.0) / (200.0 * 18.0 / 35.0) - 1.0).abs() < 0.03);
    }

    #[test]
    fn a_wide_band_reads_its_mean() {
        assert!(quietest_share(5000.0) > 0.97);
    }

    #[test]
    fn a_steady_noise_reads_its_power_in_every_band() {
        let rate = 48000.0;
        let mut state = 0x9e37_79b9_7f4a_7c15u64;
        let noise: Vec<f64> = (0..(rate * 60.0) as usize)
            .map(|_| {
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                (state >> 11) as f64 / (1u64 << 52) as f64 - 1.0
            })
            .collect();
        let room = Room::measure(&noise, rate, 261.6).unwrap();
        let window = partials::window(rate, 261.6) as f64;
        // Uniform noise from -1 to 1 has a power of a third; through a Hann window and its norm each bin reads 6 over the window's length of it, and the padded transform has twice the window's length over the rate bins a hertz.
        let per_hz = 6.0 / window / 3.0 * 2.0 * window / rate;
        for (low, high, power) in &room.bands {
            let wanted = per_hz * (high - low);
            assert!((10.0 * (power / wanted).log10()).abs() < 1.0, "{low:.0}-{high:.0} Hz: {power:e} for {wanted:e}");
        }
    }
}
