//! Lint passed: a comet of teal light sweeps across the dark, leaving a
//! clean line behind it, and a tick lights up where it comes to rest.

use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::{Shade, mix, scale, seconds, smoothstep};
use super::tick::tick;

const LENGTH_MS: u64 = 2400;
const TEAL: Shade = [0.25, 1.1, 1.0];
const NIGHT: Shade = [0.01, 0.02, 0.035];

#[derive(Debug)]
pub struct Sweep;

impl Scene for Sweep {
    fn name(&self) -> &'static str {
        "sweep"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let fade = 1.0 - smoothstep(1.9, 2.4, t);
        canvas.map(|_, y, _| mix(NIGHT, [0.02, 0.05, 0.07], y / height));
        let (row, head) = (height * 0.55, width * (0.1 + 0.62 * smoothstep(0.05, 1.2, t)));
        comet(canvas, (width * 0.1, row), head, scale(TEAL, fade));
        tick(canvas, ((width * 0.8, row), 22.0), smoothstep(1.1, 1.5, t), scale(TEAL, fade));
    }
}

/// The line swept clean from `start` up to `head`, and the comet at its head.
fn comet(canvas: &mut Canvas, start: (f64, f64), head: f64, light: Shade) {
    streak(canvas, (start, (head, start.1)), 0.8, scale(light, 0.6));
    streak(canvas, ((head - 40.0, start.1), (head, start.1)), 1.8, scale(light, 0.8));
    glow(canvas, (head, start.1), 4.5, scale(light, 1.4));
}
