//! A stage's cell: a mark that says its state by shape as well as colour,
//! and its time: `✓ 1.2s`, `✗ 1.4s`, `▲ 10s`, a spinner and the seconds
//! it has run, `·` not reached, `–` cancelled, `◌` waiting to run.

use super::palette::{FAILED, FAINT, PASSED, RUNNING, SECONDARY, TIMED_OUT};
use crate::format::{duration, seconds_since};
use crate::model::{Run, Stage};

/// What a cell shows, and in which colour at full tone.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CellText {
    pub text: String,
    pub colour: [u8; 3],
    pub bold: bool,
}

/// The cell of `stage` in `run`, with the `spinner`'s frame and the clock `now_ms`.
#[must_use]
pub fn stage_cell(run: &Run, stage: &str, spinner: char, now_ms: i64) -> CellText {
    let (not_reached, waiting) = match run.status() {
        "cancelled" => ("–", FAINT),
        "pending" => ("◌", SECONDARY),
        _ => ("·", FAINT),
    };
    match run.stage(stage) {
        Some(found) if found.status == "running" => running(found, spinner, now_ms),
        Some(found) => finished(found).unwrap_or_else(|| mark(not_reached, found, waiting)),
        None => CellText { text: not_reached.to_string(), colour: waiting, bold: false },
    }
}

fn running(stage: &Stage, spinner: char, now_ms: i64) -> CellText {
    let seconds = stage.started_at.map_or("--".to_string(), |at| format!("{}s", seconds_since(at, now_ms)));
    CellText { text: format!("{spinner} {seconds}"), colour: RUNNING, bold: true }
}

fn finished(stage: &Stage) -> Option<CellText> {
    let (symbol, colour, bold) = match stage.status.as_str() {
        "passed" => ("✓", PASSED, false),
        "failed" => ("✗", FAILED, true),
        "timeout" => ("▲", TIMED_OUT, true),
        _ => return None,
    };
    Some(CellText { bold, ..mark(symbol, stage, colour) })
}

/// `symbol` and the stage's time, if it has one.
fn mark(symbol: &str, stage: &Stage, colour: [u8; 3]) -> CellText {
    let text = stage.duration_ms.map_or(symbol.to_string(), |ms| format!("{symbol} {}", duration(ms)));
    CellText { text, colour, bold: false }
}
