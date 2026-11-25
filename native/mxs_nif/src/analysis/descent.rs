//! The struck fit by gradient descent, for `mix mx.fit --struck --descent`: every partial's and noise band's level at every time moved at once, on the GPU or MLX's processor, against the recording's measured frames.
//! It starts from the fit partial by partial, renders the figures as `fit::render` plays them, and measures the render as the recording was measured, with the room added.
//! Its loss is the mean gap in dB over each ERB band and each partial's peak through the note's own window.

use super::fit::{self, Figures, RISE, SILENT, TIMES};
use super::partials::{self, CLEAR, HOP, LEAD, Note};
use super::room::{self, Room};
use mlx_rs::{
    Array, Device, error::Exception, fft::rfft, ops, transforms::value_and_grad_with_argnums,
    with_device,
};

/// Where the descent runs.
#[derive(Clone, Copy)]
pub enum On {
    Gpu,
    Processor,
}

const STEPS: usize = 300;
const LEARNING: f32 = 0.5;
/// The frames of the note's own window kept for the loss: every frame for the first 0.3 seconds, then evenly spaced up to this many.
const MOST_FRAMES: usize = 400;
/// The partials the check counts as strong, within this many dB of the loudest at the strike, which the descent keeps from moving further off.
const STRONG: f64 = 30.0;
/// The highest a noise band's level goes, in dB.
const LOUDEST_NOISE: f32 = 40.0;

/// The loss before and after the descent, which leaves the figures unchanged where it finds no lower loss.
pub fn descend(
    figures: &mut Figures,
    recorded: &Note,
    rate: f64,
    seconds: f64,
    room: Option<&Room>,
    on: On,
) -> (f64, f64) {
    static FULL_PRECISION: std::sync::Once = std::sync::Once::new();
    // MLX multiplies f32 matrices in TF32 on Apple's newer GPUs unless this is 0 when it first multiplies, and TF32's error floor, about 62 dB under a frame's loudest content, swamps quiet partials.
    // SAFETY: set once, before mxs's first MLX operation; nothing else in mxs reads the environment while a fit runs.
    FULL_PRECISION.call_once(|| unsafe { std::env::set_var("MLX_ENABLE_TF32", "0") });
    let device = match on {
        On::Gpu => Device::gpu(),
        On::Processor => Device::cpu(),
    };
    with_device(device, || run(figures, recorded, rate, seconds, room))
        .expect("the descent's arrays are well formed")
}

