//! How one run's row looks: its words, and the colours and attributes a
//! terminal shows them in, as the 1.x console's Cucumber features specified
//! them.

use fun_ci_renderer::grid::{Colour, Emulator, Grid};
use fun_ci_renderer::model::Run;
use fun_ci_renderer::row::format_run;
use serde_json::{Value, json};

const NOW_MS: i64 = 1_790_000_000_000;
const GREEN: Colour = Colour::Idx(2);
const RED: Colour = Colour::Idx(1);
const YELLOW: Colour = Colour::Idx(3);
const CYAN: Colour = Colour::Idx(6);

fn run(status: &str, stages: &Value) -> Value {
    json!({"id": 1, "sha": "a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4c6d8e01", "branch": "main", "status": status,
           "updated_at": 1_789_999_880, "stages": stages})
}

fn drawn(run: Value, spinner: char) -> Grid {
    let run: Run = serde_json::from_value(run).unwrap();
    let mut emulator = Emulator::new((200, 1));
    emulator.feed((200, 1), format_run(&run, NOW_MS, spinner).as_bytes());
    emulator.grid()
}

fn text(run: Value) -> String {
    drawn(run, 'x').text().trim_end().to_string()
}

/// The colour and attributes of the first cell of `word` in the row.
fn look(run: Value, word: &str) -> (Colour, Vec<&'static str>) {
    let grid = drawn(run, 'x');
    let row = grid.text();
    let column = row[..row.find(word).unwrap_or_else(|| panic!("no {word:?} in {row:?}"))].chars().count();
    let cell = &grid.cells[0][column];
    (cell.fg, cell.attrs.clone())
}

fn passed() -> Value {
    run("passed", &json!([{"stage": "lint", "status": "passed", "duration_ms": 300},
                         {"stage": "slow", "status": "passed", "duration_ms": 47_000}]))
}

fn failed() -> Value {
    run("failed", &json!([{"stage": "fast", "status": "failed", "duration_ms": 6_200}, {"stage": "slow", "status": "pending"}]))
}

fn timed_out() -> Value {
    run("timeout", &json!([{"stage": "fast", "status": "timeout", "duration_ms": 10_000}]))
}

fn running() -> Value {
    run("running", &json!([{"stage": "build", "status": "passed", "duration_ms": 200},
                          {"stage": "fast", "status": "running", "started_at": 1_789_999_997},
                          {"stage": "slow", "status": "pending"}]))
}

#[test]
fn a_passed_stage_shows_its_time_in_green() {
    assert_eq!(look(passed(), "Lint 0.3s"), (GREEN, vec![]));
}

#[test]
fn a_passed_run_says_passed_in_bold_green() {
    assert_eq!(look(passed(), "PASSED"), (GREEN, vec!["bold"]));
}

#[test]
fn a_failed_stage_says_fail_with_its_time_in_bold_red() {
    assert_eq!(look(failed(), "Fast FAIL 6.2s"), (RED, vec!["bold"]));
}

#[test]
fn a_failed_run_says_failed_in_bold_red() {
    assert_eq!(look(failed(), "FAILED"), (RED, vec!["bold"]));
}

#[test]
fn a_stage_never_reached_shows_dashes_in_dim() {
    assert_eq!(look(failed(), "Slow --"), (Colour::Default, vec!["dim"]));
}

#[test]
fn a_timed_out_stage_says_timeout_with_its_time_in_bold_yellow() {
    assert_eq!(look(timed_out(), "Fast TIMEOUT 10s"), (YELLOW, vec!["bold"]));
}

#[test]
fn a_timed_out_run_says_timed_out_in_bold_yellow() {
    assert_eq!(look(timed_out(), "TIMED OUT"), (YELLOW, vec!["bold"]));
}

#[test]
fn the_running_stage_shows_the_spinner_and_its_elapsed_seconds_in_cyan() {
    assert_eq!(look(running(), "Fast x 3s"), (CYAN, vec![]));
}

#[test]
fn a_running_run_says_running_in_bold_cyan() {
    assert_eq!(look(running(), "RUNNING"), (CYAN, vec!["bold"]));
}

#[test]
fn only_the_running_stage_shows_the_spinner() {
    assert!(text(running()).contains("Build 0.2s  Fast x 3s  Slow --"));
}

#[test]
fn the_time_since_the_run_changed_is_dim() {
    assert_eq!(look(passed(), "2m ago"), (Colour::Default, vec!["dim"]));
}

#[test]
fn a_scheduled_run_shows_no_stages() {
    assert_eq!(text(run("pending", &json!([{"stage": "lint", "status": "pending"}]))), "  a3f7c01  main  Scheduled...  2m ago");
}

#[test]
fn a_scheduled_run_is_dim_throughout() {
    assert_eq!(look(run("pending", &json!([])), "main"), (Colour::Default, vec!["dim"]));
}

#[test]
fn a_cancelled_run_says_cancelled_in_dim() {
    assert_eq!(look(run("cancelled", &json!([{"stage": "lint", "status": "passed", "duration_ms": 300}])), "CANCELLED"),
               (Colour::Default, vec!["dim"]));
}

#[test]
fn a_cancelled_run_shows_its_stage_times_without_colour() {
    assert_eq!(look(run("cancelled", &json!([{"stage": "lint", "status": "passed", "duration_ms": 300}])), "Lint 0.3s"),
               (Colour::Default, vec!["dim"]));
}
