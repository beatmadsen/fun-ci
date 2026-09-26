//! Pictures drawn in pixels and shown in terminal cells: a canvas to paint
//! light on, the tools to paint it with, and the encoding of its pixels as
//! quadrant glyphs in two colours each.

pub mod canvas;
pub mod cells;
pub mod light;
pub mod math;
pub mod noise;
pub mod output;
pub mod sprite;

/// A colour as red, green and blue, 0.0 to 1.0 on screen; light painted on
/// a canvas may go above 1.0 until it is toned.
pub type Shade = [f64; 3];

/// A pixel position or size as a float.
#[must_use]
pub fn float(n: usize) -> f64 {
    f64::from(u32::try_from(n).unwrap_or(u32::MAX))
}

/// Seconds in `t_ms` milliseconds.
#[must_use]
pub fn seconds(t_ms: u64) -> f64 {
    f64::from(u32::try_from(t_ms).unwrap_or(u32::MAX)) / 1000.0
}

/// How many of the pixels 0, 1, ... `len - 1` lie at or left of `v`: the first
/// index past `v`, clamped to 0..=`len`.
#[must_use]
pub fn index_past(v: f64, len: usize) -> usize {
    let (mut lo, mut hi) = (0, len);
    while lo < hi {
        let mid = usize::midpoint(lo, hi);
        if float(mid) <= v { lo = mid + 1 } else { hi = mid }
    }
    lo
}

/// `a` scaled by `k`.
#[must_use]
pub fn scale(a: Shade, k: f64) -> Shade {
    a.map(|channel| channel * k)
}

/// The colour `k` of the way from `a` to `b`.
#[must_use]
pub fn mix(a: Shade, b: Shade, k: f64) -> Shade {
    [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k]
}

/// A colour from its `0xRRGGBB` hex code.
#[must_use]
pub fn hex(code: u32) -> Shade {
    [code >> 16, (code >> 8) & 0xFF, code & 0xFF].map(|byte| f64::from(byte) / 255.0)
}

/// 0.0 below `low`, 1.0 above `high`, easing smoothly between.
#[must_use]
pub fn smoothstep(low: f64, high: f64, v: f64) -> f64 {
    let t = ((v - low) / (high - low)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// `a` plus `b`.
#[must_use]
pub fn add(a: Shade, b: Shade) -> Shade {
    [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
}

/// A fully saturated colour of hue `turns` round the colour wheel: 0.0 red,
/// a third green, two thirds blue.
#[must_use]
pub fn hue(turns: f64) -> Shade {
    let channel = |offset: f64| (((turns + offset).rem_euclid(1.0) * 6.0 - 3.0).abs() - 1.0).clamp(0.0, 1.0);
    [channel(0.0), channel(2.0 / 3.0), channel(1.0 / 3.0)]
}
