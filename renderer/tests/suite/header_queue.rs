//! AT-7.4: a run's milestones queue their scenes in the header, and each
//! plays to its end, in the order the events arrived.

use serde_json::{Value, json};

use crate::support::boards::{board, event, run, then_ticks};
use crate::support::plain_scenes::{Plain, showing};

/// Three ticks long.
const LENGTH: Option<u64> = Some(300);
static SCENES: [Plain; 6] = [
    Plain("idle", None),
    Plain("running", None),
    Plain("explosion", LENGTH),
    Plain("sweep", LENGTH),
    Plain("bricks", LENGTH),
    Plain("flash", LENGTH),
];

fn milestone(name: &str, scene: &str) -> String {
    milestone_of(1, name, scene)
}

fn milestone_of(run_id: u64, name: &str, scene: &str) -> String {
    json!({"t": "event", "name": name, "run_id": run_id, "animation": scene}).to_string()
}

fn after(runs: &[Value], events: &[String], count: usize) -> Vec<String> {
    showing(&SCENES, &then_ticks(&[&[board(runs)], events].concat(), count))
}

fn failed() -> Value {
    run(1, "failed", &[("fast", "failed")])
}

fn three_milestones() -> Vec<String> {
    vec![milestone("lint_passed", "sweep"), milestone("build_passed", "bricks"), milestone("fast_passed", "flash")]
}

#[test]
fn should_play_the_failure_scene_when_the_run_fails() {
    assert_eq!(after(&[failed()], &[milestone("run_failed", "explosion")], 1)[0], "explosion");
}

#[test]
fn should_leave_the_header_alone_when_only_a_stage_fails() {
    assert_eq!(after(&[failed()], &[event("stage_failed", 1, "fast")], 1), after(&[failed()], &[], 1));
}

#[test]
fn should_play_each_queued_scene_for_its_full_length_in_the_order_their_events_arrived() {
    let expected: Vec<&str> = [["sweep"; 3], ["bricks"; 3], ["flash"; 3]].concat();
    assert_eq!(after(&[run(1, "passed", &[])], &three_milestones(), 9), expected);
}

#[test]
fn should_play_the_scenes_of_different_runs_in_the_order_their_events_arrived() {
    let events = [milestone_of(2, "lint_passed", "sweep"), milestone_of(1, "build_passed", "bricks")];
    let frames = after(&[run(2, "running", &[]), run(1, "running", &[])], &events, 4);
    assert_eq!([&frames[0], &frames[3]], ["sweep", "bricks"]);
}

#[test]
fn should_not_cut_a_celebration_short_when_the_run_fails() {
    let events = [milestone("lint_passed", "sweep"), milestone("run_failed", "explosion")];
    assert_eq!(after(&[failed()], &events, 4)[2..], ["sweep", "explosion"]);
}

#[test]
fn should_show_the_running_scene_only_once_the_queue_is_empty() {
    let running = run(1, "running", &[("fast", "running")]);
    let frames = after(&[running], &[milestone("lint_passed", "sweep")], 4);
    assert_eq!([&frames[0], &frames[3]], ["sweep", "running"]);
}