fn run(
    figures: &mut Figures,
    recorded: &Note,
    rate: f64,
    seconds: f64,
    room: Option<&Room>,
) -> Result<(f64, f64), Exception> {
    let spectra = &recorded.spectra;
    let window = (spectra.window * rate).round() as usize;
    let size = (2 * window).next_power_of_two();
    let count = (seconds * rate).round() as usize;
    let lead = window + 2;
    let total = lead + count + window + 2;
    let times = TIMES.len();
    let reached = TIMES
        .iter()
        .position(|t| *t >= figures.reached)
        .unwrap_or(times - 1);

    // Each sample's place among the times, and the share of the way to the next.
    // A product with this matrix rather than a gather, whose gradient the GPU adds up in a different order each run.
    let mut spread = vec![0.0f32; times * count];
    for i in 0..count {
        let t = i as f64 / rate;
        let a = (TIMES.partition_point(|time| *time <= t).max(1) - 1).min(times - 2);
        let share = ((t - TIMES[a]) / (TIMES[a + 1] - TIMES[a])).min(1.0) as f32;
        spread[a * count + i] = 1.0 - share;
        spread[(a + 1) * count + i] = share;
    }
    let sines: Vec<f32> = figures
        .partials
        .iter()
        .flat_map(|p| {
            let freq = p.ratio * figures.f0;
            let step = 2.0 * std::f64::consts::PI * freq / rate;
            (0..count).map(move |i| {
                if freq >= rate / 2.0 {
                    0.0
                } else {
                    ((i as f64 / rate / RISE).min(1.0) * (step * i as f64).sin()) as f32
                }
            })
        })
        .collect();
    let noises: Vec<f32> = figures
        .noise
        .iter()
        .enumerate()
        .flat_map(|(k, band)| {
            let audible = band.high < rate / 2.0;
            let rise = fit::noise_rise(band.low, band.high);
            let mut filtered = fit::band_noise(k, band.low, band.high, rate);
            (0..count).map(move |i| {
                if audible {
                    (fit::rising(i as f64 / rate, rise) * filtered()) as f32
                } else {
                    0.0
                }
            })
        })
        .collect();

    let bands: Vec<(f64, f64)> = figures.noise.iter().map(|b| (b.low, b.high)).collect();
    let rooms = room::over(room, &bands);
    let bins: Vec<(usize, usize)> = bands
        .iter()
        .map(|(low, high)| fit::bins(spectra, *low, *high))
        .collect();
    let band_floors: Vec<f64> = bands
        .iter()
        .zip(&bins)
        .zip(&rooms)
        .map(|(((low, high), (a, b)), room)| {
            (10f64.powf(
                (recorded.floor.at((low * high).sqrt()) + 10.0 * ((b - a) as f64).log10()) / 10.0,
            ))
            .max(*room)
        })
        .collect();
    let hann = |w: usize| -> (Vec<f32>, f64) {
        let h: Vec<f64> = (0..w)
            .map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / w as f64).cos())
            .collect();
        let norm = h.iter().sum::<f64>() / 2.0;
        (h.iter().map(|v| (v / norm) as f32).collect(), norm)
    };
    // Each partial is read as the check reads it, with the weights `partials::follow` solves for, among every partial it follows.
    let freqs: Vec<f64> = recorded
        .partials
        .iter()
        .chain(&recorded.left_out)
        .map(|t| t.freq)
        .collect();
    let reading = partials::reading(rate, spectra.window, &freqs);
    let reading = &reading[..recorded.partials.len()];
    let (hann_own, _) = hann(window);
    let bin_power: f64 = hann_own.iter().map(|h| (*h as f64).powi(2)).sum::<f64>();
    let peak_rooms: Vec<f64> = recorded
        .partials
        .iter()
        .zip(reading)
        .map(|(t, row)| {
            room::at(room, t.freq) * row.iter().map(|w| w.norm_sqr()).sum::<f64>() / bin_power
        })
        .collect();
    let peak_floors: Vec<f64> = recorded
        .partials
        .iter()
        .zip(&peak_rooms)
        .map(|(t, room)| 10f64.powf(t.floor / 10.0).max(*room))
        .collect();
    // The recording is held to each partial's own floor, and a frame is clear of it by that floor, as the check holds them; only the render has the room added.
    let track_floors_db: Vec<f64> = recorded.partials.iter().map(|t| t.floor).collect();
    let track_floors: Vec<f64> = track_floors_db
        .iter()
        .map(|f| 10f64.powf(f / 10.0))
        .collect();

    // The note's own frames: every one over the first 0.3 seconds, then evenly spaced.
    // The check matches the render's power over the first half second to the recording's before comparing, so every frame of it is kept.
    let early = (0.5 / HOP) as usize;
    let all = spectra.frames.len();
    let stride = ((all.saturating_sub(early)) / MOST_FRAMES.saturating_sub(early).max(1)).max(1);
    let kept: Vec<usize> = (0..all)
        .filter(|k| *k < early || (k - early).is_multiple_of(stride))
        .collect();
    let gather = |centres: &[f64], w: usize| -> Vec<i32> {
        centres
            .iter()
            .flat_map(|c| {
                (0..w).map(move |i| {
                    (c + i as f64 - (w / 2) as f64)
                        .round()
                        .clamp(0.0, (total - 1) as f64) as i32
                })
            })
            .collect()
    };
    // The render is measured from where its strike is found, as the check and the fit partial by partial find it, which a slow rise puts a little after the render's first sample.
    let found = partials::strike(&fit::render(figures, rate, lead as f64 / rate, seconds)) as f64;
    let centres: Vec<f64> = kept
        .iter()
        .map(|k| found - LEAD * rate + *k as f64 * HOP * rate)
        .collect();
    let (order, own_sizes) = apart(&centres, window);
    let kept: Vec<usize> = order.iter().map(|i| kept[*i]).collect();
    let centres: Vec<f64> = order.iter().map(|i| centres[*i]).collect();
    let half = size / 2 + 1;
    let band_matrix = |bins: &[(usize, usize)], half: usize, apart: &[usize]| -> Vec<f32> {
        let mut m = vec![0.0f32; half * bins.len()];
        for (k, (a, b)) in bins.iter().enumerate() {
            for i in *a..(*b).min(half) {
                if apart.iter().all(|p| i.abs_diff(*p) > 2) {
                    m[i * bins.len() + k] = 1.0;
                }
            }
        }
        m
    };
    // The noise is fitted to what lies between the partials, where the partials' own fit does not reach, its room and floor the share of the band's there.
    let own_matrix = band_matrix(&bins, half, &[]);
    let between: Vec<f64> = bins
        .iter()
        .enumerate()
        .map(|(j, (a, b))| {
            (0..half)
                .filter(|i| own_matrix[i * bins.len() + j] > 0.0)
                .count() as f64
                / (b - a) as f64
        })
        .collect();
    let own_rooms: Vec<f64> = rooms.iter().zip(&between).map(|(r, s)| r * s).collect();
    let own_floors: Vec<f64> = band_floors
        .iter()
        .zip(&between)
        .map(|(f, s)| (f * s).max(1e-30))
        .collect();
    let theirs_bands: Vec<f32> = kept
        .iter()
        .flat_map(|k| {
            let (own_matrix, width) = (&own_matrix, bins.len());
            (0..width).map(move |j| {
                (0..half)
                    .filter(|i| own_matrix[i * width + j] > 0.0)
                    .filter_map(|i| spectra.frames[*k].get(i))
                    .map(|m| m * m)
                    .sum::<f64>() as f32
            })
        })
        .collect();
    let theirs_peaks: Vec<f32> =
        kept.iter()
            .flat_map(|k| {
                recorded.partials.iter().map(move |t| {
                    10f64.powf(t.levels.get(*k).copied().unwrap_or(-300.0) / 10.0) as f32
                })
            })
            .collect();
    let columns = |part: fn(&rustfft::num_complex::Complex<f64>) -> f64| -> Vec<f32> {
        (0..window)
            .flat_map(|n| reading.iter().map(move |row| part(&row[n]) as f32))
            .collect()
    };
    let (reading_re, reading_im) = (columns(|c| c.re), columns(|c| c.im));
    let (p, b, f) = (
        figures.partials.len() as i32,
        bands.len() as i32,
        kept.len() as i32,
    );
    let floats = |v: &[f64]| v.iter().map(|x| *x as f32).collect::<Vec<f32>>();
    let arr = |v: &[f32], shape: &[i32]| Array::from_slice(v, shape);
    let spread = arr(&spread, &[times as i32, count as i32]);
    let sines = arr(&sines, &[p, count as i32]);
    let noises = arr(&noises, &[b, count as i32]);
    let hann_own = arr(&hann_own, &[1, window as i32]);
    let own_index = groups(&gather(&centres, window), &own_sizes, window);
    let own_bands = arr(&own_matrix, &[half as i32, b]);
    let reading_re = arr(&reading_re, &[window as i32, p]);
    let reading_im = arr(&reading_im, &[window as i32, p]);
    // The check holds each partial's strike, its loudest over the first 20 ms, apart from its mean, so those few frames count as much as all the others.
    let strike_frames = ((0.02 + LEAD) / HOP).round() as usize;
    let striking: Vec<f32> = kept
        .iter()
        .map(|k| {
            if *k < strike_frames {
                1.0 + kept.len() as f32 / strike_frames as f32
            } else {
                1.0
            }
        })
        .collect();
    let striking = arr(&striking, &[f, 1]).multiply(Array::from_f32(0.5))?;
    let first: Vec<f32> = kept
        .iter()
        .map(|k| if *k < early { 1.0 } else { 0.0 })
        .collect();
    let first = arr(&first, &[f, 1]);
    let total_theirs = |values: &[f32], width: usize| -> f32 {
        kept.iter()
            .enumerate()
            .filter(|(_, k)| **k < early)
            .map(|(i, _)| values[i * width..(i + 1) * width].iter().sum::<f32>())
            .sum()
    };
    let (bands_first, peaks_first) = (
        total_theirs(&theirs_bands, b as usize),
        total_theirs(&theirs_peaks, p as usize),
    );
    // The render brought to the recording's power over the first half second, as the check brings it.
    let matched = |ours: Array, theirs: f32| -> Result<Array, Exception> {
        let total = ours.multiply(&first)?.sum(None)?;
        ours.multiply(Array::from_f32(theirs).divide(total)?)
    };
    let read = |sound: &Array| -> Result<Array, Exception> {
        let frames = framed(sound, &own_index)?;
        frames
            .matmul(&reading_re)?
            .square()?
            .add(frames.matmul(&reading_im)?.square()?)
    };
    let peak_rooms = arr(&floats(&peak_rooms), &[1, p]);
    let own_rooms = arr(&floats(&own_rooms), &[1, b]);
    let own_floors = arr(&floats(&own_floors), &[1, b]);
    let peak_floors = arr(&floats(&peak_floors), &[1, p]);
    let theirs_bands = db(&ops::maximum(arr(&theirs_bands, &[f, b]), &own_floors)?)?;
    let track_floors = arr(&floats(&track_floors), &[1, p]);
    let theirs_peaks = db(&ops::maximum(arr(&theirs_peaks, &[f, p]), &track_floors)?)?;
    let padding = (
        Array::zeros::<f32>(&[lead as i32])?,
        Array::zeros::<f32>(&[(window + 2) as i32])?,
    );
    let ln10 = std::f32::consts::LN_10;

    let render = |levels: &Array, noise: &Array| -> Result<Array, Exception> {
        let between = |values: &Array| -> Result<Array, Exception> { values.matmul(&spread) };
        let amplitude = between(levels)?
            .multiply(Array::from_f32(ln10 / 20.0))?
            .exp()?;
        let power = between(&noise.multiply(Array::from_f32(ln10 / 10.0))?.exp()?)?;
        let made = amplitude
            .multiply(&sines)?
            .sum_axis(0, None)?
            .add(power.sqrt()?.multiply(&noises)?.sum_axis(0, None)?)?;
        ops::concatenate(&[&padding.0, &made, &padding.1], 0)
    };
    let gaps =
        |ours: Array, room: &Array, floor: &Array, theirs: &Array| -> Result<Array, Exception> {
            db(&ops::maximum(ours.add(room)?, floor)?)?
                .subtract(theirs)?
                .abs()
        };
    let gap =
        |ours: Array, room: &Array, floor: &Array, theirs: &Array| -> Result<Array, Exception> {
            gaps(ours, room, floor, theirs)?.mean(None)
        };
    let ours_db = |ours: Array| -> Result<Array, Exception> {
        db(&ops::maximum(ours.add(&peak_rooms)?, &peak_floors)?)
    };
    let rows = |values: Vec<Vec<f64>>| -> Vec<f32> {
        values
            .into_iter()
            .flat_map(|row| row.into_iter().map(|v| v as f32))
            .collect()
    };
    let start = [
        arr(
            &rows(figures.partials.iter().map(|q| q.levels.clone()).collect()),
            &[p, times as i32],
        ),
        arr(
            &rows(figures.noise.iter().map(|q| q.levels.clone()).collect()),
            &[b, times as i32],
        ),
    ];

    // The check holds each partial's mean gap, over the frames where either side is clear of the floor, apart from its strike, the gap between the two sides' loudest over the first 20 ms.
    // A partial pays for every dB either goes more than half a dB past where it started, so the descent does not trade one partial's gap for the others'.
    let started = ours_db(matched(read(&render(&start[0], &start[1])?)?, peaks_first)?)?;
    started.eval()?;
    theirs_peaks.eval()?;
    let (started, theirs_levels, width) = (
        started.as_slice::<f32>().to_vec(),
        theirs_peaks.as_slice::<f32>().to_vec(),
        p as usize,
    );
    let stands: Vec<f32> = kept
        .iter()
        .map(|k| if *k < early { 1.0 } else { stride as f32 })
        .collect();
    let mut clear = vec![0.0f32; kept.len() * width];
    for (j, floor) in track_floors_db.iter().enumerate().take(width) {
        let at = |i: usize| i * width + j;
        let held: Vec<usize> = (0..kept.len())
            .filter(|i| started[at(*i)].max(theirs_levels[at(*i)]) > (floor + CLEAR) as f32)
            .collect();
        let total: f32 = held.iter().map(|i| stands[*i]).sum();
        held.iter().for_each(|i| clear[at(*i)] = stands[*i] / total);
    }
    let on_strike: Vec<usize> = (0..kept.len())
        .filter(|i| kept[*i] < strike_frames)
        .collect();
    let loudest = |levels: &[f32]| -> Vec<f32> {
        (0..width)
            .map(|j| {
                on_strike
                    .iter()
                    .map(|i| levels[i * width + j])
                    .fold(f32::MIN, f32::max)
            })
            .collect()
    };
    let theirs_top = loudest(&theirs_levels);
    let mean_then: Vec<f32> = (0..width)
        .map(|j| {
            (0..kept.len())
                .map(|i| {
                    (started[i * width + j] - theirs_levels[i * width + j]).abs()
                        * clear[i * width + j]
                })
                .sum()
        })
        .collect();
    let strike_then: Vec<f32> = loudest(&started)
        .iter()
        .zip(&theirs_top)
        .map(|(a, b)| (a - b).abs())
        .collect();
    // Which frames are clear moves with the render, as the check finds them in its render, so a partial raised over more frames pays for the frames it now reaches.
    let clear_of = arr(
        &track_floors_db
            .iter()
            .map(|floor| (floor + CLEAR) as f32)
            .collect::<Vec<f32>>(),
        &[1, p],
    );
    let stands = arr(&stands, &[f, 1]);
    let off_strike: Vec<f32> = kept
        .iter()
        .map(|k| if *k < strike_frames { 0.0 } else { -1000.0 })
        .collect();
    let off_strike = arr(&off_strike, &[f, 1]);
    let theirs_top = arr(&theirs_top, &[p]);
    let loudest_strike = recorded
        .partials
        .iter()
        .map(|t| t.strike(0.02))
        .fold(f64::MIN, f64::max);
    let allowed = |then: &[f32]| {
        arr(
            &then
                .iter()
                .zip(&recorded.partials)
                .map(|(t, track)| {
                    if loudest_strike - track.strike(0.02) <= STRONG {
                        t + 0.5
                    } else {
                        1000.0
                    }
                })
                .collect::<Vec<f32>>(),
            &[p],
        )
    };
    let (mean_allowed, strike_allowed) = (allowed(&mean_then), allowed(&strike_then));
    let partial_gap = |ours: Array| -> Result<Array, Exception> {
        let ours = ours_db(ours)?;
        let apart = ours.subtract(&theirs_peaks)?.abs()?;
        let held = ops::maximum(mlx_rs::stop_gradient(&ours)?, &theirs_peaks)?
            .gt(&clear_of)?
            .as_type::<f32>()?
            .multiply(&stands)?;
        let clear = held.divide(ops::maximum(
            held.sum_axis(0, true)?,
            Array::from_f32(f32::MIN_POSITIVE),
        )?)?;
        let means = apart.multiply(&clear)?.sum_axis(0, None)?;
        let strikes = ours
            .add(&off_strike)?
            .max_axis(0, None)?
            .subtract(&theirs_top)?
            .abs()?;
        let past = |now: Array, allowed: &Array| -> Result<Array, Exception> {
            ops::maximum(now.subtract(allowed)?, Array::from_f32(0.0))?.sum(None)
        };
        apart
            .multiply(&striking)?
            .mean(None)?
            .add(past(means, &mean_allowed)?)?
            .add(past(strikes, &strike_allowed)?)
    };
    // The partials' levels are moved by their own gaps alone, so the noise does not pull a partial off its measured level to fill a band, and the noise's by every gap, so it does not fill a band by lifting what the partials read.
    let loss = |inputs: &[Array]| -> Result<Vec<Array>, Exception> {
        let (levels, noise) = (&inputs[0], &inputs[1]);
        let for_partials = render(levels, noise)?;
        let for_noise = render(&mlx_rs::stop_gradient(levels)?, noise)?;
        let partial_gap = partial_gap(matched(read(&for_partials)?, peaks_first)?)?;
        let band_gap = spectrum(&for_noise, &own_index, &hann_own, size)?.matmul(&own_bands)?;
        let band_gap = gap(
            matched(band_gap, bands_first)?,
            &own_rooms,
            &own_floors,
            &theirs_bands,
        )?;
        Ok(vec![band_gap.add(partial_gap)?])
    };

    let free: Vec<f32> = (0..times)
        .map(|j| if j <= reached { 1.0 } else { 0.0 })
        .collect();
    let free_levels = arr(
        &free
            .iter()
            .cycle()
            .take(p as usize * times)
            .cloned()
            .collect::<Vec<f32>>(),
        &[p, times as i32],
    );
    let free_noise = arr(
        &free
            .iter()
            .cycle()
            .take(b as usize * times)
            .cloned()
            .collect::<Vec<f32>>(),
        &[b, times as i32],
    );
    let ceilings = arr(
        &recorded
            .partials
            .iter()
            .map(|t| (t.strike(0.1) + 12.0) as f32)
            .collect::<Vec<f32>>(),
        &[p, 1],
    );
    let mut params = start;
    let masks = [free_levels, free_noise];
    let mut moments: Vec<(Array, Array)> = params
        .iter()
        .map(|a| (ops::zeros_like(a).unwrap(), ops::zeros_like(a).unwrap()))
        .collect();
    let mut step = value_and_grad_with_argnums(loss, &[0, 1][..]);
    let (b1, b2, eps) = (0.9f32, 0.999f32, 1e-8f32);
    let (mut first, mut best, mut best_params) = (f64::NAN, f64::MAX, params.clone());
    for n in 0..STEPS {
        let (value, grads) = step(&params)?;
        let value = value[0].item_exact::<f32>() as f64;
        if n == 0 {
            first = value;
        }
        if value < best {
            best = value;
            best_params = params.clone();
        }
        let t = (n + 1) as i32;
        for (i, grad) in grads.iter().enumerate() {
            let g = grad.multiply(&masks[i])?;
            let (m, v) = &moments[i];
            let m = m
                .multiply(Array::from_f32(b1))?
                .add(g.multiply(Array::from_f32(1.0 - b1))?)?;
            let v = v
                .multiply(Array::from_f32(b2))?
                .add(g.square()?.multiply(Array::from_f32(1.0 - b2))?)?;
            let m_hat = m.multiply(Array::from_f32(1.0 / (1.0 - b1.powi(t))))?;
            let v_hat = v.multiply(Array::from_f32(1.0 / (1.0 - b2.powi(t))))?;
            let moved = params[i].subtract(
                m_hat
                    .divide(v_hat.sqrt()?.add(Array::from_f32(eps))?)?
                    .multiply(Array::from_f32(LEARNING))?,
            )?;
            params[i] = if i == 0 {
                ops::minimum(&moved, &ceilings)?
            } else {
                ops::clip(&moved, (SILENT as f32, LOUDEST_NOISE))?
            };
            params[i].eval()?;
            moments[i] = (m, v);
        }
    }
    let (value, _) = step(&params)?;
    let last = value[0].item_exact::<f32>() as f64;
    if last < best {
        best = last;
        best_params = params;
    }
    let levels = best_params[0].as_slice::<f32>().to_vec();
    let noise = best_params[1].as_slice::<f32>().to_vec();
    for (q, partial) in figures.partials.iter_mut().enumerate() {
        for j in 0..=reached {
            partial.levels[j] = levels[q * times + j] as f64;
        }
    }
    for (k, band) in figures.noise.iter_mut().enumerate() {
        for j in 0..=reached {
            band.levels[j] = noise[k * times + j] as f64;
        }
    }
    fit::fall_on(figures, seconds, spectra.window);
    Ok((first, best))
}

