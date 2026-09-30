//! What a row says happened, in fun-ci's own words (design.md, The console):
//! the stage by its full name, what happened to it and how long it took, so
//! a row reads to someone who has never seen fun-ci.

use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::words::{said, said_briefly};
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

    assert_eq!(words(&run), "the fast suite failed after 1.4s");
}

#[test]
fn a_failed_build_is_the_build() {
    assert_eq!(words(&run("failed", &[done("build", "failed", 900)])), "the build failed after 0.9s");
}

#[test]
fn a_failed_lint_is_lint() {
    assert_eq!(words(&run("failed", &[done("lint", "failed", 300)])), "lint failed after 0.3s");
}

#[test]
fn a_failure_without_a_duration_says_only_what_failed() {
    assert_eq!(words(&run("failed", &[json!({"stage": "slow", "status": "failed"})])), "the slow suite failed");
}

#[test]
fn a_timeout_names_its_stage_and_how_long_it_ran() {
    assert_eq!(words(&run("timeout", &[done("fast", "timeout", 10_000)])), "the fast suite ran out of time after 10s");
}

#[test]
fn a_running_run_names_its_stage_and_how_long_it_has_run() {
    assert_eq!(words(&run("running", &[done("lint", "passed", 300), going("build", 4)])), "running the build · 4s");
}

#[test]
fn two_stages_running_as_long_are_named_together() {
    assert_eq!(words(&run("running", &[going("fast", 7), going("slow", 7)])), "running the fast and slow suites · 7s");
}

#[test]
fn two_stages_running_for_different_times_each_have_their_own() {
    assert_eq!(words(&run("running", &[going("fast", 7), going("slow", 3)])), "running the fast suite 7s, the slow suite 3s");
}

#[test]
fn lint_and_the_build_running_as_long_are_named_together() {
    assert_eq!(words(&run("running", &[going("lint", 2), going("build", 2)])), "running lint and the build · 2s");
}

#[test]
fn a_passed_run_says_every_stage_passed() {
    assert_eq!(words(&run("passed", &[done("slow", "passed", 90_000)])), "all four stages passed");
}

#[test]
fn a_run_waiting_to_start_says_so() {
    assert_eq!(words(&run("pending", &[])), "waiting to start");
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

#[test]
fn a_row_standing_for_one_cancelled_run_says_cancelled() {
    let mut run = run("cancelled", &[]);
    run.folded = Some(1);

    assert_eq!(words(&run), "cancelled");
}

fn briefly(run: &Run) -> String {
    said_briefly(run, NOW * 1000)
}

#[test]
fn briefly_a_failure_still_names_its_stage_in_full() {
    assert_eq!(briefly(&run("failed", &[done("fast", "failed", 1_400)])), "fast suite failed · 1.4s");
}

#[test]
fn briefly_a_timeout_says_it_timed_out() {
    assert_eq!(briefly(&run("timeout", &[done("fast", "timeout", 10_000)])), "fast suite timed out · 10s");
}

#[test]
fn briefly_a_running_stage_is_named_in_full() {
    assert_eq!(briefly(&run("running", &[done("lint", "passed", 300), going("build", 4)])), "running build · 4s");
}

#[test]
fn briefly_the_two_suites_running_are_both_suites_at_the_longer_time() {
    assert_eq!(briefly(&run("running", &[going("fast", 3), going("slow", 7)])), "running both suites · 7s");
}

#[test]
fn briefly_lint_and_build_running_are_named_together_at_the_longer_time() {
    assert_eq!(briefly(&run("running", &[going("lint", 2), going("build", 3)])), "running lint and build · 3s");
}

#[test]
fn briefly_a_passed_run_says_all_passed() {
    assert_eq!(briefly(&run("passed", &[])), "all passed");
}

#[test]
fn briefly_a_run_waiting_to_start_says_so() {
    assert_eq!(briefly(&run("pending", &[])), "waiting to start");
}
