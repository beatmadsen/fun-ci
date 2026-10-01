//! What a daily or weekly job's row says (design.md, Daily and weekly jobs):
//! what its latest run did, on which branch and commit, and when it is due
//! again; or that it is due and runs on the next commit, since only a
//! commit starts it (acceptance-tests.md, AT-13.18).

use fun_ci_renderer::model::Job;
use fun_ci_renderer::table::job_words::{said, said_briefly};
use serde_json::{Value, json};

const NOW: i64 = 1_790_000_000;
const SHA: &str = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4";

fn job(status: &str, more: &Value) -> Job {
    let mut fields = json!({"name": "soak", "cadence": "weekly", "status": status});
    fields.as_object_mut().unwrap().extend(more.as_object().unwrap().clone());
    serde_json::from_value(fields).unwrap()
}

fn ran(status: &str, started_ago: i64, ended_ago: i64, due_in: Option<i64>) -> Job {
    let due = due_in.map_or(Value::Null, |seconds| json!(NOW + seconds));
    job(status, &json!({"run_id": 9, "sha": SHA, "branch": "wip/foo", "started_at": NOW - started_ago,
                        "updated_at": NOW - ended_ago, "due_at": due}))
}

fn words(job: &Job) -> String {
    said(job, NOW * 1000)
}

#[test]
fn a_failed_job_says_how_long_it_ran_on_which_commit_and_when_it_is_due_again() {
    assert_eq!(words(&ran("failed", 20_000, 8_480, Some(3 * 86_400))), "failed after 3h12m on wip/foo 9e0b1d4 · due in 3d");
}

#[test]
fn a_job_that_ran_out_of_time_says_so() {
    assert_eq!(words(&ran("timeout", 90_000, 3_600, Some(3_600))), "ran out of time after 1d on wip/foo 9e0b1d4 · due in 1h");
}

#[test]
fn a_running_job_says_how_long_it_has_run() {
    assert_eq!(words(&ran("running", 4_320, 4_320, None)), "running on wip/foo 9e0b1d4 · 1h12m");
}

#[test]
fn a_passed_job_says_when_it_is_due_again() {
    assert_eq!(words(&ran("passed", 36_000, 35_000, Some(50_400))), "passed on wip/foo 9e0b1d4 · due in 14h");
}

#[test]
fn a_job_that_ran_and_is_due_now_says_it_is_due() {
    assert_eq!(words(&ran("passed", 90_000, 89_000, None)), "passed on wip/foo 9e0b1d4 · due");
}

#[test]
fn a_due_job_says_it_runs_on_the_next_commit() {
    assert_eq!(words(&job("due", &json!({}))), "due · runs on your next commit");
}

#[test]
fn a_short_run_is_counted_in_seconds() {
    assert_eq!(words(&ran("failed", 50, 8, Some(86_400))), "failed after 42s on wip/foo 9e0b1d4 · due in 1d");
}

#[test]
fn a_run_under_an_hour_is_counted_in_minutes() {
    assert_eq!(words(&ran("failed", 3_000, 0, Some(86_400))), "failed after 50m on wip/foo 9e0b1d4 · due in 1d");
}

#[test]
fn what_is_still_to_come_is_rounded_up() {
    assert_eq!(words(&ran("passed", 36_000, 35_000, Some(50_401))), "passed on wip/foo 9e0b1d4 · due in 15h");
}

#[test]
fn a_day_less_a_few_seconds_away_is_a_day() {
    assert_eq!(words(&ran("passed", 36_000, 35_000, Some(86_395))), "passed on wip/foo 9e0b1d4 · due in 1d");
}

#[test]
fn an_hour_less_a_few_seconds_away_is_an_hour() {
    assert_eq!(words(&ran("passed", 36_000, 35_000, Some(3_595))), "passed on wip/foo 9e0b1d4 · due in 1h");
}

#[test]
fn a_lost_job_says_it_stopped_without_a_result() {
    assert_eq!(words(&ran("lost", 20_000, 20_000, Some(3 * 86_400))), "stopped without a result on wip/foo 9e0b1d4 · due in 3d");
}

#[test]
fn briefly_a_lost_job_says_it_has_no_result() {
    assert_eq!(said_briefly(&ran("lost", 20_000, 20_000, None), NOW * 1000), "stopped · no result");
}

/// A newer fun-ci, sharing the database, may send a state this one doesn't know.
#[test]
fn a_job_of_a_state_it_does_not_know_says_so() {
    assert_eq!(words(&ran("paused", 20_000, 20_000, None)), "in a state this fun-ci doesn't know");
}

#[test]
fn briefly_a_failed_job_says_how_long_it_ran() {
    assert_eq!(said_briefly(&ran("failed", 20_000, 8_480, Some(3 * 86_400)), NOW * 1000), "failed · 3h12m");
}

#[test]
fn briefly_a_passed_job_says_when_it_is_due_again() {
    assert_eq!(said_briefly(&ran("passed", 36_000, 35_000, Some(50_400)), NOW * 1000), "passed · due in 14h");
}

#[test]
fn briefly_a_due_job_says_it_runs_on_the_next_commit() {
    assert_eq!(said_briefly(&job("due", &json!({})), NOW * 1000), "due · next commit");
}
