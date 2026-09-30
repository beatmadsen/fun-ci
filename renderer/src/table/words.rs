//! What a row says happened, in fun-ci's own words (design.md, The console):
//! `failed in fast · 1.4s`, `timed out in fast · 10s`, `running fast and
//! slow · 7s`, `passed`, `scheduled`, `cancelled`, `3 runs cancelled`.

use super::STAGES;
use crate::format::{duration, seconds_since};
use crate::model::{Run, Stage};

/// What `run` says happened, at the clock `now_ms`.
#[must_use]
pub fn said(run: &Run, now_ms: i64) -> String {
    match run.status() {
        "failed" => ended("failed", run, "failed"),
        "timeout" => ended("timed out", run, "timeout"),
        "running" => running(run, now_ms),
        "passed" => "passed".to_string(),
        "pending" => "scheduled".to_string(),
        _ => cancelled(run),
    }
}

/// `word in stage · time`, of the first stage that ended `status`.
fn ended(word: &str, run: &Run, status: &str) -> String {
    let stage = STAGES.iter().find_map(|name| run.stage(name).filter(|stage| stage.status == status));
    match stage {
        Some(Stage { stage, duration_ms: Some(ms), .. }) => format!("{word} in {stage} · {}", duration(*ms)),
        Some(Stage { stage, .. }) => format!("{word} in {stage}"),
        None => word.to_string(),
    }
}

/// The stages running and for how long, together when they started together.
fn running(run: &Run, now_ms: i64) -> String {
    let going: Vec<(&str, String)> = STAGES.iter().filter_map(|name| Some((*name, since(run.stage(name)?, now_ms)?))).collect();
    match going.as_slice() {
        [] => "running".to_string(),
        [(stage, time)] => format!("running {stage} · {time}"),
        all if all.iter().all(|(_, time)| *time == all[0].1) => {
            format!("running {} · {}", all.iter().map(|(stage, _)| *stage).collect::<Vec<_>>().join(" and "), all[0].1)
        }
        all => format!("running {}", all.iter().map(|(stage, time)| format!("{stage} {time}")).collect::<Vec<_>>().join(", ")),
    }
}

/// How long a running stage has run, `7s`, or `--` before it says when it started.
fn since(stage: &Stage, now_ms: i64) -> Option<String> {
    (stage.status == "running").then(|| stage.started_at.map_or("--".to_string(), |at| format!("{}s", seconds_since(at, now_ms))))
}

fn cancelled(run: &Run) -> String {
    match run.folded {
        Some(n) if n > 1 => format!("{n} runs cancelled"),
        _ => "cancelled".to_string(),
    }
}
