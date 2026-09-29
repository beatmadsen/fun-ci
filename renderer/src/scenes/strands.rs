//! Two strands of light, one from each edge, that wind around each other
//! where they meet: loosely while they are apart, into a tight knot as
//! `tight` goes to one. The trunk's scenes draw them (docs/trunk-conflicts.md).

use crate::art::canvas::Canvas;
use crate::art::math::Portable;
use crate::art::{Shade, add, scale};

/// How far the strands have come in from their edges (0 to 1), how tightly they wind (0 to 1), and their light.
#[derive(Debug, Clone, Copy)]
pub struct Strands {
    pub reach: f64,
    pub tight: f64,
    pub light: Shade,
}

/// Paints `strands` over what the canvas holds.
pub fn strands(canvas: &mut Canvas, strands: Strands) {
    let (width, height) = canvas.size();
    let half = width * 0.5;
    canvas.map(|x, y, shade| {
        let u = (x - half) / half;
        add(shade, scale(strands.light, lit(u, (y - height * 0.5) / height, strands)))
    });
}

/// How lit a point is, at `u` across (-1 to 1) and `v` down (-0.5 to 0.5) from the centre.
fn lit(u: f64, v: f64, strands: Strands) -> f64 {
    let (offset, knot) = (winding(u, strands.tight), (-(u / 0.12).powi(2) - (v / 0.08).powi(2)).exponential());
    let near = |sign: f64| (-((v - sign * offset) / 0.022).powi(2)).exponential();
    let from_left = reached(u + 1.0, strands.reach);
    let from_right = reached(1.0 - u, strands.reach);
    near(1.0) * from_left + near(-1.0) * from_right + knot * strands.tight * 0.8
}

/// How far from the middle line a strand is at `u`: a wave that winds faster and closer near the centre.
fn winding(u: f64, tight: f64) -> f64 {
    let centre = (-(u / 0.3).powi(2)).exponential();
    let amplitude = 0.22 * (1.0 - 0.7 * tight * centre);
    amplitude * (u * 5.0 + tight * 16.0 * centre).sine()
}

/// Whether a strand has come as far as `travelled` from its own edge (0 there, 2 at the far edge), softly;
/// at full reach each passes the centre, so the two overlap where they wind.
fn reached(travelled: f64, reach: f64) -> f64 {
    ((1.3 * reach - travelled) / 0.04).clamp(-1.0, 1.0) * 0.5 + 0.5
}
