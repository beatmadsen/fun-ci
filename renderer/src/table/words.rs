//! What a row says happened, in words someone who has never seen fun-ci can
//! read (design.md, The console): `the fast suite failed after 1.4s`, `the
//! fast suite ran out of time after 10s`, `running the fast and slow suites ·
//! 7s`, `all four stages passed`, `waiting to start`, `cancelled`, `3 runs
//! cancelled`. On a narrow screen the same, briefly, each stage still named
//! in full: `fast suite failed · 1.4s`, `running both suites · 7s`.

use super::STAGES;
use crate::format::{duration, seconds_since};
use crate::model::{Run, Stage, stage_name, stage_noun};

/// What `run` says happened, at the clock `now_ms`.
#[must_use]
pub fn said(run: &Run, now_ms: i64) -> String {
    match run.status() {
        "failed" => ended("failed", run, "failed"),
        "timeout" => ended("ran out of time", run, "timeout"),
        "running" => running(run, now_ms),
        "passed" => "all four stages passed".to_string(),
        "pending" => "waiting to start".to_string(),
        _ => cancelled(run),
    }
}

/// What `run` says happened, briefly when `brief`.
#[must_use]
pub fn phrase(run: &Run, now_ms: i64, brief: bool) -> String {
    if brief { said_briefly(run, now_ms) } else { said(run, now_ms) }
}

/// What `run` says happened, briefly, for a narrow screen.
#[must_use]
pub fn said_briefly(run: &Run, now_ms: i64) -> String {
    match run.status() {
        "failed" => ended_briefly("failed", run, "failed"),
        "timeout" => ended_briefly("timed out", run, "timeout"),
        "running" => running_briefly(run, now_ms),
        "passed" => "all passed".to_string(),
        _ => said(run, now_ms),
    }
}

/// The first stage of `run` that ended `status`.
fn first_ended<'a>(run: &'a Run, status: &str) -> Option<&'a Stage> {
    STAGES.iter().find_map(|name| run.stage(name).filter(|stage| stage.status == status))
}

/// `the stage word after time`, of the first stage that ended `status`.
fn ended(word: &str, run: &Run, status: &str) -> String {
    match first_ended(run, status) {
        Some(Stage { stage, duration_ms: Some(ms), .. }) => format!("{} {word} after {}", stage_noun(stage), duration(*ms)),
        Some(Stage { stage, .. }) => format!("{} {word}", stage_noun(stage)),
        None => word.to_string(),
    }
}

/// `stage word · time`, of the first stage that ended `status`.
fn ended_briefly(word: &str, run: &Run, status: &str) -> String {
    match first_ended(run, status) {
        Some(Stage { stage, duration_ms: Some(ms), .. }) => format!("{} {word} · {}", stage_name(stage), duration(*ms)),
        Some(Stage { stage, .. }) => format!("{} {word}", stage_name(stage)),
        None => word.to_string(),
    }
}

/// The stages running, each with how many seconds it has run, if it says when it started.
fn going(run: &Run, now_ms: i64) -> Vec<(&str, Option<i64>)> {
    let running = |name: &&str| run.stage(name).filter(|stage| stage.status == "running");
    STAGES.iter().filter_map(|name| Some((*name, running(name)?.started_at.map(|at| seconds_since(at, now_ms))))).collect()
}

/// The stages running and for how long, together when they started together.
fn running(run: &Run, now_ms: i64) -> String {
    match going(run, now_ms).as_slice() {
        [] => "running".to_string(),
        [(stage, time)] => format!("running {} · {}", stage_noun(stage), seconds(*time)),
        [(first, time), (second, other)] if time == other => format!("running {} · {}", together(first, second), seconds(*time)),
        all => format!("running {}", all.iter().map(|(stage, time)| format!("{} {}", stage_noun(stage), seconds(*time))).collect::<Vec<_>>().join(", ")),
    }
}

/// The stages running, briefly: two together at the longer time.
fn running_briefly(run: &Run, now_ms: i64) -> String {
    match going(run, now_ms).as_slice() {
        [] => "running".to_string(),
        [(stage, time)] => format!("running {} · {}", stage_name(stage), seconds(*time)),
        [(first, time), (_, other)] => format!("running {} · {}", if *first == "fast" { "both suites" } else { "lint and build" }, seconds(*time.max(other))),
        all => format!("running {} stages", all.len()),
    }
}

/// Two stages named together: `the fast and slow suites`, `lint and the build`.
fn together(first: &str, second: &str) -> String {
    if (first, second) == ("fast", "slow") { "the fast and slow suites".to_string() } else { format!("{} and {}", stage_noun(first), stage_noun(second)) }
}

/// `7s`, or `--` when a stage has not said when it started.
fn seconds(time: Option<i64>) -> String {
    time.map_or("--".to_string(), |seconds| format!("{seconds}s"))
}

fn cancelled(run: &Run) -> String {
    match run.folded {
        Some(n) if n > 1 => format!("{n} runs cancelled"),
        _ => "cancelled".to_string(),
    }
}

