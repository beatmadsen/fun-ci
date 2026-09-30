//! Effects across whole rows (design.md, The console): a run's end washes its
//! row in the colour of how it ended, draining left to right; a band of light
//! travels along a running row; both leave the row's marks to their own
//! effects, and the banner under the table leaves the sky behind it.

use crate::support::boards::{board, event, last_screen, mark, row_of, run, then_ticks};
use fun_ci_renderer::grid::{Cell, Colour, Grid};
use fun_ci_renderer::table::sky::shade;

/// The cell of `branch`'s name on `screen`.
fn name(screen: &Grid, branch: &str) -> Cell {
    let row = row_of(screen, branch);
    let line = screen.text().lines().nth(row).unwrap().to_string();
    screen.cells[row][line[..line.find(branch).unwrap()].chars().count()].clone()
}

fn name_after(lines: &[String], ticks: usize) -> Cell {
    name(&last_screen(&then_ticks(lines, ticks)), "b1")
}

fn at_rest(lines: &[String]) -> Vec<String> {
    lines.iter().filter(|line| !line.contains("\"event\"")).cloned().collect()
}

fn failing() -> Vec<String> {
    vec![board(&[run(1, "failed", &[("lint", "passed"), ("build", "failed")])]), event("stage_failed", 1, "build")]
}

fn running() -> Vec<String> {
    vec![board(&[run(1, "running", &[("lint", "passed"), ("build", "running")])])]
}

#[test]
fn a_failure_washes_its_row_at_once() {
    assert_ne!(name_after(&failing(), 1).bg, name_after(&at_rest(&failing()), 1).bg);
}

#[test]
fn a_failure_s_wash_has_drained_after_a_second_and_a_half() {
    assert_eq!(name_after(&failing(), 15), name_after(&at_rest(&failing()), 15));
}

#[test]
fn a_stage_passing_mid_run_washes_nothing() {
    let lines = [board(&[run(1, "running", &[("lint", "passed")])]), event("stage_passed", 1, "lint")];

    assert_eq!(name_after(&lines, 1), name_after(&at_rest(&lines), 1));
}

#[test]
fn a_run_passing_washes_its_row() {
    let lines = [board(&[run(1, "passed", &[("lint", "passed"), ("build", "passed")])]), event("stage_passed", 1, "build")];

    assert_ne!(name_after(&lines, 1).bg, name_after(&at_rest(&lines), 1).bg);
}

#[test]
fn a_wash_leaves_the_marks_to_their_own_effects() {
    let lines = [board(&[run(1, "passed", &[("lint", "passed"), ("build", "passed")])]), event("stage_passed", 1, "build")];
    let (washed, rest) = (last_screen(&then_ticks(&lines, 1)), last_screen(&then_ticks(&at_rest(&lines), 1)));

    assert_eq!(mark(&washed, "b1", "build").bg, mark(&rest, "b1", "build").bg);
}

#[test]
fn a_band_of_light_lifts_a_running_row_s_name_as_it_passes() {
    assert_ne!(name_after(&running(), 4).fg, name_after(&running(), 10).fg);
}

#[test]
fn the_band_comes_round_again() {
    assert_eq!(name_after(&running(), 31).fg, name_after(&running(), 4).fg);
}

#[test]
fn the_band_leaves_a_running_row_s_marks_alone() {
    let (lit, unlit) = (last_screen(&then_ticks(&running(), 4)), last_screen(&then_ticks(&running(), 10)));

    assert_eq!(mark(&lit, "b1", "lint").fg, mark(&unlit, "b1", "lint").fg);
}

#[test]
fn a_row_that_stops_running_loses_its_band() {
    let passed = board(&[run(1, "passed", &[("lint", "passed"), ("build", "passed")])]);
    let stopped = [then_ticks(&running(), 1), vec![passed.clone()]].concat();

    assert_eq!(name_after(&stopped, 4), name_after(&[passed], 4));
}

#[test]
fn the_banner_leaves_the_sky_behind_it() {
    let screen = last_screen(&then_ticks(&failing(), 9));
    let row = screen.text().lines().position(|line| line.contains("FAILED")).unwrap();
    let [r, g, b] = shade(row - 14);

    assert_eq!(screen.cells[row][0].bg, Colour::Rgb(r, g, b));
}
