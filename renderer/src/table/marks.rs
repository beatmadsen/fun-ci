//! A row's four marks, lint, build, fast and slow (design.md, The console):
//! `✓` passed, `◆` failed, `◇` timed out, the spinner running, `·` not
//! reached (a stage a failure stopped too), `◌` waiting to run, `–`
//! cancelled with its run.

use super::STAGES;
use super::night::{FAILED, PASSED, QUIET, RUNNING, TIMED_OUT};
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
