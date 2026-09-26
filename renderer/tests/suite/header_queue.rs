//! AT-7.4: a run's milestones queue their scenes in the header, and each
//! plays to its end, in the order the events arrived.

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::replay;
use serde_json::{Value, json};

use crate::support::boards::{board, event, run, then_ticks};

/// A plain scene, `length_ms` long, or looping without one.
#[derive(Debug)]
struct Plain(&'static str, Option<u64>);

impl Scene for Plain {
    fn name(&self) -> &'static str {
        self.0
    }

    fn length_ms(&self) -> Option<u64> {
        self.1
    }

    fn paint(&self, canvas: &mut Canvas, _t_ms: u64) {
        canvas.map(|_, _, _| [0.2, 0.2, 0.2]);
    }
}

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

fn showing(lines: &[String]) -> Vec<String> {
    let mut library = Library::default();
    for scene in &SCENES {
        library.insert(scene);
    }
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    replay(&messages, &library, (80, 24), Depth::TrueColour).into_iter().map(|frame| frame.showing).collect()
}

fn milestone(name: &str, scene: &str) -> String {
    json!({"t": "event", "name": name, "run_id": 1, "animation": scene}).to_string()
}

fn after(runs: &[Value], events: &[String], count: usize) -> Vec<String> {
    showing(&then_ticks(&[&[board(runs)], events].concat(), count))
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
fn should_play_queued_scenes_in_the_order_their_events_arrived() {
    let frames = after(&[run(1, "passed", &[])], &three_milestones(), 9);
    assert_eq!([&frames[0], &frames[3], &frames[6]], ["sweep", "bricks", "flash"]);
}

#[test]
fn should_play_each_queued_scene_for_its_full_length() {
    assert_eq!(after(&[run(1, "passed", &[])], &three_milestones(), 3), ["sweep"; 3]);
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
