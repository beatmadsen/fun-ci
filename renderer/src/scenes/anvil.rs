//! Build passed: a hammer rings on a small anvil three times, the hot bar on
//! it glowing brighter at each blow, and amber sparks fly.

use crate::maths::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze, streak};
use crate::art::noise::dice;
use crate::art::{Shade, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 2700;
const STRIKES: [f64; 3] = [0.45, 1.05, 1.65];
const IRON: Shade = [0.13, 0.12, 0.12];
const EDGE: Shade = [0.6, 0.32, 0.1];
const HOT: Shade = [1.1, 0.5, 0.1];
const DUSK: Shade = [0.02, 0.013, 0.01];

#[derive(Debug)]
pub struct Anvil;

impl Scene for Anvil {
    fn name(&self) -> &'static str {
        "anvil"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let (face, opacity) = ((width * 0.5, height * 0.66), 1.0 - smoothstep(2.2, 2.7, t));
        canvas.map(|_, y, _| mix(DUSK, [0.04, 0.025, 0.015], y / height));
        anvil(canvas, face, opacity);
        glow(canvas, face, 5.0, scale(HOT, opacity * (0.25 + 0.75 * ring(t))));
        hammer(canvas, face, t, opacity);
        for at in STRIKES {
            sparks(canvas, face, t - at, opacity);
        }
    }
}

/// How brightly the last blow still rings at `t`: a flare at each strike, cooling.
fn ring(t: f64) -> f64 {
    STRIKES.iter().filter(|at| t >= **at).map(|at| (-(t - at) / 0.25).exponential()).fold(0.0, f64::max)
}

/// The anvil: an iron profile (a flat face with a tapering horn, a narrow
/// waist, a broad foot), lit along its top edge by the hot bar.
fn anvil(canvas: &mut Canvas, face: (f64, f64), opacity: f64) {
    canvas.map(|x, y, pixel| {
        let (dx, dy) = (x - face.0, y - face.1);
        let lit = scale(IRON, 1.4 - dy * 0.04);
        if in_anvil(dx, dy) { mix(pixel, if dy < 1.0 { EDGE } else { lit }, opacity) } else { pixel }
    });
}

/// Whether (dx, dy) from the middle of the anvil's face lies in its profile.
fn in_anvil(dx: f64, dy: f64) -> bool {
    let face = dx.abs() < 22.0 && (0.0..6.0).contains(&dy);
    let horn = (-34.0..-22.0).contains(&dx) && dy >= 0.0 && dy < f64::midpoint(dx, 34.0);
    let waist = dx.abs() < 8.0 && (6.0..14.0).contains(&dy);
    face || horn || waist || dx.abs() < 18.0 && (14.0..19.0).contains(&dy)
}

/// The hammer: raised between blows, falling onto the face at each strike.
fn hammer(canvas: &mut Canvas, face: (f64, f64), t: f64, opacity: f64) {
    let next = STRIKES.iter().copied().find(|at| *at + 0.1 > t).unwrap_or(9.0);
    let lift = smoothstep(0.0, 0.35, next - t) * 26.0;
    let head = (face.0 + 8.0, face.1 - 6.0 - lift);
    streak(canvas, (head, (head.0 + 22.0, head.1 - 12.0)), 1.3, scale([0.28, 0.17, 0.08], opacity));
    haze(canvas, head, 4.8, (scale(IRON, 1.3), opacity));
    streak(canvas, ((head.0 - 4.5, head.1 - 4.0), (head.0 + 4.5, head.1 - 4.0)), 0.6, scale(EDGE, 0.8 * opacity));
}

/// The sparks of a blow, `age` seconds after it: flung out and falling, fading.
fn sparks(canvas: &mut Canvas, face: (f64, f64), age: f64, opacity: f64) {
    if !(0.0..0.6).contains(&age) {
        return;
    }
    for i in 0..16_u64 {
        let angle = -0.3 - dice(i, 101) * 2.5;
        let speed = 30.0 + 40.0 * dice(i, 102);
        let at = (face.0 + angle.cosine() * speed * age, face.1 + angle.sine() * speed * age + 60.0 * age * age);
        glow(canvas, at, 1.4, scale(HOT, 2.0 * (1.0 - age / 0.6) * opacity));
    }
}
