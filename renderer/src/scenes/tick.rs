//! A small tick of light, drawn stroke by stroke: the mark the lint scenes
//! leave when they are done.

use crate::art::canvas::Canvas;
use crate::art::light::streak;
use crate::art::{Shade, scale};

/// The tick centred on `centre`, `size` pixels across, the first `drawn`
/// (0 to 1) of it painted in `light`.
pub fn tick(canvas: &mut Canvas, (centre, size): ((f64, f64), f64), drawn: f64, light: Shade) {
    let (a, b, c) = ((centre.0 - size * 0.5, centre.1), (centre.0 - size * 0.15, centre.1 + size * 0.35), (centre.0 + size * 0.5, centre.1 - size * 0.45));
    stroke(canvas, (a, b), (drawn * 2.0).min(1.0), light);
    stroke(canvas, (b, c), (drawn * 2.0 - 1.0).max(0.0), light);
}

fn stroke(canvas: &mut Canvas, (from, to): ((f64, f64), (f64, f64)), drawn: f64, light: Shade) {
    if drawn <= 0.0 {
        return;
    }
    let end = (from.0 + (to.0 - from.0) * drawn, from.1 + (to.1 - from.1) * drawn);
    streak(canvas, (from, end), 4.0, scale(light, 0.25));
    streak(canvas, (from, end), 1.2, light);
}
