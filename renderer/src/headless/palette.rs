//! Terminal colours as RGB: the xterm 256-colour palette, bold brightening,
//! dim, and the measures stats.json reports.

use crate::grid::{Cell, Colour};

/// RGB.
pub type Rgb = [u8; 3];

const DEFAULT_FG: Rgb = [229, 229, 229];
const DEFAULT_BG: Rgb = [0, 0, 0];
const SYSTEM: [Rgb; 16] = [
    [0, 0, 0],
    [205, 0, 0],
    [0, 205, 0],
    [205, 205, 0],
    [0, 0, 238],
    [205, 0, 205],
    [0, 205, 205],
    [229, 229, 229],
    [127, 127, 127],
    [255, 0, 0],
    [0, 255, 0],
    [255, 255, 0],
    [92, 92, 255],
    [255, 0, 255],
    [0, 255, 255],
    [255, 255, 255],
];
const CUBE: [u8; 6] = [0, 95, 135, 175, 215, 255];

/// The (foreground, background) a cell is painted in.
#[must_use]
pub fn cell_colours(cell: &Cell) -> (Rgb, Rgb) {
    let bold = cell.attrs.contains(&"bold");
    let fg = resolve(brighten(cell.fg, bold), DEFAULT_FG);
    let fg = if cell.attrs.contains(&"dim") { fg.map(|c| c / 2 + c / 8) } else { fg };
    let bg = resolve(cell.bg, DEFAULT_BG);
    if cell.attrs.contains(&"inverse") { (bg, fg) } else { (fg, bg) }
}

/// The colour a cell shows most of: its foreground if it holds a glyph,
/// otherwise its background.
#[must_use]
pub fn visible_colour(cell: &Cell) -> Rgb {
    let (fg, bg) = cell_colours(cell);
    if cell.text.trim().is_empty() { bg } else { fg }
}

/// Relative luminance, 0-255 (Rec. 709 weights).
#[must_use]
pub fn luminance([r, g, b]: Rgb) -> u8 {
    let weighted = 2126 * u32::from(r) + 7152 * u32::from(g) + 722 * u32::from(b);
    u8::try_from(weighted / 10_000).unwrap_or(u8::MAX)
}

/// The 30-degree hue sector (0-11) of a colour; none for greys and near-black.
#[must_use]
pub fn hue_sector(rgb: Rgb) -> Option<u8> {
    let (max, min) = (rgb.iter().max().copied()?, rgb.iter().min().copied()?);
    let chroma = i32::from(max - min);
    if max < 51 || chroma * 4 < i32::from(max) {
        return None;
    }
    u8::try_from(hue_degrees(rgb, max, chroma).rem_euclid(360) / 30).ok()
}

fn hue_degrees([r, g, b]: Rgb, max: u8, chroma: i32) -> i32 {
    let (red, green, blue) = (i32::from(r), i32::from(g), i32::from(b));
    match max {
        m if m == r => 60 * (green - blue) / chroma,
        m if m == g => 60 * (blue - red) / chroma + 120,
        _ => 60 * (red - green) / chroma + 240,
    }
}

fn brighten(colour: Colour, bold: bool) -> Colour {
    match colour {
        Colour::Idx(i) if bold && i < 8 => Colour::Idx(i + 8),
        other => other,
    }
}

fn resolve(colour: Colour, default: Rgb) -> Rgb {
    match colour {
        Colour::Default => default,
        Colour::Idx(i) => xterm(i),
        Colour::Rgb(r, g, b) => [r, g, b],
    }
}

fn xterm(index: u8) -> Rgb {
    match index {
        0..=15 => SYSTEM[usize::from(index)],
        16..=231 => cube(usize::from(index - 16)),
        _ => [8 + 10 * (index - 232); 3],
    }
}

fn cube(i: usize) -> Rgb {
    [CUBE[i / 36], CUBE[i / 6 % 6], CUBE[i % 6]]
}
