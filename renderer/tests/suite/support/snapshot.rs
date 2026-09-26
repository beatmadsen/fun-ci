//! A scenario's frames as text a reviewer can read in a diff: each frame's
//! characters, then the same grid with a letter per cell for its style (`.`
//! for the terminal's default), and at the end a legend for the letters.
//! Trailing blanks in the default style are left off. The header's rows, a
//! picture in 24-bit colour, are one digest of their cells per frame instead:
//! the frames themselves are reviewed as headless PNGs.

use std::fmt::Write;

use fun_ci_renderer::animator::HEADER_HEIGHT;
use fun_ci_renderer::grid::{Cell, Colour, Grid};

const LETTERS: &str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

type Style = (Colour, Colour, Vec<&'static str>);

/// The styles met so far, lettered in the order they were met.
#[derive(Default)]
struct Styles(Vec<Style>);

impl Styles {
    fn letter(&mut self, cell: &Cell) -> char {
        let style = (cell.fg, cell.bg, cell.attrs.clone());
        if style == (Colour::Default, Colour::Default, Vec::new()) {
            return '.';
        }
        let index = self.0.iter().position(|seen| *seen == style).unwrap_or_else(|| {
            self.0.push(style);
            self.0.len() - 1
        });
        LETTERS.chars().nth(index).expect("more styles than a snapshot has letters for")
    }

    fn legend(&self) -> String {
        let line = |(letter, (fg, bg, attrs)): (char, &Style)| format!("{letter} = fg {fg:?}, bg {bg:?}, {attrs:?}\n");
        LETTERS.chars().zip(&self.0).map(line).collect()
    }
}

/// `frames` as snapshot text.
#[must_use]
pub fn render(frames: &[Grid]) -> String {
    let mut styles = Styles::default();
    let mut out = String::new();
    for (index, grid) in frames.iter().enumerate() {
        writeln!(out, "frame {:04} at {}x{}", index + 1, grid.cols, grid.rows).unwrap();
        let (header, body) = grid.cells.split_at(HEADER_HEIGHT.min(grid.cells.len()));
        writeln!(out, "  header {}", digest(header)).unwrap();
        out += &body_text(body, &mut styles);
    }
    out + "legend\n" + &styles.legend()
}

/// The rows below the header: their characters, then a letter per cell style.
fn body_text(body: &[Vec<Cell>], styles: &mut Styles) -> String {
    let characters = body.iter().map(|row| format!("  |{}\n", text(row).trim_end()));
    let letters = |row: &Vec<Cell>| format!("  :{}\n", row.iter().map(|cell| styles.letter(cell)).collect::<String>().trim_end_matches('.'));
    characters.collect::<String>() + &body.iter().map(letters).collect::<String>()
}

fn text(row: &[Cell]) -> String {
    row.iter().map(|cell| if cell.text.is_empty() { " " } else { &cell.text }).collect()
}

/// A CRC-32 of every cell of `rows`: text, colours and attributes.
#[must_use]
pub fn digest(rows: &[Vec<Cell>]) -> String {
    format!("{:08x}", crc32fast::hash(serde_json::to_string(rows).unwrap().as_bytes()))
}
