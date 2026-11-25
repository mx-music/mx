//! The spike of mx-00181: the start of a struck note as damped modes, each a sine with a frequency, a level, a rate of decay and a phase, so that two close modes beat and cancel as they do in a bar.
//! The modes are found band by band with ESPRIT, as Badeau, Boyer and David describe for exponentially damped sinusoids (DAFx 2002), and their levels and phases are then solved together over the sound itself.
//! Nothing in the fit, the check or the engine uses it.

use nalgebra::{Complex, DMatrix, DVector};
use std::f64::consts::PI;

/// A damped mode: its frequency in Hz, its level at the start in dB of a sine's amplitude, its slope in dB a second, falling below 0, and its phase at the start.
#[derive(Clone, Debug, rustler::NifMap)]
pub struct Mode {
    pub freq: f64,
    pub level: f64,
    pub slope: f64,
    pub phase: f64,
    /// A second term that grows with the time, as a repeated pole gives, so the mode can rise before it falls: its level at one second in dB had it not decayed, and its phase; under -200 dB when the modes have none.
    pub rise: f64,
    pub rise_phase: f64,
    /// The highest level the two terms reach together over the seconds measured, in dB.
    pub peak: f64,
}

impl Mode {
    /// Its value at `t` seconds after the start.
    pub fn at(&self, t: f64) -> f64 {
        let turn = 2.0 * PI * self.freq * t;
        let decay = 10f64.powf(self.slope * t / 20.0);
        decay
            * (10f64.powf(self.level / 20.0) * (turn + self.phase).cos()
                + t * 10f64.powf(self.rise / 20.0) * (turn + self.rise_phase).cos())
    }
}

/// The width in Hz of each band the modes are found in.
const WIDTH: f64 = 500.0;
/// The lowest frequency a mode is kept at: below it the recordings hold an offset and rumble, which go to the noise.
const LOWEST: f64 = 20.0;
/// How far under a band's strongest a singular value still counts as a mode, in dB.
const DEPTH: f64 = 50.0;

/// The modes of `sound` from its first sample, over `seconds` of it, up to `top` Hz, each with a rising term when `rising`.
pub fn modes(sound: &[f64], rate: f64, seconds: f64, top: f64, rising: bool) -> Vec<Mode> {
    let count = ((seconds * rate) as usize).min(sound.len());
    let sound = &sound[..count];
    let lows: Vec<f64> = (0..)
        .map(|k| k as f64 * WIDTH)
        .take_while(|low| *low < top.min(rate / 2.0))
        .collect();
    let bands: Vec<Band> = lows
        .iter()
        .map(|low| band(sound, rate, *low, low + WIDTH))
        .collect();
    // The modes are counted down to DEPTH under the strongest of the whole note, so a band holding only the noise floor gives none.
    let strongest = bands
        .iter()
        .filter_map(|b| b.hankel.as_ref().map(|(_, values)| values[0]))
        .fold(0.0, f64::max);
    let found: Vec<(f64, f64)> = bands
        .iter()
        .flat_map(|b| b.modes(strongest * 10f64.powf(-DEPTH / 20.0)))
        .collect();
    let solved = solve(sound, rate, &found, rising);
    let loudest = solved.iter().map(|m| m.peak).fold(f64::MIN, f64::max);
    // What the band filters let fold back comes out far under the loudest mode.
    solved
        .into_iter()
        .filter(|m| m.peak > loudest - 100.0)
        .collect()
}

/// The rendering of `modes` over `count` samples.
pub fn render(modes: &[Mode], rate: f64, count: usize) -> Vec<f64> {
    (0..count)
        .map(|i| modes.iter().map(|m| m.at(i as f64 / rate)).sum())
        .collect()
}

// One band of the sound, moved down to 0 Hz, kept to half its width either side through a windowed sinc, and taken one sample in `step`: its centre, edges and rate, and the left singular vectors and singular values of a Hankel matrix of its samples.
struct Band {
    low: f64,
    high: f64,
    centre: f64,
    rate: f64,
    hankel: Option<(DMatrix<Complex<f64>>, DVector<f64>)>,
}

