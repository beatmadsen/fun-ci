//! AT-7.5, AT-7.7: what the header rests on, from the runs and the clock.

use fun_ci_renderer::animator::{Outcome, Resting, resting};
use fun_ci_renderer::model::{Hidden, Run};
use serde_json::Value;

use crate::support::boards::run;

const NOW_MS: i64 = 1_790_000_000_000;

/// A run that ended with `status`, `ago` seconds before `NOW_MS`.
fn ended(status: &str, ago: i64) -> Run {
    let mut ended = run(1, status, &[]);
    ended["updated_at"] = Value::from(NOW_MS / 1000 - ago);
    serde_json::from_value(ended).unwrap()
}

#[test]
fn should_go_quiet_with_a_passed_lamp_five_minutes_after_a_run_passed() {
    assert_eq!(resting(&[ended("passed", 300)], NOW_MS), Resting::Quiet(Some(Outcome::Passed)));
}

#[test]
fn should_rest_calm_until_five_minutes_after_a_run_passed() {
    assert_eq!(resting(&[ended("passed", 299)], NOW_MS), Resting::Calm);
}

#[test]
fn should_rest_on_the_warning_until_five_minutes_after_a_run_failed() {
    assert_eq!(resting(&[ended("failed", 10)], NOW_MS), Resting::Warning);
}

#[test]
fn should_go_quiet_with_a_failed_lamp_five_minutes_after_a_run_failed() {
    assert_eq!(resting(&[ended("failed", 600)], NOW_MS), Resting::Quiet(Some(Outcome::Failed)));
}

#[test]
fn should_go_quiet_without_a_lamp_when_no_run_has_passed_or_failed() {
    assert_eq!(resting(&[ended("cancelled", 10)], NOW_MS), Resting::Quiet(None));
}

#[test]
fn should_count_a_run_that_timed_out_as_failed() {
    assert_eq!(resting(&[ended("timeout", 10)], NOW_MS), Resting::Warning);
}

#[test]
fn should_rest_on_the_run_that_finished_last_when_the_board_shows_an_older_failure_first() {
    let board_order = [ended("failed", 260_000), ended("passed", 10)];
    assert_eq!(resting(&board_order, NOW_MS), Resting::Calm);
}

#[test]
fn should_leave_a_hidden_run_out_of_the_latest_outcome() {
    let mut ignored = ended("failed", 10);
    ignored.hidden = Some(Hidden::Ignored);
    assert_eq!(resting(&[ignored, ended("passed", 600)], NOW_MS), Resting::Quiet(Some(Outcome::Passed)));
}

#[test]
fn should_rest_on_the_row_shown_first_when_two_runs_ended_in_the_same_second() {
    assert_eq!(resting(&[ended("failed", 10), ended("passed", 10)], NOW_MS), Resting::Warning);
}