fn db(power: &Array) -> Result<Array, Exception> {
    power.log10()?.multiply(Array::from_f32(10.0))
}

/// Each frame's power over its bins, the frames gathered from `sound` at `index` through `hann`.
fn spectrum(sound: &Array, index: &[Array], hann: &Array, size: usize) -> Result<Array, Exception> {
    let frames = framed(sound, index)?.multiply(hann)?;
    let spectrum = rfft(&frames, size as i32, -1)?;
    spectrum.real()?.square()?.add(spectrum.imag()?.square()?)
}

/// The order to gather frames centred at `centres` in, and how many go in each group, no two frames of a group sharing a sample.
/// A gather's gradient adds into each sample once for every frame that holds it, which the GPU does in a different order each run unless only one frame holds it.
fn apart(centres: &[f64], width: usize) -> (Vec<usize>, Vec<usize>) {
    let mut groups: Vec<(i64, Vec<usize>)> = Vec::new();
    for (i, centre) in centres.iter().enumerate() {
        let start = (centre - (width / 2) as f64).round() as i64;
        match groups.iter_mut().find(|(end, _)| *end < start) {
            Some((end, group)) => {
                *end = start + width as i64 - 1;
                group.push(i);
            }
            None => groups.push((start + width as i64 - 1, vec![i])),
        }
    }
    (
        groups.iter().flat_map(|(_, group)| group.clone()).collect(),
        groups.iter().map(|(_, group)| group.len()).collect(),
    )
}

/// The samples of each group of frames, as `apart` groups them.
fn groups(index: &[i32], sizes: &[usize], width: usize) -> Vec<Array> {
    let mut from = 0;
    sizes
        .iter()
        .map(|size| {
            let group = Array::from_slice(
                &index[from * width..(from + size) * width],
                &[*size as i32, width as i32],
            );
            from += size;
            group
        })
        .collect()
}

/// The frames of `sound` at `index`, group after group.
fn framed(sound: &Array, index: &[Array]) -> Result<Array, Exception> {
    let frames = index
        .iter()
        .map(|group| sound.take(group))
        .collect::<Result<Vec<Array>, Exception>>()?;
    ops::concatenate(&frames.iter().collect::<Vec<&Array>>(), 0)
}