impl Band {
    // The frequencies and decays, as the change of the natural log of the amplitude a second, of the modes in the band whose singular values stand above `floor`.
    // ESPRIT finds them as the rotation that moves the signal space of the Hankel matrix one sample on.
    fn modes(&self, floor: f64) -> Vec<(f64, f64)> {
        let Some((u, values)) = &self.hankel else {
            return vec![];
        };
        let rows = u.nrows();
        let order = values
            .iter()
            .take_while(|v| **v > floor)
            .count()
            .min(rows - 1);
        if order == 0 {
            return vec![];
        }
        let space = u.columns(0, order);
        let (above, below) = (
            space.rows(0, rows - 1).into_owned(),
            space.rows(1, rows - 1).into_owned(),
        );
        let Ok(rotation) = above.pseudo_inverse(1e-12) else {
            return vec![];
        };
        // A complex matrix's Schur form is triangular, with its eigenvalues on the diagonal.
        let (_, triangle) = (rotation * below).schur().unpack();
        triangle
            .diagonal()
            .iter()
            .map(|z| {
                (
                    self.centre + z.arg() * self.rate / (2.0 * PI),
                    z.norm().ln() * self.rate,
                )
            })
            .filter(|(freq, decay)| {
                *freq >= self.low.max(LOWEST) && *freq < self.high && decay.is_finite()
            })
            .collect()
    }
}

fn band(sound: &[f64], rate: f64, low: f64, high: f64) -> Band {
    let centre = (low + high) / 2.0;
    // The filter passes the band and a quarter of it either side, so a mode at an edge is not weakened, and the samples are taken at four times that, so what its Blackman window lets past does not fold back into the band.
    let pass = 0.75 * (high - low);
    let step = ((rate / (4.0 * pass)).floor() as usize).max(1);
    let taps = 16 * step + 1;
    let half = (taps / 2) as isize;
    let filter: Vec<f64> = (0..taps)
        .map(|k| {
            let x = (k as isize - half) as f64;
            let sinc = if x == 0.0 {
                1.0
            } else {
                (2.0 * PI * pass / rate * x).sin() / (PI * x) * rate / (2.0 * pass)
            };
            let turn = 2.0 * PI * k as f64 / (taps - 1) as f64;
            let window = 0.42 - 0.5 * turn.cos() + 0.08 * (2.0 * turn).cos();
            sinc * window * 2.0 * pass / rate
        })
        .collect();
    // Only samples whose filter lies wholly inside the sound are kept: where it reaches before the start, its own rise is no damped mode.
    // The levels and phases are solved over the whole sound afterwards, so nothing is lost by starting a few milliseconds late here.
    let first = (half as usize).div_ceil(step);
    let last = sound.len().saturating_sub(half as usize + 1) / step;
    let samples: Vec<Complex<f64>> = (first..last)
        .map(|j| {
            let at = (j * step) as isize;
            (0..taps)
                .map(|k| {
                    let i = (at + k as isize - half) as usize;
                    let phase = -2.0 * PI * centre * i as f64 / rate;
                    Complex::new(phase.cos(), phase.sin()) * sound[i] * filter[k]
                })
                .sum()
        })
        .collect();
    let rows = samples.len() / 3;
    let hankel = (rows >= 4).then(|| {
        let matrix = DMatrix::from_fn(rows, samples.len() - rows + 1, |i, j| samples[i + j]);
        let svd = matrix.svd(true, false);
        (svd.u.expect("left singular vectors"), svd.singular_values)
    });
    Band {
        low,
        high,
        centre,
        rate: rate / step as f64,
        hankel,
    }
}

