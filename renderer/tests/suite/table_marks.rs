//! A row's four marks, lint, build, fast and slow, each saying its stage's
//! state by shape as well as colour, in colours taken from the header's
//! night scenes.

use fun_ci_renderer::headless::palette::hue_sector;
use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::marks::marks;
use fun_ci_renderer::table::night;
use serde_json::{Value, json};

fn run(status: &str, stages: &[Value]) -> Run {
    serde_json::from_value(json!({"id": 1, "sha": "0", "branch": "main", "status": status, "updated_at": 0, "stages": stages}))
        .unwrap()
}

fn one(status: &str) -> Vec<Value> {
    vec![json!({"stage": "lint", "status": status})]
}

fn lint(run: &Run) -> (char, [u8; 3]) {
    marks(run, '⠹')[0]
}

#[test]
fn a_passed_stage_is_a_tick_in_the_passed_colour() {
    assert_eq!(lint(&run("running", &one("passed"))), ('✓', night::PASSED));
}

#[test]
fn a_failed_stage_is_a_diamond_in_the_failed_colour() {
    assert_eq!(lint(&run("failed", &one("failed"))), ('◆', night::FAILED));
}

#[test]
fn a_timed_out_stage_is_a_hollow_diamond_in_the_timeout_colour() {
    assert_eq!(lint(&run("timeout", &one("timeout"))), ('◇', night::TIMED_OUT));
}

#[test]
fn a_running_stage_is_the_spinner_in_the_running_colour() {
    assert_eq!(lint(&run("running", &one("running"))), ('⠹', night::RUNNING));
}

#[test]
fn a_stage_not_reached_is_a_quiet_dot() {
    assert_eq!(lint(&run("failed", &[])), ('·', night::QUIET));
}

#[test]
fn a_scheduled_run_s_stages_are_dotted_circles() {
    assert_eq!(lint(&run("pending", &[])), ('◌', night::QUIET));
}

#[test]
fn a_stage_cancelled_with_its_run_is_a_dash() {
    assert_eq!(lint(&run("cancelled", &one("cancelled"))), ('–', night::QUIET));
}

#[test]
fn a_stage_a_failure_stopped_is_a_dot_like_one_not_reached() {
    assert_eq!(lint(&run("failed", &one("cancelled"))), ('·', night::QUIET));
}

#[test]
fn the_marks_come_in_lint_build_fast_slow_order_whatever_order_they_arrive_in() {
    let stages = [json!({"stage": "slow", "status": "failed"}), json!({"stage": "lint", "status": "passed"})];

    assert_eq!(marks(&run("failed", &stages), '⠹').map(|(mark, _)| mark), ['✓', '·', '·', '◆']);
}

#[test]
fn passed_failed_timed_out_running_and_a_conflict_are_five_different_hues() {
    let hues = [night::PASSED, night::FAILED, night::TIMED_OUT, night::RUNNING, night::CONFLICT].map(hue_sector);

    assert!(hues.iter().enumerate().all(|(i, hue)| hue.is_some() && !hues[..i].contains(hue)), "{hues:?}");
}
