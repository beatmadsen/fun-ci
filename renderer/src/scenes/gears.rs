//! Build passed: two amber gears turn against each other in the dark, a
//! spark flying where their teeth meet, then they coast to a stop.

use std::f64::consts::TAU;

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::glow;
use crate::art::{Shade, add, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 3000;
const RADIUS: f64 = 18.0;
const TEETH: f64 = 9.0;
const AMBER: Shade = [0.95, 0.55, 0.15];
const DUSK: Shade = [0.022, 0.014, 0.01];

#[derive(Debug)]
pub struct Gears;

impl Scene for Gears {
    fn name(&self) -> &'static str {
        "gears"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let centre = (canvas.size().0 * 0.5, canvas.size().1 * 0.5);
        let (turn, light) = (turned(t), scale(AMBER, smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(2.5, 3.0, t))));
        let (left, right) = ((centre.0 - RADIUS - 2.0, centre.1), (centre.0 + RADIUS + 2.0, centre.1));
        canvas.map(|x, y, _| {
            let lit = gear((x - left.0, y - left.1), turn) + gear((x - right.0, y - right.1), 0.5 / TEETH - turn);
            add(DUSK, scale(light, lit.min(1.0)))
        });
        glow(canvas, centre, 4.0, scale([1.3, 0.9, 0.5], spark(t) * light[0]));
    }
}

/// How far the gears have turned by `t`, in turns: speeding up, then coasting.
fn turned(t: f64) -> f64 {
    0.35 * t - 0.12 * smoothstep(1.6, 3.0, t) * (t - 1.6)
}

/// How much of the point `offset` from a gear's centre the gear covers,
/// turned `turn` turns: a toothed rim around a hole, edges soft.
fn gear(offset: (f64, f64), turn: f64) -> f64 {
    let distance = offset.0.hypotenuse(offset.1);
    let angle = offset.1.arctangent2(offset.0) / TAU;
    let tooth = ((angle - turn) * TEETH).rem_euclid(1.0) < 0.5;
    let outer = RADIUS + if tooth { 3.5 } else { 0.0 };
    smoothstep(outer + 0.8, outer - 0.8, distance) * smoothstep(RADIUS * 0.35 - 0.8, RADIUS * 0.35 + 0.8, distance)
}

/// The spark where the teeth meet: a flash each time a tooth passes.
fn spark(t: f64) -> f64 {
    let phase = (turned(t) * TEETH).rem_euclid(1.0);
    (-(phase * 6.0)).exponential() * smoothstep(0.2, 0.5, t)
}