// Each mode's level and phase, solved together over the sound for the frequencies and decays found.
fn solve(sound: &[f64], rate: f64, found: &[(f64, f64)], rising: bool) -> Vec<Mode> {
    if found.is_empty() {
        return vec![];
    }
    let terms = if rising { 4 } else { 2 };
    let basis = DMatrix::from_fn(sound.len(), terms * found.len(), |i, j| {
        let (freq, decay) = found[j / terms];
        let t = i as f64 / rate;
        let turn = 2.0 * PI * freq * t;
        let grown = if j % terms >= 2 { t } else { 1.0 };
        grown * (decay * t).exp() * if j % 2 == 0 { turn.cos() } else { turn.sin() }
    });
    let wanted = DVector::from_column_slice(sound);
    let Ok(weights) = basis.svd(true, true).solve(&wanted, 1e-12) else {
        return vec![];
    };
    found
        .iter()
        .enumerate()
        .map(|(k, (freq, decay))| {
            let (a, b) = (weights[terms * k], weights[terms * k + 1]);
            let (c, d) = if rising {
                (weights[terms * k + 2], weights[terms * k + 3])
            } else {
                (0.0, 0.0)
            };
            let level = |x: f64, y: f64| 20.0 * (x * x + y * y).sqrt().max(1e-12).log10();
            // The two terms as one complex amplitude, steady plus rising times t, under the decay.
            let peak = (0..=sound.len() / 64)
                .map(|k| {
                    let t = (k * 64) as f64 / rate;
                    ((Complex::new(a, -b) + Complex::new(c, -d) * t) * (decay * t).exp()).norm()
                })
                .fold(0.0, f64::max);
            Mode {
                freq: *freq,
                level: level(a, b),
                slope: 20.0 * decay / 10f64.ln(),
                phase: (-b).atan2(a),
                rise: level(c, d),
                rise_phase: (-d).atan2(c),
                peak: 20.0 * peak.max(1e-12).log10(),
            }
        })
        .collect()
}

/// One known partial as the modes within 1 percent of it give it: its frequency, whether there are any, the peak over the first 20 ms and the mean gap over the first 100 ms against the truth in dB, and the loudest one's error in cents.
#[derive(rustler::NifMap)]
pub struct KnownPartial {
    pub freq: f64,
    pub found: bool,
    pub first: f64,
    pub mean: f64,
    pub cents: f64,
}

/// One of mx-00177's known notes as the modes give it, measured from the strike today's measuring finds, with that strike's error in ms and the count of modes.
#[derive(rustler::NifMap)]
pub struct KnownModes {
    pub kind: String,
    pub note: f64,
    pub strike: f64,
    pub count: usize,
    pub partials: Vec<KnownPartial>,
}

