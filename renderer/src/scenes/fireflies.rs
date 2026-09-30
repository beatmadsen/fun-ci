//! Quiet: fireflies. Over dark grass at dusk, warm little lights drift and
//! blink, each on its own slow path.

use crate::maths::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::dice;
use crate::art::{Shade, mix, scale, seconds, smoothstep};

const FLIES: u64 = 30;
const GLOW: Shade = [1.0, 0.85, 0.35];
const GRASS: Shade = [0.01, 0.025, 0.015];

#[derive(Debug)]
pub struct Fireflies;

impl Scene for Fireflies {
    fn name(&self) -> &'static str {
        "fireflies"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn frame_ms(&self) -> u64 {
        250
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let height = canvas.size().1;
        canvas.map(|_, y, _| mix([0.015, 0.02, 0.06], [0.04, 0.05, 0.07], y / height));
        grass(canvas);
        (0..FLIES).for_each(|i| firefly(canvas, i, t));
    }
}

/// Blades of grass along the bottom, dark against the dusk.
fn grass(canvas: &mut Canvas) {
    let (width, height) = canvas.size();
    for i in 0..u64::try_from(canvas.width() / 3).unwrap_or(0) {
        let x = dice(i, 60) * width;
        let tip = (x + (dice(i, 61) - 0.5) * 6.0, height - 10.0 - dice(i, 62) * 18.0);
        streak(canvas, ((x, height), tip), 0.7, scale(GRASS, -1.0));
    }
}

/// Firefly `i` at `t`: wandering on a slow loop, glowing in slow pulses.
fn firefly(canvas: &mut Canvas, i: u64, t: f64) {
    let (width, height) = canvas.size();
    let phase = dice(i, 63) * std::f64::consts::TAU;
    let at = (
        (dice(i, 64) * width + 14.0 * (t * 0.23 + phase).sine()).rem_euclid(width),
        height * (0.35 + 0.45 * dice(i, 65)) + 6.0 * (t * 0.31 + phase * 2.0).cosine(),
    );
    let blink = smoothstep(0.1, 1.0, (t * (0.4 + 0.3 * dice(i, 66)) + phase).sine());
    glow(canvas, at, 7.0, scale(GLOW, 0.22 * blink));
    glow(canvas, at, 1.6, scale(GLOW, 1.1 * blink));
}
