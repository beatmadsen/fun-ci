//! The night sky several scenes share: a deep gradient to a violet horizon,
//! faint nebulae drifting through it, and stars that twinkle.

use crate::art::math::Portable;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::{dice, fbm, value};
use crate::art::{Shade, add, hex, mix, scale, smoothstep};

const ZENITH: u32 = 0x02_03_0c;
const MIDDLE: u32 = 0x0c_10_33;
const HORIZON: u32 = 0x5a_2c_5e;
const DUSK: u32 = 0x9a_4a_52;
const FAR_HILL: u32 = 0x14_10_2c;
const RIM: [f64; 3] = [0.20, 0.16, 0.26];
const NEAR_HILL: u32 = 0x07_07_14;
const BLUE_STAR: Shade = [0.72, 0.82, 1.0];
const WARM_STAR: Shade = [1.0, 0.86, 0.68];

/// Paints the sky over the whole canvas, nebulae `drift` pixels a second
/// further left for each second of `t`.
pub fn sky(canvas: &mut Canvas, t: f64, drift: f64) {
    let height = canvas.size().1;
    canvas.map(|x, y, _| add(gradient(y / height), nebula(x + drift * t, y)));
}

/// Adds the stars, one for every `area` pixels, `drift` pixels a second further left.
pub fn stars(canvas: &mut Canvas, t: f64, (area, drift): (usize, f64)) {
    let count = canvas.width() * canvas.height() / area;
    for i in 0..u64::try_from(count).unwrap_or(0) {
        star(canvas, i, t, drift);
    }
}

fn gradient(k: f64) -> Shade {
    let (zenith, middle, horizon) = (hex(ZENITH), hex(MIDDLE), hex(HORIZON));
    let sky = if k < 0.5 { mix(zenith, middle, smoothstep(0.0, 0.5, k)) } else { mix(middle, horizon, smoothstep(0.5, 0.95, k)) };
    mix(sky, hex(DUSK), smoothstep(0.72, 1.0, k) * 0.6)
}

fn nebula(x: f64, y: f64) -> Shade {
    let violet = smoothstep(0.52, 0.85, fbm(x / 110.0, y / 38.0, 5));
    let teal = smoothstep(0.55, 0.9, fbm(x / 80.0 + 40.0, y / 30.0, 9));
    add(scale([0.30, 0.10, 0.42], violet * 0.55), scale([0.05, 0.22, 0.28], teal * 0.45))
}

fn star(canvas: &mut Canvas, i: u64, t: f64, drift: f64) {
    let (width, height) = canvas.size();
    let at = ((dice(i, 1) * width - drift * t).rem_euclid(width), dice(i, 2).power(1.25) * height * 0.9);
    let magnitude = dice(i, 3).powi(5);
    let light = scale(mix(BLUE_STAR, WARM_STAR, dice(i, 4)), (0.35 + 2.4 * magnitude) * twinkle(i, t));
    glow(canvas, at, 0.5 + 0.25 * magnitude, light);
    glow(canvas, at, 3.5, scale(light, 0.05 * magnitude));
    flare(canvas, at, magnitude, light);
}

/// How bright star `i` is at `t`: each at its own pace and phase.
fn twinkle(i: u64, t: f64) -> f64 {
    0.62 + 0.38 * (t * (1.3 + 3.2 * dice(i, 5)) + std::f64::consts::TAU * dice(i, 6)).sine()
}

/// A cross of light through the brightest stars.
fn flare(canvas: &mut Canvas, (x, y): (f64, f64), magnitude: f64, light: Shade) {
    let reach = 2.0 + 9.0 * magnitude;
    let dim = scale(light, 0.22 * smoothstep(0.35, 0.8, magnitude));
    streak(canvas, ((x - reach, y), (x + reach, y)), 0.35, dim);
    streak(canvas, ((x, y - reach * 0.6), (x, y + reach * 0.6)), 0.35, dim);
}

/// Paints two rolling ridges of hills along the bottom, the far one rimmed with moonlight.
pub fn hills(canvas: &mut Canvas) {
    let height = canvas.size().1;
    canvas.map(|x, y, pixel| {
        let far = ridge(y, height * 0.66 + 16.0 * value(x / 70.0, 1.0, 31) + 5.0 * value(x / 23.0, 2.0, 32));
        let near = ridge(y, height * 0.82 + 10.0 * value(x / 45.0, 3.0, 33) + 2.0 * value(x / 13.0, 4.0, 34));
        mix(mix(pixel, rimmed(far), far.min(1.0)), hex(NEAR_HILL), near.min(1.0))
    });
}

/// How far below a hill's edge at `edge` the height `y` lies, in pixels
/// from 0.0 above it; 1.0 and over is inside the hill.
fn ridge(y: f64, edge: f64) -> f64 {
    (y - edge + 0.5).max(0.0)
}

/// The far hill's colour `depth` pixels in: lit by the moon along its edge.
fn rimmed(depth: f64) -> [f64; 3] {
    crate::art::add(hex(FAR_HILL), scale(RIM, 1.0 - smoothstep(1.0, 3.0, depth)))
}

