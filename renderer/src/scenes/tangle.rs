//! A branch conflicts with the trunk: two magenta strands of light come in
//! from either side and wind around each other into a knot, which glows and
//! then fades. It winds rather than shakes (a failure) or rises (a pass).

use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::{Shade, mix, scale, seconds, smoothstep};
use super::strands::{Strands, strands};

const LENGTH_MS: u64 = 2600;
const MAGENTA: Shade = [1.0, 0.22, 0.85];
const NIGHT: Shade = [0.02, 0.01, 0.03];

#[derive(Debug)]
pub struct Tangle;

impl Scene for Tangle {
    fn name(&self) -> &'static str {
        "tangle"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let height = canvas.size().1;
        canvas.map(|_, y, _| mix(NIGHT, [0.04, 0.01, 0.05], y / height));
        let fade = 1.0 - smoothstep(2.1, 2.6, t);
        let (reach, tight) = (smoothstep(0.0, 1.0, t), smoothstep(0.8, 1.8, t));
        strands(canvas, Strands { reach, tight, light: scale(MAGENTA, fade) });
    }
}
