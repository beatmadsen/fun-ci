//! Fast suite passed: a jump to warp speed. Stars stretch into streaks that
//! rush out from the middle, a flash at full speed, and they settle back
//! into points as the ship arrives.

use crate::maths::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::dice;
use crate::art::{Shade, add, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 3500;
const STARS: u64 = 220;
const SPACE: Shade = [0.004, 0.006, 0.02];
const STARLIGHT: Shade = [0.75, 0.85, 1.2];

#[derive(Debug)]
pub struct Warp;

impl Scene for Warp {
    fn name(&self) -> &'static str {
        "warp"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let (centre, flash) = ((width * 0.5, height * 0.5), (-((t - 2.35) / 0.12).power(2.0)).exponential());
        canvas.map(|x, y, _| add(SPACE, scale([0.08, 0.12, 0.25], speed(t) * glow_at(x - centre.0, y - centre.1))));
        (0..STARS).for_each(|i| star(canvas, (centre, width.hypotenuse(height) * 0.55), i, t));
        canvas.map(|_, _, pixel| add(pixel, scale([0.6, 0.7, 0.9], flash * (1.0 - smoothstep(3.1, 3.5, t)))));
    }
}

/// How fast the ship goes at `t`, 0 to 1: pulling away, full speed, arriving.
fn speed(t: f64) -> f64 {
    smoothstep(0.5, 2.1, t) * (1.0 - smoothstep(2.4, 3.0, t))
}

/// How far the ship has travelled by `t`, in trips across the star field.
fn travelled(t: f64) -> f64 {
    t * 0.06 + 1.6 * smoothstep(0.5, 3.0, t)
}

/// The tunnel's glow at (dx, dy) from the vanishing point: brightest round it.
fn glow_at(dx: f64, dy: f64) -> f64 {
    (-dx.hypotenuse(dy * 3.0) / 60.0).exponential()
}

/// Star `i`: carried out from the vanishing point as the ship moves, drawn as
/// a streak as long as the ship is fast.
fn star(canvas: &mut Canvas, (centre, reach): ((f64, f64), f64), i: u64, t: f64) {
    let angle = dice(i, 111) * std::f64::consts::TAU;
    let depth = (dice(i, 112) + travelled(t)) % 1.0;
    let (far, near) = (depth * depth * reach, (depth * depth * (1.0 + 0.5 * speed(t))).min(1.5) * reach);
    let point = |r: f64| (centre.0 + angle.cosine() * r, centre.1 + angle.sine() * r * 0.45);
    let light = scale(mix([0.4, 0.45, 0.6], STARLIGHT, depth), 0.3 + 0.9 * depth);
    streak(canvas, (point(far), point(near.max(far + 0.5))), 0.35 + 0.4 * depth, light);
    glow(canvas, point(near.max(far)), 0.7, scale(light, 0.4));
}
