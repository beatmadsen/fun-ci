//! Build passed: six amber blocks drop out of the dark one after another and
//! stack into a small pyramid, each landing with a spark, then the whole
//! stack glows.

use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, square};
use crate::art::{Shade, float, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 2800;
const SIZE: f64 = 11.0;
const GAP: f64 = 1.5;
/// Each block's place in the pyramid: its column (in half blocks) and row up.
const PLACES: [(f64, f64); 6] = [(-2.0, 0.0), (0.0, 0.0), (2.0, 0.0), (-1.0, 1.0), (1.0, 1.0), (0.0, 2.0)];
const AMBER: Shade = [1.0, 0.55, 0.12];
const DUSK: Shade = [0.025, 0.015, 0.01];

#[derive(Debug)]
pub struct Bricks;

impl Scene for Bricks {
    fn name(&self) -> &'static str {
        "bricks"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let fade = 1.0 - smoothstep(2.3, 2.8, t);
        canvas.map(|_, y, _| mix(DUSK, [0.05, 0.03, 0.015], y / height));
        let ground = (width * 0.5, height * 0.8);
        for (i, place) in PLACES.iter().enumerate() {
            block(canvas, (ground, *place), t - 0.15 - float(i) * 0.22, fade);
        }
        glow(canvas, (ground.0, ground.1 - SIZE * 1.5), 14.0, scale(AMBER, 0.35 * smoothstep(1.5, 1.9, t) * fade));
    }
}

/// The block for `place` on the pyramid standing on `ground`, `age` seconds
/// after it started to fall.
fn block(canvas: &mut Canvas, (ground, place): ((f64, f64), (f64, f64)), age: f64, fade: f64) {
    if age < 0.0 {
        return;
    }
    let rest = (ground.0 + place.0 * (SIZE + GAP) * 0.5 - SIZE * 0.5, ground.1 - (place.1 + 1.0) * (SIZE + GAP));
    let fall = (1.0 - (age / 0.25).min(1.0)).powi(2) * (rest.1 + SIZE);
    square(canvas, (rest.0, rest.1 - fall), (SIZE, fade), mix(AMBER, [1.0, 0.8, 0.4], place.1 / 3.0));
    let spark = (1.0 - ((age - 0.25) / 0.2).clamp(0.0, 1.0)) * f64::from(u8::from(age >= 0.25));
    glow(canvas, (rest.0 + SIZE * 0.5, rest.1 + SIZE), 5.0, scale([1.2, 0.8, 0.4], spark * fade));
}
