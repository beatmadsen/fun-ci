//! The one firefly an all-green board gets (design.md, The console): only
//! when everything has passed and nothing runs; no brighter than the pale
//! names, in a dim teal from the header; wandering right of the middle
//! between two lines of the open space below the table, never jumping.

use super::jobs;
use super::needs_you;
use super::night::{FIREFLY, FIREFLY_LOW, blend};
use crate::maths::{Portable, float};
use crate::model::Board;

/// How many columns the firefly wanders either side of its place.
const WANDER: i32 = 12;

/// Where the firefly is on its line, and how brightly it glows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Mote {
    pub column: usize,
    pub colour: [u8; 3],
}

/// Whether the board is still: runs on it, each passed or cancelled, none
/// needing you, and every job quiet.
#[must_use]
pub fn still(board: &Board) -> bool {
    let settled = |status: &str| matches!(status, "passed" | "cancelled");
    let runs = !board.runs.is_empty() && board.runs.iter().all(|run| settled(run.status()) && !needs_you(run));
    runs && jobs::quiet(&board.jobs)
}

/// The firefly at `play_ms` on a screen `width` wide.
#[must_use]
pub fn mote(width: u16, play_ms: u64) -> Mote {
    let t = seconds(play_ms);
    let wander = 9.0 * (t * 0.13).sine() + 3.0 * (t * 0.41).sine();
    let offset = (-WANDER..=WANDER).min_by(|a, b| (f64::from(*a) - wander).abs().total_cmp(&(f64::from(*b) - wander).abs())).unwrap_or(0);
    let column = (usize::from(width) * 62 / 100).saturating_add_signed(isize::try_from(offset).unwrap_or(0));
    let level = 0.5 + 0.5 * (t * 0.9).sine();
    let colour = blend(FIREFLY_LOW, FIREFLY, level);
    Mote { column, colour }
}

/// Which of the open lines `open` the firefly is on: one of the two in their middle.
#[must_use]
pub fn line(open: &[usize], play_ms: u64) -> Option<usize> {
    let lower = (seconds(play_ms) * 0.05).sine() > 0.0;
    open.get(open.len() / 2 - usize::from(open.len() > 1 && !lower)).copied()
}

fn seconds(play_ms: u64) -> f64 {
    float(usize::try_from(play_ms).unwrap_or(usize::MAX)) / 1000.0
}