/// mx-00177's notes with known partials, each measured as modes over 100 ms and compared with the truth in true time, so a strike found late shows in the first 20 ms.
pub fn known(rising: bool) -> Vec<KnownModes> {
    use super::known::{self as truth, BEFORE, KINDS, NOTES, QUIET, RATE};
    let pairs: Vec<(&str, f64)> = KINDS
        .iter()
        .flat_map(|k| NOTES.iter().map(move |n| (*k, *n)))
        .collect();
    super::parallel(&pairs, |(kind, note)| {
        let made = truth::made(kind, *note);
        let sound = truth::sound(&made);
        let onset = BEFORE * RATE;
        // The modes start at the strike: before it a damped mode cannot be silent.
        let start = super::partials::strike(&sound) as f64;
        let found = modes(&sound[start as usize..], RATE, 0.1, 10000.0, rising);
        // A mode's time starts where the measuring starts, `late` seconds after the true onset.
        let late = (start - onset) / RATE;
        let times: Vec<f64> = (0..=100).map(|ms| ms as f64 / 1000.0).collect();
        let partials = made
            .partials
            .iter()
            .map(|p| {
                // Every mode within 1 percent of the partial and nearer it than any other known partial, added with its frequency offset and phase, so a partial spread over several modes reads as their sum.
                let nearer = |m: &&Mode| {
                    made.partials
                        .iter()
                        .all(|q| (m.freq - p.freq).abs() <= (m.freq - q.freq).abs())
                };
                let near: Vec<&Mode> = found
                    .iter()
                    .filter(|m| (m.freq / p.freq - 1.0).abs() < 0.01)
                    .filter(nearer)
                    .collect();
                let Some(loudest) = near.iter().max_by(|a, b| a.level.total_cmp(&b.level)) else {
                    return KnownPartial {
                        freq: p.freq,
                        found: false,
                        first: 0.0,
                        mean: 0.0,
                        cents: 0.0,
                    };
                };
                let theirs = |t: f64| (p.level)(t).max(QUIET);
                let ours = |t: f64| {
                    let since = t - late;
                    if since < 0.0 {
                        return QUIET;
                    }
                    let sum: Complex<f64> = near
                        .iter()
                        .map(|m| {
                            let steady = Complex::from_polar(10f64.powf(m.level / 20.0), m.phase);
                            let rising = Complex::from_polar(
                                since * 10f64.powf(m.rise / 20.0),
                                m.rise_phase,
                            );
                            (steady + rising)
                                * 10f64.powf(m.slope * since / 20.0)
                                * Complex::from_polar(1.0, 2.0 * PI * (m.freq - p.freq) * since)
                        })
                        .sum();
                    (20.0 * sum.norm().max(1e-12).log10()).max(QUIET)
                };
                let top = |level: &dyn Fn(f64) -> f64| {
                    times
                        .iter()
                        .filter(|t| **t <= 0.02)
                        .map(|t| level(*t))
                        .fold(f64::MIN, f64::max)
                };
                // The mean starts at the strike found, where the modes start; a strike found late shows in the first 20 ms.
                let gaps: Vec<f64> = times
                    .iter()
                    .filter(|t| **t >= late && theirs(**t) > QUIET + 10.0)
                    .map(|t| (ours(*t) - theirs(*t)).abs())
                    .collect();
                KnownPartial {
                    freq: p.freq,
                    found: true,
                    first: top(&ours) - top(&theirs),
                    mean: gaps.iter().sum::<f64>() / gaps.len().max(1) as f64,
                    cents: 1200.0 * (loudest.freq / p.freq).log2(),
                }
            })
            .collect();
        KnownModes {
            kind: kind.to_string(),
            note: *note,
            strike: late * 1000.0,
            count: found.len(),
            partials,
        }
    })
}

/// A dip in a strong partial of the recording, as one partial's level every millisecond shows it through a 5 ms smoothing: its time after the strike in ms, the partial's frequency, and the recording's and the modes' level there in dB.
#[derive(rustler::NifMap)]
pub struct Dip {
    pub at: f64,
    pub freq: f64,
    pub recording: f64,
    pub modes: f64,
}

/// One recorded note's strike as modes, beside today's fit, for mx-00181.
#[derive(rustler::NifMap)]
pub struct Strike {
    pub pitch: f64,
    /// The second of the sound given that the strike was found at.
    pub strike: f64,
    pub modes: Vec<Mode>,
    /// The energy of the recording less the modes over the first 100 ms, in dB under the recording's.
    pub distance: f64,
    pub dips: Vec<Dip>,
    /// The ERB gap over the first 100 ms of the modes with noise fitted to what they leave, and of today's fit, in dB.
    pub erb: (f64, f64),
    /// For listening, from 50 ms before the strike for `HEARD` seconds: the recording, today's fit, and the modes with their noise handing over to today's fit at the end of their span.
    pub heard: (Vec<f32>, Vec<f32>, Vec<f32>),
    /// The struck check of today's fit's own render, and of that render with the modes and their noise in place of its first `span` seconds, handing over to it over the last 20 ms.
    pub checks: (super::fit::Check, super::fit::Check),
}

/// The seconds of each note in the recording for listening.
pub const HEARD: f64 = 1.5;

