//! Pixel art stamped onto a canvas at any scale.

use super::canvas::Canvas;
use super::light::square;
use super::{Shade, float};

/// Rows of characters, each naming a colour in the palette; any character
/// the palette lacks is left clear.
#[derive(Debug, Clone, Copy)]
pub struct Sprite<'a> {
    pub rows: &'a [&'a str],
    pub palette: &'a [(char, Shade)],
}

impl Sprite<'_> {
    /// Stamps it with its top left at `corner`, each sprite pixel `pixel` wide.
    pub fn stamp(&self, canvas: &mut Canvas, corner: (f64, f64), pixel: f64) {
        for (y, row) in self.rows.iter().enumerate() {
            for (x, colour) in row.chars().enumerate().filter_map(|(x, key)| Some((x, self.colour(key)?))) {
                square(canvas, (corner.0 + float(x) * pixel, corner.1 + float(y) * pixel), (pixel, 1.0), colour);
            }
        }
    }

    fn colour(&self, key: char) -> Option<Shade> {
        self.palette.iter().find(|(k, _)| *k == key).map(|(_, colour)| *colour)
    }
}
