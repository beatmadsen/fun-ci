//! Success: YAY! Big rainbow letters, extruded and bouncing in turn, over a
//! sunset full of rays, with shiny balloons drifting up on wavy strings.

use crate::art::math::Portable;
use super::lettering::{Style, title};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::streak;
use crate::art::noise::dice;
use crate::art::{Shade, add, float, hue, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 3800;
const BALLOONS: u64 = 7;
const DEPTH: usize = 4;

#[derive(Debug)]
pub struct Yay;

impl Scene for Yay {
    fn name(&self) -> &'static str {
        "yay"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        backdrop(canvas, t);
        (0..BALLOONS).for_each(|i| balloon(canvas, i, t));
        letters(canvas, t);
    }
}

fn backdrop(canvas: &mut Canvas, t: f64) {
    let (width, height) = canvas.size();
    canvas.map(|x, y, _| {
        let (dx, dy) = (x - width * 0.5, y - height * 1.1);
        let rays = (0.5 + 0.5 * (dy.arctangent2(dx) * 18.0 - t * 1.5).cosine()) * 0.12;
        add(mix([0.28, 0.08, 0.42], [1.0, 0.45, 0.35], smoothstep(0.0, 1.0, y / height)), [rays, rays * 0.7, rays * 0.4])
    });
}

fn letters(canvas: &mut Canvas, t: f64) {
    let arrive = smoothstep(0.0, 0.35, t);
    let centre = (canvas.size().0 * 0.5, canvas.size().1 * 0.5 + 60.0 * (1.0 - arrive));
    for layer in (1..=DEPTH).rev() {
        extrusion(canvas, (centre, layer), arrive, t);
    }
    face(canvas, centre, arrive, t);
}

/// The letters' face, in rainbow colours that drift across them.
fn face(canvas: &mut Canvas, centre: (f64, f64), arrive: f64, t: f64) {
    let fill = move |i: usize, _: f64, y: f64| add(hue(t * 0.35 + float(i) * 0.18 + y / 180.0), [0.25; 3]);
    let lift = move |i: usize| bounce(t - float(i) * 0.15);
    title(canvas, "YAY!", centre, &Style { pixel: 5.5, opacity: arrive, shadow: [0.1, 0.02, 0.1], fill: &fill, lift: &lift });
}

/// The letters' side `layer` steps behind their face at `centre`, darker the deeper it lies.
fn extrusion(canvas: &mut Canvas, (centre, layer): ((f64, f64), usize), arrive: f64, t: f64) {
    let (offset, shade) = (float(layer) * 1.2, scale([0.42, 0.1, 0.3], 1.0 - float(layer) / float(DEPTH + 2)));
    let side = move |_: usize, _: f64, _: f64| shade;
    let lift = move |i: usize| bounce(t - float(i) * 0.15);
    let style = Style { pixel: 5.5, opacity: arrive, shadow: shade, fill: &side, lift: &lift };
    title(canvas, "YAY!", (centre.0 + offset, centre.1 + offset), &style);
}

/// How high a letter jumps `t` seconds into its hop: up and down each
/// 0.6 seconds, higher at the start.
fn bounce(t: f64) -> f64 {
    let phase = t.max(0.0) % 0.6 / 0.6;
    8.0 * (phase * std::f64::consts::PI).sine() * (0.5 + 0.5 * (-t.max(0.0)).exponential())
}

fn balloon(canvas: &mut Canvas, i: u64, t: f64) {
    let at = balloon_at(i, t, canvas.size());
    let colour = hue(dice(i, 174));
    string(canvas, (at.0, at.1 + 9.0), t);
    canvas.map(|x, y, pixel| {
        let (dx, dy) = ((x - at.0) / 7.0, (y - at.1) / 9.0);
        mix(pixel, shiny(colour, dx, dy), ((1.0 - dx.hypotenuse(dy)) * 8.0).clamp(0.0, 1.0))
    });
}

/// Where balloon `i` has drifted up to after `t` seconds, swaying as it goes.
fn balloon_at(i: u64, t: f64, (width, height): (f64, f64)) -> (f64, f64) {
    let rise = t * (22.0 + 10.0 * dice(i, 170));
    (width * (0.08 + 0.84 * dice(i, 171)) + 5.0 * (t * 1.7 + dice(i, 172) * 6.0).sine(), height * (0.35 + 0.9 * dice(i, 173)) - rise)
}

/// A balloon's skin at (dx, dy) of its radius from its centre: lit from the
/// upper left, with a glossy highlight.
fn shiny(colour: Shade, dx: f64, dy: f64) -> Shade {
    let light = 0.45 + 0.7 * (0.6 - dx * 0.5 - dy * 0.6).clamp(0.0, 1.0);
    let gloss = (-((dx + 0.36).hypotenuse(dy + 0.39) / 0.17).powi(2)).exponential() * 0.7;
    add(scale(colour, light), [gloss; 3])
}

fn string(canvas: &mut Canvas, from: (f64, f64), t: f64) {
    let point = |k: f64| (from.0 + 2.0 * (k * 0.5 + t * 4.0).sine(), from.1 + k * 3.0);
    for k in 0..7_u32 {
        streak(canvas, (point(f64::from(k)), point(f64::from(k + 1))), 0.35, [0.5, 0.45, 0.45]);
    }
}
