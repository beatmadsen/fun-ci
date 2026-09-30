//! Each piece of the table drawn as a line (design.md, The console): a row as
//! one phrase, name, marks, what happened and when; the lead's row on the
//! block's paper; a project's label; a conflict; a line of passed branches.

use super::Frame;
use super::columns::Columns;
pub use super::line::Part;
use super::line::{Line, Paper, Style};
use super::night::{CONFLICT, LABEL, NOTE, QUIET};
use super::rows::{folded, row};
use super::sections::{Section, spaced};
use super::stack::Piece;
use crate::format::{age, project_name};
use crate::model::{Run, StaleTrunk};

/// What every line of one screen is drawn with.
#[derive(Debug, Clone, Copy)]
pub struct Paint<'a> {
    pub columns: Columns,
    pub frame: Frame,
    /// The row in the block.
    pub lead: Option<u64>,
    pub stale: &'a [StaleTrunk],
    /// The block's colour this frame.
    pub paper: [u8; 3],
    /// In the flat layout, the widest project's name, which each row starts with.
    pub tags: Option<usize>,
}

/// `piece` as a line.
#[must_use]
pub fn paint(piece: &Piece, paint: &Paint) -> Line {
    match piece {
        Piece::Row(run) => on_paper(paint, run, &row(run, paint)),
        Piece::Conflict(run) => on_paper(paint, run, &[conflict(run, paint.columns)]),
        Piece::Label(section) => plain(&label(section, paint)),
        Piece::Edge(top) => plain(&[edge(*top, paint)]),
        Piece::Folded(runs) => plain(&folded(runs, paint)),
        Piece::More(count, below) => plain(&[more(*count, *below, paint.columns)]),
        Piece::Blank => plain(&[]),
    }
}

/// The block's edge, half blocks in its colour across it.
fn edge(top: bool, paint: &Paint) -> Part {
    let (start, end) = block(paint.columns);
    (start, (if top { "▄" } else { "▀" }).repeat(end - start), Style::plain(paint.paper))
}

/// A project's name letter-spaced, and when its trunk was last fetched if that was long ago.
fn label(section: &Section, paint: &Paint) -> Vec<Part> {
    let name = spaced(&section.project);
    let note_at = paint.columns.label + name.chars().count() + 6;
    let mut parts = vec![(paint.columns.label, name, Style::plain(LABEL))];
    let stale = paint.stale.iter().find(|trunk| project_name(&trunk.project) == section.project);
    parts.extend(stale.map(|trunk| (note_at, fetched(trunk, paint.frame.now_ms), Style::italic(NOTE))));
    parts
}

/// `trunk last fetched 2h ago`, or `trunk could not be fetched`.
#[must_use]
pub fn fetched(trunk: &StaleTrunk, now_ms: i64) -> String {
    trunk.since.map_or_else(|| "trunk could not be fetched".to_string(), |since| format!("trunk last fetched {} ago", age(since, now_ms)))
}

fn conflict(run: &Run, columns: Columns) -> Part {
    let trunk = run.trunk.as_ref().map_or("the trunk", |trunk| trunk.trunk.as_str());
    (columns.branch + 2, format!("conflicts with {trunk}"), Style::italic(CONFLICT))
}

/// `… 4 more below`, quietly, where names start.
fn more(count: usize, below: bool, columns: Columns) -> Part {
    (columns.branch, format!("… {count} more {}", if below { "below" } else { "above" }), Style::plain(QUIET))
}

/// Where the block starts and ends: the margin, and two past the age.
fn block(columns: Columns) -> (usize, usize) {
    (columns.margin, columns.age_end + 2)
}

/// `parts` on the block's paper when `run` leads, else on a plain line.
fn on_paper(paint: &Paint, run: &Run, parts: &[Part]) -> Line {
    if paint.lead != Some(run.id) {
        return plain(parts);
    }
    let (start, end) = block(paint.columns);
    placed(Line::on(Paper { start, end, colour: paint.paper }), parts)
}

/// `parts` on a plain line.
fn plain(parts: &[Part]) -> Line {
    placed(Line::default(), parts)
}

fn placed(mut line: Line, parts: &[Part]) -> Line {
    for (at, text, style) in parts {
        line.put(*at, text, *style);
    }
    line
}
