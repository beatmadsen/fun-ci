//! Resting after a failure: a warning kept in view. A dark red glow pulses
//! slowly behind an amber hazard sign, a triangle round an exclamation mark,
//! so a glance still finds it minutes after the explosion.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::{Shade, mix, scale, seconds};
use super::lettering::{Style, title};

const EMBER: Shade = [0.035, 0.008, 0.008];
const PULSE: Shade = [0.5, 0.06, 0.03];
const AMBER: Shade = [1.0, 0.6, 0.12];

#[derive(Debug)]
pub struct Warning;

impl Scene for Warning {
    fn name(&self) -> &'static str {
        "warning"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let (width, height) = canvas.size();
        let pulse = 0.5 + 0.5 * (seconds(t_ms) * std::f64::consts::TAU / 2.0).sine();
        canvas.map(|_, y, _| mix(EMBER, [0.06, 0.012, 0.01], y / height));
        glow(canvas, (width * 0.5, height * 0.5), 26.0, scale(PULSE, 0.4 + 0.6 * pulse));
        sign(canvas, (width * 0.5, height * 0.52), scale(AMBER, 0.7 + 0.3 * pulse));
    }

    fn frame_ms(&self) -> u64 {
        250
    }
}

/// A hazard triangle round an exclamation mark, centred on `centre`, in `light`.
fn sign(canvas: &mut Canvas, centre: (f64, f64), light: Shade) {
    let (top, left, right) = ((centre.0, centre.1 - 30.0), (centre.0 - 34.0, centre.1 + 26.0), (centre.0 + 34.0, centre.1 + 26.0));
    for edge in [(top, left), (left, right), (right, top)] {
        streak(canvas, edge, 1.6, light);
    }
    let fill = move |_: usize, _: f64, _: f64| light;
    let flat = |_: usize| 0.0;
    title(canvas, "!", (centre.0, centre.1 + 4.0), &Style { pixel: 3.0, opacity: 1.0, shadow: [0.05, 0.0, 0.0], fill: &fill, lift: &flat });
}
