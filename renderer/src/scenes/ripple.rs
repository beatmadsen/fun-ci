//! Lint passed: a tick of teal light appears in the dark, and rings of light
//! spread out from it one after another, fading as they go.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::{Shade, add, float, scale, seconds, smoothstep};
use super::tick::tick;

const LENGTH_MS: u64 = 2600;
const RINGS: usize = 3;
const TEAL: Shade = [0.2, 1.0, 0.95];
const NIGHT: Shade = [0.012, 0.02, 0.035];

#[derive(Debug)]
pub struct Ripple;

impl Scene for Ripple {
    fn name(&self) -> &'static str {
        "ripple"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let centre = (canvas.size().0 * 0.5, canvas.size().1 * 0.5);
        let fade = 1.0 - smoothstep(2.1, 2.6, t);
        canvas.map(|x, y, _| add(NIGHT, scale(TEAL, rings((x - centre.0, y - centre.1), t) * fade)));
        tick(canvas, (centre, 20.0), smoothstep(0.0, 0.4, t), scale(TEAL, fade));
    }
}

/// How lit the rings make a point `offset` from their centre at `t`.
fn rings(offset: (f64, f64), t: f64) -> f64 {
    let distance = offset.0.hypotenuse(offset.1 * 1.6);
    (0..RINGS).map(|i| ring(distance, t - 0.35 - float(i) * 0.4)).sum()
}

/// One ring `age` seconds after it set out: a thin band, growing and fading.
fn ring(distance: f64, age: f64) -> f64 {
    if age < 0.0 {
        return 0.0;
    }
    let (radius, strength) = (18.0 + age * 55.0, 0.8 * (-age * 1.6).exponential());
    let off = (distance - radius) / 1.8;
    strength * (-off * off).exponential()
}
