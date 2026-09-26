//! Light and shapes painted at fractional positions: soft glows, streaks,
//! anti-aliased discs and squares. Pixel (x, y) is lit at its centre,
//! (x + 0.5, y + 0.5).

use super::math::Portable;
use super::canvas::Canvas;
use super::{Shade, float, index_past, scale};

/// How far a glow reaches, in radii; past it the light is under 0.02%.
const REACH: f64 = 3.0;

/// Adds light falling off from `centre` as exp(-(d / radius)^2).
pub fn glow(canvas: &mut Canvas, centre: (f64, f64), radius: f64, light: Shade) {
    let reach = radius * REACH;
    for (x, y) in near(canvas, (centre.0 - reach, centre.1 - reach), (centre.0 + reach, centre.1 + reach)) {
        let d = distance(centre, pixel_centre(x, y));
        canvas.add((x, y), scale(light, falloff(d, radius)));
    }
}

/// Adds light around the segment `from`-`to`, falling off as a glow does.
pub fn streak(canvas: &mut Canvas, (from, to): ((f64, f64), (f64, f64)), radius: f64, light: Shade) {
    let reach = radius * REACH;
    let (low, high) = ((from.0.min(to.0) - reach, from.1.min(to.1) - reach), (from.0.max(to.0) + reach, from.1.max(to.1) + reach));
    for (x, y) in near(canvas, low, high) {
        let d = segment_distance(pixel_centre(x, y), from, to);
        canvas.add((x, y), scale(light, falloff(d, radius)));
    }
}

/// Covers pixels near `centre` with `shade`, `opacity` of the way at the
/// centre and less further out, as a glow falls off: smoke, mist, shadow.
pub fn haze(canvas: &mut Canvas, centre: (f64, f64), radius: f64, (shade, opacity): (Shade, f64)) {
    let reach = radius * REACH;
    for (x, y) in near(canvas, (centre.0 - reach, centre.1 - reach), (centre.0 + reach, centre.1 + reach)) {
        let d = distance(centre, pixel_centre(x, y));
        canvas.cover((x, y), shade, opacity * falloff(d, radius));
    }
}

/// Covers a disc of `radius` around `centre` in `shade`, its edge anti-aliased.
pub fn disc(canvas: &mut Canvas, centre: (f64, f64), radius: f64, shade: Shade) {
    let reach = radius + 1.0;
    for (x, y) in near(canvas, (centre.0 - reach, centre.1 - reach), (centre.0 + reach, centre.1 + reach)) {
        let coverage = radius - distance(centre, pixel_centre(x, y)) + 0.5;
        canvas.cover((x, y), shade, coverage);
    }
}

/// Covers the `size`-wide square from `corner` in `shade`, `opacity` of the
/// way, its edges anti-aliased.
pub fn square(canvas: &mut Canvas, corner: (f64, f64), (size, opacity): (f64, f64), shade: Shade) {
    for (x, y) in near(canvas, (corner.0 - 1.0, corner.1 - 1.0), (corner.0 + size + 1.0, corner.1 + size + 1.0)) {
        let (left, top) = (float(x), float(y));
        let across = overlap(left, corner.0, size) * overlap(top, corner.1, size);
        canvas.cover((x, y), shade, across * opacity);
    }
}

/// The pixels whose centres could lie between `low` and `high`, clipped.
fn near(canvas: &Canvas, low: (f64, f64), high: (f64, f64)) -> impl Iterator<Item = (usize, usize)> + use<> {
    let xs = index_past(low.0 - 0.5, canvas.width())..index_past(high.0 - 0.5, canvas.width());
    let ys = index_past(low.1 - 0.5, canvas.height())..index_past(high.1 - 0.5, canvas.height());
    ys.flat_map(move |y| xs.clone().map(move |x| (x, y)))
}

fn pixel_centre(x: usize, y: usize) -> (f64, f64) {
    (float(x) + 0.5, float(y) + 0.5)
}

fn falloff(d: f64, radius: f64) -> f64 {
    (-(d / radius) * (d / radius)).exponential()
}

fn distance(a: (f64, f64), b: (f64, f64)) -> f64 {
    (a.0 - b.0).hypotenuse(a.1 - b.1)
}

fn segment_distance(p: (f64, f64), a: (f64, f64), b: (f64, f64)) -> f64 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let length = (dx * dx + dy * dy).max(f64::EPSILON);
    let k = (((p.0 - a.0) * dx + (p.1 - a.1) * dy) / length).clamp(0.0, 1.0);
    distance(p, (a.0 + k * dx, a.1 + k * dy))
}

/// How much of the pixel from `start` to `start + 1` lies within `from`..`from + size`.
fn overlap(start: f64, from: f64, size: f64) -> f64 {
    ((start + 1.0).min(from + size) - start.max(from)).clamp(0.0, 1.0)
}
