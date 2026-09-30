//! The storm outside the fireplace's window: rain slanting past a small
//! arched window, and now and then lightning that lights the whole room.

use crate::maths::Portable;
use crate::art::canvas::Canvas;
use crate::art::light::streak;
use crate::art::noise::dice;
use crate::art::{Shade, add, mix, scale};

/// Each storm cycle's length, and when in it the lightning strikes (a double flash).
const CYCLE: f64 = 7.0;
const STRIKES: [f64; 3] = [2.2, 2.35, 5.6];
const NIGHT: Shade = [0.03, 0.045, 0.09];
const RAIN: Shade = [0.16, 0.2, 0.3];

/// How bright the lightning is at `t`: a sharp flash at each strike, dying fast.
pub fn lightning(t: f64) -> f64 {
    let into = t % CYCLE;
    STRIKES.iter().filter(|at| into >= **at).map(|at| (-(into - at) / 0.07).exponential()).sum::<f64>().min(1.0)
}

/// The window: an arched opening `size` pixels across and down, centred on
/// `centre`, whether (x, y) is in it.
pub fn in_window((x, y): (f64, f64), centre: (f64, f64), size: (f64, f64)) -> bool {
    let (half, top) = (size.0 / 2.0, centre.1 - size.1 / 2.0);
    let (dx, below) = ((x - centre.0).abs(), y - top - half);
    dx < half && y < centre.1 + size.1 / 2.0 && (below > 0.0 || dx.hypotenuse(below) < half)
}

/// The night beyond the window at (x, y), lit by `flash`.
pub fn outside(y: f64, flash: f64, height: f64) -> Shade {
    add(mix(NIGHT, [0.04, 0.05, 0.08], y / height), scale([0.7, 0.75, 0.95], flash))
}

/// Rain streaks falling across the window at `centre`, `t` seconds in.
pub fn rain(canvas: &mut Canvas, (centre, size): ((f64, f64), (f64, f64)), t: f64) {
    for i in 0..40_u64 {
        let fall = (t * 90.0 + dice(i, 90) * size.1 * 2.0) % (size.1 * 1.4) - size.1 * 0.2;
        let x = centre.0 - size.0 / 2.0 + dice(i, 91) * size.0 - fall * 0.3;
        let top = centre.1 - size.1 / 2.0 + fall;
        if in_window((x, top), centre, size) {
            streak(canvas, ((x, top), (x - 1.2, top + 4.0)), 0.45, RAIN);
        }
    }
}
