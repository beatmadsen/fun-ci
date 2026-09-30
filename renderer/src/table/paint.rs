//! Each piece of the table drawn as a line (design.md, The console): a row as
//! one phrase, name, marks, what happened and when; a project's label; a
//! conflict; a line of passed branches. The block's edges and paper are the
//! `sheet`'s, so an edge's line is empty here.

use ratatui::text::Line;

use super::Frame;
use super::columns::Columns;
pub use super::line::Part;
use super::legend::legend;
use super::line::placed;
use super::night::{CONFLICT, LABEL, NIGHT, NOTE, QUIET, blend, ink};
use super::rows::{accent, folded, row};
use super::sections::{Section, spaced};
use super::stack::Piece;
use crate::format::{age, columns, project_name};
use crate::maths::float;
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
    /// Whether the rows say what happened briefly, to leave the names room on a narrow screen.
    pub brief: bool,
}

/// `piece` as a line.
#[must_use]
pub fn paint(piece: &Piece, paint: &Paint) -> Line<'static> {
    placed(match piece {
        Piece::Row(run) => row(run, paint),
        Piece::Conflict(run) => conflict(run, paint.columns),
        Piece::Label(section) => label(section, paint),
        Piece::Folded(runs) => folded(runs, paint),
        Piece::More(count, below) => vec![more(*count, *below, paint.columns)],
        Piece::Legend(n) => legend(*n, paint),
        Piece::Edge(_) | Piece::Blank => Vec::new(),
    })
}

/// A project's name letter-spaced, when its trunk was last fetched if that
/// was long ago, and a rule fading out to where the block would end.
fn label(section: &Section, paint: &Paint) -> Vec<Part> {
    let name = spaced(&section.project);
    let mut end = paint.columns.label + columns(&name);
    let stale = paint.stale.iter().find(|trunk| project_name(&trunk.project) == section.project);
    let note = stale.map(|trunk| (end + 6, fetched(trunk, paint.frame.now_ms), ink(NOTE).italic()));
    end = note.as_ref().map_or(end, |(at, text, _)| at + columns(text));
    let mut parts = vec![(paint.columns.label, name, ink(LABEL))];
    parts.extend(note);
    parts.extend(rule(end + RULE_GAP, paint.columns.age_end + 2));
    parts
}

/// The space between a label and its rule, how bright the rule starts, and
/// in how many steps it fades.
const RULE_GAP: usize = 3;
const RULE: f64 = 0.45;
const RULE_STEPS: usize = 6;

/// `─` from column `start` to `end`, fading in steps from a dim label's colour into the night.
fn rule(start: usize, end: usize) -> Vec<Part> {
    let length = end.saturating_sub(start).max(1);
    let fade = |at: usize| blend(NIGHT, LABEL, RULE * (1.0 - float((at - start) * RULE_STEPS / length) / float(RULE_STEPS)));
    (start..end).map(|at| (at, "─".to_string(), ink(fade(at)))).collect()
}

/// `trunk last fetched 2h ago`, or `trunk could not be fetched`.
#[must_use]
pub fn fetched(trunk: &StaleTrunk, now_ms: i64) -> String {
    trunk.since.map_or_else(|| "trunk could not be fetched".to_string(), |since| format!("trunk last fetched {} ago", age(since, now_ms)))
}

/// The line under a row saying which trunk it conflicts with, its row's stripe carried down.
fn conflict(run: &Run, columns: Columns) -> Vec<Part> {
    let trunk = run.trunk.as_ref().map_or("the trunk", |trunk| trunk.trunk.as_str());
    let stripe = accent(run).map(|colour| (columns.margin, "▌".to_string(), ink(colour)));
    stripe.into_iter().chain([(columns.branch + 2, format!("conflicts with {trunk}"), ink(CONFLICT).italic())]).collect()
}

/// `… 4 more below`, quietly, where names start.
fn more(count: usize, below: bool, columns: Columns) -> Part {
    (columns.branch, format!("… {count} more {}", if below { "below" } else { "above" }), ink(QUIET))
}
