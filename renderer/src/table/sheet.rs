//! The page's lines drawn one under another, and the lead's block behind its
//! own (design.md, The console): a card of ratatui's `Block`, lower half
//! blocks above the lead's row and upper ones below it in the paper's colour,
//! quadrants rounding its corners, and the paper between them from the margin
//! to two past the age. The sky shows past its edges.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::Style;
use ratatui::symbols::border;
use ratatui::text::Line;
use ratatui::widgets::{Block, Borders, Widget};

use super::columns::Columns;
use super::leaders::Leaders;
use super::night::ink;
use super::stack::Piece;

/// The card's edges: half blocks along the top and bottom, a quadrant at
/// each corner, and blank sides the paper shows through.
const CARD: border::Set = border::Set {
    top_left: "▗",
    top_right: "▖",
    bottom_left: "▝",
    bottom_right: "▘",
    vertical_left: " ",
    vertical_right: " ",
    horizontal_top: "▄",
    horizontal_bottom: "▀",
};

/// The lead's block: where it lies in the table, which of its edges are on
/// the screen, and its colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Paper {
    pub area: Rect,
    pub borders: Borders,
    pub colour: [u8; 3],
}

impl Paper {
    /// The block behind `lead`'s row and conflict among `pieces`, or behind
    /// the job between its edges when no run leads, and its edges, from the
    /// margin of `columns` to two past the age.
    #[must_use]
    pub fn over(pieces: &[Piece], lead: Option<u64>, columns: Columns, colour: [u8; 3]) -> Option<Self> {
        let first = pieces.iter().position(|piece| on_block(piece, lead))?;
        let last = pieces.iter().rposition(|piece| on_block(piece, lead))?;
        let (x, width) = (cell(columns.margin), cell(columns.age_end + 2 - columns.margin));
        let area = Rect::new(x, cell(first), width, cell(last + 1 - first));
        Some(Self { area, borders: edges(&pieces[first], &pieces[last]), colour })
    }

    /// The card on `at`: the paper between its edges, then the edges over what is behind them.
    fn render(self, at: Rect, buf: &mut Buffer) {
        buf.set_style(self.between_edges(at), Style::new().bg(self.colour.into()));
        Block::new().borders(self.borders | Borders::LEFT | Borders::RIGHT).border_set(CARD).border_style(ink(self.colour)).render(at, buf);
    }

    /// The rows of `at` between the edges the card shows.
    fn between_edges(self, at: Rect) -> Rect {
        let (top, bottom) = (u16::from(self.borders.contains(Borders::TOP)), u16::from(self.borders.contains(Borders::BOTTOM)));
        Rect { y: at.y + top, height: at.height.saturating_sub(top + bottom), ..at }
    }

    /// Where line `line` of the table is drawn from, `from`, cut where the
    /// paper ends if the line is on it. A `Line` draws only its area's first row.
    fn clip(self, line: u16, from: Rect) -> Rect {
        let on = (self.area.top()..self.area.bottom()).contains(&line);
        if on { Rect { width: from.width.min(self.area.right()), ..from } } else { from }
    }
}

/// The table's lines from the top of an area, the paper behind the lead's.
#[derive(Debug, Clone)]
pub struct Sheet<'a> {
    pub lines: &'a [Line<'static>],
    pub paper: Option<Paper>,
    pub leaders: Option<Leaders>,
}

impl Widget for Sheet<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        if let Some(paper) = self.paper {
            let at = Rect { x: area.x.saturating_add(paper.area.x), y: area.y.saturating_add(paper.area.y), ..paper.area };
            paper.render(at.intersection(area), buf);
        }
        for ((line, text), y) in (0..).zip(self.lines).zip(area.top()..area.bottom()) {
            let from = Rect { y, ..area };
            text.render(self.paper.map_or(from, |paper| paper.clip(line, from)), buf);
        }
        if let Some(leaders) = &self.leaders {
            leaders.render(area, buf);
        }
    }
}

/// Whether `piece` bounds the block: an edge, the lead's row, or the job
/// that leads. A conflict is always between its row and its bottom edge.
fn on_block(piece: &Piece, lead: Option<u64>) -> bool {
    match piece {
        Piece::Edge(_) | Piece::Job(_, _, true) => true,
        Piece::Row(run) => Some(run.id) == lead,
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
