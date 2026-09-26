//! Quiet: an aurora. Violet and blue curtains of light sway slowly over the
//! hills under a sparse field of stars.

use super::sky::{hills, sky, stars};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::noise::fbm;
use crate::art::{Shade, add, scale, seconds, smoothstep};

const VIOLET: Shade = [0.34, 0.10, 0.46];
const BLUE: Shade = [0.08, 0.20, 0.42];

#[derive(Debug)]
pub struct Aurora;

impl Scene for Aurora {
    fn name(&self) -> &'static str {
        "aurora"
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
        stars(canvas, t, (520, 0.0));
        curtains(canvas, t);
        hills(canvas);
    }
}

/// The curtains: bands that ripple along the sky, brightest near their foot
/// and fading upwards, drifting a little each second.
fn curtains(canvas: &mut Canvas, t: f64) {
    let height = canvas.size().1;
    canvas.map(|x, y, pixel| {
        let sway = fbm(x / 70.0 + t * 0.04, t * 0.03, 31);
        let foot = height * (0.35 + 0.18 * sway);
        let lit = smoothstep(foot - 38.0, foot, y) * (1.0 - smoothstep(foot, foot + 6.0, y));
        let hue = smoothstep(0.3, 0.7, fbm(x / 120.0 - t * 0.02, 3.0, 37));
        add(pixel, scale(add(scale(VIOLET, hue), scale(BLUE, 1.0 - hue)), lit * (0.4 + 0.6 * sway)))
    });
}
