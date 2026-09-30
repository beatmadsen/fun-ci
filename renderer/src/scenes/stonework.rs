//! Rough fieldstones set in mortar, as a medieval mason laid them: rounded,
//! irregular stones of different sizes and shades, no two alike.

use crate::maths::Portable;
use crate::art::noise::{dice, value};
use crate::art::{Shade, mix, scale, smoothstep};

const MORTAR: Shade = [0.045, 0.04, 0.035];
const GREY: Shade = [0.17, 0.16, 0.15];
const OCHRE: Shade = [0.19, 0.15, 0.1];
/// A stone's usual size across and down, in pixels.
const SIZE: (f64, f64) = (15.0, 10.0);

/// The stone, or the mortar between stones, at (x, y); `salt` makes another wall.
pub fn stone(x: f64, y: f64, salt: u64) -> Shade {
    let (nearest, gap, id) = nearest_stones(x, y, salt);
    if gap < 1.3 {
        return MORTAR;
    }
    let tint = mix(GREY, OCHRE, dice(id, salt + 1));
    let rounded = 0.7 + 0.3 * smoothstep(0.0, 5.0, gap) - 0.004 * nearest;
    scale(tint, (0.6 + 0.6 * dice(id, salt + 2)) * rounded * (0.9 + 0.2 * value(x / 2.5, y / 2.5, salt + 3)))
}

/// The distance to the nearest stone's heart, how far that is inside its
/// edge (half the gap to the next heart), and which stone it is.
fn nearest_stones(x: f64, y: f64, salt: u64) -> (f64, f64, u64) {
    let (cx, cy) = ((x / SIZE.0).floor(), (y / SIZE.1).floor());
    let cells = (-1..=1).flat_map(|dy| (-1..=1).map(move |dx| (cx + f64::from(dx), cy + f64::from(dy))));
    let mut hearts: Vec<(f64, u64)> = cells.map(|cell| heart_distance((x, y), cell, salt)).collect();
    hearts.sort_by(|a, b| a.0.total_cmp(&b.0));
    (hearts[0].0, (hearts[1].0 - hearts[0].0) / 2.0, hearts[0].1)
}

/// How far (x, y) is from the heart of the stone in `cell`, and the stone's id.
fn heart_distance((x, y): (f64, f64), (cx, cy): (f64, f64), salt: u64) -> (f64, u64) {
    let id = cx.to_bits().rotate_left(17) ^ cy.to_bits();
    let heart = ((cx + 0.15 + 0.7 * dice(id, salt)) * SIZE.0, (cy + 0.15 + 0.7 * dice(id, salt + 4)) * SIZE.1);
    ((x - heart.0).hypotenuse((y - heart.1) * SIZE.0 / SIZE.1), id)
}
