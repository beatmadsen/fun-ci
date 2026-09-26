//! The lamp over a quiet scene (acceptance-tests.md, AT-7.7): a small light in
//! the header's lower left corner that keeps the latest outcome in view.

use super::resting::Outcome;
use crate::art::canvas::Canvas;
use crate::art::light::glow;
use crate::art::math::Portable;
use crate::art::{Shade, scale};

/// Where the lamp sits: from the left edge, and up from the bottom, in pixels.
pub const LAMP_AT: (f64, f64) = (10.0, 12.0);
const GREEN: Shade = [0.2, 0.9, 0.3];
const RED: Shade = [1.0, 0.15, 0.1];

/// Paints the lamp for `outcome`, `t` seconds into the quiet spell.
pub fn lamp(canvas: &mut Canvas, outcome: Outcome, t: f64) {
    let at = (LAMP_AT.0, canvas.size().1 - LAMP_AT.1);
    let light = match outcome {
        Outcome::Passed => GREEN,
        Outcome::Failed => scale(RED, flicker(t)),
    };
    glow(canvas, at, 3.0, light);
}

/// How bright the failed lamp is at `t`: a slow pulse, once every two seconds,
/// never quite out.
fn flicker(t: f64) -> f64 {
    0.35 + 0.65 * (0.5 + 0.5 * (t * std::f64::consts::PI).sine())
}
