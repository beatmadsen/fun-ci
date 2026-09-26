//! Running: a rocket flies right through space on a plume of fire, stars
//! streaming past, a ringed planet drifting by far behind.

use crate::art::math::Portable;
use super::rocket::rocket;
use super::sky::{sky, stars};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze, streak};
use crate::art::noise::{dice, value};
use crate::art::{Shade, mix, scale, seconds, smoothstep};

const PLUME: u64 = 160;
const SIZE: f64 = 1.6;

#[derive(Debug)]
pub struct Running;

impl Scene for Running {
    fn name(&self) -> &'static str {
        "running"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let centre = (canvas.size().0 * 0.46, canvas.size().1 * 0.5 + 3.0 * (t * 2.1).sine());
        space(canvas, t);
        plume(canvas, (centre.0 - 22.0 * SIZE, centre.1), t);
        rocket(canvas, centre, SIZE, (t % 4.0) > 3.85);
    }
}

/// Space streaming past: sky, a far planet, stars and speed lines.
fn space(canvas: &mut Canvas, t: f64) {
    sky(canvas, t, 0.0);
    planet(canvas, t);
    stars(canvas, t, (420, 22.0));
    speed_lines(canvas, t);
}

fn planet(canvas: &mut Canvas, t: f64) {
    let width = canvas.size().0 + 120.0;
    let centre = (width - 60.0 - (t * 3.0 + width * 0.2) % width, 36.0);
    ring(canvas, centre, 0.0);
    canvas.map(|x, y, pixel| mix(pixel, globe(x - centre.0, y - centre.1), (15.5 - (x - centre.0).hypotenuse(y - centre.1)).clamp(0.0, 1.0)));
    ring(canvas, centre, 1.0);
}

/// The ring's back half (`front` 0.0, hidden by the globe) or front half (1.0).
fn ring(canvas: &mut Canvas, centre: (f64, f64), front: f64) {
    let point = |i: u32| {
        let a = f64::from(i) / 48.0 * std::f64::consts::TAU;
        (centre.0 + 28.0 * a.cosine(), centre.1 + 6.0 * a.sine() - 3.0 * a.cosine())
    };
    for i in (0..48_u32).filter(|i| (*i < 24) == (front > 0.5)) {
        streak(canvas, (point(i), point(i + 1)), 0.75, [0.42, 0.34, 0.24]);
    }
}

/// A gas giant's surface at (dx, dy) from its centre: bands, lit from the upper left.
fn globe(dx: f64, dy: f64) -> Shade {
    let band = 0.5 + 0.5 * (dy * 0.42 + 0.8 * value(dx / 9.0, dy / 3.0, 80)).sine();
    let colour = mix([0.62, 0.34, 0.2], [0.98, 0.84, 0.6], band);
    scale(colour, 0.12 + 0.95 * smoothstep(-9.0, 12.0, -dx * 0.7 - dy * 0.7))
}

fn speed_lines(canvas: &mut Canvas, t: f64) {
    let (width, height) = canvas.size();
    for i in 0..14_u64 {
        let x = width + 60.0 - (t * (160.0 + 90.0 * dice(i, 60)) + dice(i, 61) * width) % (width + 120.0);
        let y = height * (0.08 + 0.84 * dice(i, 62));
        streak(canvas, ((x, y), (x + 14.0 + 20.0 * dice(i, 63), y)), 0.4, [0.16, 0.18, 0.28]);
    }
}

/// The flame and smoke behind the nozzle at `nozzle`.
fn plume(canvas: &mut Canvas, nozzle: (f64, f64), t: f64) {
    let flicker = 0.85 + 0.3 * value(t * 11.0, 0.0, 70);
    for i in 0..PLUME {
        let age = (t * (2.2 + 0.8 * dice(i, 71)) + dice(i, 72)).fract();
        particle(canvas, blown(i, (nozzle, flicker), age, t), age);
    }
    streak(canvas, (nozzle, (nozzle.0 - 20.0 * flicker, nozzle.1)), 3.2, [1.1, 0.95, 0.6]);
    glow(canvas, nozzle, 16.0, scale([1.0, 0.4, 0.1], 0.25 * flicker));
}

/// Where plume particle `i` is `age` of its life out of the nozzle.
fn blown(i: u64, (nozzle, flicker): ((f64, f64), f64), age: f64, t: f64) -> (f64, f64) {
    let drift = (dice(i, 73) - 0.5) * (3.0 + 16.0 * age) + 2.0 * (t * 9.0 + dice(i, 74) * 6.0).sine() * age;
    (nozzle.0 - age * 95.0 * flicker, nozzle.1 + drift)
}

fn particle(canvas: &mut Canvas, at: (f64, f64), age: f64) {
    if age > 0.4 {
        haze(canvas, at, 2.0 + age * 7.0, ([0.36, 0.34, 0.42], 0.10 * (1.0 - age)));
        return;
    }
    glow(canvas, at, 1.6 + age * 6.0, scale(fire(age), (1.0 - age / 0.4).power(0.6) * 0.55));
}

fn fire(age: f64) -> Shade {
    let hot = mix([1.3, 1.15, 0.8], [1.25, 0.55, 0.12], smoothstep(0.0, 0.14, age));
    mix(hot, [0.75, 0.1, 0.06], smoothstep(0.12, 0.38, age))
}
