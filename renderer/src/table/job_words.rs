//! What a daily or weekly job's row says (design.md, Daily and weekly jobs):
//! `failed after 3h12m on wip/foo 9e0b1d4 · due in 3d`, `running on main
//! 3a1f9c2 · 1h12m`, `stopped without a result on main 3a1f9c2 · due in 3d`
//! (its process died before it said how the run ended), `passed on main 3a1f9c2 · due in 14h`, `due · runs on
//! your next commit`. On a narrow screen the same, briefly: `failed · 3h12m`,
//! `passed · due in 14h`, `due · next commit`.

use crate::format::{seconds_since, short_sha};
use crate::model::{Job, JobStatus};

/// What a job says whose state this fun-ci doesn't know.
const UNKNOWN: &str = "in a state this fun-ci doesn't know";

/// What `job` says, at the clock `now_ms`.
#[must_use]
pub fn said(job: &Job, now_ms: i64) -> String {
    match job.status {
        JobStatus::Due => "due · runs on your next commit".to_string(),
        JobStatus::Lost => format!("stopped without a result on {} · {}", commit(job), due(job, now_ms)),
        JobStatus::Running => format!("running on {} · {}", commit(job), span(seconds_since(job.started_at.unwrap_or(0), now_ms))),
        JobStatus::Passed => format!("passed on {} · {}", commit(job), due(job, now_ms)),
        JobStatus::Failed => format!("failed after {} on {} · {}", span(ran_for(job)), commit(job), due(job, now_ms)),
        JobStatus::Timeout => format!("ran out of time after {} on {} · {}", span(ran_for(job)), commit(job), due(job, now_ms)),
        JobStatus::Unknown => UNKNOWN.to_string(),
    }
}

/// What `job` says, briefly, for a narrow screen.
#[must_use]
pub fn said_briefly(job: &Job, now_ms: i64) -> String {
    match job.status {
        JobStatus::Due => "due · next commit".to_string(),
        JobStatus::Lost => "stopped · no result".to_string(),
        JobStatus::Running => format!("running · {}", span(seconds_since(job.started_at.unwrap_or(0), now_ms))),
        JobStatus::Passed => format!("passed · {}", due(job, now_ms)),
        JobStatus::Failed => format!("failed · {}", span(ran_for(job))),
        JobStatus::Timeout => format!("timed out · {}", span(ran_for(job))),
        JobStatus::Unknown => "state unknown".to_string(),
    }
}

/// `wip/foo 9e0b1d4`: the branch and commit the run tested.
fn commit(job: &Job) -> String {
    format!("{} {}", job.branch.as_deref().unwrap_or_default(), short_sha(job.sha.as_deref().unwrap_or_default()))
}

/// How long the latest run ran, in seconds.
fn ran_for(job: &Job) -> i64 {
    job.updated_at.unwrap_or(0) - job.started_at.unwrap_or(0)
}

/// `due in 14h`, or `due` when it is due now.
fn due(job: &Job, now_ms: i64) -> String {
    due_in(job, now_ms).map_or_else(|| "due".to_string(), |when| format!("due in {when}"))
}

/// How long until `job` is due again, `14h`, or none while it is due now or runs.
#[must_use]
pub fn due_in(job: &Job, now_ms: i64) -> Option<String> {
    job.due_at.map(|at| roughly(-seconds_since(at, now_ms)))
}

/// A run's length: `42s`, `50m`, `3h12m`, `1d`, `1d2h`.
#[must_use]
pub fn span(seconds: i64) -> String {
    let (days, hours, minutes) = (seconds / 86_400, seconds % 86_400 / 3600, seconds % 3600 / 60);
    match seconds {
        ..60 => format!("{}s", seconds.max(0)),
        60..3600 => format!("{minutes}m"),
        3600..86_400 if minutes == 0 => format!("{hours}h"),
        3600..86_400 => format!("{hours}h{minutes:02}m"),
        _ if hours == 0 => format!("{days}d"),
        _ => format!("{days}d{hours}h"),
    }
}

/// How long until something, rounded up, since it is still to come, in the
/// largest unit it reaches once rounded: `45m`, `14h`, `3d`.
fn roughly(seconds: i64) -> String {
    let up = |unit: i64| (seconds + unit - 1) / unit;
    let (minutes, hours) = (up(60).max(1), up(3600));
    if minutes < 60 {
        format!("{minutes}m")
    } else if hours < 24 {
        format!("{hours}h")
    } else {
        format!("{}d", up(86_400))
    }
}
