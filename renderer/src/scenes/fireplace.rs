//! Quiet: a fire in a rural stone fireplace. Flames lick up from two crossed
//! logs, embers glow and the odd spark drifts up, and the firelight flickers
//! over rough stones set in uneven courses on a dark timber wall.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze, square};
use crate::art::noise::{dice, fbm, value};
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const TIMBER: Shade = [0.06, 0.032, 0.018];
const BEAM: Shade = [0.08, 0.045, 0.022];
const STONE: Shade = [0.16, 0.15, 0.14];
const MORTAR: Shade = [0.05, 0.045, 0.04];
const SOOT: Shade = [0.012, 0.008, 0.006];
const LOG: Shade = [0.09, 0.045, 0.02];
const SPARKS: u64 = 6;

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
        let (width, height) = canvas.size();
        let hearth = Hearth { centre: width * 0.5, floor: height - 10.0, flicker: flicker(t) };
        canvas.map(|x, y, _| hearth.wall(x, y));
        mantel(canvas, &hearth);
        logs(canvas, &hearth);
        canvas.map(|x, y, pixel| hearth.fire(x, y, t).map_or(pixel, |light| add(pixel, light)));
        (0..SPARKS).for_each(|i| spark(canvas, &hearth, i, t));
    }
}

/// How bright the fire burns at `t`: a restless flicker around a steady glow.
fn flicker(t: f64) -> f64 {
    0.85 + 0.1 * (t * 7.3).sine() + 0.08 * (value(t * 3.1, 0.5, 71) - 0.5)
}

/// The fireplace: its opening centred at `centre`, standing on `floor`.
struct Hearth {
    centre: f64,
    floor: f64,
    flicker: f64,
}

impl Hearth {
    const HALF_WIDTH: f64 = 30.0;
    const HEIGHT: f64 = 52.0;
    const SURROUND: f64 = 26.0;

    /// Whether (x, y) lies inside the opening: straight sides under a round arch.
    fn inside(&self, x: f64, y: f64) -> bool {
        let dx = (x - self.centre).abs();
        let spring = self.floor - Self::HEIGHT + Self::HALF_WIDTH;
        dx < Self::HALF_WIDTH && y < self.floor && (y > spring || dx.hypotenuse(spring - y) < Self::HALF_WIDTH)
    }

    /// The wall: stones around the opening, timber beyond, all lit by the fire.
    fn wall(&self, x: f64, y: f64) -> Shade {
        let near = (x - self.centre).abs() < Self::HALF_WIDTH + Self::SURROUND && y > self.floor - Self::HEIGHT - 18.0;
        let base = if self.inside(x, y) { SOOT } else if near { stone(x, y) } else { plank(x) };
        let reach = (x - self.centre).hypotenuse((y - self.floor + 20.0) * 1.3);
        add(base, scale([0.55, 0.24, 0.07], self.flicker * 0.7 * (-reach / 55.0).exponential()))
    }

    /// The flames' light at (x, y), rising from the logs; none outside them.
    fn fire(&self, x: f64, y: f64, t: f64) -> Option<Shade> {
        let (across, up) = ((x - self.centre) / 24.0, (self.floor - 8.0 - y) / 44.0);
        if !self.inside(x, y) || up < 0.0 || across.abs() > 1.0 {
            return None;
        }
        let tongue = (fbm(x / 5.0, y / 10.0 + t * 2.6, 73) + 0.12) * (1.0 - across * across);
        let heat = smoothstep(up - 0.1, up + 0.3, tongue * self.flicker);
        (heat > 0.02).then(|| flame(heat))
    }
}

/// Upright timber planks, each a little different, with dark seams between.
fn plank(x: f64) -> Shade {
    let board = (x / 14.0).floor();
    let seam = if x.rem_euclid(14.0) < 1.0 { 0.4 } else { 1.0 };
    scale(TIMBER, seam * (0.8 + 0.4 * dice(board.to_bits(), 79)))
}

/// The timber mantel beam over the stones, its underside catching the light.
fn mantel(canvas: &mut Canvas, hearth: &Hearth) {
    let (left, top) = (hearth.centre - Hearth::HALF_WIDTH - Hearth::SURROUND - 6.0, hearth.floor - Hearth::HEIGHT - 24.0);
    for column in 0..14_u32 {
        square(canvas, (left + f64::from(column) * 8.0, top), (8.0, 1.0), BEAM);
    }
    haze(canvas, (hearth.centre, top + 8.0), 20.0, (scale([0.5, 0.22, 0.06], hearth.flicker), 0.25));
}

/// A rough stone at (x, y): courses of uneven blocks, each its own shade, in mortar.
fn stone(x: f64, y: f64) -> Shade {
    let course = (y / 10.0).floor();
    let offset = if course.rem_euclid(2.0) < 1.0 { 0.0 } else { 9.0 };
    let (column, along, down) = (((x + offset) / 18.0).floor(), (x + offset).rem_euclid(18.0), y.rem_euclid(10.0));
    if along < 1.5 || down < 1.5 {
        return MORTAR;
    }
    let block = dice(column.to_bits() ^ course.to_bits(), 74);
    scale(STONE, 0.7 + 0.5 * block + 0.15 * (value(x / 3.0, y / 3.0, 75) - 0.5))
}

/// The flame's colour for `heat`, from deep red at its edge to a pale core.
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
    glow(canvas, (hearth.centre, base + 3.0), 9.0, scale([0.9, 0.28, 0.05], 0.55 * hearth.flicker));
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
