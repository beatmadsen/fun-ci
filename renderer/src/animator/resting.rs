//! What the header shows when nothing is queued or running: the latest
//! outcome for a while, then a quiet scene (acceptance-tests.md, AT-7.5, AT-7.7).

use crate::model::Run;

/// How long the header rests on the latest outcome before it goes quiet.
const QUIET_AFTER_MS: i64 = 5 * 60 * 1000;

/// How the latest run that passed or failed ended.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome {
    Passed,
    Failed,
}

/// Which kind of scene the header rests on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Resting {
    Calm,
    Warning,
    /// Nothing has happened for a while; the lamp shows the latest outcome, if any.
    Quiet(Option<Outcome>),
}

impl Resting {
    /// The lamp a quiet scene shows; none for any other resting scene.
    #[must_use]
    pub fn lamp(self) -> Option<Outcome> {
        if let Resting::Quiet(lamp) = self { lamp } else { None }
    }
}

/// What to rest on, given `runs` (newest first) as of `now_ms`.
#[must_use]
pub fn resting(runs: &[Run], now_ms: i64) -> Resting {
    let Some((outcome, ended_at)) = latest_outcome(runs) else { return Resting::Quiet(None) };
    if now_ms - ended_at * 1000 >= QUIET_AFTER_MS {
        return Resting::Quiet(Some(outcome));
    }
    match outcome {
        Outcome::Passed => Resting::Calm,
        Outcome::Failed => Resting::Warning,
    }
}

/// How the newest run that passed or failed ended, and when, in epoch seconds.
fn latest_outcome(runs: &[Run]) -> Option<(Outcome, i64)> {
    let run = runs.iter().find(|run| matches!(run.status(), "passed" | "failed" | "timeout"))?;
    let outcome = if run.status() == "passed" { Outcome::Passed } else { Outcome::Failed };
    Some((outcome, run.state.updated_at))
}