/// A recorded struck note's first `span` seconds as modes, with noise in ERB bands fitted to what they leave, beside today's fit of the same note, the two compared over the first 100 ms.
pub fn strike(
    sound: &[f64],
    rate: f64,
    note: f64,
    seconds: f64,
    exact: bool,
    span: f64,
    rising: bool,
) -> Strike {
    use super::fit::{self, band_filter, erb_bands};
    let start = super::partials::strike(sound);
    let compared = (0.1 * rate) as usize;
    let span = (span * rate) as usize;
    let segment: Vec<f64> = (0..span)
        .map(|i| sound.get(start + i).copied().unwrap_or(0.0))
        .collect();
    let found = modes(&segment, rate, span as f64 / rate, 12000.0, rising);
    let played = render(&found, rate, span);
    let left: Vec<f64> = segment.iter().zip(&played).map(|(a, b)| a - b).collect();
    let energy = |x: &[f64]| x.iter().map(|v| v * v).sum::<f64>();
    let distance = 10.0 * (energy(&left[..compared]) / energy(&segment[..compared])).log10();
    let bands = erb_bands();
    let filters: Vec<_> = bands
        .iter()
        .filter(|(_, high)| *high < rate / 2.0)
        .map(|(low, high)| band_filter(*low, *high, rate))
        .collect();
    // The noise of each band follows what the modes leave there, its level smoothed over 5 ms.
    let mut seed = 0x9e37_79b9_7f4a_7c15u64;
    let noise: Vec<f64> = filters.iter().fold(vec![0.0; span], |mut sum, filter| {
        let wanted = smoothed_level(&through(filter, &left), rate);
        let white: Vec<f64> = (0..span)
            .map(|_| {
                seed ^= seed << 13;
                seed ^= seed >> 7;
                seed ^= seed << 17;
                (seed >> 11) as f64 / (1u64 << 53) as f64 * 2.0 - 1.0
            })
            .collect();
        let banded = through(filter, &white);
        let own = smoothed_level(&banded, rate);
        for (i, x) in banded.iter().enumerate() {
            sum[i] += x * wanted[i] / own[i].max(1e-12);
        }
        sum
    });
    let ours: Vec<f64> = played.iter().zip(&noise).map(|(a, b)| a + b).collect();
    let (figures, _) = fit::fit(&fit::Recording {
        sound,
        rate,
        note,
        seconds,
        exact,
        top: super::partials::TOP,
        room: None,
    });
    let lead = 0.05;
    let today_whole = fit::render(&figures, rate, lead, seconds + 0.3);
    let today_start = super::partials::strike(&today_whole);
    let today: Vec<f64> = (0..span)
        .map(|i| today_whole.get(today_start + i).copied().unwrap_or(0.0))
        .collect();
    let erb = (
        band_gap(&segment[..compared], &ours[..compared], &filters, rate),
        band_gap(&segment[..compared], &today[..compared], &filters, rate),
    );
    let measured =
        super::partials::measure(sound, rate, note, seconds, exact, super::partials::TOP);
    let loudest = measured
        .partials
        .iter()
        .map(|t| t.strike(0.02))
        .fold(f64::MIN, f64::max);
    let dips = measured
        .partials
        .iter()
        .filter(|t| t.strike(0.02) > loudest - 30.0)
        .flat_map(|t| {
            let (theirs, mine) = (
                envelope(&segment[..compared], t.freq, rate),
                envelope(&played[..compared], t.freq, rate),
            );
            dips_of(&theirs).into_iter().map(move |ms| Dip {
                at: ms as f64,
                freq: t.freq,
                recording: theirs[ms],
                modes: mine[ms],
            })
        })
        .collect();
    // The listening parts start 50 ms before the strike; the modes hand over to today's fit over the last 20 ms of their span.
    let heard_len = (HEARD * rate) as usize;
    let before = (lead * rate) as usize;
    let from = |x: &[f64], at: usize| -> Vec<f64> {
        (0..heard_len)
            .map(|i| {
                (at + i)
                    .checked_sub(before)
                    .and_then(|k| x.get(k))
                    .copied()
                    .unwrap_or(0.0)
            })
            .collect()
    };
    let recording = from(sound, start);
    let today_heard = from(&today_whole, today_start);
    let handed: Vec<f64> = today_heard
        .iter()
        .enumerate()
        .map(|(i, later)| {
            let since = i as f64 / rate - lead;
            let k = (since * rate).round() as isize;
            let earlier = if k >= 0 && (k as usize) < span {
                ours[k as usize]
            } else {
                0.0
            };
            let fade = ((since - (span as f64 / rate - 0.02)) / 0.02).clamp(0.0, 1.0);
            if since < 0.0 {
                0.0
            } else {
                earlier * (1.0 - fade) + later * fade
            }
        })
        .collect();
    let fade = |k: usize| ((k as f64 / rate - (span as f64 / rate - 0.02)) / 0.02).clamp(0.0, 1.0);
    let handed_whole: Vec<f64> = today_whole
        .iter()
        .enumerate()
        .map(|(i, later)| match i.checked_sub(today_start) {
            Some(k) if k < span => ours[k] * (1.0 - fade(k)) + later * fade(k),
            Some(_) => *later,
            None => 0.0,
        })
        .collect();
    let checks = (
        fit::check(
            sound,
            rate,
            &today_whole,
            rate,
            note,
            seconds,
            exact,
            super::partials::TOP,
            None,
        ),
        fit::check(
            sound,
            rate,
            &handed_whole,
            rate,
            note,
            seconds,
            exact,
            super::partials::TOP,
            None,
        ),
    );
    let floats = |x: &[f64]| x.iter().map(|v| *v as f32).collect::<Vec<f32>>();
    Strike {
        pitch: measured.f0,
        strike: start as f64 / rate,
        modes: found,
        distance,
        dips,
        erb,
        heard: (floats(&recording), floats(&today_heard), floats(&handed)),
        checks,
    }
}

