//! Success: a storm. Clouds churn, lightning forks down and lights them up,
//! and where it strikes a neon check mark buzzes into being in the rain.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::{dice, fbm};
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 3600;
const STRIKES: [f64; 5] = [0.3, 0.42, 0.55, 2.0, 2.12];
const BOLT: Shade = [1.4, 1.5, 2.0];
const NEON: Shade = [0.35, 1.45, 0.55];

#[derive(Debug)]
pub struct Flash;

impl Scene for Flash {
    fn name(&self) -> &'static str {
        "flash"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let impact = (canvas.size().0 * 0.5, canvas.size().1 * 0.66);
        clouds(canvas, t, lightning(t));
        rain(canvas, t);
        bolt(canvas, impact, t);
        check(canvas, impact, t);
    }
}

/// How bright the lightning is at `t`: a pulse at each strike, dying fast.
fn lightning(t: f64) -> f64 {
    STRIKES.iter().map(|at| if t >= *at { (-(t - at) / 0.05).exponential() } else { 0.0 }).sum()
}

fn clouds(canvas: &mut Canvas, t: f64, lit: f64) {
    let height = canvas.size().1;
    canvas.map(|x, y, _| {
        let cloud = smoothstep(0.35, 0.8, fbm(x / 42.0 + t * 0.25, y / 18.0, 150)) * (1.0 - y / height * 0.7);
        let sky = mix([0.01, 0.015, 0.04], [0.05, 0.07, 0.12], y / height);
        add(add(sky, scale([0.16, 0.18, 0.26], cloud)), scale([0.55, 0.6, 0.9], lit * (0.08 + cloud)))
    });
}

fn rain(canvas: &mut Canvas, t: f64) {
    let (width, height) = canvas.size();
    for i in 0..90_u64 {
        let y = (t * 140.0 + dice(i, 151) * height * 1.5) % (height * 1.5) - height * 0.25;
        let x = (dice(i, 150) * width * 1.2 - y * 0.25) % width;
        streak(canvas, ((x, y), (x - 2.0, y + 7.0)), 0.35, [0.10, 0.13, 0.2]);
    }
}

/// The bolt down to `impact` with a branch off it, while the first strikes last.
fn bolt(canvas: &mut Canvas, impact: (f64, f64), t: f64) {
    let lit = lightning(t).min(1.0);
    if t >= 1.0 || lit <= 0.05 { return; }
    let points = fork(impact, 0);
    trace(canvas, &points, (0.7, scale(BOLT, lit)));
    trace(canvas, &points, (3.5, scale([0.25, 0.3, 0.6], lit)));
    trace(canvas, &fork((points[5].0 + 22.0, points[5].1 + 16.0), 1)[5..], (0.5, scale(BOLT, 0.6 * lit)));
    glow(canvas, impact, 14.0, scale([0.6, 0.7, 1.0], lit));
}

/// Streaks of `radius` and `light` along `points`.
fn trace(canvas: &mut Canvas, points: &[(f64, f64)], (radius, light): (f64, Shade)) {
    for pair in points.windows(2) {
        streak(canvas, (pair[0], pair[1]), radius, light);
    }
}

/// A jagged path from the top of the sky down to `end`.
fn fork(end: (f64, f64), seed: u64) -> Vec<(f64, f64)> {
    let start = (end.0 - 30.0 + 20.0 * dice(seed, 152), -4.0);
    (0..=14_u64).map(|k| {
        let along = float(usize::try_from(k).unwrap_or(0)) / 14.0;
        let jag = if k == 0 || k == 14 { 0.0 } else { (dice(k, 153 + seed) - 0.5) * 16.0 };
        (start.0 + (end.0 - start.0) * along + jag, start.1 + (end.1 - start.1) * along)
    }).collect()
}

/// A neon tick drawn stroke by stroke after the strike, buzzing now and then.
fn check(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    let (a, b, c) = ((centre.0 - 24.0, centre.1 - 12.0), (centre.0 - 8.0, centre.1 + 4.0), (centre.0 + 28.0, centre.1 - 34.0));
    let drawn = smoothstep(0.55, 1.1, t) * 2.0;
    let brightness = neon(t);
    stroke(canvas, (a, b), drawn.min(1.0), brightness);
    stroke(canvas, (b, c), (drawn - 1.0).max(0.0), brightness);
}

/// How bright the neon is at `t`: flickering off now and then, fading at the end.
fn neon(t: f64) -> f64 {
    let buzz = if t > 1.6 && dice(0, (t * 14.0).floor().to_bits()) < 0.12 { 0.35 } else { 1.0 };
    (1.0 - smoothstep(3.1, 3.6, t)) * buzz
}

/// The first `drawn` of the stroke `from`-`to` in neon, `brightness` bright.
fn stroke(canvas: &mut Canvas, (from, to): ((f64, f64), (f64, f64)), drawn: f64, brightness: f64) {
    if drawn <= 0.0 { return; }
    let end = (from.0 + (to.0 - from.0) * drawn, from.1 + (to.1 - from.1) * drawn);
    streak(canvas, (from, end), 8.0, scale([0.05, 0.3, 0.1], brightness));
    streak(canvas, (from, end), 2.2, scale(NEON, brightness));
}
