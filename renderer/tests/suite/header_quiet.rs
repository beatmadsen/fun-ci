//! AT-7.7: when nothing has run for a while, the header goes quiet.

use fun_ci_renderer::grid::{Cell, Colour};
use serde_json::{Value, json};

use crate::support::boards::{board, frames, last_screen, run, then_ticks};

const NOW: i64 = 1_790_000_000;
const QUIET: [&str; 6] = ["idle", "aurora", "fireflies", "fireplace", "island", "snowfall"];

/// A run that ended with `status`, `ago` seconds before the board's clock.
fn ended(status: &str, ago: i64) -> Value {
    let mut ended = run(1, status, &[]);
    ended["updated_at"] = Value::from(NOW - ago);
    ended
}

fn showing(runs: &[Value]) -> String {
    frames(&then_ticks(&[board(runs)], 1)).remove(0).showing
}

#[test]
fn should_show_a_quiet_scene_five_minutes_after_the_latest_run_finished() {
    // Given a run that passed five minutes ago, and nothing running since
    let runs = [ended("passed", 300)];

    // When the console draws
    let scene = showing(&runs);

    // Then the header has gone quiet
    assert!(QUIET.contains(&scene.as_str()), "expected a quiet scene, got {scene}");
}


/// The header cell the lamp lights, over the starry night, `ticks` after the board.
fn lamp_cell(runs: &[Value], ticks: usize) -> Cell {
    let pin = json!({"t": "event", "name": "pin", "animation": "idle"}).to_string();
    last_screen(&then_ticks(&[board(runs), pin], ticks)).cells[12][2].clone()
}

const RED: usize = 0;
const GREEN: usize = 1;

/// Whether one of the cell's colours leans towards `channel`: that channel well above the other two.
fn leans(cell: &Cell, channel: usize) -> bool {
    let rgb = |colour: &Colour| if let Colour::Rgb(r, g, b) = *colour { Some([r, g, b]) } else { None };
    let leaning = |c: [u8; 3]| (0..3).filter(|other| *other != channel).all(|other| c[channel] > c[other].saturating_add(40));
    [cell.fg, cell.bg].iter().filter_map(rgb).any(leaning)
}

#[test]
fn should_light_a_green_lamp_over_the_quiet_scene_after_a_run_passed() {
    // Given a run that passed ten minutes ago
    let runs = [ended("passed", 600)];

    // When the header has gone quiet
    let cell = lamp_cell(&runs, 2);

    // Then the lamp in its corner glows green
    assert!(leans(&cell, GREEN), "expected a green lamp, got {cell:?}");
}

#[test]
fn should_still_rest_on_the_outcome_just_before_five_minutes_have_passed() {
    assert_eq!(showing(&[ended("passed", 299)]), "calm");
}

#[test]
fn should_light_no_lamp_when_no_run_has_finished() {
    let cell = lamp_cell(&[], 2);
    assert!(!leans(&cell, GREEN) && !leans(&cell, RED), "expected no lamp, got {cell:?}");
}

/// What the header shows a tick after `later` follows a board gone quiet.
fn showing_after_quiet(later: &[Value]) -> String {
    let lines = [board(&[ended("passed", 300)]), crate::support::boards::TICK.to_string(), board(later)];
    frames(&then_ticks(&lines, 1)).pop().unwrap().showing
}

#[test]
fn should_leave_the_quiet_scene_for_the_rocket_when_a_run_starts() {
    let mut started = run(2, "running", &[("lint", "running")]);
    started["updated_at"] = Value::from(NOW);

    assert_eq!(showing_after_quiet(&[started, ended("passed", 300)]), "running");
}

#[test]
fn should_leave_the_quiet_scene_for_the_outcome_when_a_newer_run_passes() {
    let mut passed = run(2, "passed", &[("lint", "passed")]);
    passed["updated_at"] = Value::from(NOW);

    assert_eq!(showing_after_quiet(&[passed, ended("passed", 300)]), "calm");
}
