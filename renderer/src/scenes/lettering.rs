//! Big lettering for scene titles, in a chunky 5x7 display face with open
//! counters, so it reads at a glance at any size.

use crate::art::canvas::Canvas;
use crate::art::light::square;
use crate::art::{Shade, float};

/// Font pixels across a letter and down it.
const GLYPH: (usize, usize) = (5, 7);

const FACE: [(char, [&str; 7]); 10] = [
    ('A', [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"]),
    ('B', ["XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX."]),
    ('D', ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."]),
    ('E', ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"]),
    ('M', ["X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"]),
    ('O', [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."]),
    ('P', ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."]),
    ('S', [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."]),
    ('Y', ["X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."]),
    ('!', ["..X..", "..X..", "..X..", "..X..", "..X..", ".....", "..X.."]),
];

/// How `title` draws its letters.
pub struct Style<'f> {
    pub pixel: f64,
    pub opacity: f64,
    pub shadow: Shade,
    pub fill: &'f dyn Fn(usize, f64, f64) -> Shade,
    pub lift: &'f dyn Fn(usize) -> f64,
}

/// Letters `text` centred on `centre`, each font pixel `style.pixel` canvas
/// pixels, filled by `style.fill(letter, x, y)`, raised `style.lift(letter)`
/// pixels, over a shadow to their lower right, all `style.opacity` opaque.
pub fn title(canvas: &mut Canvas, text: &str, centre: (f64, f64), style: &Style) {
    let advance = float(GLYPH.0 + 1) * style.pixel;
    let left = centre.0 - title_width(text, style.pixel) / 2.0;
    for (i, ch) in text.chars().enumerate() {
        let corner = (left + float(i) * advance, centre.1 - float(GLYPH.1) * style.pixel / 2.0 - (style.lift)(i));
        letter(canvas, (i, ch), corner, style);
    }
}

/// Letter `i` of a title, `ch`, with its top left at `corner`, over its shadow.
fn letter(canvas: &mut Canvas, (i, ch): (usize, char), corner: (f64, f64), style: &Style) {
    let shadow = (corner.0 + style.pixel * 0.5, corner.1 + style.pixel * 0.5);
    glyph(canvas, (ch, shadow), style, &|_, _| style.shadow);
    glyph(canvas, (ch, corner), style, &|x, y| (style.fill)(i, x, y));
}

/// The width `text` takes at `pixel` canvas pixels a font pixel.
fn title_width(text: &str, pixel: f64) -> f64 {
    (float(GLYPH.0 + 1) * float(text.chars().count()) - 1.0) * pixel
}

fn glyph(canvas: &mut Canvas, (ch, corner): (char, (f64, f64)), style: &Style, shade: &dyn Fn(f64, f64) -> Shade) {
    let rows = FACE.iter().find(|(c, _)| *c == ch).map_or([""; 7], |(_, rows)| *rows);
    for (y, row) in rows.iter().enumerate() {
        for x in row.char_indices().filter(|(_, c)| *c == 'X').map(|(x, _)| x) {
            let at = (corner.0 + float(x) * style.pixel, corner.1 + float(y) * style.pixel);
            square(canvas, at, (style.pixel, style.opacity), shade(at.0, at.1));
        }
    }
}
