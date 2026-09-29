//! One line of the table built cell by cell, so it can never be wider than
//! the terminal: a line that wrapped would push the whole board up.

use crate::art::output::{Depth, escape};

/// How a cell's text is drawn.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Style {
    pub fg: [u8; 3],
    pub bold: bool,
}

impl Style {
    #[must_use]
    pub fn plain(fg: [u8; 3]) -> Self {
        Self { fg, bold: false }
    }

    #[must_use]
    pub fn bold(fg: [u8; 3]) -> Self {
        Self { fg, bold: true }
    }
}

/// A line `width` cells wide, on the background `paper` when it has one.
#[derive(Debug, Clone)]
pub struct Line {
    cells: Vec<(char, Style)>,
    width: usize,
    paper: Option<[u8; 3]>,
}

impl Line {
    #[must_use]
    pub fn new(width: usize, paper: Option<[u8; 3]>) -> Self {
        Self { cells: Vec::new(), width, paper }
    }

    /// `text` from 0-based column `column`, as much of it as fits.
    pub fn put(&mut self, column: usize, text: &str, style: Style) {
        self.fill_to(column);
        let room = self.width.saturating_sub(self.cells.len());
        self.cells.extend(text.chars().take(room).map(|c| (c, style)));
    }

    /// `text` ending at the 0-based column `end`, exclusive.
    pub fn put_right(&mut self, end: usize, text: &str, style: Style) {
        self.put(end.saturating_sub(text.chars().count()), text, style);
    }

    /// The line's escapes and text, in colours the terminal has.
    #[must_use]
    pub fn encode(&self, depth: Depth) -> String {
        let mut pen = Pen::new(depth, self.paper);
        self.cells.iter().for_each(|&(c, style)| pen.draw(c, style));
        if self.paper.is_some() {
            (self.cells.len()..self.width).for_each(|_| pen.draw(' ', Style::plain([0; 3])));
        }
        pen.finish()
    }

    fn fill_to(&mut self, column: usize) {
        let missing = column.min(self.width).saturating_sub(self.cells.len());
        self.cells.extend(std::iter::repeat_n((' ', Style::plain([0; 3])), missing));
    }
}

/// The escapes written so far on a line, so each changes only what differs.
struct Pen {
    depth: Depth,
    style: Option<Style>,
    out: String,
}

impl Pen {
    fn new(depth: Depth, paper: Option<[u8; 3]>) -> Self {
        let out = paper.map_or_else(String::new, |rgb| escape(48, rgb, depth));
        Self { depth, style: None, out }
    }

    fn draw(&mut self, c: char, style: Style) {
        if c != ' ' && self.style != Some(style) {
            self.out.push_str(if style.bold { "\u{1b}[1m" } else { "\u{1b}[22m" });
            self.out.push_str(&escape(38, style.fg, self.depth));
            self.style = Some(style);
        }
        self.out.push(c);
    }

    fn finish(self) -> String {
        self.out + "\u{1b}[0m"
    }
}
