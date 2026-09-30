//! A row's four marks, lint, build, fast and slow (design.md, The console):
//! `✓` passed, `◆` failed, `◇` timed out, the spinner running, `·` not
//! reached (a stage a failure stopped too), `◌` waiting to run, `–`
//! cancelled with its run. Between them a link leads into each stage: a
//! line once the stage was reached, so a run fills its track left to right,
//! and a faint dotted one before.

use super::STAGES;
use super::night::{FAILED, NIGHT, PASSED, QUIET, RUNNING, TIMED_OUT, blend};
use crate::model::Run;

/// Each stage's mark and colour, in lint, build, fast, slow order.
#[must_use]
pub fn marks(run: &Run, spinner: char) -> [(char, [u8; 3]); 4] {
    STAGES.map(|stage| match run.stage(stage).map(|found| found.status.as_str()) {
        Some("passed") => ('✓', PASSED),
        Some("failed") => ('◆', FAILED),
        Some("timeout") => ('◇', TIMED_OUT),
        Some("running") => (spinner, RUNNING),
        Some("cancelled") if run.status() == "cancelled" => ('–', QUIET),
        _ if run.status() == "pending" => ('◌', QUIET),
        _ => ('·', QUIET),
    })
}

/// How much of the mark it leads into a link shows.
const LINK: f64 = 0.5;

/// The links between `marks`, each in front of the mark after it: `─` in
/// that mark's colour, dimmed, once its stage was reached, else a faint `┄`.
#[must_use]
pub fn links(marks: &[(char, [u8; 3]); 4]) -> [(char, [u8; 3]); 3] {
    std::array::from_fn(|i| match marks[i + 1] {
        ('·' | '◌' | '–', colour) => ('┄', blend(NIGHT, colour, LINK)),
        (_, colour) => ('─', blend(NIGHT, colour, LINK)),
    })
}
