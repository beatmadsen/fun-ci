//! AT-7.5: with nothing queued and nothing running, the header rests on the
//! outcome of the latest run that passed or failed.

use serde_json::{Value, json};

use crate::support::boards::{board, run, then_ticks};
use crate::support::plain_scenes::{Plain, showing};

static SCENES: [Plain; 5] =
    [Plain("idle", None), Plain("running", None), Plain("calm", None), Plain("warning", None), Plain("success", Some(300))];

fn shown(runs: &[Value], events: &[String], count: usize) -> Vec<String> {
    showing(&SCENES, &then_ticks(&[&[board(runs)], events].concat(), count))
}

fn resting_on(runs: &[Value]) -> String {
    shown(runs, &[], 1).remove(0)
}

fn finished(id: u64, status: &str) -> Value {
    run(id, status, &[])
}

#[test]
fn should_rest_on_the_calm_scene_after_a_run_passed() {
    assert_eq!(resting_on(&[finished(2, "passed")]), "calm");
}

#[test]
fn should_rest_on_the_warning_scene_after_a_run_failed() {
    assert_eq!(resting_on(&[finished(2, "failed")]), "warning");
}

#[test]
fn should_rest_on_the_latest_finished_run() {
    assert_eq!(resting_on(&[finished(3, "failed"), finished(2, "passed")]), "warning");
}

#[test]
fn should_rest_calm_when_the_latest_finished_run_passed_after_an_older_one_failed() {
    assert_eq!(resting_on(&[finished(3, "passed"), finished(2, "failed")]), "calm");
}

#[test]
fn should_skip_cancelled_runs_when_choosing_what_to_rest_on() {
    assert_eq!(resting_on(&[finished(3, "cancelled"), finished(2, "passed")]), "calm");
}

#[test]
fn should_show_the_idle_scene_when_no_run_has_finished() {
    assert_eq!(resting_on(&[finished(3, "cancelled")]), "idle");
}

#[test]
fn should_show_the_running_scene_over_the_resting_one_while_a_run_runs() {
    assert_eq!(resting_on(&[run(3, "running", &[("fast", "running")]), finished(2, "failed")]), "running");
}

#[test]
fn should_rest_only_once_the_queued_scenes_have_played() {
    let passed = json!({"t": "event", "name": "run_passed", "run_id": 2, "animation": "success"}).to_string();
    let frames = shown(&[finished(2, "passed")], &[passed], 4);
    assert_eq!([&frames[0], &frames[3]], ["success", "calm"]);
}
