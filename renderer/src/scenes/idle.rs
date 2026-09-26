//! Idle: a quiet night. Stars twinkle over rolling hills, a crescent moon
//! glows, a cottage keeps its window lit, and now and then a star falls.

use crate::art::math::Portable;
use super::sky::{hills, sky, stars};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::{dice, value};
use crate::art::sprite::Sprite;
use crate::art::{Shade, hex, mix, scale, seconds, smoothstep};

const MOON: u32 = 0xf6_ee_d2;
const FALL_EVERY: f64 = 9.0;

const COTTAGE: Sprite = Sprite {
    rows: &["    c    ", "   rrr c ", "  rrrrrrr", " rrrrrrrrr", "  wwwwww ", "  wyywdw ", "  wyywdw ", "  wwwwdw "],
    palette: &[('r', [0.16, 0.05, 0.07]), ('w', [0.07, 0.06, 0.12]), ('y', [1.0, 0.72, 0.30]), ('d', [0.25, 0.14, 0.08]), ('c', [0.09, 0.07, 0.1])],
};

#[derive(Debug)]
pub struct Idle;

impl Scene for Idle {
    fn name(&self) -> &'static str {
        "idle"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn frame_ms(&self) -> u64 {
        250
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        sky(canvas);
        stars(canvas, t, (260, 0.0));
        falling_star(canvas, t);
        moon(canvas);
        hills(canvas);
        cottage(canvas, t);
    }
}

fn moon(canvas: &mut Canvas) {
    let centre = (canvas.size().0 * 0.83, 30.0);
    glow(canvas, centre, 26.0, [0.10, 0.09, 0.07]);
    glow(canvas, centre, 12.0, [0.18, 0.16, 0.12]);
    canvas.map(|x, y, pixel| mix(pixel, moon_surface(x - centre.0, y - centre.1), crescent(x - centre.0, y - centre.1)));
}

/// How much of the pixel at (dx, dy) from the moon's centre is lit crescent.
fn crescent(dx: f64, dy: f64) -> f64 {
    let (radius, lit) = (11.0, 11.0 - dx.hypotenuse(dy) + 0.5);
    let shadow = (dx + 6.5).hypotenuse(dy + 3.5) - radius + 0.5;
    lit.clamp(0.0, 1.0) * shadow.clamp(0.0, 1.0)
}

fn moon_surface(dx: f64, dy: f64) -> Shade {
    let craters = smoothstep(0.55, 0.8, value(dx / 3.5 + 10.0, dy / 3.5, 21));
    scale(hex(MOON), 1.05 - 0.22 * craters)
}

fn cottage(canvas: &mut Canvas, t: f64) {
    let (x, y) = (canvas.size().0 * 0.18, canvas.size().1 * 0.84 - 22.0);
    COTTAGE.stamp(canvas, (x, y), 2.6);
    glow(canvas, (x + 8.5, y + 15.5), 9.0, [0.30, 0.16, 0.04]);
    for puff in 0..7_u64 {
        chimney_smoke(canvas, (x + 21.0, y - 1.0), puff, t);
    }
}

/// Puff `puff` of smoke curling up from the chimney top at `top`.
fn chimney_smoke(canvas: &mut Canvas, top: (f64, f64), puff: u64, t: f64) {
    let age = (t * 0.22 + dice(puff, 40)).fract();
    let at = (top.0 + age * 14.0 + 2.5 * (age * 9.0 + dice(puff, 41) * 6.0).sine(), top.1 - age * 26.0);
    glow(canvas, at, 1.8 + age * 4.0, scale([0.40, 0.36, 0.48], 0.20 * (1.0 - age)));
}

/// Every `FALL_EVERY` seconds a star falls for 0.9 seconds from a new place.
fn falling_star(canvas: &mut Canvas, t: f64) {
    let (seed, k) = ((t / FALL_EVERY).floor().to_bits(), (t % FALL_EVERY) / 0.9);
    if k >= 1.0 { return; }
    let start = (canvas.size().0 * (0.25 + 0.5 * dice(seed, 50)), 6.0 + 20.0 * dice(seed, 51));
    let head = (start.0 + 70.0 * k, start.1 + 26.0 * k);
    let fade = 1.0 - smoothstep(0.6, 1.0, k);
    streak(canvas, ((head.0 - 26.0, head.1 - 9.7), head), 0.6, scale([0.5, 0.6, 0.9], 0.6 * fade));
    glow(canvas, head, 1.4, scale([1.0, 1.0, 1.0], 1.4 * fade));
}
