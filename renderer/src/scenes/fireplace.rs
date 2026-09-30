//! Quiet: a fire in a medieval stone hearth. Flames lick up from logs under a
//! pointed arch of rough fieldstones, a stone hood rises into the chimney,
//! and through a small window the storm rages: rain slants past and lightning
//! now and then lights the room.

use crate::maths::Portable;
use super::stonework::stone;
use super::storm::{in_window, lightning, outside, rain};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze};
use crate::art::noise::{dice, fbm, value};
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const PLASTER: Shade = [0.055, 0.04, 0.03];
const SOOT: Shade = [0.012, 0.008, 0.006];
const LOG: Shade = [0.09, 0.045, 0.02];
const FIRELIGHT: Shade = [0.55, 0.24, 0.07];
const SPARKS: u64 = 6;
/// The window's size across and down, in pixels.
const WINDOW: (f64, f64) = (18.0, 30.0);

#[derive(Debug)]
pub struct Fireplace;

impl Scene for Fireplace {
    fn name(&self) -> &'static str {
        "fireplace"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn frame_ms(&self) -> u64 {
        150
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let hearth = Hearth::new(canvas, t);
        canvas.map(|x, y, _| hearth.wall(x, y));
        rain(canvas, (hearth.window, WINDOW), t);
        logs(canvas, &hearth);
        canvas.map(|x, y, pixel| hearth.fire(x, y, t).map_or(pixel, |light| add(pixel, light)));
        (0..SPARKS).for_each(|i| spark(canvas, &hearth, i, t));
        canvas.map(|x, y, pixel| add(pixel, hearth.lightning_at(x, y)));
    }
}

/// The hearth: its arch centred at `centre`, standing on `floor`, with the
/// window beside it and the fire's flicker and the lightning's flash of the moment.
struct Hearth {
    centre: f64,
    floor: f64,
    window: (f64, f64),
    light: (f64, f64),
}

impl Hearth {
    const HALF_WIDTH: f64 = 30.0;
    const SPRING: f64 = 24.0;

    fn new(canvas: &Canvas, t: f64) -> Self {
        let (width, height) = canvas.size();
        let flicker = 0.85 + 0.1 * (t * 7.3).sine() + 0.08 * (value(t * 3.1, 0.5, 71) - 0.5);
        Self { centre: width * 0.45, floor: height - 8.0, window: (width * 0.84, 34.0), light: (flicker, lightning(t)) }
    }

    fn flicker(&self) -> f64 {
        self.light.0
    }

    /// Whether (x, y) lies in the opening: straight jambs under a pointed arch.
    fn inside(&self, x: f64, y: f64) -> bool {
        let (spring, k) = (self.floor - Self::SPRING, Self::HALF_WIDTH * 0.5);
        let arc = |cx: f64| (x - cx).hypotenuse(y - spring) < Self::HALF_WIDTH + k;
        (x - self.centre).abs() < Self::HALF_WIDTH && y < self.floor && (y > spring || arc(self.centre - k) && arc(self.centre + k))
    }

    /// Whether (x, y) lies in the stonework: a hood that narrows as it rises
    /// into the chimney, its edge as rough as the stones.
    fn masonry(&self, x: f64, y: f64) -> bool {
        let reach = 34.0 + 30.0 * smoothstep(0.0, self.floor, y) + 5.0 * value(y / 9.0, 1.0, 80);
        (x - self.centre).abs() < reach || y > self.floor
    }

    /// The wall at (x, y), lit by the fire.
    fn wall(&self, x: f64, y: f64) -> Shade {
        let reach = (x - self.centre).hypotenuse((y - self.floor + 20.0) * 1.3);
        add(self.surface(x, y), scale(FIRELIGHT, self.flicker() * 0.7 * (-reach / 55.0).exponential()))
    }

    /// What the wall is at (x, y): soot in the opening, the storm in the
    /// window, stones in the hood, hearth and window frame, plaster beyond.
    fn surface(&self, x: f64, y: f64) -> Shade {
        if self.inside(x, y) { return SOOT; }
        if in_window((x, y), self.window, WINDOW) { return outside(y, self.light.1, self.floor); }
        let frame = in_window((x, y), self.window, (WINDOW.0 + 10.0, WINDOW.1 + 10.0));
        if self.masonry(x, y) || frame { return stone(x, y, 81); }
        scale(PLASTER, 0.8 + 0.4 * fbm(x / 20.0, y / 14.0, 82))
    }

    /// The lightning's cold light at (x, y), falling in through the window.
    fn lightning_at(&self, x: f64, y: f64) -> Shade {
        let from_window = (x - self.window.0).hypotenuse(y - self.window.1);
        scale([0.22, 0.25, 0.34], self.light.1 * (-from_window / 90.0).exponential())
    }

    /// The flames' light at (x, y), rising from the logs; none outside them.
    fn fire(&self, x: f64, y: f64, t: f64) -> Option<Shade> {
        let (across, up) = ((x - self.centre) / 24.0, (self.floor - 8.0 - y) / 44.0);
        if !self.inside(x, y) || up < 0.0 || across.abs() > 1.0 {
            return None;
        }
        let tongue = (fbm(x / 5.0, y / 10.0 + t * 2.6, 73) + 0.12) * (1.0 - across * across);
        let heat = smoothstep(up - 0.1, up + 0.3, tongue * self.flicker());
        (heat > 0.02).then(|| flame(heat))
    }
}

/// The flame's colour for `heat`, from deep red at its edge to a warm core.
fn flame(heat: f64) -> Shade {
    let ember = mix([0.45, 0.05, 0.01], [1.0, 0.36, 0.05], smoothstep(0.0, 0.7, heat));
    mix(ember, [1.2, 0.8, 0.3], smoothstep(0.75, 1.0, heat))
}

/// Two logs on the hearth, solid wood, with embers glowing under them.
fn logs(canvas: &mut Canvas, hearth: &Hearth) {
    let base = hearth.floor - 5.0;
    for step in 0..9_u32 {
        let along = f64::from(step) * 4.0 - 16.0;
        haze(canvas, (hearth.centre + along, base - along.abs() * 0.12), 2.2, (LOG, 1.0));
    }
    glow(canvas, (hearth.centre, base + 3.0), 9.0, scale([0.9, 0.28, 0.05], 0.55 * hearth.flicker()));
}

/// Spark `i`: every few seconds it leaves the fire, drifts up and dies.
fn spark(canvas: &mut Canvas, hearth: &Hearth, i: u64, t: f64) {
    let period = 2.5 + 2.0 * dice(i, 76);
    let age = (t + period * dice(i, 77)) % period / period;
    let at = (hearth.centre + (dice(i, 78) - 0.5) * 30.0 + 4.0 * (age * 9.0 + float(usize::try_from(i).unwrap_or(0))).sine(),
              hearth.floor - 12.0 - age * 40.0);
    if hearth.inside(at.0, at.1) {
        glow(canvas, at, 0.8, scale([1.4, 0.7, 0.2], 1.0 - age));
    }
}
