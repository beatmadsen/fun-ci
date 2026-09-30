//! What a row says happened, in fun-ci's own words (design.md, The console):
//! the outcome, the stage it happened in and how long it took.

use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::words::said;
use serde_json::{Value, json};

const NOW: i64 = 1_790_000_000;

fn run(status: &str, stages: &[Value]) -> Run {
    serde_json::from_value(json!({"id": 1, "sha": "0", "branch": "main", "status": status, "updated_at": NOW, "stages": stages}))
        .unwrap()
}

fn done(stage: &str, status: &str, ms: u64) -> Value {
    json!({"stage": stage, "status": status, "duration_ms": ms})
}

fn going(stage: &str, since: i64) -> Value {
    json!({"stage": stage, "status": "running", "started_at": NOW - since})
}

fn words(run: &Run) -> String {
    said(run, NOW * 1000)
}

#[test]
fn a_failure_names_its_stage_and_how_long_it_ran() {
    let run = run("failed", &[done("lint", "passed", 300), done("fast", "failed", 1_400)]);

    assert_eq!(words(&run), "failed in fast · 1.4s");
}

#[test]
fn a_timeout_names_its_stage_and_how_long_it_ran() {
    assert_eq!(words(&run("timeout", &[done("fast", "timeout", 10_000)])), "timed out in fast · 10s");
}

#[test]
fn a_running_run_names_its_stage_and_how_long_it_has_run() {
    assert_eq!(words(&run("running", &[done("lint", "passed", 300), going("build", 4)])), "running build · 4s");
}

#[test]
fn two_stages_running_as_long_are_named_together() {
    assert_eq!(words(&run("running", &[going("fast", 7), going("slow", 7)])), "running fast and slow · 7s");
}

#[test]
fn two_stages_running_for_different_times_each_have_their_own() {
    assert_eq!(words(&run("running", &[going("fast", 7), going("slow", 3)])), "running fast 7s, slow 3s");
}

#[test]
fn a_passed_run_says_passed() {
    assert_eq!(words(&run("passed", &[done("slow", "passed", 90_000)])), "passed");
}

#[test]
fn a_run_waiting_to_start_says_scheduled() {
    assert_eq!(words(&run("pending", &[])), "scheduled");
}

#[test]
fn a_cancelled_run_says_cancelled() {
    assert_eq!(words(&run("cancelled", &[])), "cancelled");
}

#[test]
fn a_row_standing_for_several_cancelled_runs_says_how_many() {
    let mut run = run("cancelled", &[]);
    run.folded = Some(3);

    assert_eq!(words(&run), "3 runs cancelled");
}
