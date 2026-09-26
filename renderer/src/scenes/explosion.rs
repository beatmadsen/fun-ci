//! Failure: BOOM. A flash, a turbulent fireball that cools into rising
//! smoke, a shockwave, sparks flung out on trails, and a comic-book title.

use crate::art::math::Portable;
use super::lettering::{Style, title};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze, streak};
use crate::art::noise::{dice, fbm};
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 3200;
const SPARKS: u64 = 80;

#[derive(Debug)]
pub struct Explosion;

impl Scene for Explosion {
    fn name(&self) -> &'static str {
        "explosion"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let shake = 3.5 * (-t * 4.0).exponential() * (t * 55.0).sine();
        backdrop(canvas, t);
        blast(canvas, (canvas.size().0 * 0.5 + shake, canvas.size().1 * 0.58 - t * 7.0), t);
        boom(canvas, (canvas.size().0 * 0.5 + shake * 1.5, canvas.size().1 * 0.3), t);
        flash(canvas, t);
    }
}

fn backdrop(canvas: &mut Canvas, t: f64) {
    let height = canvas.size().1;
    canvas.map(|x, y, _| {
        let smoke = fbm(x / 30.0 + t * 0.3, y / 18.0, 91);
        mix([0.01, 0.005, 0.01], [0.09, 0.025, 0.02], y / height * 0.7 + smoke * 0.3)
    });
}

/// The fireball at `centre` with its smoke, shockwave and sparks.
fn blast(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    fireball(canvas, centre, t);
    smoke(canvas, centre, t);
    shockwave(canvas, centre, t);
    sparks(canvas, centre, t);
}

fn fireball(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    let radius = 54.0 * (1.0 - (-t * 3.0).exponential()) + 2.0;
    canvas.map(|x, y, pixel| {
        let (dx, dy) = ((x - centre.0) / radius, (y - centre.1) / (radius * 0.7));
        let churn = fbm(x / 13.0 + t * 0.7, y / 11.0 - t * 1.8, 92) - 0.5;
        let density = smoothstep(1.05, 0.45, dx.hypotenuse(dy) + churn * 0.7);
        burn(pixel, density, heat(dx.hypotenuse(dy), churn, t))
    });
}

/// How hot the fireball is at `d` radii from its centre: hottest in the
/// middle and early on, cooling into smoke.
fn heat(d: f64, churn: f64, t: f64) -> f64 {
    ((1.25 - d * 0.9 + churn * 0.5) * (1.35 - t * 0.42)).max(0.0)
}

fn burn(pixel: Shade, density: f64, heat: f64) -> Shade {
    let smoke = mix(pixel, [0.13, 0.11, 0.12], density * 0.85);
    add(smoke, scale(flame(heat), density))
}

/// Black-body-ish colour for `heat`: dark red, orange, yellow, then white.
fn flame(heat: f64) -> Shade {
    let red = scale([0.9, 0.12, 0.03], smoothstep(0.1, 0.45, heat));
    let orange = scale([0.6, 0.45, 0.05], smoothstep(0.4, 0.8, heat));
    add(add(red, orange), scale([0.6, 0.6, 0.5], smoothstep(0.8, 1.3, heat)))
}

/// Puffs of smoke billowing up out of the fireball, lit orange from below
/// while the fire still burns.
fn smoke(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    for i in 0..18_u64 {
        let born = 0.15 + 0.07 * f64::from(u32::try_from(i).unwrap_or(0));
        let age = (t - born).max(0.0);
        let at = (centre.0 + (dice(i, 110) - 0.5) * (30.0 + 40.0 * age), centre.1 - 6.0 - age * (14.0 + 10.0 * dice(i, 111)));
        let lit = mix([0.85, 0.35, 0.1], [0.34, 0.29, 0.3], smoothstep(0.0, 1.4, age));
        haze(canvas, at, 6.0 + 8.0 * age, (lit, 0.6 * smoothstep(0.0, 0.3, age) * (1.0 - smoothstep(2.0, 3.1, t))));
    }
}

fn shockwave(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    let (radius, fade) = (t * 170.0, 1.0 - smoothstep(0.0, 0.7, t));
    canvas.map(|x, y, pixel| {
        let d = (x - centre.0).hypotenuse((y - centre.1) * 1.6);
        add(pixel, scale([1.0, 0.75, 0.5], fade * (-((d - radius) / 3.0).powi(2)).exponential() * 0.8))
    });
}

fn sparks(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    for i in 0..SPARKS {
        let fade = 1.0 - t / (0.9 + 1.4 * dice(i, 101));
        let at = |t: f64| spark_at(i, centre, t);
        if fade > 0.0 {
            streak(canvas, (at((t - 0.07).max(0.0)), at(t)), 0.55, scale([1.4, 0.8, 0.3], fade));
        }
    }
}

/// Where spark `i` is `t` seconds out: flung at a random angle, slowed by
/// drag and pulled down by gravity.
fn spark_at(i: u64, centre: (f64, f64), t: f64) -> (f64, f64) {
    let angle = dice(i, 102) * std::f64::consts::TAU;
    let (speed, drag) = (90.0 + 160.0 * dice(i, 103), 2.2);
    let out = speed * (1.0 - (-t * drag).exponential()) / drag;
    (centre.0 + angle.cosine() * out, centre.1 + angle.sine() * out * 0.7 + 38.0 * t * t)
}

fn boom(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    let (pop, fade) = (pop(t), fade(t));
    if pop * fade < 0.05 { return; }
    let top = centre.1 - 12.0 * pop;
    let fill = move |_: usize, _: f64, y: f64| mix([1.3, 1.15, 0.35], [1.1, 0.25, 0.05], smoothstep(top, top + 22.0 * pop, y));
    let lift = |i: usize| 2.0 * (t * 9.0 + float(i)).sine();
    title(canvas, "BOOM!", centre, &Style { pixel: 4.2 * pop, opacity: fade, shadow: [0.05, 0.02, 0.02], fill: &fill, lift: &lift });
    glow(canvas, centre, 30.0, scale([0.4, 0.15, 0.03], fade * pop));
}

/// How much of the title is left at `t`.
fn fade(t: f64) -> f64 {
    1.0 - smoothstep(2.6, 3.2, t)
}

/// How big the title is at `t`: nothing, then swelling past full size and settling.
fn pop(t: f64) -> f64 {
    smoothstep(0.12, 0.3, t) * (1.0 + 0.35 * (-(t - 0.3) * 6.0).exponential() * smoothstep(0.28, 0.32, t))
}

fn flash(canvas: &mut Canvas, t: f64) {
    let light = 1.6 * (1.0 - smoothstep(0.0, 0.3, t)).powi(2);
    canvas.map(|_, _, pixel| add(pixel, [light, light * 0.95, light * 0.85]));
}
