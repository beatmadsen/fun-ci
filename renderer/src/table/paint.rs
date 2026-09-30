//! Each piece of the table drawn as a line (design.md, The console): a row as
//! one phrase, name, marks, what happened and when; a project's label; a
//! conflict; a line of passed branches. The block's edges and paper are the
//! `sheet`'s, so an edge's line is empty here.

use ratatui::text::Line;

use super::Frame;
use super::columns::Columns;
pub use super::line::Part;
use super::line::placed;
use super::night::{CONFLICT, LABEL, NOTE, QUIET, ink};
use super::rows::{folded, row};
use super::sections::{Section, spaced};
use super::stack::Piece;
use crate::format::{age, columns, project_name};
use crate::model::{Run, StaleTrunk};

/// What every line of one screen is drawn with.
#[derive(Debug, Clone, Copy)]
pub struct Paint<'a> {
    pub columns: Columns,
    pub frame: Frame,
    /// The row in the block.
    pub lead: Option<u64>,
    pub stale: &'a [StaleTrunk],
    /// In the flat layout, the widest project's name, which each row starts with.
    pub tags: Option<usize>,
}

/// `piece` as a line.
#[must_use]
pub fn paint(piece: &Piece, paint: &Paint) -> Line<'static> {
    placed(match piece {
        Piece::Row(run) => row(run, paint),
        Piece::Conflict(run) => vec![conflict(run, paint.columns)],
        Piece::Label(section) => label(section, paint),
        Piece::Folded(runs) => folded(runs, paint),
        Piece::More(count, below) => vec![more(*count, *below, paint.columns)],
        Piece::Edge(_) | Piece::Blank => Vec::new(),
    })
}

/// A project's name letter-spaced, and when its trunk was last fetched if that was long ago.
fn label(section: &Section, paint: &Paint) -> Vec<Part> {
    let name = spaced(&section.project);
    let note_at = paint.columns.label + columns(&name) + 6;
    let mut parts = vec![(paint.columns.label, name, ink(LABEL))];
    let stale = paint.stale.iter().find(|trunk| project_name(&trunk.project) == section.project);
    parts.extend(stale.map(|trunk| (note_at, fetched(trunk, paint.frame.now_ms), ink(NOTE).italic())));
    parts
}

/// `trunk last fetched 2h ago`, or `trunk could not be fetched`.
#[must_use]
pub fn fetched(trunk: &StaleTrunk, now_ms: i64) -> String {
    trunk.since.map_or_else(|| "trunk could not be fetched".to_string(), |since| format!("trunk last fetched {} ago", age(since, now_ms)))
}

fn conflict(run: &Run, columns: Columns) -> Part {
    let trunk = run.trunk.as_ref().map_or("the trunk", |trunk| trunk.trunk.as_str());
    (columns.branch + 2, format!("conflicts with {trunk}"), ink(CONFLICT).italic())
}

/// `… 4 more below`, quietly, where names start.
fn more(count: usize, below: bool, columns: Columns) -> Part {
    (columns.branch, format!("… {count} more {}", if below { "below" } else { "above" }), ink(QUIET))
}
