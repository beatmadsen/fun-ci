//! Lint passed: a spirit level. Its bubble wobbles along the vial, settles
//! dead centre between the marks, and a teal tick lights up above it.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze, streak};
use crate::art::{Shade, mix, scale, seconds, smoothstep};
use super::tick::tick;

const LENGTH_MS: u64 = 2400;
const TEAL: Shade = [0.25, 1.05, 0.95];
const GLASS: Shade = [0.08, 0.26, 0.25];
const NIGHT: Shade = [0.012, 0.02, 0.03];
/// The vial's half length and half height, in pixels.
const VIAL: (f64, f64) = (34.0, 5.0);

#[derive(Debug)]
pub struct Level;

impl Scene for Level {
    fn name(&self) -> &'static str {
        "level"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let (centre, fade) = ((width * 0.5, height * 0.6), 1.0 - smoothstep(1.9, 2.4, t));
        canvas.map(|_, y, _| mix(NIGHT, [0.02, 0.035, 0.045], y / height));
        vial(canvas, centre, fade, smoothstep(1.0, 1.3, t));
        glow(canvas, (centre.0 + VIAL.0 * 0.8 * wobble(t), centre.1), 3.2, scale([0.8, 1.2, 1.1], 0.8 * fade));
        tick(canvas, ((centre.0, centre.1 - 18.0), 14.0), smoothstep(1.2, 1.6, t), scale(TEAL, fade));
    }
}

/// Where the bubble sits at `t`, from -1 (one end) to 1 (the other): a
/// swing that dies away to the centre.
fn wobble(t: f64) -> f64 {
    (-t * 2.4).exponential() * (t * 7.0 + 0.9).cosine()
}

/// The glass vial at `centre`, `fade` bright, with its two centre marks
/// glowing teal once the bubble has `settled`.
fn vial(canvas: &mut Canvas, centre: (f64, f64), fade: f64, settled: f64) {
    for step in 0..=16_u32 {
        let along = (f64::from(step) / 16.0 * 2.0 - 1.0) * VIAL.0;
        haze(canvas, (centre.0 + along, centre.1), VIAL.1, (scale(GLASS, fade), 0.9));
    }
    let rim = centre.1 - VIAL.1;
    streak(canvas, ((centre.0 - VIAL.0, rim), (centre.0 + VIAL.0, rim)), 0.5, scale([0.2, 0.4, 0.4], fade));
    for side in [-1.0, 1.0] {
        let x = centre.0 + side * 6.0;
        streak(canvas, ((x, centre.1 - VIAL.1), (x, centre.1 + VIAL.1)), 0.5, scale(TEAL, fade * (0.25 + 0.75 * settled)));
    }
}
