//! Canvas pixels as terminal cells. Each cell covers 4x8 pixels, sampled as
//! 2x4 blocks of 2x2. A cell is drawn as whichever glyph, in the two colours
//! that fit it best, comes closest to its samples: a quadrant glyph, solid in
//! the quarters it covers; a lower block a quarter or three quarters high,
//! for edges between the quadrants' rows; or up to three braille dots, which
//! light about a quarter of the spot each covers and so draw points of light.

use super::canvas::Canvas;
use super::Shade;

/// Pixels a cell covers, (width, height).
pub const CELL_PIXELS: (usize, usize) = (4, 8);

/// How much of its sample a braille dot lights.
const DOT: f64 = 0.25;

/// How much closer than a quadrant glyph braille must come to be chosen:
/// dots over a soft gradient read as a dotted texture, not as the gradient.
const BRAILLE_HANDICAP: f64 = 2.5;

/// A glyph in a foreground colour over a background colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Cell {
    pub glyph: char,
    pub fg: [u8; 3],
    pub bg: [u8; 3],
}

/// The quadrant glyph for each set of quarters in the foreground, bit 0 the
/// top right, bit 1 the bottom left, bit 2 the bottom right; the top left is
/// always background.
const QUADRANTS: [char; 8] = [' ', '▝', '▖', '▞', '▗', '▐', '▄', '▟'];

/// Lower blocks by the sample rows they cover.
const LOWER_BLOCKS: [(char, usize); 2] = [('▂', 3), ('▆', 1)];

/// The eight samples of a cell, left then right, top to bottom.
type Samples = [Shade; 8];

/// How much of each sample a glyph covers.
type Mask = [f64; 8];

/// A glyph with the colours that fit it, and how far it is from the samples.
struct Fit {
    glyph: char,
    fg: Shade,
    bg: Shade,
    error: f64,
}

/// The canvas as rows of cells.
#[must_use]
pub fn encode(canvas: &Canvas) -> Vec<Vec<Cell>> {
    let (cols, rows) = (canvas.width() / CELL_PIXELS.0, canvas.height() / CELL_PIXELS.1);
    (0..rows).map(|row| (0..cols).map(|col| cell(&samples(canvas, col, row))).collect()).collect()
}

fn samples(canvas: &Canvas, col: usize, row: usize) -> Samples {
    let (left, top) = (col * CELL_PIXELS.0, row * CELL_PIXELS.1);
    std::array::from_fn(|j| mean(canvas, left + j % 2 * 2, top + j / 2 * 2))
}

fn mean(canvas: &Canvas, left: usize, top: usize) -> Shade {
    let pixels = (0..4).map(|i| canvas.get(left + i % 2, top + i / 2));
    pixels.fold([0.0; 3], |sum, p| [sum[0] + p[0] / 4.0, sum[1] + p[1] / 4.0, sum[2] + p[2] / 4.0])
}

fn cell(samples: &Samples) -> Cell {
    let fits = candidates(samples).into_iter().map(|(glyph, mask)| fit(samples, glyph, &mask));
    let best = fits.min_by(|a, b| a.error.total_cmp(&b.error)).expect("a space is always a candidate");
    let fg = if best.glyph == ' ' { best.bg } else { best.fg };
    Cell { glyph: best.glyph, fg: fg.map(byte), bg: best.bg.map(byte) }
}

fn candidates(samples: &Samples) -> Vec<(char, Mask)> {
    let quadrants = (0..QUADRANTS.len()).map(|bits| (QUADRANTS[bits], quadrant_mask(bits)));
    let lower = LOWER_BLOCKS.iter().map(|(glyph, from)| (*glyph, std::array::from_fn(|j| if j / 2 >= *from { 1.0 } else { 0.0 })));
    quadrants.chain(lower).chain((1..=3).map(|dots| braille(samples, dots))).collect()
}

fn quadrant_mask(bits: usize) -> Mask {
    std::array::from_fn(|j| if in_fg(bits, j / 4 * 2 + j % 2) { 1.0 } else { 0.0 })
}

fn in_fg(bits: usize, quadrant: usize) -> bool {
    quadrant > 0 && bits & (1 << (quadrant - 1)) != 0
}

/// Dots on the `count` brightest samples.
fn braille(samples: &Samples, count: usize) -> (char, Mask) {
    let mut order: Vec<usize> = (0..8).collect();
    order.sort_by(|a, b| brightness(samples[*b]).total_cmp(&brightness(samples[*a])));
    let lit = &order[..count];
    let bits: u32 = lit.iter().map(|j| 1 << dot_bit(*j)).sum();
    (char::from_u32(0x2800 + bits).unwrap_or(' '), std::array::from_fn(|j| if lit.contains(&j) { DOT } else { 0.0 }))
}

/// Braille numbers the dots down the left column, down the right, then the bottom row.
fn dot_bit(sample: usize) -> usize {
    let (col, row) = (sample % 2, sample / 2);
    if row < 3 { col * 3 + row } else { 6 + col }
}

fn brightness(shade: Shade) -> f64 {
    shade[0] + shade[1] + shade[2]
}

/// The colours that make `mask` closest to the samples, by least squares on
/// each channel, kept in range.
fn fit(samples: &Samples, glyph: char, mask: &Mask) -> Fit {
    let channels: [(f64, f64); 3] = std::array::from_fn(|c| regress(mask, &samples.map(|s| s[c])));
    let (bg, fg) = (channels.map(|(bg, _)| bg), channels.map(|(_, fg)| fg));
    let error: f64 = (0..8).map(|j| distance(samples[j], blend(bg, fg, mask[j]))).sum();
    let handicap = if glyph >= '\u{2800}' { BRAILLE_HANDICAP } else { 1.0 };
    Fit { glyph, fg, bg, error: error * handicap }
}

/// (background, foreground) for one channel `values` under `mask`.
fn regress(mask: &Mask, values: &[f64; 8]) -> (f64, f64) {
    let (mean_mask, mean_value) = (mask.iter().sum::<f64>() / 8.0, values.iter().sum::<f64>() / 8.0);
    let spread: f64 = mask.iter().map(|m| (m - mean_mask) * (m - mean_mask)).sum();
    let together: f64 = mask.iter().zip(values).map(|(m, v)| (m - mean_mask) * (v - mean_value)).sum();
    let step = if spread > f64::EPSILON { together / spread } else { 0.0 };
    let bg = (mean_value - step * mean_mask).clamp(0.0, 1.0);
    (bg, (bg + step).clamp(0.0, 1.0))
}

fn blend(bg: Shade, fg: Shade, coverage: f64) -> Shade {
    std::array::from_fn(|c| bg[c] + (fg[c] - bg[c]) * coverage)
}

fn distance(a: Shade, b: Shade) -> f64 {
    (0..3).map(|i| (a[i] - b[i]) * (a[i] - b[i])).sum()
}

/// The byte nearest `channel` scaled to 0-255.
#[must_use]
pub fn byte(channel: f64) -> u8 {
    let scaled = (channel.clamp(0.0, 1.0) * 255.0).round();
    u8::try_from(LEVELS.partition_point(|level| *level < scaled)).unwrap_or(u8::MAX)
}

static LEVELS: std::sync::LazyLock<Vec<f64>> = std::sync::LazyLock::new(|| (0u8..=255).map(f64::from).collect());
