//! Success: a gold trophy on a turning sunburst, a glint sweeping over it,
//! sparkles around it and confetti tumbling down.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{square, streak};
use crate::art::noise::dice;
use crate::art::{Shade, add, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 4000;
const CONFETTI: u64 = 140;
const GOLD: Shade = [1.0, 0.72, 0.18];
const COLOURS: [Shade; 6] = [[1.0, 0.25, 0.45], [0.2, 0.8, 1.0], [1.0, 0.85, 0.2], [0.45, 1.0, 0.4], [0.75, 0.4, 1.0], [1.0, 0.55, 0.15]];

#[derive(Debug)]
pub struct Celebrate;

impl Scene for Celebrate {
    fn name(&self) -> &'static str {
        "celebrate"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let centre = (canvas.size().0 * 0.5, canvas.size().1 * 0.52 + 30.0 * (1.0 - smoothstep(0.0, 0.5, t)).powi(2));
        sunburst(canvas, centre, t);
        trophy(canvas, centre, t);
        sparkles(canvas, centre, t);
        confetti(canvas, t);
    }
}

fn sunburst(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    canvas.map(|x, y, _| {
        let (dx, dy) = (x - centre.0, (y - centre.1) * 1.8);
        let rays = 0.5 + 0.5 * (dy.arctangent2(dx) * 14.0 + t * 0.9).cosine();
        let near = (-(dx.hypotenuse(dy) / 150.0).powi(2)).exponential();
        add(mix([0.10, 0.02, 0.14], [0.42, 0.12, 0.28], rays * near), scale([0.6, 0.4, 0.1], near.powi(4) * 0.6))
    });
}

fn trophy(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    canvas.map(|x, y, pixel| {
        let (u, v) = ((x - centre.0) / 1.25, (y - centre.1) / 1.25);
        let (cover, width) = cup((u, v));
        mix(pixel, gilt(u, v, width, t), cover)
    });
}

/// How much of the pixel at (u, v) from the trophy's centre it covers, and
/// the half-width of the trophy at that height, for shading.
fn cup((u, v): (f64, f64)) -> (f64, f64) {
    let bowl = 19.0 * (1.0 - ((v + 24.0) / 22.0).clamp(0.0, 1.0).powi(2)).sqrt();
    let width = if v < -2.0 { bowl } else if v < 8.0 { 3.5 + (v - 5.0).max(0.0) } else { 14.0 - (v - 8.0) * 0.4 };
    let inside = (width - u.abs() + 0.5).clamp(0.0, 1.0) * (v + 24.5).clamp(0.0, 1.0) * (17.5 - v).clamp(0.0, 1.0);
    let handle = (2.2 - ((u.abs() - 18.0).hypotenuse(v + 15.0) - 6.5).abs()).clamp(0.0, 1.0) * f64::from(u8::from(u.abs() > 18.0));
    (inside.max(handle), width.max(4.0))
}

/// Polished gold: lit from the left, a highlight down the side, a darker
/// plinth, and a glint sweeping across.
fn gilt(u: f64, v: f64, width: f64, t: f64) -> Shade {
    let across = (u / width).clamp(-1.0, 1.0);
    let lambert = 0.35 + 0.65 * ((1.0 - across * across).sqrt() * 0.8 - across * 0.35).max(0.0);
    let stripe = (-((across + 0.45) / 0.15).powi(2)).exponential() * 0.9;
    let glint = (-((u + v * 0.6 - (t - 0.8) * 70.0) / 5.0).powi(2)).exponential() * 1.4;
    let base = if v > 13.0 { [0.25, 0.12, 0.06] } else { GOLD };
    add(scale(base, lambert), [stripe + glint, (stripe + glint) * 0.9, (stripe + glint) * 0.6])
}

fn sparkles(canvas: &mut Canvas, centre: (f64, f64), t: f64) {
    for i in 0..10_u64 {
        let angle = dice(i, 130) * std::f64::consts::TAU;
        let at = (centre.0 + angle.cosine() * (40.0 + 24.0 * dice(i, 131)), centre.1 - 8.0 + angle.sine() * 30.0);
        let twinkle = (0.5 + 0.5 * (t * 7.0 + dice(i, 132) * 6.0).sine()).powi(3) * smoothstep(0.4, 0.8, t);
        sparkle(canvas, at, twinkle);
    }
}

/// A four-pointed glint at `at`, its arms as long as `twinkle` is bright.
fn sparkle(canvas: &mut Canvas, at: (f64, f64), twinkle: f64) {
    let (reach, light) = (5.0 * twinkle, scale([1.3, 1.1, 0.6], twinkle));
    streak(canvas, ((at.0 - reach, at.1), (at.0 + reach, at.1)), 0.5, light);
    streak(canvas, ((at.0, at.1 - reach), (at.0, at.1 + reach)), 0.5, light);
}

fn confetti(canvas: &mut Canvas, t: f64) {
    let size = canvas.size();
    for i in 0..CONFETTI {
        let turn = (t * (5.0 + 6.0 * dice(i, 145)) + dice(i, 146) * 6.0).cosine().abs();
        let colour = COLOURS[usize::try_from(i).unwrap_or(0) % COLOURS.len()];
        square(canvas, piece_at(i, t, size), (1.2 + 1.4 * turn, 1.0), scale(colour, 0.55 + 0.6 * turn));
    }
}

/// Where confetti piece `i` has fluttered down to after `t` seconds.
fn piece_at(i: u64, t: f64, (width, height): (f64, f64)) -> (f64, f64) {
    let fall = t * (22.0 + 20.0 * dice(i, 141)) - dice(i, 142) * height * 1.2;
    (dice(i, 140) * width + 6.0 * (t * (2.0 + 2.0 * dice(i, 143)) + dice(i, 144) * 6.0).sine(), fall)
}
