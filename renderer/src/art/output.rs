//! Cells as terminal output: escape sequences in the colour depth the
//! terminal has, and which cells need drawing again.

use super::cells::Cell;

/// How many colours the terminal shows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Depth {
    TrueColour,
    Xterm256,
}

/// A run of `len` cells from (`row`, `col`), counted from 0.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Span {
    pub row: usize,
    pub col: usize,
    pub len: usize,
}

const CUBE: [u8; 6] = [0, 95, 135, 175, 215, 255];

/// `cells` with the escapes that colour them, ending in the default style.
#[must_use]
pub fn sgr_line(cells: &[Cell], depth: Depth) -> String {
    let mut pen = Pen { depth, fg: None, bg: None, line: String::new() };
    for cell in cells {
        pen.draw(cell);
    }
    pen.line + "\u{1b}[0m"
}

/// The colours set so far on a line being written.
struct Pen {
    depth: Depth,
    fg: Option<[u8; 3]>,
    bg: Option<[u8; 3]>,
    line: String,
}

impl Pen {
    fn draw(&mut self, cell: &Cell) {
        if cell.glyph != ' ' && self.fg != Some(cell.fg) {
            self.line.push_str(&escape(38, cell.fg, self.depth));
            self.fg = Some(cell.fg);
        }
        self.paper(cell.bg);
        self.line.push(cell.glyph);
    }

    fn paper(&mut self, bg: [u8; 3]) {
        if self.bg != Some(bg) {
            self.line.push_str(&escape(48, bg, self.depth));
            self.bg = Some(bg);
        }
    }
}

/// Unchanged cells a run of changed cells may bridge: moving the cursor past
/// two costs less than drawing them again.
const BRIDGE: usize = 1;

/// Where `now` differs from `before`: per row, the runs of changed cells,
/// joined across single unchanged cells; every cell when there is no
/// `before` of the same size.
#[must_use]
pub fn changed_spans(before: Option<&Vec<Vec<Cell>>>, now: &[Vec<Cell>]) -> Vec<Span> {
    let same_size = before.filter(|b| b.len() == now.len() && b.iter().zip(now).all(|(x, y)| x.len() == y.len()));
    let whole = |(row, cells): (usize, &Vec<Cell>)| Some(Span { row, col: 0, len: cells.len() });
    match same_size {
        Some(before) => now.iter().zip(before).enumerate().flat_map(|(row, (a, b))| spans(row, a, b)).collect(),
        None => now.iter().enumerate().filter_map(whole).collect(),
    }
}

fn spans(row: usize, now: &[Cell], before: &[Cell]) -> Vec<Span> {
    let changed = now.iter().zip(before).enumerate().filter(|(_, (a, b))| a != b).map(|(col, _)| col);
    changed.fold(Vec::new(), |spans, col| extended(spans, row, col))
}

/// `spans` with changed cell (`row`, `col`) added to the last span, or starting a new one.
fn extended(mut spans: Vec<Span>, row: usize, col: usize) -> Vec<Span> {
    match spans.last_mut() {
        Some(last) if col - (last.col + last.len) <= BRIDGE => last.len = col - last.col + 1,
        _ => spans.push(Span { row, col, len: 1 }),
    }
    spans
}

fn escape(layer: u8, rgb: [u8; 3], depth: Depth) -> String {
    match depth {
        Depth::TrueColour => format!("\u{1b}[{layer};2;{};{};{}m", rgb[0], rgb[1], rgb[2]),
        Depth::Xterm256 => format!("\u{1b}[{layer};5;{}m", xterm(rgb)),
    }
}

/// The xterm colour (16-255) nearest `rgb`.
#[must_use]
pub fn xterm(rgb: [u8; 3]) -> u8 {
    let levels = rgb.map(nearest_level);
    let cube = levels.map(|level| CUBE[usize::from(level)]);
    let grey_step = ((u16::from(rgb[0]) + u16::from(rgb[1]) + u16::from(rgb[2])) / 3).saturating_sub(3) / 10;
    let grey_step = u8::try_from(grey_step.min(23)).unwrap_or(23);
    let grey = [8 + 10 * grey_step; 3];
    if distance(rgb, grey) < distance(rgb, cube) { 232 + grey_step } else { 16 + 36 * levels[0] + 6 * levels[1] + levels[2] }
}

fn nearest_level(channel: u8) -> u8 {
    let gap = |level: &u8| channel.abs_diff(*level);
    let index = CUBE.iter().enumerate().min_by_key(|(_, level)| gap(level)).map_or(0, |(i, _)| i);
    u8::try_from(index).unwrap_or(0)
}

fn distance(a: [u8; 3], b: [u8; 3]) -> u32 {
    (0..3).map(|i| u32::from(a[i].abs_diff(b[i])).pow(2)).sum()
}
