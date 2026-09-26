//! Resting after a pass: a still, deep teal dusk with a soft band of light
//! along the horizon that breathes very slowly, and a steady tick above it.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::{Shade, add, mix, scale, seconds};
use super::tick::tick;

const DUSK: Shade = [0.01, 0.03, 0.045];
const HORIZON: Shade = [0.05, 0.22, 0.2];
const TEAL: Shade = [0.3, 0.95, 0.75];

#[derive(Debug)]
pub struct Calm;

impl Scene for Calm {
    fn name(&self) -> &'static str {
        "calm"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let (width, height) = canvas.size();
        let breath = 0.85 + 0.15 * (seconds(t_ms) * std::f64::consts::TAU / 6.0).sine();
        canvas.map(|_, y, _| {
            let near = (-((y - height * 0.82) / 10.0).power(2.0)).exponential();
            add(mix(DUSK, [0.02, 0.06, 0.07], y / height), scale(HORIZON, near * breath))
        });
        tick(canvas, ((width * 0.5, height * 0.45), 18.0), 1.0, scale(TEAL, 0.8));
    }

    fn frame_ms(&self) -> u64 {
        250
    }
}
