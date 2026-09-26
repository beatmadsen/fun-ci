//! Quiet: a castaway's island by moonlight. A lone palm leans over a scrap of
//! sand, its fronds swaying in the breeze, surf laps the shore, and the full
//! moon lays a glittering path across the sea.

use crate::art::math::Portable;
use super::sky::stars;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze, streak};
use crate::art::noise::value;
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const ZENITH: Shade = [0.005, 0.01, 0.04];
const HORIZON_SKY: Shade = [0.04, 0.07, 0.16];
const SEA: Shade = [0.01, 0.025, 0.06];
const MOONLIGHT: Shade = [0.9, 0.9, 0.75];
const SAND: Shade = [0.22, 0.2, 0.14];
const TRUNK: Shade = [0.07, 0.05, 0.035];
const LEAF: Shade = [0.035, 0.09, 0.05];
const RIM: Shade = [0.2, 0.21, 0.18];
const FRONDS: u32 = 7;

#[derive(Debug)]
pub struct Island;

impl Scene for Island {
    fn name(&self) -> &'static str {
        "island"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn frame_ms(&self) -> u64 {
        250
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let view = View { horizon: height * 0.62, moon: (width * 0.76, 24.0), shore: (width * 0.36, height * 0.62 + 12.0) };
        canvas.map(|x, y, _| view.backdrop(x, y, t));
        stars(canvas, t, (700, 0.0));
        moon(canvas, view.moon);
        sand_and_surf(canvas, view.shore, t);
        palm(canvas, view.shore, t);
    }
}

/// Where the sea meets the sky, where the moon hangs, and the island's middle.
struct View {
    horizon: f64,
    moon: (f64, f64),
    shore: (f64, f64),
}

impl View {
    /// The sky above the horizon; below it the sea, with the moon's path glittering.
    fn backdrop(&self, x: f64, y: f64, t: f64) -> Shade {
        if y < self.horizon {
            return mix(ZENITH, HORIZON_SKY, smoothstep(0.0, self.horizon, y));
        }
        let depth = y - self.horizon;
        let path = (-((x - self.moon.0) / (4.0 + depth * 0.5)).power(2.0)).exponential();
        let glitter = smoothstep(0.62, 0.8, value(x / 3.0, depth * 0.9 - t * 1.5, 91));
        add(scale(SEA, 1.0 + depth * 0.02), scale(MOONLIGHT, path * glitter * 0.8))
    }
}

/// The full moon at `at`, with a soft halo.
fn moon(canvas: &mut Canvas, at: (f64, f64)) {
    glow(canvas, at, 16.0, scale(MOONLIGHT, 0.12));
    glow(canvas, at, 6.5, scale(MOONLIGHT, 1.4));
}

/// The island's sand, pale in the moonlight, and a line of surf that swells and ebbs.
fn sand_and_surf(canvas: &mut Canvas, shore: (f64, f64), t: f64) {
    let swell = 0.6 + 0.4 * (t * 1.3).sine();
    for step in 0..=20_u32 {
        let along = f64::from(step) / 20.0 * 2.0 - 1.0;
        let at = (shore.0 + along * 46.0, shore.1 - (1.0 - along * along) * 10.0);
        haze(canvas, at, 5.0, (SAND, 1.0));
        glow(canvas, (at.0, shore.1 + 3.0), 1.4, scale([0.4, 0.45, 0.5], swell * 0.4));
    }
}

/// The palm: a trunk that leans and curves up from the sand, and fronds
/// drooping from its crown, swaying in the breeze.
fn palm(canvas: &mut Canvas, shore: (f64, f64), t: f64) {
    let trunk = |k: f64| (shore.0 + k * 22.0 + k * k * 10.0, shore.1 - 9.0 - k * 60.0);
    for step in 0..=24_u32 {
        let k = f64::from(step) / 24.0;
        haze(canvas, trunk(k), 2.2 - k * 0.8, (TRUNK, 1.0));
        streak(canvas, (trunk(k), (trunk(k).0 + 1.5, trunk(k).1)), 0.4, RIM);
    }
    (0..FRONDS).for_each(|i| frond(canvas, trunk(1.0), i, t));
}

/// Frond `i` from `crown`: an arc out and down, swaying with the breeze.
fn frond(canvas: &mut Canvas, crown: (f64, f64), i: u32, t: f64) {
    let angle = -2.6 + f64::from(i) * 0.85 + 0.08 * (t * 0.9 + f64::from(i)).sine();
    let point = |k: f64| (crown.0 + angle.cosine() * 34.0 * k, crown.1 + angle.sine() * 14.0 * k + 13.0 * k * k);
    for step in 0..=14_u32 {
        let k = float(usize::try_from(step).unwrap_or(0)) / 14.0;
        haze(canvas, point(k), 2.6 * (1.0 - k) + 0.7, (LEAF, 1.0));
        streak(canvas, (point(k), (point(k).0, point(k).1 - 1.2)), 0.35, scale(RIM, 0.7));
    }
}
