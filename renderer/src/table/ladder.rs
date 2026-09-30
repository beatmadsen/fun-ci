//! How the table fits a short screen (design.md, The console): it climbs down
//! a ladder of rungs, folding its passed rows, then leaving the folded lines
//! out, then closing up the rows, then dropping the labels, until it fits.
//! The legend at the top of the table stays while folding the passed rows makes
//! room for it, but never at the cost of a row. When even the last rung is too
//! long it keeps the lead's row on screen and says how many rows it can't show.

use super::sections::Section;
use super::stack::{Fold, Piece, Rung, stack, with_legend};

/// How many of the first rungs are tried with the legend before any without it.
const LEGEND_RUNGS: usize = 2;

const RUNGS: [Rung; 6] = [
    Rung { gap: true, labels: true, fold: Fold::Never, passed: true },
    Rung { gap: true, labels: true, fold: Fold::All, passed: true },
    Rung { gap: true, labels: true, fold: Fold::All, passed: false },
    Rung { gap: false, labels: true, fold: Fold::All, passed: false },
    Rung { gap: true, labels: false, fold: Fold::All, passed: false },
    Rung { gap: false, labels: false, fold: Fold::All, passed: false },
];

/// The table as it fits: its pieces, how many passed rows it left out,
/// whether it had to drop the labels, and whether it kept the legend.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Fitted<'a> {
    pub pieces: Vec<Piece<'a>>,
    pub unshown: usize,
    pub flat: bool,
    pub legend: bool,
}

/// `sections` in at most `room` lines; on a `calm` board, where nothing needs
/// you, a project's passed rows fold even when there is room.
#[must_use]
pub fn fit<'a>(sections: &'a [Section<'a>], lead: Option<u64>, room: usize, calm: bool) -> Fitted<'a> {
    let first = Rung { fold: if calm { Fold::Many } else { Fold::Never }, ..RUNGS[0] };
    let rungs = std::iter::once(first).chain(RUNGS.into_iter().skip(1));
    let rungs = rungs.clone().take(LEGEND_RUNGS).map(|rung| (rung, true)).chain(rungs.map(|rung| (rung, false)));
    let stacked = |(rung, legend): (Rung, bool)| if legend { with_legend(stack(sections, lead, rung)) } else { stack(sections, lead, rung) };
    let chosen = rungs.clone().find(|step| stacked(*step).len() <= room).unwrap_or((RUNGS[5], false));
    let pieces = window(stacked(chosen), room);
    Fitted { pieces, unshown: unshown(sections, lead, chosen.0), flat: !chosen.0.labels, legend: chosen.1 }
}

/// How many passed rows `rung` leaves out: those it would have folded.
fn unshown(sections: &[Section], lead: Option<u64>, rung: Rung) -> usize {
    if rung.passed {
        return 0;
    }
    let folded = stack(sections, lead, Rung { passed: true, ..rung });
    folded.iter().map(|piece| if let Piece::Folded(runs) = piece { runs.len() } else { 0 }).sum()
}

/// `pieces` cut to `room` lines around the lead's row, the first or last
/// line saying how many rows are off the screen that way.
fn window(mut pieces: Vec<Piece<'_>>, room: usize) -> Vec<Piece<'_>> {
    let total = pieces.len();
    if total <= room || room == 0 {
        return pieces;
    }
    let end = block_end(&pieces).map_or(0, |at| at + 1 + usize::from(at + 1 < total));
    let start = end.saturating_sub(room);
    let shown: Vec<Piece> = pieces.drain(start..start + room).collect();
    marked(shown, rows(&pieces[..start]), rows(&pieces[start..]))
}

/// `shown` with its first line saying how many rows are above it, and its
/// last how many are below, where there are any.
fn marked(mut shown: Vec<Piece<'_>>, above: usize, below: usize) -> Vec<Piece<'_>> {
    let last = shown.len() - 1;
    if below > 0 {
        let replaced = rows(&shown[last..]);
        shown[last] = Piece::More(below + replaced, true);
    }
    if above > 0 {
        let replaced = rows(&shown[..1]);
        shown[0] = Piece::More(above + replaced, false);
    }
    shown
}

/// The last line of the lead's row: the block's bottom edge, the only one.
fn block_end(pieces: &[Piece]) -> Option<usize> {
    pieces.iter().position(|piece| *piece == Piece::Edge(false))
}

fn rows(pieces: &[Piece]) -> usize {
    pieces.iter().filter(|piece| matches!(piece, Piece::Row(_))).count()
}