fn through(filter: &[[f64; 5]; 4], signal: &[f64]) -> Vec<f64> {
    let mut state = [[0.0f64; 4]; 4];
    signal
        .iter()
        .map(|x| {
            let mut x = *x;
            for (s, [b0, b1, b2, a1, a2]) in state.iter_mut().zip(filter) {
                let y = b0 * x + b1 * s[0] + b2 * s[1] - a1 * s[2] - a2 * s[3];
                *s = [x, s[0], y, s[2]];
                x = y;
            }
            x
        })
        .collect()
}

// The root mean square of `x` over 5 ms centred on each sample.
fn smoothed_level(x: &[f64], rate: f64) -> Vec<f64> {
    let half = (0.0025 * rate) as usize;
    let mut sums = vec![0.0; x.len() + 1];
    for (i, v) in x.iter().enumerate() {
        sums[i + 1] = sums[i] + v * v;
    }
    (0..x.len())
        .map(|i| {
            let (a, b) = (i.saturating_sub(half), (i + half + 1).min(x.len()));
            ((sums[b] - sums[a]) / (b - a) as f64).sqrt()
        })
        .collect()
}

// The ERB gap over the first 100 ms: each band's level in each 10 ms, the mean gap where either stands within 60 dB of the recording's loudest band then.
fn band_gap(theirs: &[f64], ours: &[f64], filters: &[[[f64; 5]; 4]], rate: f64) -> f64 {
    let block = (0.01 * rate) as usize;
    let levels = |x: &[f64]| -> Vec<Vec<f64>> {
        filters
            .iter()
            .map(|f| {
                through(f, x)
                    .chunks(block)
                    .map(|c| {
                        10.0 * (c.iter().map(|v| v * v).sum::<f64>() / c.len() as f64)
                            .max(1e-24)
                            .log10()
                    })
                    .collect()
            })
            .collect()
    };
    let (a, b) = (levels(theirs), levels(ours));
    let blocks = a.first().map_or(0, |band| band.len());
    let mut gaps = vec![];
    for k in 0..blocks {
        let loudest = a.iter().map(|band| band[k]).fold(f64::MIN, f64::max);
        for (x, y) in a.iter().zip(&b) {
            if x[k] > loudest - 60.0 || y[k] > loudest - 60.0 {
                gaps.push((y[k].max(loudest - 60.0) - x[k].max(loudest - 60.0)).abs());
            }
        }
    }
    gaps.iter().sum::<f64>() / gaps.len().max(1) as f64
}

