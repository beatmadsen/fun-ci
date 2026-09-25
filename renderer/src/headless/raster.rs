//! A cell grid drawn as pixels with the bundled 8x8 bitmap font (the MIT
//! licensed `font8x8` crate), each font row doubled to make 8x16 cells.
//! Braille (the spinner) is drawn as dots.

use font8x8::{BASIC_FONTS, BLOCK_FONTS, BOX_FONTS, LATIN_FONTS, UnicodeFonts};

use super::palette::{Rgb, cell_colours};
use crate::grid::{Cell, Grid};

/// Pixels per cell, (width, height).
pub const CELL: (usize, usize) = (8, 16);

/// An RGB image.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Image {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<u8>,
}

impl Image {
    #[must_use]
    pub fn blank(width: usize, height: usize) -> Self {
        Self { width, height, pixels: vec![0; width * height * 3] }
    }

    #[must_use]
    pub fn pixel(&self, x: usize, y: usize) -> Rgb {
        let at = (y * self.width + x) * 3;
        [self.pixels[at], self.pixels[at + 1], self.pixels[at + 2]]
    }

    pub fn set(&mut self, x: usize, y: usize, rgb: Rgb) {
        let at = (y * self.width + x) * 3;
        self.pixels[at..at + 3].copy_from_slice(&rgb);
    }
}

/// The grid as the terminal would paint it.
#[must_use]
pub fn render(grid: &Grid) -> Image {
    let mut image = Image::blank(usize::from(grid.cols) * CELL.0, usize::from(grid.rows) * CELL.1);
    for (row, cells) in grid.cells.iter().enumerate() {
        for (col, cell) in cells.iter().enumerate() {
            paint(&mut image, (col * CELL.0, row * CELL.1), cell);
        }
    }
    image
}

fn paint(image: &mut Image, (left, top): (usize, usize), cell: &Cell) {
    let (fg, bg) = cell_colours(cell);
    let glyph = glyph(cell.text.chars().next().unwrap_or(' '));
    for (y, bits) in glyph.iter().enumerate() {
        for x in 0..CELL.0 {
            image.set(left + x, top + y, if bits & (1 << x) == 0 { bg } else { fg });
        }
    }
}

/// Sixteen rows of eight pixels, bit 0 leftmost.
fn glyph(ch: char) -> [u8; 16] {
    if ('\u{2800}'..='\u{28FF}').contains(&ch) {
        return braille(u32::from(ch) - 0x2800);
    }
    let rows = [BASIC_FONTS.get(ch), LATIN_FONTS.get(ch), BOX_FONTS.get(ch), BLOCK_FONTS.get(ch)];
    let rows = rows.into_iter().flatten().next().unwrap_or([0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF]);
    std::array::from_fn(|y| rows[y / 2])
}

const BRAILLE_DOTS: [(usize, usize); 8] = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)];

fn braille(dots: u32) -> [u8; 16] {
    std::array::from_fn(|y| braille_row(dots, y))
}

fn braille_row(dots: u32, y: usize) -> u8 {
    let Some(offset) = y.checked_sub(1).filter(|offset| offset % 4 < 2) else {
        return 0;
    };
    let raised = |col: &usize| BRAILLE_DOTS.iter().position(|&dot| dot == (*col, offset / 4));
    let raised = |col: &usize| raised(col).is_some_and(|bit| dots & (1 << bit) != 0);
    (0..2).filter(raised).fold(0, |bits, col| bits | 0b11 << (1 + col * 4))
}
