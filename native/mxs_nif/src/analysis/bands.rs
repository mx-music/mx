//! Bands one ERB (equivalent rectangular bandwidth) wide, and the power a frame of a spectrum holds over a band, which the fit, the room and held notes all measure in.

/// The bands one ERB wide from 50 Hz to `top`.
pub fn erb_bands_to(top: f64) -> Vec<(f64, f64)> {
    let erb = |hz: f64| 21.4 * (1.0 + 0.00437 * hz).log10();
    let inverse = |e: f64| (10f64.powf(e / 21.4) - 1.0) / 0.00437;
    let (low, high) = (erb(50.0), erb(top));
    let count = (high - low).round() as usize;
    (0..count)
        .map(|k| {
            (
                inverse(low + (high - low) * k as f64 / count as f64),
                inverse(low + (high - low) * (k + 1) as f64 / count as f64),
            )
        })
        .collect()
}

/// The power of a frame's magnitudes over a band from `low` to `high` Hz.
/// Each bin covers half a bin either side of its centre and counts for the share of that inside the band, so a band moved with a pitch takes the same part of each partial.
pub fn band_power(frame: &[f64], bin: f64, low: f64, high: f64) -> f64 {
    let (from, to) = (low / bin, high / bin);
    let first = (from - 0.5).floor().max(0.0) as usize;
    let last = ((to + 0.5).ceil() as usize).min(frame.len());
    (first..last)
        .map(|i| {
            (frame[i] * frame[i]) * ((i as f64 + 0.5).min(to) - (i as f64 - 0.5).max(from)).max(0.0)
        })
        .sum()
}
