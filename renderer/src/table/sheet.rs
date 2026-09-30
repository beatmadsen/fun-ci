//! The page's lines drawn one under another, and the lead's block behind its
//! own (design.md, The console): ratatui's `Block` with the proportional wide
//! border set, its top and bottom edges only, lower half blocks above the
//! lead's row and upper ones below it in the paper's colour, and the paper
//! between them from the margin to two past the age.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Color, Style};
use ratatui::symbols::border::PROPORTIONAL_WIDE;
use ratatui::text::Line;
use ratatui::widgets::{Block, Borders, Widget};

use super::columns::Columns;
use super::stack::Piece;

/// The lead's block: where it lies in the table, which of its edges are on
/// the screen, and its colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Paper {
    pub area: Rect,
    pub borders: Borders,
    pub colour: [u8; 3],
}

impl Paper {
    /// The block behind `lead`'s row and conflict among `pieces`, and its
    /// edges, from the margin of `columns` to two past the age.
    #[must_use]
    pub fn over(pieces: &[Piece], lead: u64, columns: Columns, colour: [u8; 3]) -> Option<Self> {
        let first = pieces.iter().position(|piece| on_block(piece, lead))?;
        let last = pieces.iter().rposition(|piece| on_block(piece, lead))?;
        let (x, width) = (cell(columns.margin), cell(columns.age_end + 2 - columns.margin));
        let area = Rect::new(x, cell(first), width, cell(last + 1 - first));
        Some(Self { area, borders: edges(&pieces[first], &pieces[last]), colour })
    }

    fn block(self) -> Block<'static> {
        let edge = Style::new().fg(self.colour.into()).bg(Color::Reset);
        Block::new().borders(self.borders).border_set(PROPORTIONAL_WIDE).style(Style::new().bg(self.colour.into())).border_style(edge)
    }

    /// Where line `line` of the table is drawn from, `from`, cut where the
    /// paper ends if the line is on it. A `Line` draws only its area's first row.
    fn clip(self, line: u16, from: Rect) -> Rect {
        let on = (self.area.top()..self.area.bottom()).contains(&line);
        if on { Rect { width: from.width.min(self.area.right()), ..from } } else { from }
    }
}

/// The table's lines from the top of an area, the paper behind the lead's.
#[derive(Debug, Clone, Copy)]
pub struct Sheet<'a> {
    pub lines: &'a [Line<'static>],
    pub paper: Option<Paper>,
}

impl Widget for Sheet<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        if let Some(paper) = self.paper {
            let at = Rect { x: area.x.saturating_add(paper.area.x), y: area.y.saturating_add(paper.area.y), ..paper.area };
            paper.block().render(at.intersection(area), buf);
        }
        for ((line, text), y) in (0..).zip(self.lines).zip(area.top()..area.bottom()) {
            let from = Rect { y, ..area };
            text.render(self.paper.map_or(from, |paper| paper.clip(line, from)), buf);
        }
    }
}

/// Whether `piece` bounds `lead`'s block: an edge or its row. Its conflict
/// is always between its row and its bottom edge.
fn on_block(piece: &Piece, lead: u64) -> bool {
    match piece {
        Piece::Edge(_) => true,
        Piece::Row(run) => run.id == lead,
        _ => false,
    }
}

/// The edges the block shows: the top one if it starts on it, the bottom one if it ends on it.
fn edges(first: &Piece, last: &Piece) -> Borders {
    let mut borders = Borders::NONE;
    borders.set(Borders::TOP, *first == Piece::Edge(true));
    borders.set(Borders::BOTTOM, *last == Piece::Edge(false));
    borders
}

fn cell(at: usize) -> u16 {
    u16::try_from(at).unwrap_or(u16::MAX)
}
