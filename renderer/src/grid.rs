//! What a terminal shows after a stream of bytes, as a grid of cells, read
//! through the `vt100` emulator.

use serde::Serialize;

/// A cell colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Colour {
    Default,
    Idx(u8),
    Rgb(u8, u8, u8),
}

impl From<vt100::Color> for Colour {
    fn from(colour: vt100::Color) -> Self {
        match colour {
            vt100::Color::Default => Self::Default,
            vt100::Color::Idx(i) => Self::Idx(i),
            vt100::Color::Rgb(r, g, b) => Self::Rgb(r, g, b),
        }
    }
}

const ATTR_NAMES: [&str; 5] = ["bold", "dim", "italic", "underline", "inverse"];

/// One character cell: its text, colours and attributes.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Cell {
    pub text: String,
    pub fg: Colour,
    pub bg: Colour,
    pub attrs: Vec<&'static str>,
}

impl From<&vt100::Cell> for Cell {
    fn from(cell: &vt100::Cell) -> Self {
        let flags = [cell.bold(), cell.dim(), cell.italic(), cell.underline(), cell.inverse()];
        let attrs = ATTR_NAMES.iter().zip(flags).filter(|(_, on)| *on).map(|(name, _)| *name).collect();
        Self { text: cell.contents().to_string(), fg: cell.fgcolor().into(), bg: cell.bgcolor().into(), attrs }
    }
}

/// Every cell of a screen, row by row.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Grid {
    pub cols: u16,
    pub rows: u16,
    pub cells: Vec<Vec<Cell>>,
}

impl Grid {
    /// Where this grid first differs from `other`, described for a test failure.
    #[must_use]
    pub fn first_difference(&self, other: &Grid) -> Option<String> {
        if (self.cols, self.rows) != (other.cols, other.rows) {
            return Some(format!("size {}x{} vs {}x{}", self.cols, self.rows, other.cols, other.rows));
        }
        let cells = self.cells.iter().flatten().zip(other.cells.iter().flatten()).enumerate();
        let (index, (a, b)) = cells.into_iter().find(|(_, (a, b))| a != b)?;
        let (row, col) = (index / usize::from(self.cols) + 1, index % usize::from(self.cols) + 1);
        Some(format!("row {row} col {col}: {a:?} vs {b:?}\n{}\n---\n{}", self.text(), other.text()))
    }

    /// The characters on screen, one line per row.
    #[must_use]
    pub fn text(&self) -> String {
        let line = |row: &Vec<Cell>| row.iter().map(|c| if c.text.is_empty() { " " } else { &c.text }).collect();
        self.cells.iter().map(line).collect::<Vec<String>>().join("\n")
    }
}

/// A terminal emulator fed frame by frame.
pub struct Emulator {
    parser: vt100::Parser,
}

impl Emulator {
    /// An emulator of `size` (cols, rows).
    #[must_use]
    pub fn new((cols, rows): (u16, u16)) -> Self {
        Self { parser: vt100::Parser::new(rows, cols, 0) }
    }

    /// Resizes to `size` (cols, rows) when it changed, then processes one
    /// frame's bytes.
    pub fn feed(&mut self, (cols, rows): (u16, u16), bytes: &[u8]) {
        if self.parser.screen().size() != (rows, cols) {
            self.parser.screen_mut().set_size(rows, cols);
        }
        self.parser.process(bytes);
    }

    /// The screen as it stands.
    #[must_use]
    pub fn grid(&self) -> Grid {
        let screen = self.parser.screen();
        let (rows, cols) = screen.size();
        let row = |r| (0..cols).map(|c| screen.cell(r, c).map_or_else(blank, Cell::from)).collect();
        Grid { cols, rows, cells: (0..rows).map(row).collect() }
    }
}

fn blank() -> Cell {
    Cell { text: String::new(), fg: Colour::Default, bg: Colour::Default, attrs: Vec::new() }
}
