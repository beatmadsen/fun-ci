//! A little rocket, pointing right: a lit white fuselage with a red nose,
//! stripe and fins, a porthole with a pilot who blinks, and a nozzle.
//! Painted per pixel from shapes, in units of `scale` canvas pixels.

use crate::art::math::Portable;
use crate::art::canvas::Canvas;
use crate::art::{Shade, add, mix, scale, smoothstep};

const HULL: Shade = [0.93, 0.94, 0.97];
const RED: Shade = [0.88, 0.12, 0.14];
const STEEL: Shade = [0.42, 0.45, 0.52];
const GLASS: Shade = [0.10, 0.28, 0.52];
const LENGTH: (f64, f64) = (28.0, 10.0);
const BACK: f64 = -20.0;

/// Paints the rocket centred on `centre`, `size` canvas pixels to a unit,
/// its pilot's eyes shut when `blink`.
pub fn rocket(canvas: &mut Canvas, centre: (f64, f64), size: f64, blink: bool) {
    canvas.map(|x, y, pixel| {
        let p = ((x - centre.0) / size, (y - centre.1) / size);
        let (shade, cover) = part(p, blink);
        mix(pixel, shade, cover)
    });
}

/// The colour at local point `p` and how much of the pixel it covers.
fn part(p: (f64, f64), blink: bool) -> (Shade, f64) {
    let fins = fin(p).max(fin((p.0, -p.1)));
    let body = body_cover(p);
    let hull = if body > 0.0 { hull(p, blink) } else { scale(RED, 0.62 + 0.2 * (-p.1 / 16.0)) };
    (hull, body.max(fins).max(nozzle(p)))
}

fn body_cover((u, v): (f64, f64)) -> f64 {
    let edge = ((u / LENGTH.0).powi(2) + (v / LENGTH.1).powi(2)).sqrt() - 1.0;
    ((0.5 - edge * LENGTH.1).clamp(0.0, 1.0)) * (u - BACK + 0.5).clamp(0.0, 1.0)
}

fn hull((u, v): (f64, f64), blink: bool) -> Shade {
    if u < BACK + 0.5 {
        return mix(lit(STEEL, v), [1.0, 0.55, 0.2], smoothstep(BACK - 1.0, BACK - 3.0, u));
    }
    let paint = if u > 13.0 || (-11.0..-8.0).contains(&u) { RED } else { HULL };
    let window = porthole((u - 3.0, v + 0.5), blink);
    mix(lit(paint, v), window.0, window.1)
}

/// Lambert light from above on a cylinder along the rocket, plus a highlight.
fn lit(colour: Shade, v: f64) -> Shade {
    let k = (v / LENGTH.1).clamp(-1.0, 1.0);
    let lambert = 0.28 + 0.72 * ((1.0 - k * k).sqrt() * 0.75 - k * 0.5).max(0.0);
    let highlight = (-((k + 0.5) / 0.16).powi(2)).exponential() * 0.55;
    add(scale(colour, lambert), [highlight; 3])
}

fn porthole((u, v): (f64, f64), blink: bool) -> (Shade, f64) {
    let r = u.hypotenuse(v);
    let rim = (6.6 - r).clamp(0.0, 1.0);
    let glass = mix(GLASS, [0.35, 0.6, 0.85], smoothstep(4.5, -4.5, v + u * 0.3));
    let inside = if r < 5.2 { pilot((u, v), glass, blink) } else { lit(STEEL, v * 1.5) };
    (inside, rim)
}

fn pilot((u, v): (f64, f64), glass: Shade, blink: bool) -> Shade {
    let face = (u.hypotenuse(v + -1.8) - 3.4).clamp(-0.5, 0.5) + 0.5;
    let skin = mix([1.0, 0.8, 0.62], glass, face);
    let across = u.abs() - 1.3;
    let eye = if blink { ((v + 1.2).abs() * 3.0).min(across.abs() * 1.2) } else { across.hypotenuse(v + 1.2) * 1.4 };
    let eyes = (eye - 0.6).clamp(0.0, 1.0);
    let shine = (-((u + 2.2).hypotenuse(v + 3.0) / 1.3).powi(2)).exponential() * 0.5;
    add(mix([0.08, 0.06, 0.1], skin, eyes), [shine; 3])
}

/// How much of the top fin covers `p`: a swept triangle behind the body.
fn fin((u, v): (f64, f64)) -> f64 {
    let (root, front, tip) = ((-21.0, -4.0), (-6.0, -6.0), (-25.0, -16.0));
    edge((u, v), root, front).min(edge((u, v), front, tip)).min(edge((u, v), tip, root)).clamp(0.0, 1.0)
}

/// Signed distance to the left of edge a->b, shifted to cover half a pixel on it.
fn edge(p: (f64, f64), a: (f64, f64), b: (f64, f64)) -> f64 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    ((p.0 - a.0) * dy - (p.1 - a.1) * dx) / dx.hypotenuse(dy) + 0.5
}

fn nozzle((u, v): (f64, f64)) -> f64 {
    ((u - BACK + 3.5).min(BACK + 0.5 - u) + 0.5).clamp(0.0, 1.0) * (5.0 - v.abs() + 0.5 - (BACK - u).max(0.0) * 0.4).clamp(0.0, 1.0)
}
