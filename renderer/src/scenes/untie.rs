//! A branch no longer conflicts with the trunk: the magenta knot loosens,
//! the strands unwind, paling to lilac, and draw back to their edges.

use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::{Shade, mix, scale, seconds, smoothstep};
use super::strands::{Strands, strands};

const LENGTH_MS: u64 = 2400;
const MAGENTA: Shade = [1.0, 0.22, 0.85];
const LILAC: Shade = [0.75, 0.6, 1.0];
const NIGHT: Shade = [0.02, 0.01, 0.03];

#[derive(Debug)]
pub struct Untie;

impl Scene for Untie {
    fn name(&self) -> &'static str {
        "untie"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let height = canvas.size().1;
        canvas.map(|_, y, _| mix(NIGHT, [0.03, 0.02, 0.05], y / height));
        let tight = 1.0 - smoothstep(0.0, 1.0, t);
        let reach = 1.0 - smoothstep(1.1, 2.2, t);
        let light = scale(mix(LILAC, MAGENTA, tight), 1.0 - smoothstep(1.9, 2.4, t));
        strands(canvas, Strands { reach, tight, light });
    }
}