// One frequency's level in dB every millisecond: the sound moved down by it and averaged over 5 ms, which passes 100 Hz either side, so two partials closer than that beat in it.
fn envelope(x: &[f64], freq: f64, rate: f64) -> Vec<f64> {
    let half = (0.0025 * rate) as usize;
    let moved: Vec<Complex<f64>> = x
        .iter()
        .enumerate()
        .map(|(i, v)| {
            let p = -2.0 * PI * freq * i as f64 / rate;
            Complex::new(p.cos(), p.sin()) * *v
        })
        .collect();
    let ms = (0.001 * rate) as usize;
    (0..x.len() / ms)
        .map(|k| {
            let at = k * ms;
            let (a, b) = (at.saturating_sub(half), (at + half + 1).min(x.len()));
            let mean: Complex<f64> = moved[a..b].iter().sum::<Complex<f64>>() / (b - a) as f64;
            20.0 * (2.0 * mean.norm()).max(1e-12).log10()
        })
        .collect()
}

// The milliseconds where a level is the lowest within 5 ms either side, at least 10 dB under the highest of the 15 ms before and 6 dB under the highest of the 15 ms after: a dip it climbs back out of, as two close partials beating make.
fn dips_of(levels: &[f64]) -> Vec<usize> {
    let high = |a: usize, b: usize| {
        levels[a..b.min(levels.len())]
            .iter()
            .cloned()
            .fold(f64::MIN, f64::max)
    };
    let low = |a: usize, b: usize| {
        levels[a..b.min(levels.len())]
            .iter()
            .cloned()
            .fold(f64::MAX, f64::min)
    };
    (1..levels.len().saturating_sub(1))
        .filter(|k| {
            let k = *k;
            levels[k] <= low(k.saturating_sub(5), k + 6)
                && high(k.saturating_sub(15), k) - levels[k] >= 10.0
                && high(k + 1, k + 16) - levels[k] >= 6.0
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const RATE: f64 = 44100.0;

    fn made(modes: &[Mode], seconds: f64) -> Vec<f64> {
        render(modes, RATE, (seconds * RATE) as usize)
    }

    #[test]
    fn finds_two_modes_20_hz_apart_from_100_ms() {
        let truth = [
            Mode {
                freq: 523.25,
                level: -18.0,
                slope: -20.0,
                phase: 0.3,
                rise: -240.0,
                rise_phase: 0.0,
                peak: 0.0,
            },
            Mode {
                freq: 543.25,
                level: -18.0,
                slope: -40.0,
                phase: 1.1,
                rise: -240.0,
                rise_phase: 0.0,
                peak: 0.0,
            },
            Mode {
                freq: 1569.75,
                level: -12.0,
                slope: -1200.0,
                phase: 0.0,
                rise: -240.0,
                rise_phase: 0.0,
                peak: 0.0,
            },
        ];
        let found = modes(&made(&truth, 0.1), RATE, 0.1, 4000.0, false);
        for want in &truth {
            let got = found
                .iter()
                .min_by(|a, b| {
                    (a.freq - want.freq)
                        .abs()
                        .total_cmp(&(b.freq - want.freq).abs())
                })
                .unwrap();
            assert!(
                (got.freq - want.freq).abs() < 0.1,
                "{want:?} found as {got:?}"
            );
            assert!(
                (got.level - want.level).abs() < 0.1,
                "{want:?} found as {got:?}"
            );
            assert!(
                (got.slope - want.slope).abs() < 1.0,
                "{want:?} found as {got:?}"
            );
        }
    }
}
