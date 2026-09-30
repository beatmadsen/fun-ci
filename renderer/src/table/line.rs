//! One line of the table: parts of text, each at the column it starts at,
//! and the block's paper behind it when its row leads. It draws itself into
//! the screen's buffer cut where the screen or the paper ends, so a line can
//! never wrap: a line that wrapped would push the whole board up.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier};
use ratatui::widgets::Widget;
use unicode_width::UnicodeWidthStr;

/// How a part's text is drawn.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Style {
    pub fg: [u8; 3],
    pub bold: bool,
    pub italic: bool,
}

impl Style {
    #[must_use]
    pub fn plain(fg: [u8; 3]) -> Self {
        Self { fg, bold: false, italic: false }
    }

    #[must_use]
    pub fn bold(fg: [u8; 3]) -> Self {
        Self { fg, bold: true, italic: false }
    }

    #[must_use]
    pub fn italic(fg: [u8; 3]) -> Self {
        Self { fg, bold: false, italic: true }
    }
}

impl From<Style> for ratatui::style::Style {
    fn from(style: Style) -> Self {
        let [r, g, b] = style.fg;
        let modifier = [(style.bold, Modifier::BOLD), (style.italic, Modifier::ITALIC)].iter().filter(|(on, _)| *on).fold(Modifier::empty(), |all, (_, one)| all | *one);
        Self::default().fg(Color::Rgb(r, g, b)).add_modifier(modifier)
    }
}

/// The block's paper: its colour, from column `start` up to `end`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Paper {
    pub start: usize,
    pub end: usize,
    pub colour: [u8; 3],
}

/// A part of a line: where it starts, what it says and how.
pub type Part = (usize, String, Style);

/// The parts of one line, and the paper under them if it has one.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Line {
    parts: Vec<Part>,
    paper: Option<Paper>,
}

impl Line {
    /// A line on `paper`, cut where the paper ends.
    #[must_use]
    pub fn on(paper: Paper) -> Self {
        Self { parts: Vec::new(), paper: Some(paper) }
    }

    /// `text` from column `column`, or straight after the part before it if that runs past `column`.
    pub fn put(&mut self, column: usize, text: &str, style: Style) {
        self.parts.push((column, text.to_string(), style));
    }

    /// Whether the line draws nothing.
    #[must_use]
    pub fn is_blank(&self) -> bool {
        self.parts.is_empty() && self.paper.is_none()
    }

    /// What the line says, each part where it lands, trailing blanks left off.
    #[must_use]
    pub fn text(&self) -> String {
        let widest = self.parts.iter().map(|(at, _, _)| *at).max().unwrap_or(0) + self.parts.iter().map(|(_, text, _)| text.width()).sum::<usize>();
        let mut buf = Buffer::empty(Rect::new(0, 0, column(widest), 1));
        self.render(buf.area, &mut buf);
        buf.content().iter().map(ratatui::buffer::Cell::symbol).collect::<String>().trim_end().to_string()
    }

    /// The parts left to right.
    fn sorted(&self) -> Vec<&Part> {
        let mut sorted: Vec<&Part> = self.parts.iter().collect();
        sorted.sort_by_key(|part| part.0);
        sorted
    }
}

impl Widget for &Line {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let end = self.paper.map_or(usize::from(area.width), |paper| paper.end.min(usize::from(area.width)));
        if let Some(paper) = self.paper {
            paint_paper(paper, area, buf);
        }
        let mut next = 0;
        for (at, text, style) in self.sorted() {
            let x = (*at).max(next);
            if x < end {
                next = usize::from(buf.set_stringn(area.x + column(x), area.y, text, end - x, *style).0 - area.x);
            }
        }
    }
}

/// The paper's colour over its columns of `area`'s first row.
fn paint_paper(paper: Paper, area: Rect, buf: &mut Buffer) {
    let [r, g, b] = paper.colour;
    let span = Rect::new(area.x + column(paper.start), area.y, column(paper.end.saturating_sub(paper.start)), 1);
    buf.set_style(span.intersection(area), ratatui::style::Style::default().bg(Color::Rgb(r, g, b)));
}

fn column(at: usize) -> u16 {
    u16::try_from(at).unwrap_or(u16::MAX)
}
