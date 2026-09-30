//! The lines down from the legend through the whole table (design.md, The
//! console): the legend belongs to no project, so its leaders run down every
//! blank line and across every project's rule to the last project, and each
//! column of marks hangs from its stage's name. A project's name and note
//! stand in front of them, letter spacing and all, and they never cross a
//! row, a block's edge, a conflict, a line of folded branches or a count.

use ratatui::buffer::{Buffer, Cell};
use ratatui::layout::{Position, Rect};

use super::night::{LABEL, NIGHT, blend};
use super::stack::Piece;

/// The lines down from the legend: the blank lines of the table they run
/// down, the label lines whose rules they cross, the column of the first
/// mark, and their colour.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Leaders {
    pub lines: Vec<u16>,
    pub labels: Vec<u16>,
    pub column: u16,
    pub colour: [u8; 3],
}

/// How many leaders run down, one over each mark, two columns apart.
const MARKS: u16 = 4;

/// The leaders' colour, a label's, dimmed: the legend's own lines are drawn in it too.
#[must_use]
pub fn colour() -> [u8; 3] {
    blend(NIGHT, LABEL, 0.6)
}

fn line(at: usize) -> u16 {
    u16::try_from(at).unwrap_or(u16::MAX)
}

impl Leaders {
    /// The leaders for `pieces`, down each blank line and label from the
    /// legend to the last row or line of folded branches, so they reach the
    /// last project whatever it shows, from the column of the first mark;
    /// none without a legend.
    #[must_use]
    pub fn over(pieces: &[Piece], column: usize) -> Option<Self> {
        let first = pieces.iter().rposition(|piece| matches!(piece, Piece::Legend(_)))? + 1;
        let end = pieces.iter().rposition(|piece| matches!(piece, Piece::Row(_) | Piece::Folded(_)))?;
        let lines = |kind: fn(&Piece) -> bool| (first..end).filter(|at| kind(&pieces[*at])).map(line).collect();
        Some(Self { lines: lines(blank), labels: lines(label), column: line(column), colour: colour() })
    }

    /// Each leader down its lines of the table drawn on `area`: over a blank
    /// cell, crossing a rule, and behind anything else, text or the block's
    /// edge; on a label line, only across its rule.
    pub fn render(&self, area: Rect, buf: &mut Buffer) {
        for (at, blanks) in self.cells(&self.lines, (area, true)).chain(self.cells(&self.labels, (area, false))) {
            if area.contains(at) {
                cross(&mut buf[at], (blanks, self.colour));
            }
        }
    }

    /// The cells of `lines` of the table drawn on `area` a leader runs
    /// through, each with whether it may cover a blank.
    fn cells<'a>(&'a self, lines: &'a [u16], (area, blanks): (Rect, bool)) -> impl Iterator<Item = (Position, bool)> + 'a {
        let at = move |x: u16, y: u16| Position::new(area.x.saturating_add(self.column).saturating_add(x), area.y.saturating_add(y));
        lines.iter().flat_map(move |y| (0..MARKS).map(move |mark| (at(2 * mark, *y), blanks)))
    }
}

fn blank(piece: &Piece) -> bool {
    *piece == Piece::Blank
}

fn label(piece: &Piece) -> bool {
    matches!(piece, Piece::Label(_))
}

/// `cell` with a leader down it: `│` over a blank when `blanks` says it may, `┼` across a rule.
fn cross(cell: &mut Cell, (blanks, colour): (bool, [u8; 3])) {
    let leader = match cell.symbol() {
        " " if blanks => "│",
        "─" => "┼",
        _ => return,
    };
    cell.set_symbol(leader).set_fg(colour.into());
}
