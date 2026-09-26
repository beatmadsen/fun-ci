//! Run passed: sunrise. The sun climbs from behind layered hills, the sky
//! warms from deep blue through rose to gold, rays fan out and turn slowly,
//! and a few birds flap across the new day.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::{dice, fbm};
use crate::art::{Shade, add, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 4800;
const NIGHT: Shade = [0.02, 0.03, 0.1];
const ROSE: Shade = [0.55, 0.22, 0.3];
const GOLD: Shade = [1.0, 0.62, 0.25];
const SUN: Shade = [1.6, 1.25, 0.7];
const BIRDS: u64 = 5;

#[derive(Debug)]
pub struct Sunrise;

impl Scene for Sunrise {
    fn name(&self) -> &'static str {
        "sunrise"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let dawn = smoothstep(-0.6, 2.8, t);
        let sun = (width * 0.5, height * (0.95 - 0.55 * dawn));
        canvas.map(|x, y, _| add(sky(y / height, dawn), scale(rays(x - sun.0, y - sun.1, t), dawn)));
        glow(canvas, sun, 26.0, scale(GOLD, 0.35 * dawn));
        glow(canvas, sun, 9.0, SUN);
        canvas.map(|x, y, pixel| hills(x, y / height, dawn).unwrap_or(pixel));
        (0..BIRDS).for_each(|i| bird(canvas, i, t, dawn));
    }
}

/// The sky at `k` of the way down, as dawn comes: night overhead giving way
/// to rose, and gold low down.
fn sky(k: f64, dawn: f64) -> Shade {
    let low = mix(ROSE, GOLD, smoothstep(0.4, 1.0, k));
    mix(scale(NIGHT, 1.0 - dawn * 0.5), low, dawn * smoothstep(0.0, 1.0, k + dawn * 0.4))
}

/// The rays' light at (dx, dy) from the sun: bright spokes turning slowly.
fn rays(dx: f64, dy: f64, t: f64) -> Shade {
    let spokes = 0.5 + 0.5 * (dy.arctangent2(dx) * 14.0 + t * 0.3).cosine();
    scale(GOLD, spokes.power(3.0) * 0.18 * (-dx.hypotenuse(dy) / 140.0).exponential())
}

/// The hills at (x, `k` down): three ridges, darker nearer, their tops lit
/// by the sun as it rises; none above them.
fn hills(x: f64, k: f64, dawn: f64) -> Option<Shade> {
    let ridges = [(0.78, 0.2, 121_u64), (0.86, 0.14, 122), (0.94, 0.1, 123)];
    ridges.iter().enumerate().rev().find_map(|(i, (base, wobble, salt))| {
        let top = base - wobble * fbm(x / 45.0, 0.5, *salt);
        let shade = scale(mix([0.03, 0.02, 0.05], [0.25, 0.12, 0.08], dawn), 1.0 - 0.3 * f64::from(u8::try_from(i).unwrap_or(0)));
        (k > top).then(|| add(shade, scale(GOLD, dawn * 0.4 * (-(k - top) * 80.0).exponential())))
    })
}

/// Bird `i`: a small dark V flapping from left to right once dawn has come.
fn bird(canvas: &mut Canvas, i: u64, t: f64, dawn: f64) {
    let (width, height) = canvas.size();
    let x = (t - 1.2 - 0.4 * dice(i, 124)) * (40.0 + 20.0 * dice(i, 125));
    let at = (x + width * 0.1 * dice(i, 126), height * (0.2 + 0.25 * dice(i, 127)));
    let flap = 2.0 * (t * 9.0 + dice(i, 128) * 6.0).sine();
    let ink = scale([0.04, 0.03, 0.04], -dawn * 4.0);
    streak(canvas, ((at.0 - 6.0, at.1 - flap * 1.5), at), 0.7, ink);
    streak(canvas, (at, (at.0 + 6.0, at.1 - flap * 1.5)), 0.7, ink);
}
