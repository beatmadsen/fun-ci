//! AT-7.5: with nothing queued and nothing running, the header rests on the
//! outcome of the latest run that passed or failed.

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::replay;
use serde_json::{Value, json};

use crate::support::boards::{board, run, then_ticks};

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

static SCENES: [Plain; 5] =
    [Plain("idle", None), Plain("running", None), Plain("calm", None), Plain("warning", None), Plain("success", Some(300))];

fn showing(runs: &[Value], events: &[String], count: usize) -> Vec<String> {
    let mut library = Library::default();
    for scene in &SCENES {
        library.insert(scene);
    }
    let lines = then_ticks(&[&[board(runs)], events].concat(), count);
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    replay(&messages, &library, (80, 24), Depth::TrueColour).into_iter().map(|frame| frame.showing).collect()
}

fn resting_on(runs: &[Value]) -> String {
    showing(runs, &[], 1).remove(0)
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
    let frames = showing(&[finished(2, "passed")], &[passed], 4);
    assert_eq!([&frames[0], &frames[3]], ["success", "calm"]);
}
