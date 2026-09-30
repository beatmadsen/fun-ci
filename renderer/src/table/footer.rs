//! The footer's words (design.md, The console): the keys that do something
//! now, or the prompt to confirm a cancel; what a short screen left out; and
//! in the flat layout, where no label can say it, which trunks are stale.

use ratatui::text::Line;

use super::line::placed;
use super::night::{NOTE, QUIET, ink};
use super::paint::fetched;
use super::{Drawn, Frame};
use crate::format::{columns, cut, project_name, short_sha};
use crate::model::{Board, Run};

/// The least space between the keys and what the footer says beside them.
const APART: usize = 5;

const KEYS: &str = "j/k move      c cancel      q quit";
const KEYS_WITHOUT_CANCEL: &str = "j/k move      q quit";

/// The keys, `c cancel` among them only while a run is running or waits to
/// start; or the prompt naming the run the cursor would cancel.
#[must_use]
pub fn keys(board: &Board) -> String {
    if let Some(run) = confirming(board) {
        return format!("Cancel {} ({})? y / n", run.commit.branch, short_sha(&run.commit.sha));
    }
    let cancellable = board.runs.iter().any(|run| matches!(run.status(), "running" | "pending"));
    (if cancellable { KEYS } else { KEYS_WITHOUT_CANCEL }).to_string()
}

/// `2 passed not shown`, or nothing when nothing was left out.
#[must_use]
pub fn aside(unshown: usize) -> String {
    if unshown == 0 { String::new() } else { format!("{unshown} passed not shown") }
}

/// Each stale trunk with its project: `agent-tome: trunk last fetched 2h ago`.
#[must_use]
pub fn stale(board: &Board, now_ms: i64) -> String {
    let named = board.stale_trunks.iter().map(|trunk| format!("{}: {}", project_name(&trunk.project), fetched(trunk, now_ms)));
    named.collect::<Vec<_>>().join(" · ")
}

fn confirming(board: &Board) -> Option<&Run> {
    board.view.cursor.filter(|_| board.view.confirming).and_then(|index| board.runs.get(index))
}

/// The footer: the keys where the labels start, and beside them, quieter,
/// how many passed rows the screen was too short for, cut if it must be.
#[must_use]
pub fn footer_line(board: &Board, drawn: &Drawn, frame: Frame) -> Line<'static> {
    let (width, keys) = (usize::from(frame.width), keys(board));
    let keys_end = drawn.columns.label + columns(&keys) + APART;
    let aside = cut(&aside(drawn.unshown), width.saturating_sub(keys_end + drawn.columns.margin));
    let aside_at = width.saturating_sub(drawn.columns.margin + columns(&aside)).max(keys_end);
    placed(vec![(drawn.columns.label, keys, ink(QUIET)), (aside_at, aside, ink(NOTE).italic())])
}
